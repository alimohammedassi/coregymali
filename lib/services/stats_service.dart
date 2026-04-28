import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class StatsService {
  // Get today's summary
  Future<Map<String, dynamic>> getTodaySummary() async {
    if (currentUserId == null) return _empty();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final res = await supabase
          .from('daily_summary')
          .select()
          .eq('user_id', currentUserId!)
          .eq('summary_date', today)
          .maybeSingle();
      if (res == null) return _empty();
      return res;
    } on PostgrestException catch (e) {
      print('Supabase error getting today summary: ${e.message} | code: ${e.code}');
      return _empty();
    } catch (e) {
      print('Error getting today summary: $e');
      return _empty();
    }
  }

  // Update manual stats (steps, water, sleep, mood)
  Future<void> updateTodaySummary(Map<String, dynamic> data) async {
    if (currentUserId == null) return;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await supabase.from('daily_summary').upsert({
        'user_id': currentUserId,
        'summary_date': today,
        ...data,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,summary_date');
    } on PostgrestException catch (e) {
      print('Supabase error updating today summary: ${e.message} | code: ${e.code}');
    } catch (e) {
      print('Error updating today summary: $e');
    }
  }

  // Get weekly progress (for charts — last 7 days)
  Future<List<Map<String, dynamic>>> getWeeklyProgress() async {
    if (currentUserId == null) return [];
    try {
      final from = DateTime.now().subtract(const Duration(days: 6));
      return await supabase
          .from('weekly_progress')
          .select()
          .eq('user_id', currentUserId!)
          .gte('summary_date', from.toIso8601String().substring(0, 10))
          .order('summary_date');
    } on PostgrestException catch (e) {
      print('Supabase error getting weekly progress: ${e.message} | code: ${e.code}');
      return [];
    } catch (e) {
      print('Error getting weekly progress: $e');
      return [];
    }
  }

  // Get user goals
  Future<Map<String, dynamic>> getGoals() async {
    if (currentUserId == null) return _defaultGoals();
    try {
      final res = await supabase
          .from('user_goals')
          .select()
          .eq('user_id', currentUserId!)
          .maybeSingle();
      if (res == null) return _defaultGoals();
      return res;
    } on PostgrestException catch (e) {
      print('Supabase error getting goals: ${e.message} | code: ${e.code}');
      return _defaultGoals();
    } catch (e) {
      print('Error getting goals: $e');
      return _defaultGoals();
    }
  }

  Map<String, dynamic> _empty() => {
        'calories_consumed': 0,
        'calories_burned': 0,
        'protein_g': 0,
        'carbs_g': 0,
        'fat_g': 0,
        'steps': 0,
        'active_minutes': 0,
        'water_ml': 0,
        'workout_done': false,
        'workout_duration': 0,
      };

  Map<String, dynamic> _defaultGoals() => {
        'daily_calories': 2000,
        'daily_protein_g': 150,
        'daily_carbs_g': 250,
        'daily_fat_g': 65,
        'daily_water_ml': 2500,
        'daily_steps': 10000,
      };
}
