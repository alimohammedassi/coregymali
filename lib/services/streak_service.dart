import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_client.dart';

/// Snapshot of the server-computed streak state for the calling user.
class StreakStatus {
  final int currentStreak;
  final int longestStreak;
  final bool loggedToday;
  final bool atRisk;

  const StreakStatus({
    required this.currentStreak,
    required this.longestStreak,
    this.loggedToday = false,
    this.atRisk = false,
  });

  static const empty = StreakStatus(currentStreak: 0, longestStreak: 0);

  factory StreakStatus.fromJson(Map<String, dynamic> json) {
    return StreakStatus(
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      loggedToday: json['logged_today'] == true,
      atRisk: json['at_risk'] == true,
    );
  }
}

/// Single source of truth for streaks. All math happens in the
/// `record_daily_activity` Postgres function — the client only reports
/// activity and reads status back.
class StreakService {
  /// Milestones that trigger a one-time celebration, fired through
  /// [milestoneReached] when crossed while the app is open.
  static const List<int> _milestones = [7, 30, 100];
  static const String _celebratedKey = 'last_celebrated_milestone';

  /// Set when a new milestone is crossed; UI listens and shows a dialog once.
  static final ValueNotifier<int?> milestoneReached = ValueNotifier(null);

  /// Fire-and-forget activity report. Never throws — failures are logged so
  /// save flows are never blocked or delayed by streak bookkeeping.
  Future<void> recordActivity(String source) async {
    assert(source == 'workout' || source == 'nutrition');
    if (currentUserId == null) return;

    try {
      final row = await supabase.rpc(
        'record_daily_activity',
        params: {'p_source': source},
      );
      debugPrint('🔥 streak updated: ${row?['current_streak']}');
      await _checkMilestone((row?['current_streak'] as num?)?.toInt() ?? 0);
    } catch (e) {
      debugPrint('❌ record_daily_activity failed: $e');
    }
  }

  /// Reads current streak state + whether today is still unlogged (at risk).
  Future<StreakStatus> getStatus() async {
    if (currentUserId == null) return StreakStatus.empty;
    try {
      final data =
          await supabase.rpc('get_streak_status') as Map<String, dynamic>?;
      if (data == null) return StreakStatus.empty;
      return StreakStatus.fromJson(data);
    } catch (e) {
      debugPrint('❌ get_streak_status failed: $e');
      return StreakStatus.empty;
    }
  }

  Future<void> _checkMilestone(int currentStreak) async {
    final crossed = _milestones.where((m) => m <= currentStreak).toList();
    if (crossed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final celebrated = prefs.getInt(_celebratedKey) ?? 0;
    final highest = crossed.reduce((a, b) => a > b ? a : b);

    if (highest > celebrated && currentStreak >= highest) {
      // Only fire when we are exactly landing on it this session.
      await prefs.setInt(_celebratedKey, highest);
      milestoneReached.value = highest;
    }
  }
}
