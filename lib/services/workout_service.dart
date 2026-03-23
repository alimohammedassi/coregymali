import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class WorkoutService {
  // Start a new session
  Future<String?> startSession({
    required String muscleGroup,
    String? sessionName,
  }) async {
    if (currentUserId == null) return null;
    try {
      final row = await supabase.from('workout_sessions').insert({
        'user_id': currentUserId,
        'muscle_group': muscleGroup,
        'session_name': sessionName ?? '$muscleGroup workout',
        'session_date': DateTime.now().toIso8601String().substring(0, 10),
      }).select().single();
      return row['id'];
    } on PostgrestException catch (e) {
      print('Supabase error starting session: ${e.message} | code: ${e.code}');
      return null;
    } catch (e) {
      print('Error starting session: $e');
      return null;
    }
  }

  // Log a set
  Future<void> logSet({
    required String sessionId,
    required String exerciseName,
    required int setNumber,
    int? reps,
    double? weightKg,
    int? durationSec,
  }) async {
    if (currentUserId == null) return;
    try {
      await supabase.from('workout_sets').insert({
        'session_id': sessionId,
        'user_id': currentUserId,
        'exercise_name': exerciseName,
        'set_number': setNumber,
        if (reps != null) 'reps': reps,
        if (weightKg != null) 'weight_kg': weightKg,
        if (durationSec != null) 'duration_sec': durationSec,
      });
    } on PostgrestException catch (e) {
      print('Supabase error logging set: ${e.message} | code: ${e.code}');
    } catch (e) {
      print('Error logging set: $e');
    }
  }

  // End session
  Future<void> endSession(String sessionId, int durationMin) async {
    if (currentUserId == null) return;
    try {
      await supabase.from('workout_sessions').update({
        'ended_at': DateTime.now().toIso8601String(),
        'duration_min': durationMin,
      }).eq('id', sessionId).eq('user_id', currentUserId!);
    } on PostgrestException catch (e) {
      print('Supabase error ending session: ${e.message} | code: ${e.code}');
    } catch (e) {
      print('Error ending session: $e');
    }
  }

  // Get today's sessions
  Future<List<Map<String, dynamic>>> getTodaySessions() async {
    if (currentUserId == null) return [];
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      return await supabase
          .from('workout_sessions')
          .select('*, workout_sets(*)')
          .eq('user_id', currentUserId!)
          .eq('session_date', today)
          .order('started_at');
    } on PostgrestException catch (e) {
      print('Supabase error getting today sessions: ${e.message} | code: ${e.code}');
      return [];
    } catch (e) {
      print('Error getting today sessions: $e');
      return [];
    }
  }

  // Get sets for a session
  Future<List<Map<String, dynamic>>> getSessionSets(String sessionId) async {
    if (currentUserId == null) return [];
    try {
      return await supabase
          .from('workout_sets')
          .select()
          .eq('session_id', sessionId)
          .eq('user_id', currentUserId!)
          .order('set_number');
    } on PostgrestException catch (e) {
      print('Supabase error getting session sets: ${e.message} | code: ${e.code}');
      return [];
    } catch (e) {
      print('Error getting session sets: $e');
      return [];
    }
  }

  // Personal records
  Future<List<Map<String, dynamic>>> getPersonalRecords() async {
    if (currentUserId == null) return [];
    try {
      return await supabase
          .from('personal_records')
          .select()
          .eq('user_id', currentUserId!);
    } on PostgrestException catch (e) {
      print('Supabase error getting personal records: ${e.message} | code: ${e.code}');
      return [];
    } catch (e) {
      print('Error getting personal records: $e');
      return [];
    }
  }
}
