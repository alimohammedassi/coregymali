import 'dart:async';

import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';

import '../../../../providers/profile_provider.dart';
import '../../../../services/supabase_client.dart';
import '../../../../theme/app_colors.dart';
import '../../../../screens/onboarding_flow.dart';
import '../../../../fitness_home_pages.dart';
import '../../../../splashscreen.dart' show OnboardingScreen; // existing carousel onboarding
import '../../../../features/coach/presentation/screens/coach_profile_setup_screen.dart';
import '../../../../features/coach/presentation/providers/coach_setup_provider.dart';

/// Animated splash for CoreGym — Flutter level, after the native OS splash.
///
/// * Native splash (Android `launch_background` + iOS `LaunchScreen`) shows
///   `assets/splashscreen/logo_static.png` on `#121310` before the engine
///   starts — static PNG because the OS can't decode a GIF.
/// * This widget runs *after* the engine starts, so it can use
///   `assets/splashscreen/logo_animated.gif` with its built-in motion.
///
/// It uses `AnimatedSplashScreen.withScreenFunction` so the destination is
/// resolved async and we land directly on the right screen without a double
/// navigation flash. The async check reuses the exact same code path as the
/// old `SplashScreen._resolveDestination` — Supabase session + `ProfileProvider`
/// + `OnboardingService` via `ProfileProvider.fetchProfile()`.
///
/// Background is `AppColors.darkBackground` / `#121310` — the same value as
/// `android/app/src/main/res/values/colors.xml` `launch_bg` and the old
/// `_SplashScreenState._bgColor` — so native → animated → app UI has no flash.
/// Transition is `fadeTransition` (calm, no gimmick) and total visible time is
/// kept to ~2.6s (800ms animation + ~1800ms duration) — the GIF loops if the
/// async check takes longer, so it never freezes on its last frame.
class AnimatedCoreSplash extends StatelessWidget {
  const AnimatedCoreSplash({super.key});

  // Keep the whole splash short — GIF itself loops (Image.asset GIFs repeat),
  // so a slow network doesn't freeze the screen, it just keeps looping.
  static const _bg = Color(0xFF121310); // == AppColors.darkBackground == launch_bg
  static const _durationMs = 1800; // plus 800ms animation → ~2.6s visible
  static const _animDuration = Duration(milliseconds: 800);
  static const double _iconSize = 260;

  Future<Widget> _resolve(BuildContext context) async {
    // Mirror SplashScreen._resolveDestination exactly — so this file and
    // splashscreen.dart never drift. Any future auth/onboarding change needs
    // to be made in only one place; keep them in sync.
    //
    // Existing source of truth:
    //  - Supabase session: `supabase.auth.currentUser` (supabase_client.dart: currentUserId / supabase)
    //  - Onboarding flag: `OnboardingService.isCompleted()` via `ProfileProvider.fetchProfile()`
    //    which also resolves role (`profiles.role`) and coach setup (`coach_onboarding.is_completed`)
    //  - ProfileProvider state: `needsUserOnboarding`, `isCoach`, `needsCoachSetup` (profile_provider.dart)
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return const OnboardingScreen();

      // `fetchProfile` is the canonical resolver used everywhere (splashscreen.dart,
      // main auth flows). It does: `OnboardingService().isCompleted()` +
      // `profiles.role` + `coach_onboarding.is_completed` in parallel.
      // We read the provider without listening so the splash doesn't rebuild
      // mid-resolve.
      final profileProv = context.read<ProfileProvider>();

      // Give the async work a hard ceiling so the splash never hangs
      // indefinitely on an offline device — 4s covers a slow 3G round-trip
      // but still lets the error-fallback screen appear promptly.
      await profileProv.fetchProfile().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('AnimatedCoreSplash: fetchProfile timed out');
        },
      );

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
    } catch (e, st) {
      debugPrint('AnimatedCoreSplash resolve failed: $e\n$st');
      // Fallback — don't strand user on splash. OnboardingScreen is safe for
      // unauthenticated, FitnessHomePage would redirect anyway; onboarding
      // avoids leaking authed UI when profile fetch failed.
      return const OnboardingScreen();
    }
  }

  Widget _splashWidget(BuildContext context) {
    // Netflix-style: static PNG holds first (matches native splash exactly,
    // so OS → Flutter handoff is seamless), then crossfades to the animated
    // GIF which plays its built-in motion. Uses everything in
    // assets/splashscreen/ — native showed PNG, Flutter re-shows PNG then GIF.
    return const _NetflixSequence();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedSplashScreen captures BuildContext at build time for its internal
    // Navigator; screenFunction closure captures the same context so Provider
    // reads work. `withScreenFunction` awaits `_resolve` then waits `duration`
    // before navigating — total visible = animation (800ms) + duration + resolve.
    return AnimatedSplashScreen.withScreenFunction(
      splash: _splashWidget(context),
      screenFunction: () => _resolve(context),
      backgroundColor: _bg,
      splashTransition: SplashTransition.fadeTransition,
      animationDuration: _animDuration,
      splashIconSize: _iconSize,
      duration: _durationMs,
      curve: Curves.easeOutCubic,
      centered: true,
      pageTransitionType: PageTransitionType.fade,
      // If resolve is instant (cached session), we still show the GIF for
      // at least `duration` so the brand moment isn't skipped.
    );
  }
}

/// Netflix-style sequence that uses *everything* in `assets/splashscreen/`:
///
/// 1. Shows `logo_static.png` first (≈ 700 ms, faded/scaled in) — this is
///    pixel-identical to the native `launch_background` PNG, so the OS splash
///    → Flutter splash cut is invisible.
/// 2. Crossfades to `logo_animated.gif` (its built-in motion) and holds it
///    for the remainder, looping if `screenFunction` takes longer than the
///    animation so it never freezes on the last frame.
///
/// Total fits inside `AnimatedSplashScreen`'s `animationDuration (800) +
/// duration (1800) ≈ 2.6s` brand moment — same timing as the previous custom
/// `_SplashMarkPainter` brand animation, just driven by the real GIF now.
class _NetflixSequence extends StatefulWidget {
  const _NetflixSequence();

  @override
  State<_NetflixSequence> createState() => _NetflixSequenceState();
}

class _NetflixSequenceState extends State<_NetflixSequence>
    with SingleTickerProviderStateMixin {
  bool _showGif = false;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _pngFade;
  late final Animation<double> _pngScale;
  late final Animation<double> _gifFade;

  // Timings tuned to feel like Netflix N → ribbon: static holds, then
  // animated takes over. Keep total PNG phase short so brand moment stays
  // within 2.5–3 s.
  static const _pngHold = Duration(milliseconds: 700);
  static const _crossFade = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pngFade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _pngScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic),
    );
    _gifFade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInCubic);

    // PNG entrance — scale/fade in immediately (native → Flutter handoff
    // already shows static, so this is a subtle re-affirm, not a flash).
    _fadeCtrl.forward();

    // After hold, switch to GIF and drive crossfade.
    Future.delayed(_pngHold, () {
      if (!mounted) return;
      setState(() => _showGif = true);
      _fadeCtrl
        ..value = 0
        ..animateTo(1, duration: _crossFade, curve: Curves.easeOut);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache both so PNG → GIF has no decode hitch on first frame.
    precacheImage(
      const AssetImage('assets/splashscreen/logo_static.png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/splashscreen/logo_animated.gif'),
      context,
    );
    // Also pre-cache original Arabic-named files (same bytes, different path)
    // so `assets/splashscreen/` is fully utilized regardless of which path
    // is referenced elsewhere.
    precacheImage(
      const AssetImage('assets/splashscreen/تطبيق كور (1).png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/splashscreen/تطبيق كور.gif'),
      context,
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Both assets sized identically so crossfade has no jump — 200×200 is
    // the GIF's natural logo bounds; PNG is same logo transparent.
    const double logoSize = 200;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: logoSize,
          height: logoSize,
          child: AnimatedSwitcher(
            duration: _crossFade,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: _showGif
                ? FadeTransition(
                    key: const ValueKey('gif'),
                    opacity: _gifFade,
                    child: Image.asset(
                      'assets/splashscreen/logo_animated.gif',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/splashscreen/logo_static.png',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                : FadeTransition(
                    key: const ValueKey('png'),
                    opacity: _pngFade,
                    child: ScaleTransition(
                      scale: _pngScale,
                      child: Image.asset(
                        'assets/splashscreen/logo_static.png',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        // Loader stays for the whole sequence — reads as "loading" if the
        // async `screenFunction` (Supabase + onboarding) takes longer than
        // the brand animation, so it never looks stuck on GIF's last frame.
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryFixed),
            backgroundColor: Colors.white.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

/// Optional: keep the old route name working — redirect legacy `SplashScreen`
/// pushes to the animated version without duplicating resolve logic.
/// Not used by `main.dart` anymore (which now points at `AnimatedCoreSplash`
/// directly) but handy for deep-links/tests that still reference `SplashScreen`.
class SplashScreenCompat extends StatelessWidget {
  const SplashScreenCompat({super.key});

  @override
  Widget build(BuildContext context) => const AnimatedCoreSplash();
}
