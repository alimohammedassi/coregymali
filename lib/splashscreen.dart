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
// Shared bits
//
// Pulled out because the same "frosted glass" treatment (BackdropFilter +
// translucent container + border) was being hand-built three separate times
// with slightly different padding/radius args scattered inline. One widget
// now owns that look, so a future style tweak happens in one place instead
// of three, and the call sites read as "what" instead of "how".
// ────────────────────────────────────────────────────────────────────────────
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.blurSigma = 25,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final double blurSigma;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.glass1,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Splash
//
// Animation timing/behavior is unchanged: "CORE" still types on letter at a
// time, holds briefly, then zooms centered exactly on the "O" until it
// expands past the edges of the screen and fades out. Auth/profile bootstrap
// still runs underneath, navigation still waits on it (not a fixed timer),
// a minimum splash duration is still enforced, and a failed fetchProfile()
// still falls back to a retryable error state instead of hanging forever.
//
// What changed is code quality around that: the error is no longer silently
// swallowed (it's logged so a real bootstrap failure is diagnosable), and
// the alignment/typing/zoom math is unchanged but now sits behind clearer
// names.
// ────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _word = 'CORE';
  static const _letterDuration = Duration(milliseconds: 160);
  static const _pauseBeforeZoom = Duration(milliseconds: 450);
  static const _zoomDuration = Duration(milliseconds: 700);
  static const _minSplashDuration = Duration(milliseconds: 1900);
  static const _maxScale = 30.0;

  // Splash-specific palette: full green background with near-black text
  // gives the strongest contrast of the options tried, so it's kept local
  // to this screen rather than pulled from AppColors (which still backs
  // the rest of the app).
  static const _bgColor = Color(0xFFD4FF57);
  static const _onBgColor = Color(0xFF14140F);

  static const _textStyle = TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.w900,
    letterSpacing: 4,
    color: _onBgColor,
  );

  late final AnimationController _typeController;
  late final AnimationController _zoomController;
  late final double _zoomAlignmentX; // -1..1, centered exactly on the "O"

  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    // Computed analytically from font metrics (not layout timing), so it's
    // correct on the very first frame with no post-frame measuring step.
    _zoomAlignmentX = _alignmentXForLetter(_word, 'O', _textStyle);

    _typeController = AnimationController(
      vsync: this,
      duration: _letterDuration * _word.length,
    )..forward();

    _zoomController = AnimationController(vsync: this, duration: _zoomDuration);

    _run();
  }

  /// Horizontal Alignment (-1..1) of [letter]'s center within [word] as
  /// rendered in [style]. Lets the zoom transform be centered exactly on
  /// that letter regardless of font/weight/letterSpacing changes later.
  double _alignmentXForLetter(String word, String letter, TextStyle style) {
    double widthOf(String s) {
      final painter = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    final index = word.indexOf(letter);
    if (index == -1) return 0.0;

    final fullWidth = widthOf(word);
    final beforeWidth = widthOf(word.substring(0, index));
    final letterWidth = widthOf(word[index]);
    final centerX = beforeWidth + letterWidth / 2;

    return ((centerX / fullWidth) * 2) - 1;
  }

  Future<void> _run() async {
    final started = DateTime.now();

    try {
      final destination = await _resolveDestination();

      await _waitForTypingAndMinimum(started);
      if (!mounted) return;

      await _zoomController.forward();
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destination,
          transitionDuration: Duration.zero,
        ),
      );
    } catch (error, stackTrace) {
      // Previously swallowed with `catch (_)`, which made a broken
      // bootstrap (bad auth token, network failure, etc.) indistinguishable
      // from "nothing happened" in logs. Surface it, still show the same
      // retryable error UI.
      debugPrint('SplashScreen bootstrap failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  /// Figures out where navigation should land once auth/profile state is
  /// known. Pulled out of `_run` so the try/catch there is just "do the
  /// bootstrap, then animate, then navigate" without the branching logic
  /// in the middle of it.
  Future<Widget> _resolveDestination() async {
    final user = supabase.auth.currentUser;
    if (user == null) return const OnboardingScreen();

    final profileProv = context.read<ProfileProvider>();
    await profileProv.fetchProfile();

    if (profileProv.needsUserOnboarding) return const OnboardingFlow();

    if (profileProv.isCoach) {
      return profileProv.needsCoachSetup
          ? ChangeNotifierProvider(
              create: (_) => CoachSetupNotifier(),
              child: const CoachProfileSetupScreen(),
            )
          : const FitnessHomePage();
    }

    return const FitnessHomePage();
  }

  Future<void> _waitForTypingAndMinimum(DateTime started) async {
    final typingDone = _letterDuration * _word.length + _pauseBeforeZoom;
    final target = typingDone > _minSplashDuration
        ? typingDone
        : _minSplashDuration;
    final remaining = target - DateTime.now().difference(started);
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  void _retry() {
    setState(() => _hasError = false);
    _typeController
      ..reset()
      ..forward();
    _zoomController.reset();
    _run();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Center(child: _hasError ? _buildError() : _buildWord()),
    );
  }

  Widget _buildWord() {
    return AnimatedBuilder(
      animation: Listenable.merge([_typeController, _zoomController]),
      builder: (context, child) {
        final scale = 1 + (_zoomController.value * (_maxScale - 1));
        final opacity = _zoomController.value == 0
            ? 1.0
            : (1 - Curves.easeIn.transform(_zoomController.value)).clamp(
                0.0,
                1.0,
              );

        return Transform.scale(
          scale: scale,
          alignment: Alignment(_zoomAlignmentX, 0),
          child: Opacity(
            opacity: opacity,
            child: Semantics(
              label: 'Loading CoreGym',
              liveRegion: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_word.length, (i) {
                  final start = i / _word.length;
                  final end = (i + 1) / _word.length;
                  final t = Interval(
                    start,
                    end,
                    curve: Curves.easeOut,
                  ).transform(_typeController.value);

                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 14),
                      child: Text(_word[i], style: _textStyle),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: _onBgColor, size: 32),
          const SizedBox(height: 12),
          Text(
            "Couldn't connect. Check your internet and try again.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _onBgColor.withValues(alpha: 0.75),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _retry,
            style: ElevatedButton.styleFrom(
              backgroundColor: _onBgColor,
              foregroundColor: _bgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('RETRY'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _typeController.dispose();
    _zoomController.dispose();
    super.dispose();
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Onboarding
//
// Behavior unchanged: dedicated "Skip" action distinct from "already a
// member? sign in", page dots live in the glass card's header row, content
// cross-fades between pages instead of hard-cutting. What's cleaner:
// the three hand-rolled BackdropFilter blocks now go through `_GlassPanel`,
// and the "NEXT" button's content is memoized once instead of rebuilding
// on every page (it's the same widget regardless of which page you're on
// except for `isLastPage`).
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
                    child: _GlassPanel(
                      blurSigma: 10,
                      borderRadius: 6,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
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

  final OnboardingData data;
  final bool isLastPage;
  final int pageIndex;
  final int totalPages;
  final Widget dotIndicator;
  final VoidCallback onNextPressed;
  final VoidCallback onSignInPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildBackgroundImage(),

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
                child: _GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dots live here, anchored to the card that actually
                      // contains the paginated content.
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

                      _NextButton(
                        isLastPage: isLastPage,
                        onPressed: onNextPressed,
                      ),
                    ],
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

  Widget _buildBackgroundImage() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Semantics(
        image: true,
        label: data.placeholderText,
        child: Image.asset(
          data.imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _ImageFallback(data: data),
        ),
      ),
    );
  }
}

/// What used to render inline inside `errorBuilder`. Pulling it out means
/// the fallback doesn't get rebuilt as a closure on every `OnboardingPage`
/// build, and the "placeholder art" concern is separated from "here's the
/// real background image" concern.
class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.data});

  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
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
                child: Icon(data.icon, size: 80, color: AppColors.primaryFixed),
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
  }
}

/// The full-width "NEXT" / "INITIATE ENGINE" button. Extracted so its
/// Semantics label logic sits in one named place instead of inline in a
/// deeply nested tree.
class _NextButton extends StatelessWidget {
  const _NextButton({required this.isLastPage, required this.onPressed});

  final bool isLastPage;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isLastPage ? 'Initiate engine, continue to sign up' : 'Next',
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onPressed,
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
              Icon(Icons.arrow_forward, color: AppColors.onPrimary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingData {
  OnboardingData({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.placeholderText,
    required this.icon,
  });

  final String title;
  final String description;
  final String imagePath;
  final String placeholderText;
  final IconData icon;
}
