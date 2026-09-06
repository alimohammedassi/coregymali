import 'package:flutter/material.dart';

// ────────────────────────────────────────────────────────────────────────────
// Motion tokens
//
// Single source of truth for the app's motion language, same role
// AppColors plays for color. Screens reference these instead of hardcoding
// `Duration(milliseconds: 300)` / `Curves.easeInOut` inline, so the rhythm
// stays consistent and can be retuned in one place.
//
// Rhythm:
//   fast   — micro-interactions: press feedback, toggles, checkmarks
//   medium — standard transitions: route push/pop, sheets, fills
//   slow   — large/settling moments only: splash hand-off, big surfaces
// ────────────────────────────────────────────────────────────────────────────
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
}

abstract final class AppCurves {
  /// Enter/expand — fast start, gentle settle.
  static const Curve standard = Curves.easeOutCubic;

  /// Two-way moves — theme cross-fade, layout morphs.
  static const Curve emphasized = Curves.easeInOutCubic;

  /// Exit/collapse — accelerate away.
  static const Curve exit = Curves.easeInCubic;
}

// ────────────────────────────────────────────────────────────────────────────
// Page transitions
//
// Applied app-wide via `pageTransitionsTheme` in main.dart, so every
// MaterialPageRoute picks it up without per-screen work. Incoming page
// fades in while settling a short slide from the trailing edge (flipped for
// RTL); the page being covered counter-slides slightly for depth parallax.
// With reduced-motion enabled the system setting wins: pages cut instead
// of animating.
// ────────────────────────────────────────────────────────────────────────────
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final double dir = Directionality.of(context) == TextDirection.rtl
        ? -1.0
        : 1.0;

    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: AppCurves.standard),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0.06 * dir, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: AppCurves.standard),
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: Offset(-0.03 * dir, 0),
          ).animate(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: AppCurves.emphasized,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Splash hand-off
//
// The splash ends on a solid lime frame, so instead of an abrupt cut into
// the destination the new page fades in over it while settling from a
// subtle scale-down — a "zoom completes into the app" feel.
//
// `opaque: false` guarantees the splash stays painted underneath for the
// whole transition, so the fade blends against the lime frame rather than
// a black canvas.
// ────────────────────────────────────────────────────────────────────────────
class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  FadeScalePageRoute({required Widget page})
    : super(
        pageBuilder: (_, __, ___) => page,
        opaque: false,
        transitionDuration: AppDurations.slow,
        transitionsBuilder: (context, animation, _, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child;

          final curved = CurvedAnimation(
            parent: animation,
            curve: AppCurves.standard,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );
}
