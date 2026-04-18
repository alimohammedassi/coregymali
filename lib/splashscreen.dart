import 'dart:ui';
import 'package:flutter/material.dart';
import 'gender.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';
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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.92).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _animationController.forward();
    _progressController.forward();

    // Navigate after 3 seconds
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      final user = supabase.auth.currentUser;
      if (user == null) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const OnboardingScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        final profileProv = context.read<ProfileProvider>();
        await profileProv.fetchProfile();
        if (!mounted) return;

        if (profileProv.needsUserOnboarding) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingFlow()),
          );
        } else if (profileProv.isCoach) {
          if (profileProv.needsCoachSetup) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => CoachSetupNotifier(),
                  child: const CoachProfileSetupScreen(),
                ),
              ),
            );
          } else {
            // "NEVER send a coach to a subscription page... /home (with coach nav bar)"
            // Notice: the requirements say /home contains the coach tab!
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const FitnessHomePage()),
            );
          }
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const FitnessHomePage()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLowest,
      body: Stack(
        children: [
          // Background gym image with dark overlay
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
          // Primary glow orb top-right
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
                    colors: [
                      AppColors.glowOrbPrimary,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Content
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 40),
                          // Top branding
                          Text(
                            'KINETIC SYSTEM V2.0',
                            style: AppText.labelMd.copyWith(
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

                          // Bolt icon
                          Center(
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: 1.0 + (_pulseController.value * 0.08),
                                  child: Icon(
                                    Icons.bolt,
                                    size: 56,
                                    color: AppColors.primaryFixed,
                                    shadows: [
                                      Shadow(
                                        color: AppColors.primaryFixed.withValues(alpha: 0.6),
                                        blurRadius: 30,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // CORE title
                          Center(
                            child: Text(
                              'CORE',
                              style: AppText.displayLg.copyWith(
                                fontSize: 80,
                                letterSpacing: -3,
                              ),
                            ),
                          ),

                          // Ghost reflection text
                          Center(
                            child: ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.15),
                                  Colors.transparent,
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'CORE',
                                style: AppText.displayLg.copyWith(
                                  fontSize: 64,
                                  letterSpacing: -3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const Spacer(flex: 2),

                          // Status pill
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
                                  style: AppText.labelMd.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Progress section
                          Text(
                            'ELECTRIC VOLT ENGINE',
                            style: AppText.labelMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              return Text(
                                '${(_progressAnimation.value * 100).toInt()}%',
                                style: AppText.headlineMd.copyWith(
                                  color: AppColors.primaryFixed,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Progress bar
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              return Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _progressAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryActionGradient,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryFixed.withValues(alpha: 0.5),
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

                          // Sub labels
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('SYNCING BIO-METRICS', style: AppText.labelSm),
                              Text('COREGYM', style: AppText.labelSm),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Status card
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.glass2,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.glassBorder),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'STATUS',
                                          style: AppText.labelMd.copyWith(
                                            color: AppColors.onSurface,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'READY FOR IGNITION',
                                          style: AppText.labelSm.copyWith(
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
                                                color: AppColors.primaryFixed.withValues(
                                                  alpha: 0.5 + _pulseController.value * 0.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.primaryFixed.withValues(alpha: 0.4),
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
                                          style: AppText.labelMd.copyWith(
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
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<String?> _getUserRole() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      return response['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Onboarding
// ────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int currentPage = 0;

  List<OnboardingData> onboardingData = [
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLowest,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                currentPage = page;
              });
            },
            itemCount: onboardingData.length,
            itemBuilder: (context, index) {
              return OnboardingPage(
                data: onboardingData[index],
                isLastPage: index == onboardingData.length - 1,
                pageIndex: index,
                totalPages: onboardingData.length,
                onNextPressed: () => _handleNextPage(index),
                onSkipPressed: () => _navigateToLogin(),
              );
            },
          ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'KINETIC',
                  style: AppText.headlineSm.copyWith(
                    color: AppColors.primaryFixed,
                    fontSize: 18,
                  ),
                ),
                // Page counter pill
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.glass1,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primaryFixed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${(currentPage + 1).toString().padLeft(2, '0')}/${onboardingData.length.toString().padLeft(2, '0')}',
                        style: AppText.labelMd.copyWith(
                          color: AppColors.primaryFixed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Page indicator (dots)
          Positioned(
            bottom: 180,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                onboardingData.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentPage == index
                        ? AppColors.primaryFixed
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: currentPage == index
                        ? [
                            BoxShadow(
                              color: AppColors.primaryFixed.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                ),
              ),
            ),
          ),
        ],
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
  final VoidCallback onNextPressed;
  final VoidCallback onSkipPressed;

  const OnboardingPage({
    super.key,
    required this.data,
    required this.isLastPage,
    required this.pageIndex,
    required this.totalPages,
    required this.onNextPressed,
    required this.onSkipPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image
        _buildBackgroundImage(context),

        // Dark gradient overlay
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

        // Primary glow orb
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
                  colors: [
                    AppColors.glowOrbPrimary,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Content overlay at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title — bleeds off edges
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildTitle(),
              ),

              const SizedBox(height: 8),

              // Accent bar
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

              // Glass bottom card
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
                        border: Border.all(
                          color: AppColors.glassBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Handle bar
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          Text(
                            data.description,
                            style: AppText.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // CTA Button — Electric Volt
                          SizedBox(
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
                                    isLastPage
                                        ? 'INITIATE ENGINE'
                                        : 'NEXT',
                                    style: AppText.buttonPrimary,
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Already a member
              Center(
                child: GestureDetector(
                  onTap: onSkipPressed,
                  child: RichText(
                    text: TextSpan(
                      style: AppText.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      children: [
                        const TextSpan(text: 'ALREADY A MEMBER? '),
                        TextSpan(
                          text: 'SIGN IN',
                          style: AppText.labelMd.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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
            style: AppText.displaySm.copyWith(
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
                      style: AppText.titleMd,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Image Placeholder',
                      style: AppText.bodySm.copyWith(
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

class LoginPlaceholder extends StatelessWidget {
  const LoginPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLowest,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryFixed.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGlow,
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: AppColors.primaryFixed,
                        size: 60,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('CORE', style: AppText.displayMd),
                    Text(
                      'GYM',
                      style: AppText.labelLg.copyWith(
                        color: AppColors.primaryFixed,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: AppColors.glass1,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.login,
                            color: AppColors.primaryFixed,
                            size: 40,
                          ),
                          const SizedBox(height: 16),
                          Text('Login Screen', style: AppText.headlineSm),
                          const SizedBox(height: 8),
                          Text(
                            'Replace this with your\nlogin page implementation',
                            style: AppText.bodyMd,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Implement your login logic here'),
                                backgroundColor: AppColors.primaryFixed,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryFixed,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text('CONTINUE TO LOGIN', style: AppText.buttonPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
