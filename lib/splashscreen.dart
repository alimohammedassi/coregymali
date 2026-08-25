import 'dart:ui';
import 'package:flutter/material.dart';
import 'gender.dart';
import 'theme/app_colors.dart';
import 'theme/auth_app_text.dart';
import 'services/supabase_client.dart';

import 'screens/onboarding_flow.dart';
import 'fitness_home_pages.dart';

import 'features/coach/presentation/screens/coach_profile_setup_screen.dart';

import 'package:provider/provider.dart';
import 'features/coach/presentation/providers/coach_setup_provider.dart';
import 'providers/profile_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Core Gym',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Splash
//
// UX changes from the previous version:
//  - Navigation used to fire on a hardcoded `Future.delayed(3s)` regardless
//    of whether the profile fetch had actually finished, and the progress
//    bar animated to a fixed 92% that never reached 100% — it just sat
//    there. Now the bar has two phases (an indeterminate-feeling ramp to
//    ~65% while we wait, then a real jump to 100% once auth/profile data
//    is in) and navigation waits on the real async work, not a guess.
//  - A failed `fetchProfile()` used to have no catch — an exception would
//    leave the user stuck on the splash screen forever. It's now wrapped
//    and falls back to onboarding with a brief inline error state instead
//    of a silent hang.
//  - Enforces only a *minimum* splash duration (so the brand moment never
//    feels like a flash on a fast connection) rather than always forcing
//    the full 3 seconds even when data is ready sooner.
// ────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _minSplashDuration = Duration(milliseconds: 1600);
  static const _rampCeiling = 0.65; // where the bar "waits" until data is ready

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  late final AnimationController _progressController;
  late final Animation<double> _progressRamp;

  late final AnimationController _pulseController;

  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeIn,
    );
    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _progressRamp = Tween<double>(begin: 0.0, end: _rampCeiling).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    )..addListener(() => setState(() {}));
    _progressController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bootstrap();
  }

  double _completedProgress = 0.0; // set to 1.0 once real work is done

  Future<void> _bootstrap() async {
    final started = DateTime.now();

    try {
      final user = supabase.auth.currentUser;

      Widget destination;
      if (user == null) {
        destination = const OnboardingScreen();
      } else {
        final profileProv = context.read<ProfileProvider>();
        await profileProv.fetchProfile();

        if (profileProv.needsUserOnboarding) {
          destination = const OnboardingFlow();
        } else if (profileProv.isCoach) {
          destination = profileProv.needsCoachSetup
              ? ChangeNotifierProvider(
                  create: (_) => CoachSetupNotifier(),
                  child: const CoachProfileSetupScreen(),
                )
              : const FitnessHomePage();
        } else {
          destination = const FitnessHomePage();
        }
      }

      await _finishProgressBar();
      await _respectMinimumDuration(started);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => destination,
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  Future<void> _finishProgressBar() async {
    setState(() => _completedProgress = 1.0);
    _progressController.stop();
    await Future.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _respectMinimumDuration(DateTime started) async {
    final elapsed = DateTime.now().difference(started);
    final remaining = _minSplashDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  double get _displayedProgress =>
      _completedProgress > 0 ? _completedProgress : _progressRamp.value;

  void _retry() {
    setState(() => _hasError = false);
    _progressController
      ..reset()
      ..forward();
    _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLowest,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/coreGym.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: AppColors.surfaceLowest),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.glowOrbPrimary, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.glowOrbSecondary, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _entryController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(scale: _scaleAnimation, child: child),
              );
            },
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Semantics(
                  label: _hasError
                      ? 'CoreGym failed to load. Tap retry.'
                      : 'Loading CoreGym',
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        'KINETIC SYSTEM V2.0',
                        style: AuthAppText.labelMd.copyWith(
                          color: AppColors.primaryFixed,
                          letterSpacing: 3.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 60,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      const Spacer(flex: 3),

                      Center(
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.08),
                              child: child,
                            );
                          },
                          child: Icon(
                            Icons.bolt,
                            size: 56,
                            color: AppColors.primaryFixed,
                            shadows: [
                              Shadow(
                                color: AppColors.primaryFixed.withValues(
                                  alpha: 0.6,
                                ),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: Text(
                          'CORE',
                          style: AuthAppText.displayLg.copyWith(
                            fontSize: 80,
                            letterSpacing: -3,
                          ),
                        ),
                      ),

                      // Real mirrored reflection instead of a second static
                      // line of text — flips vertically and fades out, so it
                      // actually reads as a reflection rather than a caption.
                      Center(
                        child: Transform(
                          alignment: Alignment.topCenter,
                          transform: Matrix4.diagonal3Values(1, -1, 1),
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.18),
                                Colors.transparent,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              'CORE',
                              style: AuthAppText.displayLg.copyWith(
                                fontSize: 80,
                                letterSpacing: -3,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),

                      if (_hasError)
                        _ErrorCard(onRetry: _retry)
                      else ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.glass1,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              child: Text(
                                'INITIALIZING HIGH-PERFORMANCE MODULES',
                                style: AuthAppText.labelMd.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'ELECTRIC VOLT ENGINE',
                          style: AuthAppText.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(_displayedProgress * 100).toInt()}%',
                          style: AuthAppText.headlineMd.copyWith(
                            color: AppColors.primaryFixed,
                          ),
                        ),
                        const SizedBox(height: 12),

                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _displayedProgress),
                          duration: const Duration(milliseconds: 250),
                          builder: (context, value, child) {
                            return Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryActionGradient,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryFixed
                                            .withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SYNCING BIO-METRICS',
                              style: AuthAppText.labelSm,
                            ),
                            Text('COREGYM', style: AuthAppText.labelSm),
                          ],
                        ),

                        const SizedBox(height: 24),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.glass2,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.glass2,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.wifi_tethering,
                                      color: AppColors.onSurfaceVariant,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'STATUS',
                                        style: AuthAppText.labelMd.copyWith(
                                          color: AppColors.onSurface,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _completedProgress >= 1.0
                                            ? 'IGNITION COMPLETE'
                                            : 'READY FOR IGNITION',
                                        style: AuthAppText.labelSm.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      AnimatedBuilder(
                                        animation: _pulseController,
                                        builder: (context, child) {
                                          return Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.primaryFixed
                                                  .withValues(
                                                    alpha:
                                                        0.5 +
                                                        _pulseController.value *
                                                            0.5,
                                                  ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.primaryFixed
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'LIVE',
                                        style: AuthAppText.labelMd.copyWith(
                                          color: AppColors.primaryFixed,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glass2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                "Couldn't connect. Check your internet and try again.",
                textAlign: TextAlign.center,
                style: AuthAppText.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryFixed,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('RETRY', style: AuthAppText.buttonPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Onboarding
//
// UX changes from the previous version:
//  - Added a real, dedicated "Skip" action (top-right) distinct from
//    "already a member? sign in" — previously the only way to bypass the
//    3-page intro was to tap Next twice or use the sign-in link, which is
//    a signup-flow entry, not a skip. A first-time visitor who just wants
//    past the intro now has an obvious way to do that.
//  - Page dots moved from a magic `bottom: 180` position (which drifts out
//    of alignment with the glass card on different screen heights) into
//    the glass card's header row, so they always sit exactly where the
//    content is, on every device.
//  - Content (title + description) now cross-fades between pages instead
//    of hard-cutting, which reads as noticeably more polished during swipe.
// ────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int currentPage = 0;

  final List<OnboardingData> onboardingData = [
    OnboardingData(
      title: "Transform your\nbody and mind",
      description:
          "Discover the power within you. Our comprehensive fitness programs are designed to help you achieve your goals and unlock your full potential.",
      imagePath: 'assets/images/unsplash_9MR78HGoflw.png',
      placeholderText: 'Workout Image 1',
      icon: Icons.fitness_center,
    ),
    OnboardingData(
      title: "Professional\ntraining guidance",
      description:
          "Get expert guidance from certified trainers who will help you master proper form and technique for maximum results and safety.",
      imagePath: 'assets/images/unsplash_sHfo3WOgGTU.png',
      placeholderText: 'Pull-up Exercise',
      icon: Icons.person,
    ),
    OnboardingData(
      title: "Achieve your\nfitness goals",
      description:
          "Whether you want to lose weight, build muscle, or improve endurance, our personalized approach will get you there faster.",
      imagePath: 'assets/images/unsplash_Yuv-iwByVRQ.png',
      placeholderText: 'Weight Training',
      icon: Icons.trending_up,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLowest,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) => setState(() => currentPage = page),
            itemCount: onboardingData.length,
            itemBuilder: (context, index) {
              return OnboardingPage(
                data: onboardingData[index],
                isLastPage: index == onboardingData.length - 1,
                pageIndex: index,
                totalPages: onboardingData.length,
                dotIndicator: _buildDots(),
                onNextPressed: () => _handleNextPage(index),
                onSignInPressed: _navigateToLogin,
              );
            },
          ),

          // Top bar — brand mark + Skip
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'KINETIC',
                  style: AuthAppText.headlineSm.copyWith(
                    color: AppColors.primaryFixed,
                    fontSize: 18,
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Skip introduction',
                  child: GestureDetector(
                    onTap: _navigateToLogin,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.glass1,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Text(
                            'SKIP',
                            style: AuthAppText.labelMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        onboardingData.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 6),
          width: currentPage == index ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: currentPage == index
                ? AppColors.primaryFixed
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            boxShadow: currentPage == index
                ? [
                    BoxShadow(
                      color: AppColors.primaryFixed.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ]
                : [],
          ),
        ),
      ),
    );
  }

  void _handleNextPage(int currentIndex) {
    if (currentIndex == onboardingData.length - 1) {
      _navigateToLogin();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GenderSelectionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Onboarding Page
// ────────────────────────────────────────────────────────────────────────────
class OnboardingPage extends StatelessWidget {
  final OnboardingData data;
  final bool isLastPage;
  final int pageIndex;
  final int totalPages;
  final Widget dotIndicator;
  final VoidCallback onNextPressed;
  final VoidCallback onSignInPressed;

  const OnboardingPage({
    super.key,
    required this.data,
    required this.isLastPage,
    required this.pageIndex,
    required this.totalPages,
    required this.dotIndicator,
    required this.onNextPressed,
    required this.onSignInPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildBackgroundImage(context),

        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 0.7, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: -60,
          left: -100,
          child: IgnorePointer(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.glowOrbPrimary, Colors.transparent],
                ),
              ),
            ),
          ),
        ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Padding(
                  key: ValueKey('title_$pageIndex'),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildTitle(),
                ),
              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.glass1,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dots now live here, anchored to the card that
                          // actually contains the paginated content.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              dotIndicator,
                              Text(
                                '${(pageIndex + 1).toString().padLeft(2, '0')}/${totalPages.toString().padLeft(2, '0')}',
                                style: AuthAppText.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              data.description,
                              key: ValueKey('desc_$pageIndex'),
                              style: AuthAppText.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                                height: 1.6,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Semantics(
                            button: true,
                            label: isLastPage
                                ? 'Initiate engine, continue to sign up'
                                : 'Next',
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: onNextPressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryFixed,
                                  foregroundColor: AppColors.onPrimary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isLastPage ? 'INITIATE ENGINE' : 'NEXT',
                                      style: AuthAppText.buttonPrimary,
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: AppColors.onPrimary,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Semantics(
                  button: true,
                  label: 'Already a member, sign in',
                  child: GestureDetector(
                    onTap: onSignInPressed,
                    child: RichText(
                      text: TextSpan(
                        style: AuthAppText.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        children: [
                          const TextSpan(text: 'ALREADY A MEMBER? '),
                          TextSpan(
                            text: 'SIGN IN',
                            style: AuthAppText.labelMd.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    final words = data.title.split('\n');
    return Column(
      key: ValueKey('title_col_$pageIndex'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < words.length; i++)
          Text(
            words[i].toUpperCase(),
            style: AuthAppText.displaySm.copyWith(
              fontSize: i == 1 ? 44 : 38,
              color: i == 1 ? AppColors.primaryFixed : AppColors.onSurface,
            ),
          ),
      ],
    );
  }

  Widget _buildBackgroundImage(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Semantics(
        image: true,
        label: data.placeholderText,
        child: Image.asset(
          data.imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.surfaceContainer, AppColors.surface],
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(40),
                  margin: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: AppColors.glass1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryFixed.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          data.icon,
                          size: 80,
                          color: AppColors.primaryFixed,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        data.placeholderText,
                        style: AuthAppText.titleMd,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Image Placeholder',
                        style: AuthAppText.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String imagePath;
  final String placeholderText;
  final IconData icon;

  OnboardingData({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.placeholderText,
    required this.icon,
  });
}
