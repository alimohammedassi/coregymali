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

/// Next tier threshold the given score is climbing toward (null at diamond).
int? nextTierThreshold(int score) {
  if (score >= 85) return null;
  if (score >= 70) return 85;
  if (score >= 50) return 70;
  if (score > 0) return 50;
  return 1; // unranked → bronze
}

/// Competition board category. Wire values match get_leaderboard_v2's
/// p_category parameter.
enum LeaderboardCategory {
  overall('overall'),
  calories('calories'),
  water('water'),
  workouts('workouts'),
  streak('streak'),
  longestStreak('longest_streak');

  final String wire;
  const LeaderboardCategory(this.wire);

  /// True when the board value is a day count rather than a 0..100 score,
  /// so tier chips/milestones don't apply.
  bool get isStreakBased =>
      this == LeaderboardCategory.streak ||
      this == LeaderboardCategory.longestStreak;
}

class LeaderboardEntry {
  final String userId;
  final String name;
  final String? avatarUrl;
  final int score; // 0..100 weekly commitment (or category value: count/days)
  final int daysLogged;
  final int avgCalories;
  final int avgWaterMl;

  // v2 competitive fields — null on legacy get_leaderboard payloads.
  final int rank;
  final int? rankDelta; // previous_rank - current_rank; null = new on board
  final List<int>? trend; // last 7 daily values (0..100) for the sparkline
  final int currentStreak;
  final int longestStreak;

  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.score,
    required this.daysLogged,
    this.avgCalories = 0,
    this.avgWaterMl = 0,
    this.rank = 0,
    this.rankDelta,
    this.trend,
    this.currentStreak = 0,
    this.longestStreak = 0,
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
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      rankDelta: (map['rank_delta'] as num?)?.toInt(),
      trend: map['trend'] == null
          ? null
          : [
              for (final v in (map['trend'] as List))
                (v as num?)?.toInt() ?? 0,
            ],
      currentStreak: (map['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longest_streak'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The signed-in user's full position on one category board — served in the
/// same get_leaderboard_v2 payload so the screen needs a single round trip.
class LeaderboardStanding {
  final String userId;
  final String name;
  final String? avatarUrl;
  final int rank;
  final int total;
  final int score;
  final int daysLogged;
  final int? rankDelta;
  final List<int>? trend;
  final int currentStreak;
  final int longestStreak;
  final int calAdherence; // component %, for the overall breakdown sheet
  final int waterAdherence;
  final String? nextUser;
  final int? nextRank;
  final int? nextScore;

  /// Points (or days/workouts) needed to pass [nextUser]; 0 when tied,
  /// and meaningless when [nextUser] is null (rank 1).
  final int pointsToNext;

  const LeaderboardStanding({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.rank,
    required this.total,
    required this.score,
    required this.daysLogged,
    required this.currentStreak,
    required this.longestStreak,
    required this.calAdherence,
    required this.waterAdherence,
    required this.pointsToNext,
    this.rankDelta,
    this.trend,
    this.nextUser,
    this.nextRank,
    this.nextScore,
  });

  RankTier get tier => tierForScore(score);

  factory LeaderboardStanding.fromMap(Map<String, dynamic> map) {
    return LeaderboardStanding(
      userId: map['user_id'].toString(),
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Client',
      avatarUrl: map['avatar_url'] as String?,
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      score: (map['score'] as num?)?.toInt() ?? 0,
      daysLogged: (map['days_logged'] as num?)?.toInt() ?? 0,
      rankDelta: (map['rank_delta'] as num?)?.toInt(),
      trend: map['trend'] == null
          ? null
          : [
              for (final v in (map['trend'] as List))
                (v as num?)?.toInt() ?? 0,
            ],
      currentStreak: (map['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longest_streak'] as num?)?.toInt() ?? 0,
      calAdherence: (map['cal_adherence'] as num?)?.toInt() ?? 0,
      waterAdherence: (map['water_adherence'] as num?)?.toInt() ?? 0,
      nextUser: map['next_user'] as String?,
      nextRank: (map['next_rank'] as num?)?.toInt(),
      nextScore: (map['next_score'] as num?)?.toInt(),
      pointsToNext: (map['points_to_next'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeaderboardResult {
  final LeaderboardCategory category;
  final int days;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<LeaderboardEntry> entries;
  final LeaderboardStanding? me;

  const LeaderboardResult({
    required this.category,
    required this.days,
    required this.periodStart,
    required this.periodEnd,
    required this.entries,
    required this.me,
  });
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

class ScoreHistoryPoint {
  final DateTime date;
  final double score;
  const ScoreHistoryPoint({required this.date, required this.score});
}

class RankHistoryPoint {
  final DateTime date;
  final int rank;
  final int total;
  final int score;
  const RankHistoryPoint({
    required this.date,
    required this.rank,
    required this.total,
    required this.score,
  });
}

class RankDelta {
  final int currentRank;
  final int? previousRank;

  /// previousRank - currentRank; positive = improved. Null when the user
  /// wasn't on the previous board (new entrant).
  final int? delta;
  const RankDelta({
    required this.currentRank,
    required this.previousRank,
    required this.delta,
  });
}

class UserStreak {
  final int current;
  final int longest;
  final DateTime? lastActiveDate;
  const UserStreak({
    required this.current,
    required this.longest,
    this.lastActiveDate,
  });

  static const empty = UserStreak(current: 0, longest: 0);

  factory UserStreak.fromMap(Map<String, dynamic> map) {
    return UserStreak(
      current: (map['current_streak'] as num?)?.toInt() ?? 0,
      longest: (map['longest_streak'] as num?)?.toInt() ?? 0,
      lastActiveDate: map['last_active_date'] == null
          ? null
          : DateTime.parse(map['last_active_date'].toString()),
    );
  }
}

class RecapEntry {
  final String userId;
  final String name;
  final String? avatarUrl;
  final int score;
  const RecapEntry({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.score,
  });
}

/// Podium of the previous Fri..Thu cycle (overall commitment).
class WeeklyRecap {
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<RecapEntry> entries;
  const WeeklyRecap({
    required this.periodStart,
    required this.periodEnd,
    required this.entries,
  });
}

class RankService {
  /// Ranked clients over the last [days] days (server computes the score).
  /// Legacy endpoint — still used as a fallback; the competitive hub screen
  /// uses [getLeaderboardV2].
  Future<List<LeaderboardEntry>> getLeaderboard({int days = 7}) async {
    final res = await SupabaseConfig.client
        .rpc('get_leaderboard', params: {'p_days': days});
    return (res as List)
        .map((row) =>
            LeaderboardEntry.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// One-shot competitive board: entries (rank, delta, 7-day trend, streaks)
  /// plus the signed-in user's full standing — a single round trip.
  Future<LeaderboardResult> getLeaderboardV2({
    LeaderboardCategory category = LeaderboardCategory.overall,
    int days = 7,
    String? forUserId,
  }) async {
    final res = await SupabaseConfig.client.rpc(
      'get_leaderboard_v2',
      params: {
        'p_category': category.wire,
        'p_days': days,
        if (forUserId != null) 'p_target': forUserId,
      },
    );
    final map = Map<String, dynamic>.from(res as Map);
    return LeaderboardResult(
      category: category,
      days: days,
      periodStart: DateTime.parse(map['period_start'].toString()),
      periodEnd: DateTime.parse(map['period_end'].toString()),
      entries: [
        for (final row in (map['entries'] as List?) ?? const [])
          LeaderboardEntry.fromMap(Map<String, dynamic>.from(row as Map)),
      ],
      me: map['me'] == null
          ? null
          : LeaderboardStanding.fromMap(
              Map<String, dynamic>.from(map['me'] as Map)),
    );
  }

  /// Top 3 of the previous Fri..Thu cycle. Null when nobody logged.
  Future<WeeklyRecap?> getWeeklyRecap({int days = 7}) async {
    final res = await SupabaseConfig.client
        .rpc('get_weekly_recap', params: {'p_days': days});
    if (res == null) return null;
    final map = Map<String, dynamic>.from(res as Map);
    final entries = [
      for (final row in (map['entries'] as List?) ?? const [])
        RecapEntry(
          userId: (row as Map)['user_id'].toString(),
          name: ((row['name'] as String?) ?? 'Client').trim(),
          avatarUrl: row['avatar_url'] as String?,
          score: (row['score'] as num?)?.toInt() ?? 0,
        ),
    ];
    if (entries.isEmpty) return null;
    return WeeklyRecap(
      periodStart: DateTime.parse(map['period_start'].toString()),
      periodEnd: DateTime.parse(map['period_end'].toString()),
      entries: entries,
    );
  }

  /// The user's rank at the end of each of the last [days] days
  /// (ranked by the rolling 7-day overall score as of that day).
  Future<List<RankHistoryPoint>> getRankHistory(
    String userId, {
    int days = 30,
  }) async {
    final res = await SupabaseConfig.client
        .rpc('get_rank_history', params: {'p_target': userId, 'p_days': days});
    return [
      for (final row in (res as List))
        () {
          final map = Map<String, dynamic>.from(row as Map);
          return RankHistoryPoint(
            date: DateTime.parse(map['history_date'].toString()),
            rank: (map['rank'] as num?)?.toInt() ?? 0,
            total: (map['total'] as num?)?.toInt() ?? 0,
            score: (map['score'] as num?)?.toInt() ?? 0,
          );
        }(),
    ];
  }

  /// Effective current + longest streak (reuses the user_streaks system).
  Future<UserStreak?> getUserStreak(String userId) async {
    final res = await SupabaseConfig.client
        .rpc('get_user_streak', params: {'p_target': userId});
    if (res == null) return null;
    return UserStreak.fromMap(Map<String, dynamic>.from(res as Map));
  }

  /// Daily commitment score for [userId] over the last [days] days.
  /// Served by the same RPC that feeds the profile charts (day_score), so
  /// the ranking math is never duplicated client-side.
  Future<List<ScoreHistoryPoint>> getScoreHistory(
    String userId, {
    int days = 30,
  }) async {
    final activity = await getUserActivity(userId, days: days);
    return [
      for (final d in activity)
        ScoreHistoryPoint(date: d.date, score: d.score.toDouble()),
    ];
  }

  /// Rank movement between the previous and current board. The board payload
  /// already carries deltas for every entry, so UI code never needs this —
  /// it exists as the standalone API for callers that hold no board.
  Future<RankDelta?> getRankDelta(
    String userId, {
    LeaderboardCategory category = LeaderboardCategory.overall,
    int days = 7,
  }) async {
    final result = await getLeaderboardV2(
      category: category,
      days: days,
      forUserId: userId,
    );
    final me = result.me;
    if (me == null) return null;
    return RankDelta(
      currentRank: me.rank,
      previousRank: me.rank + (me.rankDelta ?? 0), // delta = prev - current
      delta: me.rankDelta,
    );
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
