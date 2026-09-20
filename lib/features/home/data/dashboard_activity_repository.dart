import 'package:flutter/foundation.dart';

import '../../../services/stats_service.dart';
import '../../../services/supabase_client.dart';
import '../domain/day_activity.dart';

/// Data source for the Home week selector + Water/Steps cards.
///
/// Reads come from the existing `get_user_activity` RPC (already live for
/// the leaderboard/profile screens) so the week view, the rings and the
/// leaderboard all agree on what "a logged day" means. Writes reuse
/// [StatsService.updateWater] so the water-reminder schedule re-anchors
/// exactly like every other water entry point in the app.
class DashboardActivityRepository {
  static const int glassMl = 250;

  /// Friday that starts the week containing [d] (Fri..Thu — the Egyptian
  /// week). Shared by the repository, the week provider and the strip's
  /// arrow gating.
  static DateTime fridayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(
      Duration(days: (day.weekday - DateTime.friday + 7) % 7),
    );
  }

  /// The Friday-based week containing [anchor], one [DayActivity] per slot.
  /// Days after today come back empty and weeks entirely in the future come
  /// back all-empty, so the selector can page backwards through history but
  /// never forwards past now (owner brief 2026-09-18: "I can't go back and
  /// see my data").
  Future<List<DayActivity>> fetchWeek(DateTime anchor) async {
    final friday = fridayOf(anchor);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Slots at index > lastLive are in the future relative to TODAY.
    // -1 = the whole week is in the future → all-empty strip.
    final daysFromFridayToToday = today.difference(friday).inDays;
    final lastLive = daysFromFridayToToday > 6
        ? 6
        : daysFromFridayToToday;

    if (currentUserId == null || lastLive < 0) {
      return _paddedWeek(friday, lastLive, const {});
    }

    try {
      // p_days counts back from today, so it must span this week's Friday
      // through today — 8+ for weeks older than the current one.
      final rows = await supabase.rpc(
        'get_user_activity',
        params: {
          'p_target': currentUserId,
          'p_days': daysFromFridayToToday + 1,
        },
      );
      final byDate = <String, Map<String, dynamic>>{
        for (final row in (rows as List))
          (row as Map<String, dynamic>)['summary_date'].toString().substring(0, 10):
              Map<String, dynamic>.from(row),
      };
      return _paddedWeek(friday, lastLive, byDate);
    } catch (e) {
      debugPrint('DashboardActivityRepository.fetchWeek error: $e');
      // Empty week — the selector renders with dim dots, never an error.
      return _paddedWeek(friday, lastLive, const {});
    }
  }

  /// The current week (convenience wrapper over [fetchWeek]).
  Future<List<DayActivity>> fetchCurrentWeek() => fetchWeek(DateTime.now());

  List<DayActivity> _paddedWeek(
    DateTime friday,
    int lastLive,
    Map<String, dynamic> rowsByDate,
  ) {
    return List.generate(7, (i) {
      final date = friday.add(Duration(days: i));
      if (i > lastLive) return DayActivity.empty(date); // future day
      final key = date.toIso8601String().substring(0, 10);
      final row = rowsByDate[key];
      return row == null
          ? DayActivity.empty(date)
          : DayActivity.fromMap(date, row);
    });
  }

  /// Persists today's total water intake (ml). Delegates to [StatsService]
  /// so the local water-reminder schedule is re-anchored on goal reached —
  /// identical behavior to the vitals bar's +250ml action.
  Future<void> saveTodayWaterMl(int totalMl) async {
    await StatsService().updateWater(totalMl);
  }
}
