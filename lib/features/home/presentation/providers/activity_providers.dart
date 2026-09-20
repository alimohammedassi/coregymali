import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/stats_service.dart';
import '../../data/dashboard_activity_repository.dart';
import '../../domain/day_activity.dart';

final dashboardActivityRepositoryProvider = Provider<DashboardActivityRepository>(
  (ref) => DashboardActivityRepository(),
);

/// The Friday-based week currently loaded (7 slots, future days empty).
/// Starts anchored on the current week; [switchWeek] pages it backwards
/// (and forwards, never past now) for the strip's arrows. Mutated by
/// [addWaterGlass] so the selector dot and both cards update optimistically
/// from a single source.
class ActivityWeekNotifier extends AsyncNotifier<List<DayActivity>> {
  DateTime _anchor = DateTime.now();

  /// Friday that starts the week this provider is currently showing.
  DateTime get weekAnchor => DashboardActivityRepository.fridayOf(_anchor);

  @override
  Future<List<DayActivity>> build() {
    return ref.read(dashboardActivityRepositoryProvider).fetchWeek(_anchor);
  }

  /// Loads the week containing [anchor]. The previous week's list stays on
  /// screen until the fetch succeeds, so the strip never flashes empty; a
  /// failed fetch keeps what was already shown.
  Future<void> switchWeek(DateTime anchor) async {
    _anchor = anchor;
    final repo = ref.read(dashboardActivityRepositoryProvider);
    final next = await AsyncValue.guard(() => repo.fetchWeek(anchor));
    if (next.hasValue) state = next;
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DayActivity? _dayOf(List<DayActivity> week, DateTime day) {
    for (final d in week) {
      if (d.isSameDay(day)) return d;
    }
    return null;
  }

  bool _waterWritePending = false;

  /// Adds one 250ml glass to TODAY, mirroring the vitals bar's behavior:
  /// optimistic state update, then persist through [StatsService] (which
  /// also re-anchors the water reminders). The write path matches the
  /// existing home `_addWater` — glasses stay the source of truth, so a
  /// non-multiple-of-250ml manual value rounds down before incrementing.
  Future<void> addWaterGlass({int maxGlasses = 20}) async {
    if (_waterWritePending) return; // debounce rapid double-taps
    _waterWritePending = true;
    try {
      final today = _today;
      final current = state.value;
      if (current == null) return;

      final todayRow = _dayOf(current, today);
      final glasses =
          ((todayRow?.waterMl ?? 0) ~/ DashboardActivityRepository.glassMl) + 1;
      if (glasses > maxGlasses) return;
      final newMl = glasses * DashboardActivityRepository.glassMl;

      // Optimistic update
      state = AsyncData([
        for (final d in current)
          if (d.isSameDay(today))
            d.copyWith(waterMl: newMl)
          else
            d,
      ]);

      try {
        await ref
            .read(dashboardActivityRepositoryProvider)
            .saveTodayWaterMl(newMl);
      } catch (e) {
        debugPrint('addWaterGlass persist error: $e');
        // Don't roll back the optimistic tick — the vitals bar behaves the
        // same way; a pull-to-refresh re-syncs from daily_summary.
      }
    } finally {
      _waterWritePending = false;
    }
  }
}

final activityWeekProvider =
    AsyncNotifierProvider<ActivityWeekNotifier, List<DayActivity>>(
  ActivityWeekNotifier.new,
);

/// Daily targets from `user_goals` (water in ml, steps as a count). Never
/// hardcoded in the cards: the goals row is the single source, with the same
/// defaults the rest of the app falls back to when goals aren't set yet.
class ActivityGoals {
  final int waterGoalMl;
  final int stepsGoal;

  const ActivityGoals({required this.waterGoalMl, required this.stepsGoal});

  /// Same fallbacks as [StatsService] so every surface agrees when the user
  /// hasn't set goals yet (the design's "8 glasses" is just the mockup's
  /// 2000ml goal rendered as glasses).
  static const defaults = ActivityGoals(waterGoalMl: 2500, stepsGoal: 8000);
}

final activityGoalsProvider = FutureProvider<ActivityGoals>((ref) async {
  try {
    final goals = await StatsService().getGoals();
    return ActivityGoals(
      waterGoalMl: (goals['daily_water_ml'] as num?)?.toInt() ??
          ActivityGoals.defaults.waterGoalMl,
      stepsGoal: (goals['daily_steps'] as num?)?.toInt() ??
          ActivityGoals.defaults.stepsGoal,
    );
  } catch (e) {
    debugPrint('activityGoalsProvider error: $e');
    return ActivityGoals.defaults;
  }
});
