import 'supabase_config.dart';

class StatsService {
  final _client = SupabaseConfig.client;

  Future<Map<String, dynamic>> getTodayStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return _emptyStats();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      return await _client
          .from('daily_stats')
          .select()
          .eq('user_id', userId)
          .eq('date', today)
          .single();
    } catch (_) {
      return _emptyStats();
    }
  }

  Future<void> updateTodayStats({
    int? calories,
    int? steps,
    int? activeMinutes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _client.from('daily_stats').upsert({
      'user_id': userId,
      'date': today,
      if (calories != null) 'calories': calories,
      if (steps != null) 'steps': steps,
      if (activeMinutes != null) 'active_minutes': activeMinutes,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,date');
  }

  Future<List<Map<String, dynamic>>> getWeeklyActivity() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return _emptyWeek();
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = monday.toIso8601String().substring(0, 10);
    try {
      final response = await _client
          .from('weekly_activity')
          .select()
          .eq('user_id', userId)
          .eq('week_start', weekStart)
          .order('day_index');
      if ((response as List).isEmpty) return _emptyWeek();
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return _emptyWeek();
    }
  }

  Future<void> logWorkout({
    required String muscleGroup,
    required String exerciseName,
    int? setsDone,
    int? repsDone,
    double? weightKg,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('workout_logs').insert({
      'user_id': userId,
      'muscle_group': muscleGroup,
      'exercise_name': exerciseName,
      if (setsDone != null) 'sets_done': setsDone,
      if (repsDone != null) 'reps_done': repsDone,
      if (weightKg != null) 'weight_kg': weightKg,
    });
  }

  Map<String, dynamic> _emptyStats() =>
      {'calories': 0, 'steps': 0, 'active_minutes': 0};

  List<Map<String, dynamic>> _emptyWeek() =>
      List.generate(7, (i) =>
          {'day_index': i, 'actual_pct': 0, 'goal_pct': 0});
}
