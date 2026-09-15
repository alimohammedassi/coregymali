import 'package:flutter/foundation.dart';

/// One day's tracked activity, as shown by the Home week selector and the
/// Water/Steps cards. Source of truth is `daily_summary` (fed by nutrition
/// logging, water logging, manual steps and the smartwatch sync) joined with
/// `user_goals` — the exact same data the leaderboard RPC already exposes.
@immutable
class DayActivity {
  final DateTime date;

  final int caloriesConsumed;
  final int waterMl;
  final int steps;
  final bool workoutDone;

  const DayActivity({
    required this.date,
    this.caloriesConsumed = 0,
    this.waterMl = 0,
    this.steps = 0,
    this.workoutDone = false,
  });

  /// True when the user logged anything that day — drives the week
  /// selector's activity dot. Future days and untouched days are empty.
  bool get hasActivity =>
      caloriesConsumed > 0 || waterMl > 0 || steps > 0 || workoutDone;

  bool isSameDay(DateTime other) =>
      date.year == other.year && date.month == other.month && date.day == other.day;

  DayActivity copyWith({
    int? caloriesConsumed,
    int? waterMl,
    int? steps,
    bool? workoutDone,
  }) {
    return DayActivity(
      date: date,
      caloriesConsumed: caloriesConsumed ?? this.caloriesConsumed,
      waterMl: waterMl ?? this.waterMl,
      steps: steps ?? this.steps,
      workoutDone: workoutDone ?? this.workoutDone,
    );
  }

  factory DayActivity.empty(DateTime date) => DayActivity(date: date);

  factory DayActivity.fromMap(DateTime date, Map<String, dynamic> map) {
    return DayActivity(
      date: date,
      caloriesConsumed: (map['calories_consumed'] as num?)?.toInt() ?? 0,
      waterMl: (map['water_ml'] as num?)?.toInt() ?? 0,
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      workoutDone: map['workout_done'] as bool? ?? false,
    );
  }
}
