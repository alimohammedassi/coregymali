import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../supabase/supabase_config.dart';

/// Task 4 — local water reminders (no server round-trip).
///
/// Schedule: every 2 hours 08:00 → 22:00 device time (8 slots, daily repeat).
/// Stops for the day once the user's water goal (user_goals.daily_water_ml
/// vs daily_summary.water_ml) is reached — [refresh] re-anchors the schedule
/// to tomorrow in that case. Call [refresh] on app start and after any water
/// log. Respects notification_preferences.water_reminders_enabled (missing
/// row = enabled, per the all-ON default).
///
/// Timezone is pinned to Africa/Cairo (the app's user base); quiet hours past
/// 22:00 are inherently respected by the schedule window.
class WaterReminderService {
  WaterReminderService._();
  static final WaterReminderService instance = WaterReminderService._();

  static const List<int> _hours = [8, 10, 12, 14, 16, 18, 20, 22];
  static const int _firstId = 100; // ids 100..107

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _tzReady = false;

  Future<void> _ensureReady() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Permission is requested by the OneSignal dialog only.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) {},
    );
    _tzReady = true;
  }

  /// Re-evaluates everything and re-anchors the daily schedule. Cheap enough
  /// to call on every app start and after every water log.
  Future<void> refresh() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    await _ensureReady();

    bool enabled = true; // missing prefs row = all-ON default
    try {
      final pref = await SupabaseConfig.client
          .from('notification_preferences')
          .select('water_reminders_enabled')
          .eq('user_id', userId)
          .maybeSingle();
      if (pref != null) {
        enabled = pref['water_reminders_enabled'] as bool? ?? true;
      }
    } catch (_) {
      enabled = true;
    }

    if (!enabled) {
      await _cancelAll();
      debugPrint('Water reminders: disabled by preference');
      return;
    }

    int goalMl = 2500;
    int drankMl = 0;
    try {
      final goals = await SupabaseConfig.client
          .from('user_goals')
          .select('daily_water_ml')
          .eq('user_id', userId)
          .maybeSingle();
      goalMl = (goals?['daily_water_ml'] as num?)?.toInt() ?? 2500;

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final summary = await SupabaseConfig.client
          .from('daily_summary')
          .select('water_ml')
          .eq('user_id', userId)
          .eq('summary_date', today)
          .maybeSingle();
      drankMl = (summary?['water_ml'] as num?)?.toInt() ?? 0;
    } catch (_) {
      // Keep defaults on any read failure.
    }

    final goalReached = drankMl >= goalMl && goalMl > 0;
    final now = DateTime.now();
    // Goal hit → the whole schedule re-anchors to tomorrow; otherwise slots
    // already past today simply resume tomorrow (daily repeat skips them).
    final anchorDate = goalReached
        ? DateTime(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day);

    for (var i = 0; i < _hours.length; i++) {
      final slot = tz.TZDateTime(
        tz.local,
        anchorDate.year,
        anchorDate.month,
        anchorDate.day,
        _hours[i],
      );
      await _plugin.zonedSchedule(
        _firstId + i,
        'Time to hydrate 💧',
        'Drink a glass of water — $drankMl / $goalMl ml so far today.',
        slot,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'water_reminders',
            'Water reminders',
            channelDescription: 'Every-2-hours hydration nudges',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
    debugPrint(
      'Water reminders: 8 slots scheduled from $anchorDate '
      '(goalReached=$goalReached, $drankMl/$goalMl ml)',
    );

    // Debug-only smoke test: shows one immediate notification the very first
    // run so the pipeline is visibly confirmed (never in release builds).
    if (kDebugMode) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('water_smoke_done') != true) {
        await prefs.setBool('water_smoke_done', true);
        await _plugin.show(
          199,
          'Water reminders are on 💧',
          'You will be nudged every 2 hours from 8:00 to 22:00.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'water_reminders',
              'Water reminders',
            ),
          ),
        );
      }
    }
  }

  Future<void> _cancelAll() async {
    await _ensureReady();
    for (var i = 0; i < _hours.length; i++) {
      await _plugin.cancel(_firstId + i);
    }
  }
}
