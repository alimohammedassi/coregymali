import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Compact "current logging streak" pill: a painted flame glyph + the day
/// count. Deliberately NOT an emoji (owner rule: no emojis in UI) and NOT
/// color-only — the number carries the information.
///
/// The flame uses the fill-lime token (mode-proof sibling of the retired
/// volt, which the design system reserves for exactly this kind of
/// micro-accent but which fails contrast on light canvases).
class LeaderboardStreakBadge extends StatelessWidget {
  final int streak;

  /// Hidden entirely at 0 — an empty flame pill is visual noise.
  const LeaderboardStreakBadge({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    if (streak <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(9, 12),
            painter: _FlamePainter(color: AppColors.primaryFixed),
          ),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: AppText.labelSm.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hand-drawn flame silhouette (a droplet with a leaning tip). Painted in
/// [AppColors.primaryFixed] — the "streak fire" micro-accent of the app.
class _FlamePainter extends CustomPainter {
  final Color color;
  _FlamePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.50, 0)
      ..cubicTo(w * 0.74, h * 0.26, w * 0.96, h * 0.44, w * 0.92, h * 0.68)
      ..cubicTo(w * 0.89, h * 0.90, w * 0.72, h, w * 0.50, h)
      ..cubicTo(w * 0.28, h, w * 0.11, h * 0.90, w * 0.08, h * 0.68)
      ..cubicTo(w * 0.04, h * 0.44, w * 0.28, h * 0.28, w * 0.50, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.color != color;
}
