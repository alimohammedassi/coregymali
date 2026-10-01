import 'package:flutter/foundation.dart';

import '../../../services/supabase_client.dart';
import 'attendance_day.dart';
import 'gym.dart';
import 'selected_gym.dart';

/// Data access for the user's configured gym.
///
/// Follows the app's shared Supabase access pattern (services/supabase_client):
/// the global `supabase` client + `currentUserId` getter. RLS on the `gyms`
/// table scopes every read/write to the signed-in user's own rows.
class GymService {
  /// Saves a new gym row. Multiple inserts are allowed over time — the newest
  /// row (created_at desc) is treated as the active gym.
  Future<void> saveGym(SelectedGym g) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError('GymService: no signed-in user');
    }
    await supabase.from('gyms').insert({
      'user_id': userId,
      'name': g.name,
      'latitude': g.latitude,
      'longitude': g.longitude,
      'radius_m': g.radiusM,
    });
  }

  /// The active gym — latest `gyms` row by created_at desc — or null when the
  /// user has not configured one yet (or the read fails; failures never
  /// crash the UI, they surface as "no gym configured").
  Future<Gym?> getActiveGym() async {
    if (currentUserId == null) return null;
    try {
      final rows = await supabase
          .from('gyms')
          .select()
          .order('created_at', ascending: false)
          .limit(1);
      final list = rows as List<dynamic>;
      if (list.isEmpty) return null;
      return Gym.fromMap(Map<String, dynamic>.from(list.first as Map));
    } catch (e) {
      debugPrint('❌ getActiveGym failed: $e');
      return null;
    }
  }

  /// True when the user has an active gym configured.
  Future<bool> hasConfiguredGym() async {
    return (await getActiveGym()) != null;
  }

  /// Attendance history for the heatmap — one [AttendanceDay] per calendar
  /// date since [since] (duration = that day's longest dwell, across gyms).
  /// Failures return an empty map: the heatmap renders as all-empty rather
  /// than erroring the screen.
  Future<Map<DateTime, AttendanceDay>> getAttendanceSince(
    DateTime since,
  ) async {
    if (currentUserId == null) return {};
    try {
      final rows = await supabase
          .from('gym_attendance')
          .select('date, duration_minutes')
          .gte('date', since.toIso8601String().substring(0, 10));
      final map = <DateTime, AttendanceDay>{};
      for (final raw in rows as List<dynamic>) {
        final row = Map<String, dynamic>.from(raw as Map);
        final date = DateTime.parse(row['date'] as String);
        final day = DateTime(date.year, date.month, date.day);
        final minutes = (row['duration_minutes'] as num?)?.toInt() ?? 0;
        final existing = map[day];
        if (existing == null || minutes > existing.minutes) {
          map[day] = AttendanceDay(minutes: minutes);
        }
      }
      return map;
    } catch (e) {
      debugPrint('❌ getAttendanceSince failed: $e');
      return {};
    }
  }

  /// The most recent raw attendance rows for the check-ins list. Newest
  /// first; failures return an empty list like every other read here.
  Future<List<AttendanceRecord>> getRecentAttendance({int limit = 4}) async {
    if (currentUserId == null) return [];
    try {
      final rows = await supabase
          .from('gym_attendance')
          .select(
            'date, check_in_time, check_out_time, duration_minutes, source',
          )
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      final records = <AttendanceRecord>[];
      for (final raw in rows as List<dynamic>) {
        final row = Map<String, dynamic>.from(raw as Map);
        final date = DateTime.parse(row['date'] as String);
        final checkIn = row['check_in_time'] == null
            ? null
            : DateTime.parse(row['check_in_time'] as String);
        final checkOut = row['check_out_time'] == null
            ? null
            : DateTime.parse(row['check_out_time'] as String);
        records.add(
          AttendanceRecord(
            date: DateTime(date.year, date.month, date.day),
            checkIn: checkIn,
            checkOut: checkOut,
            minutes: (row['duration_minutes'] as num?)?.toInt() ?? 0,
            source: (row['source'] as String?) ?? 'geofence',
          ),
        );
      }
      return records;
    } catch (e) {
      debugPrint('❌ getRecentAttendance failed: $e');
      return [];
    }
  }

  /// Records a geofence-detected visit on `gym_attendance`.
  ///
  /// `gym_attendance` holds ONE row per (user, gym, date), so a longer
  /// session always wins: an existing row is only updated when the new
  /// dwell is longer (extends check_out_time + duration_minutes); a shorter
  /// or equal re-detection leaves the row untouched. Never throws — a failed
  /// write must not break the watcher's state machine.
  Future<void> recordAttendance({
    required DateTime sessionStart,
    required int durationMinutes,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      final gym = await getActiveGym();
      if (gym == null) return;

      // Local calendar date of the check-in (yyyy-MM-dd).
      final date = sessionStart.toIso8601String().substring(0, 10);
      final checkOut = sessionStart.add(Duration(minutes: durationMinutes));

      final existing = await supabase
          .from('gym_attendance')
          .select('id, duration_minutes')
          .eq('user_id', userId)
          .eq('gym_id', gym.id)
          .eq('date', date)
          .maybeSingle();

      if (existing == null) {
        await supabase.from('gym_attendance').insert({
          'user_id': userId,
          'gym_id': gym.id,
          'date': date,
          'check_in_time': sessionStart.toIso8601String(),
          'check_out_time': checkOut.toIso8601String(),
          'duration_minutes': durationMinutes,
          'activity_confirmed': false,
          'source': 'geofence',
        });
      } else {
        final existingMinutes =
            (existing['duration_minutes'] as num?)?.toInt() ?? 0;
        if (durationMinutes > existingMinutes) {
          await supabase
              .from('gym_attendance')
              .update({
                'check_out_time': checkOut.toIso8601String(),
                'duration_minutes': durationMinutes,
              })
              .eq('id', existing['id'] as String);
        }
      }
    } catch (e) {
      debugPrint('recordAttendance failed: $e');
    }
  }

  /// Manual check-in fallback (GPS-unavailable / permission-revoked path).
  ///
  /// Records a 30-minute manual visit for today via the same longest-wins
  /// [recordAttendance] path, so a longer geofence session on the same day
  /// still wins. Returns true when a visit was recorded (an active gym
  /// exists), false otherwise. Never throws.
  Future<bool> recordManualCheckIn() async {
    try {
      final gym = await getActiveGym();
      if (gym == null) return false;
      await recordAttendance(
        sessionStart: DateTime.now(),
        durationMinutes: 30,
      );
      return true;
    } catch (e) {
      debugPrint('recordManualCheckIn failed: $e');
      return false;
    }
  }
}
