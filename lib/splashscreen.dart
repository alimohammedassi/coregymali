import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_sign_up.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_animations.dart';
import 'theme/app_colors.dart';
import 'theme/auth_app_text.dart';
import 'services/supabase_client.dart';

import 'screens/onboarding_flow.dart';
import 'fitness_home_pages.dart';

import 'features/coach/presentation/screens/coach_profile_setup_screen.dart';

import 'package:provider/provider.dart';
import 'features/coach/presentation/providers/coach_setup_provider.dart';
import 'providers/profile_provider.dart';

// NOTE: App entry is lib/main.dart → MyApp with providers + navigatorKey.
// The standalone demo `main()/MyApp` previously here created a SECOND
// MaterialApp definition and shadowed the real MyApp on import, which is
// confusing and can hide analyzer errors. Removed to keep a single entry point.

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
// Brand animation modeled on the owner's reference clip: two dumbbell
// capsules fly in from opposite corners, collide at the mark slot, morph
// into a four-lobe lime clover (with small violet/steel impact arcs), then
// the wordmark slides in beside the mark.
//
// Smoothness: ONE AnimationController drives everything through Interval
// curves; the capsules and impact arcs are a single CustomPaint behind one
// RepaintBoundary, so every frame is transform/alpha/arc work only — no
// layout, no image filters.
//
// Locale: the wordmark follows the app locale (which follows the device on
// first run). English animates "CoreGym" per letter with a violet→white
// sweep; Arabic renders «كور جيم» as ONE unit because per-letter animation
// would break cursive joining — it slides in as a whole word. The lockup
// mirrors for RTL via the MaterialApp-set Directionality.
//
// Bootstrap behavior unchanged: auth/profile resolution still runs under the
// animation, navigation still waits on it plus a minimum duration (so the
// animation always completes even on a fast network), and a failed
// fetchProfile() still falls back to a retryable error state instead of
// hanging forever.
// ────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _animDuration = Duration(milliseconds: 2600);
  static const _minSplashDuration = _animDuration;

  // Splash-local palette — the canvas stays dark in BOTH theme modes (it's
  // a brand moment, per the reference clip); accents ride the app tokens.
  static const _bgColor = AppColors.darkBackground;
  static const _ink = Color(0xFFF2F4EC);

  late final AnimationController _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animDuration)
      ..forward();
    _run();
  }

  Future<void> _run() async {
    final started = DateTime.now();

    try {
      final destination = await _resolveDestination();

      // A fast bootstrap must not cut the brand moment short — always let
      // the animation reach its hold state before navigating.
      final remaining = _minSplashDuration - DateTime.now().difference(started);
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
      // Completes immediately if the animation already finished.
      await _controller.forward();
      if (!mounted) return;

      Navigator.of(
        context,
      ).pushReplacement(FadeScalePageRoute(page: destination));
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

  void _retry() {
    setState(() => _hasError = false);
    _controller.forward(from: 0);
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: _bgColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final s = ((w < h ? w : h) / 390).clamp(0.85, 1.35).toDouble();

          // Mark slot: left of center in LTR, mirrored in RTL, so the
          // finished lockup (mark + wordmark) reads centered like the
          // reference clip.
          final focusX = isRtl ? 0.33 : -0.33;
          final markCx = w * (1 + focusX) / 2;
          final markCy = h / 2;
          final markR = 30 * s; // finished clover bounding radius
          final gap = 15 * s; // mark ↔ wordmark gap

          return Stack(
            children: [
              // Flying capsules + impact arcs — one paint layer.
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _SplashMarkPainter(
                      anim: _controller,
                      center: Offset(markCx, markCy),
                      scale: s,
                    ),
                  ),
                ),
              ),

              // Wordmark — anchored to the mark slot's inner edge.
              Positioned(
                top: 0,
                bottom: 0,
                left: isRtl ? null : markCx + markR + gap,
                right: isRtl ? w - markCx + markR + gap : null,
                child: Center(
                  child: Semantics(
                    label: isArabic ? 'جارٍ تحميل كور ' : 'Loading Core',
                    liveRegion: true,
                    textDirection: isArabic
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    excludeSemantics: true,
                    child: _Wordmark(
                      anim: _controller,
                      isArabic: isArabic,
                      scale: s,
                    ),
                  ),
                ),
              ),

              // Quiet loading cue while bootstrap finishes under the
              // animation, so a slow network reads as "loading", not stuck.
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) {
                      final t = Interval(
                        0.72,
                        0.88,
                        curve: Curves.easeOut,
                      ).transform(_controller.value);
                      return Opacity(
                        opacity: _hasError ? 0 : t,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.primaryFixed,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              if (_hasError) _buildError(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      left: 24,
      right: 24,
      bottom: 88,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1D16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _ink, size: 30),
            const SizedBox(height: 10),
            Text(
              l10n.splashError,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink.withValues(alpha: 0.75),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _retry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryFixed,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.retry.toUpperCase()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// The wordmark half of the splash lockup. English animates per letter with a
/// violet→white color sweep; Arabic animates as one unit (cursive joining
/// must never be split) sliding in from the mark's side.
class _Wordmark extends StatelessWidget {
  const _Wordmark({
    required this.anim,
    required this.isArabic,
    required this.scale,
  });

  final Animation<double> anim;
  final bool isArabic;
  final double scale;

  static const _arWord = 'كور ';
  static const _enWord = 'Core';
  static const _ink = Color(0xFFF2F4EC);
  static const _sweepFrom = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => isArabic ? _buildArabic() : _buildEnglish(),
    );
  }

  Widget _buildArabic() {
    final t = Interval(
      0.58,
      0.82,
      curve: Curves.easeOutCubic,
    ).transform(anim.value);
    return Opacity(
      opacity: t,
      child: Transform.translate(
        // Slides in from the mark's side — the mark is to the word's RIGHT
        // in the RTL lockup, so that's the +x direction on screen.
        offset: Offset((1 - t) * 18 * scale, 0),
        child: Transform.scale(
          scale: 0.97 + 0.03 * t,
          child: Text(
            _arWord,
            textDirection: TextDirection.rtl,
            style: GoogleFonts.cairo(
              fontSize: 29 * scale,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: _ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnglish() {
    final letters = _enWord.split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < letters.length; i++)
          _buildLetter(letters[i], i, letters.length),
      ],
    );
  }

  Widget _buildLetter(String ch, int i, int n) {
    const window = 0.16;
    final start = (0.58 + i * 0.024).clamp(0.0, 0.86 - window);
    final t = Interval(
      start,
      start + window,
      curve: Curves.easeOutCubic,
    ).transform(anim.value);
    return Opacity(
      opacity: t,
      child: Transform.translate(
        // Letters slide out from behind the mark (its left side in LTR).
        offset: Offset((1 - t) * -16 * scale, 0),
        child: Text(
          ch,
          style: GoogleFonts.poppins(
            fontSize: 31 * scale,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: Color.lerp(_sweepFrom, _ink, t),
          ),
        ),
      ),
    );
  }
}

/// Paints the two flying dumbbell capsules and their collision. Capsule A
/// comes from the upper-left; capsule B is the same shape rotated π around
/// the mark center (so it comes from the lower-right). On impact the gray
/// handles retract, the violet tips fade, and lime lobes grow on both ends —
/// two crossed lime stadiums = the four-lobe clover of the reference clip.
class _SplashMarkPainter extends CustomPainter {
  _SplashMarkPainter({
    required Animation<double> anim,
    required this.center,
    required this.scale,
  }) : _anim = anim,
       super(repaint: anim);

  final Animation<double> _anim;
  final Offset center;
  final double scale;

  static const _lime = Color(0xFFB2D742);
  static const _steel = Color(0xFFA9ADA0);
  static const _violet = Color(0xFF7E71E0);

  @override
  void paint(Canvas canvas, Size size) {
    final v = _anim.value;

    final flight = Interval(0.0, 0.30, curve: Curves.easeOutCubic).transform(v);
    final arcsT = Interval(0.22, 0.46, curve: Curves.easeOut).transform(v);
    final squashT = Interval(0.22, 0.40, curve: Curves.easeOut).transform(v);
    // easeOutBack overshoots (>1) on purpose — the lobes pop past their
    // resting size and settle, like the reference's collision squash.
    final morph = Interval(0.30, 0.58, curve: Curves.easeOutBack).transform(v);

    // Impact micro-bounce: the whole mark group pops on collision.
    final bounce = 1.0 + 0.10 * sin(pi * squashT);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(bounce, bounce);

    // Impact sparks — small violet/steel arcs flanking the mark, fading out.
    if (arcsT > 0 && arcsT < 1) {
      final fade = sin(pi * arcsT);
      final arcR = lerpDouble(15, 27, arcsT)! * scale;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4 * scale
        ..strokeCap = StrokeCap.round;
      stroke.color = _violet.withValues(alpha: 0.9 * fade);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: arcR),
        pi * 0.80,
        pi * 0.40,
        false,
        stroke,
      );
      stroke.color = _steel.withValues(alpha: 0.9 * fade);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: arcR),
        -pi * 0.20,
        pi * 0.40,
        false,
        stroke,
      );
    }

    final s = scale;
    final rLobe = 13.0 * s;
    final headX = lerpDouble(-26, -16, morph)! * s;
    final tailX = lerpDouble(28, 16, morph)! * s;
    final rTail = rLobe * morph.clamp(0.0, 1.0);
    final rTip = 6.5 * s * (1 - morph).clamp(0.0, 1.0);
    final barH = lerpDouble(9, 5, morph)! * s;
    // The handle retracts into the lobes as the clover forms — at rest the
    // mark is all lime, no gray residue at the center.
    final barLen = (tailX - headX) * (1 - morph.clamp(0.0, 1.0));

    for (var flip = 0; flip < 2; flip++) {
      final mirrored = flip == 1;
      canvas.save();

      // A flies in from the upper-left corner, B from the lower-right.
      final startPos = mirrored
          ? Offset(size.width * 0.42, size.height * 0.34)
          : Offset(-size.width * 0.42, -size.height * 0.34);
      final pos = Offset.lerp(startPos, Offset.zero, flight)!;
      final spin = (1 - flight) * 0.85;
      canvas.translate(pos.dx, pos.dy);
      // Rest axes are CROSSED (+45° and −45°) so the two capsules form the
      // four-lobe clover; the spin decays as each capsule arrives.
      final restAngle = mirrored ? -pi / 4 : pi / 4;
      canvas.rotate(restAngle - spin);

      // Gray handle — retracts to nothing as the clover forms.
      if (barLen > 0.5) {
        final bar = RRect.fromRectAndRadius(
          Rect.fromLTWH(headX, -barH / 2, barLen, barH),
          Radius.circular(barH / 2),
        );
        canvas.drawRRect(bar, Paint()..color = _steel);
      }
      // Lime lobes: the head is always there, the tail lobe grows on impact.
      canvas.drawCircle(Offset(headX, 0), rLobe, Paint()..color = _lime);
      if (rTail > 0.4) {
        canvas.drawCircle(Offset(tailX, 0), rTail, Paint()..color = _lime);
      }
      // Violet tip — visible only in flight, collapses into the mark.
      if (rTip > 0.4) {
        canvas.drawCircle(Offset(tailX, 0), rTip, Paint()..color = _violet);
      }
      canvas.restore();
    }

    canvas.restore();
  }

  // Repaints are driven by the animation via `super(repaint: anim)`.
  @override
  bool shouldRepaint(_SplashMarkPainter oldDelegate) => false;
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

  /// Page copy comes from l10n so the funnel follows the app/device language.
  List<OnboardingData> _pages(AppLocalizations l10n) => [
    OnboardingData(
      title: l10n.onb1Title,
      description: l10n.onb1Desc,
      imagePath: 'assets/images/unsplash_9MR78HGoflw.png',
      placeholderText: 'Workout Image 1',
      icon: Icons.fitness_center,
    ),
    OnboardingData(
      title: l10n.onb2Title,
      description: l10n.onb2Desc,
      imagePath: 'assets/images/unsplash_sHfo3WOgGTU.png',
      placeholderText: 'Pull-up Exercise',
      icon: Icons.person,
    ),
    OnboardingData(
      title: l10n.onb3Title,
      description: l10n.onb3Desc,
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
    final l10n = AppLocalizations.of(context)!;
    final pages = _pages(l10n);
    return Scaffold(
      backgroundColor: AppColors.surfaceLowest,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) => setState(() => currentPage = page),
            itemCount: pages.length,
            itemBuilder: (context, index) {
              return OnboardingPage(
                data: pages[index],
                isLastPage: index == pages.length - 1,
                pageIndex: index,
                totalPages: pages.length,
                dotIndicator: _buildDots(pages.length),
                onNextPressed: () => _handleNextPage(index, pages.length),
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
                        l10n.onbSkip.toUpperCase(),
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

  Widget _buildDots(int pageCount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        pageCount,
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

  void _handleNextPage(int currentIndex, int pageCount) {
    if (currentIndex == pageCount - 1) {
      _navigateToLogin();
    } else {
      _pageController.nextPage(
        duration: AppDurations.medium,
        curve: AppCurves.standard,
      );
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthWrapper(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child;
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: AppCurves.standard),
                ),
            child: child,
          );
        },
        transitionDuration: AppDurations.slow,
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
    final l10n = AppLocalizations.of(context)!;
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
                            color: AppColors.darkTextPrimary,
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
                  label: '${l10n.onbAlreadyMember} ${l10n.onbSignInLink}',
                  child: GestureDetector(
                    onTap: onSignInPressed,
                    child: RichText(
                      text: TextSpan(
                        style: AuthAppText.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        children: [
                          TextSpan(text: '${l10n.onbAlreadyMember} '),
                          TextSpan(
                            text: l10n.onbSignInLink,
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
              color: i == 1
                  ? AppColors.primaryFixed
                  : AppColors.darkTextPrimary,
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
      decoration: BoxDecoration(
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
    final l10n = AppLocalizations.of(context)!;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      label: isLastPage ? l10n.onbInitiate : l10n.onbNext,
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
                (isLastPage ? l10n.onbInitiate : l10n.onbNext).toUpperCase(),
                style: AuthAppText.buttonPrimary,
              ),
              const SizedBox(width: 10),
              Icon(
                // Forward means "toward the next screen" — which is the
                // left edge in RTL layouts.
                rtl ? Icons.arrow_back : Icons.arrow_forward,
                color: AppColors.onPrimary,
                size: 18,
              ),
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
