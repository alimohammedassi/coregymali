import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../theme/app_animations.dart';
import '../../../../theme/app_colors.dart';

/// The pin + geofence-ring motif — a volt pin holding position while two
/// soft rings ping outward around it. Shared by the attendance intro screen
/// and the home promo popup so both surfaces carry the same "arrival
/// detection" animation. Reduced motion shows the settled pose.
class GymPinGlyph extends StatefulWidget {
  const GymPinGlyph({super.key, this.size = const Size(190, 130)});

  final Size size;

  @override
  State<GymPinGlyph> createState() => _GymPinGlyphState();
}

class _GymPinGlyphState extends State<GymPinGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  bool _repeating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is only readable here — and staying subscribed means a
    // reduced-motion toggle stops/restarts the loop live.
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced && _repeating) {
      _ctrl.stop();
      _repeating = false;
    } else if (!reduced && !_repeating) {
      _ctrl.repeat();
      _repeating = true;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return CustomPaint(size: widget.size, painter: GymPinPainter(0.25));
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) =>
          CustomPaint(size: widget.size, painter: GymPinPainter(_ctrl.value)),
    );
  }
}

class GymPinPainter extends CustomPainter {
  final double t;

  GymPinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.40);

    // Two staggered pings breathing around the pin.
    for (final (start, radius) in [(0.0, 58.0), (0.5, 44.0)]) {
      final p = ((t - start) % 1.0);
      final eased = AppCurves.standard.transform(p);
      canvas.drawCircle(
        center,
        lerpDouble(16, radius, eased)!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.accent.withValues(alpha: (1 - eased) * 0.35),
      );
    }

    // Steady geofence ring.
    canvas.drawCircle(
      center,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.accent.withValues(alpha: 0.6),
    );

    // Gentle pin bob.
    final bob = math.sin(t * 2 * math.pi) * 2.5;
    final headCenter = Offset(center.dx, center.dy - 8 + bob);
    final pinPaint = Paint()..color = AppColors.accent;

    final pinPath = Path()
      ..moveTo(center.dx, center.dy + 16 + bob)
      ..quadraticBezierTo(
        headCenter.dx - 14,
        headCenter.dy + 2,
        headCenter.dx,
        headCenter.dy,
      )
      ..quadraticBezierTo(
        headCenter.dx + 14,
        headCenter.dy + 2,
        center.dx,
        center.dy + 16 + bob,
      )
      ..close();
    canvas.drawCircle(headCenter, 12, pinPaint);
    canvas.drawPath(pinPath, pinPaint);
    canvas.drawCircle(
      headCenter,
      4.5,
      Paint()..color = AppColors.onPrimary,
    );
  }

  @override
  bool shouldRepaint(GymPinPainter oldDelegate) => oldDelegate.t != t;
}
