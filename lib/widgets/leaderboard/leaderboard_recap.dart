import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/rank_service.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// "LAST WEEK" podium recap, shown when a new cycle starts. Compact,
/// dismissible (dismissal persisted per cycle by the screen) and never
/// blocking: it sits above the board and scrolls away like any card.
class LeaderboardRecapCard extends StatelessWidget {
  final WeeklyRecap recap;
  final VoidCallback onDismiss;

  const LeaderboardRecapCard({
    super.key,
    required this.recap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final medalColors = [
      AppColors.tierGold,
      AppColors.tierSilver,
      AppColors.tierBronze,
    ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.slow,
      curve: AppCurves.standard,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 10),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.lbLastWeek,
                    style: AppText.labelMd.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.lbDismiss,
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textMuted),
                  onPressed: onDismiss,
                ),
              ],
            ),
            for (var i = 0; i < recap.entries.length && i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 16,
                      color: medalColors[i],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recap.entries[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.labelMd.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${recap.entries[i].score} ${l10n.lbUnitPts}',
                      style: AppText.labelSm.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Text(
              l10n.lbNewCycle,
              style: AppText.labelSm.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
