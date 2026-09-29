import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../services/rank_service.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Competitive mode selector — not ordinary tabs. Horizontal chips that
/// fill with the action lime when selected; switching haptic + animated
/// container are the only motion (content transition lives in the screen).
class LeaderboardCategoryTabs extends StatelessWidget {
  final LeaderboardCategory selected;
  final ValueChanged<LeaderboardCategory> onChanged;

  const LeaderboardCategoryTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = {
      LeaderboardCategory.overall: l10n.lbCatOverall,
      LeaderboardCategory.calories: l10n.lbCatCalories,
      LeaderboardCategory.water: l10n.lbCatWater,
      LeaderboardCategory.workouts: l10n.lbCatWorkouts,
      LeaderboardCategory.streak: l10n.lbCatStreak,
      LeaderboardCategory.longestStreak: l10n.lbCatLongestStreak,
    };

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final entry in labels.entries) ...[
            GestureDetector(
              onTap: () {
                if (entry.key == selected) return;
                HapticFeedback.selectionClick();
                onChanged(entry.key);
              },
              child: AnimatedContainer(
                duration: AppDurations.medium,
                curve: AppCurves.standard,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: entry.key == selected
                      ? AppColors.primaryFixed
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: entry.key == selected
                        ? AppColors.primaryFixed
                        : AppColors.borderSubtle,
                  ),
                ),
                child: Text(
                  entry.value,
                  style: AppText.labelMd.copyWith(
                    color: entry.key == selected
                        ? AppColors.onPrimary
                        : AppColors.textSecondary,
                    fontWeight:
                        entry.key == selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
