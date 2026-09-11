import '../supabase/supabase_config.dart';
/// Tier for a 0..100 weekly commitment score.
enum RankTier { unranked, bronze, silver, gold, diamond }

RankTier tierForScore(int score) {
  if (score >= 85) return RankTier.diamond;
  if (score >= 70) return RankTier.gold;
  if (score >= 50) return RankTier.silver;
  if (score > 0) return RankTier.bronze;
  return RankTier.unranked;
}

class LeaderboardEntry {
  final String userId;
  final String name;
  final String? avatarUrl;
  final int score; // 0..100 weekly commitment
  final int daysLogged;
  final int avgCalories;
  final int avgWaterMl;

  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.score,
    required this.daysLogged,
    required this.avgCalories,
    required this.avgWaterMl,
  });

  RankTier get tier => tierForScore(score);

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      userId: map['user_id'].toString(),
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Client',
      avatarUrl: map['avatar_url'] as String?,
      score: (map['score'] as num?)?.toInt() ?? 0,
      daysLogged: (map['days_logged'] as num?)?.toInt() ?? 0,
      avgCalories: (map['avg_calories'] as num?)?.toInt() ?? 0,
      avgWaterMl: (map['avg_water_ml'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One day of a user's tracked activity (from daily_summary + user_goals).
class ActivityDay {
  final DateTime date;
  final int calories;
  final int calorieGoal;
  final int waterMl;
  final int waterGoal;
  final int steps;
  final int stepsGoal;
  final bool workoutDone;
  final int score; // 0..100

  const ActivityDay({
    required this.date,
    required this.calories,
    required this.calorieGoal,
    required this.waterMl,
    required this.waterGoal,
    required this.steps,
    required this.stepsGoal,
    required this.workoutDone,
    required this.score,
  });

  double get calorieAdherence {
    if (calories <= 0 || calorieGoal <= 0) return 0;
    return (1 - ((calories - calorieGoal).abs() / calorieGoal))
        .clamp(0.0, 1.0);
  }

  double get waterAdherence =>
      waterGoal <= 0 ? 0 : (waterMl / waterGoal).clamp(0.0, 1.0);

  double get stepsAdherence =>
      stepsGoal <= 0 ? 0 : (steps / stepsGoal).clamp(0.0, 1.0);

  factory ActivityDay.fromMap(Map<String, dynamic> map) {
    return ActivityDay(
      date: DateTime.parse(map['summary_date'].toString()),
      calories: (map['calories_consumed'] as num?)?.toInt() ?? 0,
      calorieGoal: (map['calorie_goal'] as num?)?.toInt() ?? 2000,
      waterMl: (map['water_ml'] as num?)?.toInt() ?? 0,
      waterGoal: (map['water_goal'] as num?)?.toInt() ?? 2500,
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      stepsGoal: (map['steps_goal'] as num?)?.toInt() ?? 8000,
      workoutDone: map['workout_done'] as bool? ?? false,
      score: (map['day_score'] as num?)?.toInt() ?? 0,
    );
  }
}

class RankService {
  /// Ranked clients over the last [days] days (server computes the score).
  Future<List<LeaderboardEntry>> getLeaderboard({int days = 7}) async {
    final res = await SupabaseConfig.client
        .rpc('get_leaderboard', params: {'p_days': days});
    return (res as List)
        .map((row) =>
            LeaderboardEntry.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// One user's daily activity for the profile-page charts.
  Future<List<ActivityDay>> getUserActivity(String userId, {int days = 30}) async {
    final res = await SupabaseConfig.client
        .rpc('get_user_activity', params: {'p_target': userId, 'p_days': days});
    return (res as List)
        .map((row) =>
            ActivityDay.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }
}
