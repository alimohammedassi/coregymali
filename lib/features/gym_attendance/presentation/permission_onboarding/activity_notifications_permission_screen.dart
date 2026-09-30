import 'dart:ui' show lerpDouble;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_animations.dart';
import '../../../../theme/app_colors.dart';
import 'permission_onboarding_step.dart';

/// Step 3 — optional activity recognition + notifications.
///
/// Requests BOTH permissions in one go; granted only when both resolve
/// granted. Since both are optional, the idle state's escape hatch is the
/// more explicit "Continue without it" (→ [onContinue]); onSkip is kept for
/// flow-host parity. Denied lands in the friendly state — retry / Open
/// Settings primary, "Continue without it" secondary.
class ActivityNotificationsPermissionScreen extends StatefulWidget {
  const ActivityNotificationsPermissionScreen({
    super.key,
    required this.onContinue,
    this.onSkip,
  });

  final VoidCallback onContinue;
  final VoidCallback? onSkip;

  @override
  State<ActivityNotificationsPermissionScreen> createState() =>
      _ActivityNotificationsPermissionScreenState();
}

enum _Phase { idle, denied, permanentlyDenied, granted }

class _ActivityNotificationsPermissionScreenState
    extends State<ActivityNotificationsPermissionScreen>
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

    final results = await [
      Permission.activityRecognition,
      Permission.notification,
    ].request();

    if (!mounted) return;
    setState(() => _busy = false);
    _resolve(
      results[Permission.activityRecognition] ?? PermissionStatus.denied,
      results[Permission.notification] ?? PermissionStatus.denied,
    );
  }

  void _resolve(PermissionStatus activity, PermissionStatus notification) {
    final bothGranted =
        (activity.isGranted || activity.isLimited) &&
            (notification.isGranted || notification.isLimited);

    if (bothGranted) {
      setState(() => _phase = _Phase.granted);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) widget.onContinue();
      });
      return;
    }
    if (activity.isPermanentlyDenied || notification.isPermanentlyDenied) {
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
      animation: _PulseToCheckGlyph(controller: _glyph),
      title: denied ? l10n.gymAttPermDeniedTitle : l10n.gymAttActTitle,
      body: denied ? l10n.gymAttPermDeniedBody : l10n.gymAttActBody,
      whyLine: l10n.gymAttActWhy,
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
      // Both permissions are optional — "Continue without it" is the
      // prominent secondary here (also in the idle state).
      secondaryLabel: l10n.gymAttContinueWithout,
      onSecondary: widget.onContinue,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glyph — a heartbeat: a core dot double-thumps while two pulse rings expand
// and dissolve, then the rings collapse inward and a check mark draws itself
// inside a badge ("pulse → confirmed"). One controller + intervals.
// ─────────────────────────────────────────────────────────────────────────────
class _PulseToCheckGlyph extends StatelessWidget {
  final AnimationController controller;

  const _PulseToCheckGlyph({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return CustomPaint(
        size: const Size(250, 210),
        painter: _PulseToCheckPainter(0.9),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        size: const Size(250, 210),
        painter: _PulseToCheckPainter(controller.value),
      ),
    );
  }
}

class _PulseToCheckPainter extends CustomPainter {
  final double t;

  _PulseToCheckPainter(this.t);

  // Heartbeat: quick thump, breather, second softer thump. (Interval
  // transforms clamp to [0,1], so the sine stays non-negative.)
  static double _thump(double t, double start, double strength) =>
      math.sin(
        Interval(start, start + 0.10, curve: Curves.easeOut).transform(t) *
            math.pi,
      ) *
      strength;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.48);

    final checkIn = Interval(0.52, 0.60, curve: AppCurves.overshoot)
        .transform(t);
    final dotOut = 1.0 - Interval(0.46, 0.58).transform(t);
    final checkOut = Interval(0.94, 1.0).transform(t);

    // ── Heartbeat phase ──
    if (dotOut > 0) {
      final beat = _thump(t, 0.02, 0.30) + _thump(t, 0.16, 0.18);
      canvas.drawCircle(
        center,
        10 + 6 * beat,
        Paint()..color = AppColors.accent.withValues(alpha: 0.12 * dotOut),
      );
      canvas.drawCircle(
        center,
        9 + 3 * beat,
        Paint()..color = AppColors.accent.withValues(alpha: dotOut),
      );

      // Two staggered expanding pulse rings.
      for (final (start, end, width) in [(0.04, 0.44, 2.5), (0.15, 0.55, 2.0)]) {
        final p = Interval(start, end, curve: AppCurves.standard).transform(t);
        if (p > 0 && p < 1) {
          canvas.drawCircle(
            center,
            lerpDouble(14, 74, p)!,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = width
              ..color = AppColors.accent.withValues(
                alpha: (1 - p) * 0.55 * dotOut,
              ),
          );
        }
      }
    }

    // ── Check badge phase ──
    if (checkIn > 0) {
      final badgeAlpha = 1.0 - checkOut; // already in [0, 1]
      final badgeR = lerpDouble(26, 46, checkIn)!;

      canvas.drawCircle(
        center,
        badgeR,
        Paint()
          ..color = AppColors.surfaceContainerHigh
              .withValues(alpha: badgeAlpha),
      );
      canvas.drawCircle(
        center,
        badgeR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.glassBorderActive.withValues(
            alpha: badgeAlpha,
          ),
      );

      // Check stroke draws itself, then dissolves before the loop restarts.
      final drawT = Interval(0.60, 0.84, curve: AppCurves.standard)
          .transform(t);
      if (drawT > 0) {
        final checkPath = Path()
          ..moveTo(center.dx - badgeR * 0.46, center.dy + 1)
          ..lineTo(center.dx - badgeR * 0.10, center.dy + badgeR * 0.36)
          ..lineTo(center.dx + badgeR * 0.52, center.dy - badgeR * 0.34);

        final metric = checkPath.computeMetrics().first;
        final strokePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.accent.withValues(alpha: badgeAlpha);
        canvas.drawPath(
          metric.extractPath(0, metric.length * drawT),
          strokePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PulseToCheckPainter oldDelegate) => oldDelegate.t != t;
}
