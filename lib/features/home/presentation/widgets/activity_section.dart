import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../data/dashboard_activity_repository.dart';
import '../../domain/day_activity.dart';
import '../providers/activity_providers.dart';
import 'steps_card.dart';
import 'water_card.dart';
import 'week_day_selector.dart';

/// The Fri..Thu week strip, fed by [activityWeekProvider]. Lives ABOVE the
/// hero fuel card on Home and drives the page's selected day — the hero's
/// date stepper and this strip stay in sync through home's `_selectedDate`.
/// The end chevrons page across weeks (owner brief 2026-09-18); next-week
/// is disabled once the current week is on screen.
class WeekSelectorStrip extends ConsumerWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  const WeekSelectorStrip({
    super.key,
    required this.selectedDate,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekAsync = ref.watch(activityWeekProvider);
    final notifier = ref.read(activityWeekProvider.notifier);
    final anchor = notifier.weekAnchor;
    final isCurrentWeek = DashboardActivityRepository.fridayOf(
      DateTime.now(),
    ).isAtSameMomentAs(anchor);
    return WeekDaySelector(
      week: weekAsync.value ?? emptyWeekPlaceholder(),
      selectedDate: selectedDate,
      onSelectDate: onSelectDate,
      onPreviousWeek: () =>
          notifier.switchWeek(anchor.subtract(const Duration(days: 7))),
      onNextWeek: () =>
          notifier.switchWeek(anchor.add(const Duration(days: 7))),
      canGoNext: !isCurrentWeek,
    );
  }
}

/// Home "Activity" block: section title + the Water/Steps card pair, all
/// driven by one week fetch ([activityWeekProvider]) and one goals fetch
/// ([activityGoalsProvider]). Replaces the old vitals rings bar.
class ActivitySection extends ConsumerWidget {
  final DateTime selectedDate;

  /// Water writes only land on today — same rule as the old vitals bar.
  final bool canEditDaily;
  final VoidCallback? onDataChanged;
  final VoidCallback? onOpenWatchSheet;

  const ActivitySection({
    super.key,
    required this.selectedDate,
    required this.canEditDaily,
    this.onDataChanged,
    this.onOpenWatchSheet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final weekAsync = ref.watch(activityWeekProvider);
    final goalsAsync = ref.watch(activityGoalsProvider);

    final week = weekAsync.value ?? emptyWeekPlaceholder();
    final goals = goalsAsync.value ?? ActivityGoals.defaults;

    DayActivity selected = week.last;
    for (final d in week) {
      if (d.isSameDay(selectedDate)) {
        selected = d;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l10n.activity,
            style: AppText.styledHeadlineSm(
              isArabic: isArabic,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: WaterCard(
                    waterMl: selected.waterMl,
                    goalMl: goals.waterGoalMl,
                    canEdit: canEditDaily,
                    onChanged: onDataChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StepsCard(
                    steps: selected.steps,
                    goal: goals.stepsGoal,
                    weekSteps: [for (final d in week) d.steps],
                    onConnectWatch: onOpenWatchSheet,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Placeholder before the first fetch lands: the current Fri..Thu window
/// with empty days so the strip keeps its stable 7-cell layout.
List<DayActivity> emptyWeekPlaceholder() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final friday = today.subtract(
    Duration(days: (today.weekday - DateTime.friday + 7) % 7),
  );
  return List.generate(
    7,
    (i) => DayActivity.empty(friday.add(Duration(days: i))),
  );
}
