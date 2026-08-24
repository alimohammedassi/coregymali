import 'package:flutter/foundation.dart';

@immutable
class DailyActivity {
  final int steps;
  final double activeCaloriesBurned;
  final double? heartRateAvg;
  final double? exerciseMinutes;
  final DateTime date;
  final String source; // 'healthkit', 'health_connect', 'manual'
  final DateTime? syncedAt;

  const DailyActivity({
    required this.steps,
    required this.activeCaloriesBurned,
    this.heartRateAvg,
    this.exerciseMinutes,
    required this.date,
    this.source = 'health_connect',
    this.syncedAt,
  });

  factory DailyActivity.empty([DateTime? date]) => DailyActivity(
        steps: 0,
        activeCaloriesBurned: 0.0,
        heartRateAvg: null,
        exerciseMinutes: null,
        date: date ?? DateTime.now(),
        source: 'manual',
        syncedAt: null,
      );

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    return DailyActivity(
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      activeCaloriesBurned:
          (json['active_calories_burned'] as num?)?.toDouble() ?? 0.0,
      heartRateAvg: (json['heart_rate_avg'] as num?)?.toDouble(),
      exerciseMinutes: (json['exercise_minutes'] as num?)?.toDouble(),
      date: json['activity_date'] != null
          ? DateTime.tryParse(json['activity_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      source: json['source']?.toString() ?? 'health_connect',
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson({String? userId}) {
    return {
      if (userId != null) 'user_id': userId,
      'activity_date': date.toIso8601String().substring(0, 10),
      'steps': steps,
      'active_calories_burned': activeCaloriesBurned,
      if (heartRateAvg != null) 'heart_rate_avg': heartRateAvg,
      if (exerciseMinutes != null) 'exercise_minutes': exerciseMinutes,
      'source': source,
      'synced_at': DateTime.now().toIso8601String(),
    };
  }

  DailyActivity copyWith({
    int? steps,
    double? activeCaloriesBurned,
    double? heartRateAvg,
    double? exerciseMinutes,
    DateTime? date,
    String? source,
    DateTime? syncedAt,
  }) {
    return DailyActivity(
      steps: steps ?? this.steps,
      activeCaloriesBurned:
          activeCaloriesBurned ?? this.activeCaloriesBurned,
      heartRateAvg: heartRateAvg ?? this.heartRateAvg,
      exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
      date: date ?? this.date,
      source: source ?? this.source,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyActivity &&
          runtimeType == other.runtimeType &&
          steps == other.steps &&
          activeCaloriesBurned == other.activeCaloriesBurned &&
          heartRateAvg == other.heartRateAvg &&
          exerciseMinutes == other.exerciseMinutes &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day &&
          source == other.source;

  @override
  int get hashCode =>
      steps.hashCode ^
      activeCaloriesBurned.hashCode ^
      heartRateAvg.hashCode ^
      exerciseMinutes.hashCode ^
      date.day.hashCode ^
      source.hashCode;
}
