import 'supabase_client.dart';

class WorkoutService {
  // Start a new session
  Future<String?> startSession({
    required String muscleGroup,
    String? sessionName,
  }) async {
    if (currentUserId == null) return null;
    final row = await supabase.from('workout_sessions').insert({
      'user_id': currentUserId,
      'muscle_group': muscleGroup,
      'session_name': sessionName ?? '$muscleGroup workout',
      'session_date': DateTime.now().toIso8601String().substring(0,10),
    }).select().single();
    return row['id'];
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
    await supabase.from('workout_sets').insert({
      'session_id': sessionId,
      'user_id': currentUserId,
      'exercise_name': exerciseName,
      'set_number': setNumber,
      if (reps != null) 'reps': reps,
      if (weightKg != null) 'weight_kg': weightKg,
      if (durationSec != null) 'duration_sec': durationSec,
    });
  }

  // End session
  Future<void> endSession(String sessionId, int durationMin) async {
    await supabase.from('workout_sessions').update({
      'ended_at': DateTime.now().toIso8601String(),
      'duration_min': durationMin,
    }).eq('id', sessionId);
  }

  // Get today's sessions
  Future<List<Map<String,dynamic>>> getTodaySessions() async {
    if (currentUserId == null) return [];
    final today = DateTime.now().toIso8601String().substring(0,10);
    return await supabase
        .from('workout_sessions')
        .select('*, workout_sets(*)')
        .eq('user_id', currentUserId!)
        .eq('session_date', today)
        .order('started_at');
  }

  // Get sets for a session
  Future<List<Map<String,dynamic>>> getSessionSets(String sessionId) async {
    return await supabase
        .from('workout_sets')
        .select()
        .eq('session_id', sessionId)
        .order('set_number');
  }

  // Personal records
  Future<List<Map<String,dynamic>>> getPersonalRecords() async {
    if (currentUserId == null) return [];
    return await supabase
        .from('personal_records')
        .select()
        .eq('user_id', currentUserId!);
  }
}
