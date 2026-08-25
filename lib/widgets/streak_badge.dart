import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Flame + streak count badge. Server-computed streak — the UI only renders
/// what `StreakService.getStatus()` reports.
///
/// - Active today (or streak still alive & logged): warm green-accent flame
/// - Streak at risk (yesterday active, today unlogged): muted gray
class StreakBadge extends StatelessWidget {
  final int streak;
  final bool loggedToday;
  final bool compact;

  const StreakBadge({
    super.key,
    required this.streak,
    this.loggedToday = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAlive = streak > 0;
    final accent = isAlive ? AppColors.primary : AppColors.textMuted;
    final bg = isAlive
        ? AppColors.lightGreen
        : AppColors.surfaceContainerHigh;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: accent.withValues(alpha: isAlive ? .35 : .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: compact ? 14 : 16,
            color: accent,
          ),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: AppText.labelMd.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
