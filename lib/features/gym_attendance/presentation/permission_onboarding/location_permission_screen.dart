import 'dart:ui' show lerpDouble;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_animations.dart';
import '../../../../theme/app_colors.dart';
import 'permission_onboarding_step.dart';

/// Step 1 — When-in-use location permission.
///
/// The screen owns the OS request (no shared service): on grant it flashes
/// the scaffold's success state for ~600 ms and hands off via [onContinue].
/// Denied shows a friendly inline retry state; permanently denied routes to
/// Open Settings. Both paths keep a "continue without it" escape hatch so
/// the screen never dead-ends.
class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({
    super.key,
    required this.onContinue,
    this.onSkip,
  });

  final VoidCallback onContinue;
  final VoidCallback? onSkip;

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

enum _Phase { idle, denied, permanentlyDenied, granted }

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glyph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
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

    final status = await Permission.locationWhenInUse.request();

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
      setState(() => _phase = _Phase.denied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final denied = _phase == _Phase.denied ||
        _phase == _Phase.permanentlyDenied;

    return PermissionOnboardingStep(
      animation: _MapPinGlyph(controller: _glyph),
      title: denied ? l10n.gymAttPermDeniedTitle : l10n.gymAttLocTitle,
      body: denied ? l10n.gymAttPermDeniedBody : l10n.gymAttLocBody,
      whyLine: l10n.gymAttLocWhy,
      granted: _phase == _Phase.granted,
      primaryLabel: switch (_phase) {
        _Phase.idle => l10n.gymAttPermAllow,
        _Phase.denied => l10n.gymAttRetry,
        _Phase.permanentlyDenied => l10n.gymAttOpenSettings,
        _Phase.granted => l10n.gymAttPermGranted,
      },
      onPrimary: switch (_phase) {
        _Phase.permanentlyDenied => openAppSettings,
        _ => _request,
      },
      secondaryLabel: denied
          ? l10n.gymAttContinueWithout
          : l10n.gymAttPermSkip,
      onSecondary: denied ? widget.onContinue : widget.onSkip,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glyph — a pin drops onto a stylized map surface, then a circular geofence
// ring expands and gently pulses around it ("user → gym → detection").
// One controller + intervals, 2.4 s loop, reduced-motion shows the settled
// pose.
// ─────────────────────────────────────────────────────────────────────────────
class _MapPinGlyph extends StatelessWidget {
  final AnimationController controller;

  const _MapPinGlyph({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return CustomPaint(
        size: const Size(250, 215),
        painter: _MapPinPainter(1.0),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        size: const Size(250, 215),
        painter: _MapPinPainter(controller.value),
      ),
    );
  }
}

class _MapPinPainter extends CustomPainter {
  final double t;

  _MapPinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final mapRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.56),
      width: size.width * 0.86,
      height: size.height * 0.78,
    );
    final mapRRect = RRect.fromRectAndRadius(mapRect, Radius.circular(20));

    // Stylized map surface.
    canvas.drawRRect(
      mapRRect,
      Paint()..color = AppColors.surfaceContainerLow,
    );
    canvas.drawRRect(
      mapRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.borderSubtle,
    );

    // Streets — a crossing pair plus a small block.
    final street = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppColors.outlineVariant.withValues(alpha: 0.7);
    canvas.drawLine(
      Offset(mapRect.left + 18, mapRect.top + 34),
      Offset(mapRect.right - 18, mapRect.top + 34),
      street,
    );
    canvas.drawLine(
      Offset(mapRect.left + 52, mapRect.top + 12),
      Offset(mapRect.left + 52, mapRect.bottom - 12),
      street,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          mapRect.left + 78,
          mapRect.top + 56,
          mapRect.width * 0.42,
          mapRect.height * 0.30,
        ),
        const Radius.circular(10),
      ),
      Paint()..color = AppColors.surfaceContainerHigh,
    );

    final pinCenter = Offset(size.width / 2, mapRect.top + 34);

    // Contact shadow grows as the pin lands.
    final dropT = Curves.easeOutBack.transform(
      Interval(0.06, 0.38).transform(t),
    );
    final shadowAlpha = Interval(0.10, 0.38).transform(t) * 0.22;
    canvas.drawOval(
      Rect.fromCenter(
        center: pinCenter + const Offset(0, 26),
        width: 34 * (0.5 + 0.5 * dropT),
        height: 9,
      ),
      Paint()..color = AppColors.cardShadow.withValues(alpha: shadowAlpha),
    );

    // Geofence ring: expands after the pin lands, then breathes.
    final ringIn = Interval(0.44, 0.78, curve: AppCurves.standard).transform(t);
    final ringR = lerpDouble(14, 62, ringIn)!;
    final breathe = math.sin(t * 2 * math.pi);
    final ringAlpha = (0.55 + 0.20 * breathe) * ringIn;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = AppColors.accent.withValues(alpha: ringAlpha);
    canvas.drawCircle(pinCenter, ringR, ringPaint);

    // Outer ping — expands and dissolves each cycle.
    final pingT = Interval(0.55, 0.98).transform(t);
    if (pingT > 0) {
      canvas.drawCircle(
        pinCenter,
        lerpDouble(ringR, ringR + 22, pingT)!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.accent.withValues(alpha: (1 - pingT) * 0.30),
      );
    }

    // Pin — teardrop in the accent color with an ink core.
    final pinAlpha = Interval(0.06, 0.16).transform(t);
    final dy = lerpDouble(-52, 0, dropT)!;
    final pinPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: pinAlpha);
    final corePaint = Paint()..color = AppColors.onPrimary;
    final bodyCenter = Offset(pinCenter.dx, pinCenter.dy + dy - 10);

    final pinPath = Path()
      ..moveTo(pinCenter.dx, pinCenter.dy + dy + 12)
      ..quadraticBezierTo(
        bodyCenter.dx - 16,
        bodyCenter.dy + 2,
        bodyCenter.dx,
        bodyCenter.dy,
      )
      ..quadraticBezierTo(
        bodyCenter.dx + 16,
        bodyCenter.dy + 2,
        pinCenter.dx,
        pinCenter.dy + dy + 12,
      )
      ..close();
    // Teardrop = head circle + tail wedge.
    canvas.drawCircle(bodyCenter, 14, pinPaint);
    canvas.drawPath(pinPath, pinPaint);
    canvas.drawCircle(bodyCenter, 5.5, corePaint);
  }

  @override
  bool shouldRepaint(_MapPinPainter oldDelegate) => oldDelegate.t != t;
}
