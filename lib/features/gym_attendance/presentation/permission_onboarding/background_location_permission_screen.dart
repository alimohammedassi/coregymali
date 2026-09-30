import 'dart:ui' show lerpDouble;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_animations.dart';
import '../../../../theme/app_colors.dart';
import 'permission_onboarding_step.dart';

/// Step 2 — Background ("all the time") location permission.
///
/// On Android 11+ a plain `denied` can come back even when when-in-use is
/// granted (the OS routes through Settings), so BOTH denied flavours land in
/// the friendly state with Open Settings as the primary action — retrying in
/// place cannot help there. Granted still flashes the success state for
/// ~600 ms before [onContinue].
class BackgroundLocationPermissionScreen extends StatefulWidget {
  const BackgroundLocationPermissionScreen({
    super.key,
    required this.onContinue,
    this.onSkip,
  });

  final VoidCallback onContinue;
  final VoidCallback? onSkip;

  @override
  State<BackgroundLocationPermissionScreen> createState() =>
      _BackgroundLocationPermissionScreenState();
}

enum _Phase { idle, denied, permanentlyDenied, granted }

class _BackgroundLocationPermissionScreenState
    extends State<BackgroundLocationPermissionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glyph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  _Phase _phase = _Phase.idle;
  bool _busy = false;

  @override
  void dispose() {
    _glyph.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_busy || _phase == _Phase.granted) return;
    setState(() => _busy = true);

    final status = await Permission.locationAlways.request();

    if (!mounted) return;
    setState(() => _busy = false);
    _resolve(status);
  }

  void _resolve(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      setState(() => _phase = _Phase.granted);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) widget.onContinue();
      });
    } else if (status.isPermanentlyDenied || status.isRestricted) {
      setState(() => _phase = _Phase.permanentlyDenied);
    } else {
      // Android 11+: plain denied after the Settings hand-off — same
      // friendly state, Open Settings primary.
      setState(() => _phase = _Phase.denied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final denied = _phase == _Phase.denied ||
        _phase == _Phase.permanentlyDenied;

    return PermissionOnboardingStep(
      animation: _BackgroundTrackingGlyph(controller: _glyph),
      title: denied ? l10n.gymAttPermDeniedTitle : l10n.gymAttBgTitle,
      body: denied ? l10n.gymAttPermDeniedBody : l10n.gymAttBgBody,
      whyLine: l10n.gymAttBgWhy,
      granted: _phase == _Phase.granted,
      primaryLabel: switch (_phase) {
        _Phase.idle => l10n.gymAttPermAllow,
        _Phase.denied ||
        _Phase.permanentlyDenied => l10n.gymAttOpenSettings,
        _Phase.granted => l10n.gymAttPermGranted,
      },
      onPrimary: switch (_phase) {
        _Phase.idle => _request,
        _Phase.denied ||
        _Phase.permanentlyDenied => openAppSettings,
        _Phase.granted => widget.onContinue,
      },
      secondaryLabel: denied
          ? l10n.gymAttContinueWithout
          : l10n.gymAttPermSkip,
      onSecondary: denied ? widget.onContinue : widget.onSkip,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glyph — visually distinct from the map step: an app-icon-like rounded
// square fades toward the background (dimmed, slightly receded) while a small
// location dot stays awake in front of it, pulsing, with a tiny geofence ring
// that keeps emitting quiet pings — "tracking continues while the app is
// backgrounded".
// ─────────────────────────────────────────────────────────────────────────────
class _BackgroundTrackingGlyph extends StatelessWidget {
  final AnimationController controller;

  const _BackgroundTrackingGlyph({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return CustomPaint(
        size: const Size(250, 215),
        painter: _BackgroundTrackingPainter(0.5),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        size: const Size(250, 215),
        painter: _BackgroundTrackingPainter(controller.value),
      ),
    );
  }
}

class _BackgroundTrackingPainter extends CustomPainter {
  final double t;

  _BackgroundTrackingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.46);
    final squareSize = size.width * 0.44;

    // App-icon-like rounded square — recedes to ~35% presence and a slight
    // scale-down, then eases back each cycle so the dim reads as motion.
    final dimT = Interval(0.0, 0.30, curve: AppCurves.emphasized).transform(t);
    final liftT = Interval(0.88, 1.0, curve: AppCurves.standard).transform(t);
    final presence = 1.0 - 0.65 * dimT + 0.65 * liftT;
    final scale = 1.0 - 0.04 * dimT + 0.04 * liftT;

    final squareRect = Rect.fromCenter(
      center: center,
      width: squareSize * scale,
      height: squareSize * scale,
    );
    final squareRRect = RRect.fromRectAndRadius(
      squareRect,
      Radius.circular(squareSize * 0.26),
    );
    canvas.drawRRect(
      squareRRect,
      Paint()..color = AppColors.surfaceContainerHigh.withValues(
        alpha: presence,
      ),
    );
    canvas.drawRRect(
      squareRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.glassBorder.withValues(alpha: presence),
    );

    // Inner abstract mark — a quiet ring + core so it reads "app", not box.
    canvas.drawCircle(
      center,
      squareSize * 0.18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accent.withValues(alpha: 0.45 * presence),
    );
    canvas.drawCircle(
      center,
      squareSize * 0.06,
      Paint()..color = AppColors.accent.withValues(alpha: 0.55 * presence),
    );

    // Awake location dot, anchored to the square's bottom-trailing corner.
    final dot = Offset(
      squareRect.right - squareSize * 0.10,
      squareRect.bottom - squareSize * 0.02,
    );
    final breathe = math.sin(t * 2 * math.pi);
    final dotR = 7.0 + 1.6 * breathe;
    canvas.drawCircle(
      dot,
      dotR + 8,
      Paint()..color = AppColors.accent.withValues(alpha: 0.12 + 0.05 * breathe),
    );
    canvas.drawCircle(
      dot,
      dotR,
      Paint()..color = AppColors.accent,
    );
    canvas.drawCircle(
      dot,
      dotR * 0.42,
      Paint()..color = AppColors.onPrimary,
    );

    // Tiny geofence ring holding steady around the dot.
    canvas.drawCircle(
      dot,
      20 + 1.5 * breathe,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accent.withValues(alpha: 0.40 + 0.20 * breathe),
    );

    // Quiet sonar ping leaving the ring — detection reaching out.
    final pingT = (t % 0.5) / 0.5;
    final pingPhase = Interval(0.0, 1.0, curve: AppCurves.standard)
        .transform(pingT);
    canvas.drawCircle(
      dot,
      lerpDouble(20, 40, pingPhase)!,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.accent.withValues(alpha: (1 - pingPhase) * 0.25),
    );
  }

  @override
  bool shouldRepaint(_BackgroundTrackingPainter oldDelegate) => oldDelegate.t != t;
}
