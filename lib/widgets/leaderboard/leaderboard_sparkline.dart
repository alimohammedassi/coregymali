import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Tiny 7-point trend — a visual signal (rising / falling / flat), not a
/// chart: no axes, grid, labels or tooltips. CustomPaint keeps it cheap for
/// list rows. The line draws itself over [duration] so it can stagger with
/// its row's entrance (existing leaderboard motion language).
///
/// Null/short values render nothing — sparkline data is optional by design
/// (graceful degradation when the trend payload is missing).
class LeaderboardSparkline extends StatelessWidget {
  final List<int>? values;
  final double width;
  final double height;
  final Duration duration;
  final Color? color;

  const LeaderboardSparkline({
    super.key,
    required this.values,
    this.width = 56,
    this.height = 22,
    this.duration = const Duration(milliseconds: 600),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final v = values;
    if (v == null || v.length < 2) return SizedBox(width: width, height: height);

    Widget paint(double w) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(
            size: Size(w, height),
            painter: _SparklinePainter(
              values: v,
              progress: t,
              color: color ?? AppColors.primaryFixed,
            ),
          ),
        );

    // Infinite width = fill the parent (LayoutBuilder resolves the actual
    // extent) — used by the profile rank-journey chart.
    if (width == double.infinity) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) => paint(constraints.maxWidth),
        ),
      );
    }
    return paint(width);
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> values;
  final double progress;
  final Color color;

  static const double _pad = 2;

  _SparklinePainter({
    required this.values,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce((a, b) => a < b ? a : b).toDouble();
    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble();
    final span = (maxV - minV).clamp(1, double.infinity).toDouble();

    Offset pointAt(int i) {
      final x = _pad + i * (size.width - _pad * 2) / (values.length - 1);
      final y = size.height -
          _pad -
          ((values[i] - minV) / span) * (size.height - _pad * 2);
      return Offset(x, y);
    }

    final visible = 1 + ((values.length - 1) * progress.clamp(0, 1)).round();
    if (visible < 2) return;

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < visible; i++) {
      line.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.9);
    canvas.drawPath(line, paint);

    // "Now" dot at the last drawn point — anchors the eye on the latest day.
    final last = pointAt(visible - 1);
    canvas.drawCircle(
      last,
      1.8,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.color != color || old.values != values;
}
