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

  /// The current Friday-based week (Fri..Thu — the Egyptian week), one
  /// [DayActivity] per slot. Days after today come back empty; days before
  /// Friday are outside the visible week.
  Future<List<DayActivity>> fetchCurrentWeek() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Dart weekday: Mon=1..Sun=7. Friday=5 → 0 days since Friday.
    final daysSinceFriday = (today.weekday - DateTime.friday + 7) % 7;
    final friday = today.subtract(Duration(days: daysSinceFriday));

    if (currentUserId == null) {
      return _paddedWeek(friday, daysSinceFriday, const {});
    }

    try {
      // p_days counts back from today; we only need Friday..today.
      final rows = await supabase.rpc(
        'get_user_activity',
        params: {'p_target': currentUserId, 'p_days': daysSinceFriday + 1},
      );
      final byDate = <String, Map<String, dynamic>>{
        for (final row in (rows as List))
          (row as Map<String, dynamic>)['summary_date'].toString().substring(0, 10):
              Map<String, dynamic>.from(row),
      };
      return _paddedWeek(friday, daysSinceFriday, byDate);
    } catch (e) {
      debugPrint('DashboardActivityRepository.fetchCurrentWeek error: $e');
      // Empty week — the selector renders with dim dots, never an error.
      return _paddedWeek(friday, daysSinceFriday, const {});
    }
  }

  List<DayActivity> _paddedWeek(
    DateTime friday,
    int daysSinceFriday,
    Map<String, dynamic> rowsByDate,
  ) {
    return List.generate(7, (i) {
      final date = friday.add(Duration(days: i));
      if (i > daysSinceFriday) return DayActivity.empty(date); // future day
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
