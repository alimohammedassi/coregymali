import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_animations.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';

/// Payoff screen after tracking is enabled: the check draws itself in with
/// an overshoot settle, title and body stagger in, and [onDone] fires
/// automatically ~1.2 s later — no buttons on purpose.
class GymAttendanceSuccessScreen extends StatefulWidget {
  const GymAttendanceSuccessScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<GymAttendanceSuccessScreen> createState() =>
      _GymAttendanceSuccessScreenState();
}

class _GymAttendanceSuccessScreenState extends State<GymAttendanceSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppDurations.countUp,
  )..forward();

  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), _handOff);
  }

  void _handOff() {
    if (!mounted || _handedOff) return;
    setState(() => _handedOff = true);
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final reduced = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SuccessCheckGlyph(controller: _c),
              const SizedBox(height: AppSpacing.xl),
              AnimatedBuilder(
                animation: _c,
                builder: (context, child) => _Reveal(
                  controller: _c,
                  interval: const Interval(0.35, 0.65),
                  reduced: reduced,
                  child: child!,
                ),
                child: Text(
                  l10n.gymAttSuccessTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppText.fontFamily(isArabic: isArabic),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AnimatedBuilder(
                animation: _c,
                builder: (context, child) => _Reveal(
                  controller: _c,
                  interval: const Interval(0.50, 0.80),
                  reduced: reduced,
                  child: child!,
                ),
                child: Text(
                  l10n.gymAttSuccessBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppText.fontFamily(isArabic: isArabic),
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fade + settle-slide reveal driven by one interval of the shared
/// controller; reduced motion pins the final pose.
class _Reveal extends StatelessWidget {
  final AnimationController controller;
  final Interval interval;
  final bool reduced;
  final Widget child;

  const _Reveal({
    required this.controller,
    required this.interval,
    required this.reduced,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = interval.transform(controller.value);
        return Opacity(
          opacity: reduced ? 1.0 : v,
          child: Transform.translate(
            offset: Offset(0, reduced ? 0 : (1 - v) * 14),
            child: child,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One-shot glyph — a badge scales in with overshoot while the check stroke
// draws itself and a soft ring bursts outward once. Reduced motion shows the
// final pose.
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessCheckGlyph extends StatelessWidget {
  final AnimationController controller;

  const _SuccessCheckGlyph({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return CustomPaint(
        size: const Size(140, 140),
        painter: _SuccessCheckPainter(1.0),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        size: const Size(140, 140),
        painter: _SuccessCheckPainter(controller.value),
      ),
    );
  }
}

class _SuccessCheckPainter extends CustomPainter {
  final double t;

  _SuccessCheckPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Badge — scale-in with overshoot settle.
    final scaleT = Interval(0.0, 0.50, curve: AppCurves.overshoot).transform(t);
    final r = lerpDouble(30, 56, scaleT)!;

    // One-shot burst ring behind the badge.
    final burstT =
        Interval(0.30, 0.80, curve: AppCurves.standard).transform(t);
    if (burstT > 0 && burstT < 1) {
      canvas.drawCircle(
        center,
        lerpDouble(r + 4, r + 30, burstT)!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.accent.withValues(alpha: (1 - burstT) * 0.40),
      );
    }

    canvas.drawCircle(
      center,
      r,
      Paint()..color = AppColors.surfaceContainerHigh,
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.accent,
    );

    // Check stroke draws itself once the badge lands.
    final drawT = Interval(0.30, 0.75, curve: AppCurves.standard).transform(t);
    if (drawT > 0) {
      final checkPath = Path()
        ..moveTo(center.dx - r * 0.40, center.dy + 2)
        ..lineTo(center.dx - r * 0.08, center.dy + r * 0.34)
        ..lineTo(center.dx + r * 0.46, center.dy - r * 0.30);

      final metric = checkPath.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * drawT),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_SuccessCheckPainter oldDelegate) => oldDelegate.t != t;
}
