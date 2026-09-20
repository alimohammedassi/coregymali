import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'streak_service.dart';
import 'supabase_client.dart';
import 'workout_service.dart' show WorkoutService;

/// One exercise row of the coach's template
/// (`workout_template_exercises`), in template order.
class AssignedExercise {
  final String id;
  final String exerciseName;
  final int targetSets;
  final int? targetReps;
  final double? targetWeightKg;
  final int? restSec;
  final String? notes;
  final int orderIndex;

  const AssignedExercise({
    required this.id,
    required this.exerciseName,
    required this.targetSets,
    this.targetReps,
    this.targetWeightKg,
    this.restSec,
    this.notes,
    required this.orderIndex,
  });

  factory AssignedExercise.fromMap(Map<String, dynamic> map) {
    final sets = (map['target_sets'] as num?)?.toInt() ?? 3;
    return AssignedExercise(
      id: map['id'].toString(),
      exerciseName: (map['exercise_name'] as String?) ?? '',
      targetSets: sets < 1 ? 1 : sets,
      targetReps: (map['target_reps'] as num?)?.toInt(),
      targetWeightKg: (map['target_weight_kg'] as num?)?.toDouble(),
      restSec: (map['rest_sec'] as num?)?.toInt(),
      notes: map['notes'] as String?,
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A coach-assigned workout for today: the assignment joined with its
/// template and the template's exercises (the app's read model).
class AssignedWorkout {
  final String assignmentId;
  final String templateName;
  final List<String> targetMuscles;
  final String? templateNotes;
  final List<AssignedExercise> exercises;

  /// The day the coach scheduled this workout for. The today-card only ever
  /// carries today's date; the history list carries past/upcoming days.
  final DateTime scheduledDate;

  /// 'assigned' for a fresh workout, 'started' when the user already began
  /// it earlier (app killed mid-way) and is resuming. The history list also
  /// carries 'completed' and 'skipped'.
  final String assignmentStatus;

  const AssignedWorkout({
    required this.assignmentId,
    required this.templateName,
    required this.targetMuscles,
    this.templateNotes,
    required this.exercises,
    required this.scheduledDate,
    required this.assignmentStatus,
  });

  bool get isResumable => assignmentStatus == 'started';

  /// First template muscle — becomes the linked workout_sessions
  /// muscle_group (the DB CHECK only accepts the known snake_case list).
  String get primaryMuscle =>
      targetMuscles.isNotEmpty && targetMuscles.first.trim().isNotEmpty
      ? targetMuscles.first.trim()
      : 'Full Body';

  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.targetSets);

  /// Rough session length from the total sets: each set ≈ its work time
  /// plus the template's rest (60s when unset). Display-only estimate.
  int get estimatedMinutes {
    final seconds = exercises.fold<int>(
      0,
      (sum, e) => sum + e.targetSets * ((e.restSec ?? 60) + 45),
    );
    return (seconds / 60).round().clamp(1, 999);
  }

  factory AssignedWorkout.fromMap(Map<String, dynamic> map) {
    final template = map['workout_templates'] as Map<String, dynamic>?;
    final rawExercises = (template?['workout_template_exercises'] as List?)
        ?? const [];
    final muscles = (template?['target_muscles'] as List?)
        ?.map((m) => m.toString())
        .toList() ?? const <String>[];
    return AssignedWorkout(
      assignmentId: map['id'].toString(),
      templateName: (template?['name'] as String?) ?? '',
      targetMuscles: muscles,
      templateNotes: template?['notes'] as String?,
      scheduledDate:
          DateTime.tryParse((map['scheduled_date'] as String?) ?? '') ??
          DateTime.now(),
      assignmentStatus: (map['status'] as String?) ?? 'assigned',
      exercises: rawExercises
          .whereType<Map<String, dynamic>>()
          .map(AssignedExercise.fromMap)
          .toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
    );
  }
}

/// An already-open session found when resuming a 'started' assignment.
class OpenAssignedSession {
  final String id;
  final DateTime? startedAt;
  const OpenAssignedSession({required this.id, this.startedAt});
}

/// Client side of the coach workflow: fetch today's assigned workout,
/// start it (creating a linked workout_sessions row), log every set, and
/// finish (closing the session and completing the assignment) so the
/// result shows up on the coach's dashboard.
///
/// The assignment/template tables ship with the dashboard's migration.
/// Until it lands every read fails with "table not found" — that must
/// degrade to "nothing assigned", never break the app. Likewise the
/// workout_sessions.assignment_id link column may not exist yet, so the
/// insert falls back to an unlinked (still fully logged) session.
class AssignedWorkoutService {
  /// Postgres "undefined column" — assignment_id not migrated yet.
  static const _undefinedColumn = '42703';

  /// workout_sessions_muscle_group_check — muscle label outside the
  /// known snake_case list.
  static const _checkViolation = '23514';

  /// PostgREST "could not find the table" — migration not applied yet.
  static const _missingTable = 'PGRST205';

  Future<AssignedWorkout?> fetchTodayAssignment() async {
    if (currentUserId == null) return null;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final rows = await supabase
          .from('workout_assignments')
          .select(
            'id, status, scheduled_date, '
            'workout_templates(name, target_muscles, notes, '
            'workout_template_exercises(id, exercise_name, target_sets, '
            'target_reps, target_weight_kg, rest_sec, notes, order_index))',
          )
          .eq('client_id', currentUserId!)
          .eq('scheduled_date', today)
          // 'started' assignments stay on the card so a mid-workout app
          // kill can be resumed today; 'skipped'/'completed' are done.
          .inFilter('status', ['assigned', 'started']);
      if (rows.isEmpty) return null;
      final parsed = rows
          .whereType<Map<String, dynamic>>()
          .map(AssignedWorkout.fromMap)
          .toList();
      // Fresh assignments beat the resumable one when both exist.
      parsed.sort(
        (a, b) => (a.isResumable ? 1 : 0).compareTo(b.isResumable ? 1 : 0),
      );
      return parsed.first;
    } on PostgrestException catch (e) {
      // Missing migration is the expected pre-deploy state, not an error.
      if (e.code != _missingTable) {
        debugPrint(
          'Supabase error fetching today\'s assignment: '
          '${e.message} | code: ${e.code}',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching today\'s assignment: $e');
      return null;
    }
  }

  /// Re-reads one assignment fresh from the DB (client-scoped). The today
  /// card passes an assignment object that may be minutes old — the screen
  /// revalidates with this before offering start/resume, so a stale card can
  /// never start a workout the coach's data no longer offers (skipped,
  /// completed, or deleted).
  Future<AssignedWorkout?> fetchAssignmentById(String assignmentId) async {
    if (currentUserId == null) return null;
    try {
      final rows = await supabase
          .from('workout_assignments')
          .select(
            'id, status, scheduled_date, '
            'workout_templates(name, target_muscles, notes, '
            'workout_template_exercises(id, exercise_name, target_sets, '
            'target_reps, target_weight_kg, rest_sec, notes, order_index))',
          )
          .eq('client_id', currentUserId!)
          .eq('id', assignmentId)
          .limit(1);
      if (rows.isEmpty) return null;
      return AssignedWorkout.fromMap(
        (rows as List).whereType<Map<String, dynamic>>().first,
      );
    } on PostgrestException catch (e) {
      if (e.code != _missingTable) {
        debugPrint(
          'Supabase error fetching assignment $assignmentId: '
          '${e.message} | code: ${e.code}',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching assignment $assignmentId: $e');
      return null;
    }
  }

  /// The session left open for a resumed assignment (no ended_at yet).
  /// Returns null when the link column is not migrated yet — resuming
  /// then starts a fresh session instead of reconnecting the old one.
  Future<OpenAssignedSession?> findOpenSession(String assignmentId) async {
    if (currentUserId == null) return null;
    try {
      final rows = await supabase
          .from('workout_sessions')
          .select('id, started_at')
          .eq('assignment_id', assignmentId)
          .eq('user_id', currentUserId!)
          .filter('ended_at', 'is', null)
          .order('started_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      final row = rows.first;
      return OpenAssignedSession(
        id: row['id'].toString(),
        startedAt: row['started_at'] == null
            ? null
            : DateTime.tryParse(row['started_at'] as String),
      );
    } on PostgrestException catch (e) {
      if (e.code != _undefinedColumn) {
        debugPrint(
          'Supabase error finding open session: ${e.message} | code: ${e.code}',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error finding open session: $e');
      return null;
    }
  }

  /// STEP 2 — insert the workout_sessions row for this assignment and flip
  /// the assignment to 'started'. Returns the session id, or null when the
  /// session could not be created (the screen keeps the user in control).
  Future<String?> startWorkout(AssignedWorkout workout) async {
    if (currentUserId == null) return null;
    final now = DateTime.now();
    final session = await _insertSession({
      'user_id': currentUserId,
      'session_name': workout.templateName,
      'muscle_group': WorkoutService.normalizeMuscleGroup(
        workout.primaryMuscle,
      ),
      'session_date': now.toIso8601String().substring(0, 10),
      'started_at': now.toIso8601String(),
      'assignment_id': workout.assignmentId,
    });
    if (session != null) await _setAssignmentStatus('started', workout.assignmentId);
    return session;
  }

  /// Insert with the two pre-migration fallbacks layered: drop
  /// assignment_id when the column doesn't exist, and fall back to
  /// 'full_body' when the template's muscle label fails the DB CHECK.
  Future<String?> _insertSession(Map<String, dynamic> payload) async {
    Future<Map<String, dynamic>?> attempt(Map<String, dynamic> p) async {
      try {
        return await supabase
            .from('workout_sessions')
            .insert(p)
            .select()
            .single();
      } on PostgrestException catch (e) {
        if (e.code == _undefinedColumn && p.containsKey('assignment_id')) {
          return attempt(p..remove('assignment_id'));
        }
        if (e.code == _checkViolation && p['muscle_group'] != 'full_body') {
          return attempt(p..['muscle_group'] = 'full_body');
        }
        debugPrint(
          'Supabase error starting assigned session: '
          '${e.message} | code: ${e.code}',
        );
        return null;
      }
    }

    final row = await attempt(payload);
    return row?['id'] as String?;
  }

  /// STEP 3 — one confirmed set = one workout_sets row. The exercise name
  /// is written exactly as the template spells it so the coach's dashboard
  /// can join logged sets back to the template rows. Every set logged here
  /// is a working set — `is_warmup` is written explicitly (false) because
  /// the dashboard's volume/performance queries filter on it and a NULL
  /// would drop the row from those calculations.
  Future<bool> logSet({
    required String sessionId,
    required String exerciseName,
    required int setNumber,
    required int? reps,
    required double? weightKg,
    required int? restSec,
  }) async {
    if (currentUserId == null) return false;
    try {
      await supabase.from('workout_sets').insert({
        'session_id': sessionId,
        'user_id': currentUserId,
        'exercise_name': exerciseName,
        'set_number': setNumber,
        'is_warmup': false,
        if (reps != null) 'reps': reps,
        if (weightKg != null) 'weight_kg': weightKg,
        if (restSec != null) 'rest_sec': restSec,
        'logged_at': DateTime.now().toIso8601String(),
      });
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Supabase error logging assigned set: ${e.message} | code: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Error logging assigned set: $e');
      return false;
    }
  }

  /// All sets logged in this session so far (progress display reads back
  /// from Supabase, never from local guesswork).
  Future<List<Map<String, dynamic>>> fetchSessionSets(String sessionId) async {
    if (currentUserId == null) return [];
    try {
      return await supabase
          .from('workout_sets')
          .select()
          .eq('session_id', sessionId)
          .eq('user_id', currentUserId!)
          .order('logged_at');
    } on PostgrestException catch (e) {
      debugPrint('Supabase error fetching session sets: ${e.message} | code: ${e.code}');
      return [];
    } catch (e) {
      debugPrint('Error fetching session sets: $e');
      return [];
    }
  }

  /// STEP 4 — close the session (ended_at + rounded duration_min) and mark
  /// the assignment 'completed'. Abandoned sessions are never touched: no
  /// ended_at, assignment stays 'started'.
  Future<bool> finishWorkout({
    required String sessionId,
    required String? assignmentId,
    required DateTime? startedAt,
  }) async {
    if (currentUserId == null) return false;
    final endedAt = DateTime.now();
    final durationMin = startedAt == null
        ? 0
        : (endedAt.difference(startedAt).inSeconds / 60).round();
    try {
      await supabase.from('workout_sessions').update({
        'ended_at': endedAt.toIso8601String(),
        'duration_min': durationMin,
      }).eq('id', sessionId).eq('user_id', currentUserId!);
      StreakService().recordActivity('workout');
    } on PostgrestException catch (e) {
      debugPrint('Supabase error ending assigned session: ${e.message} | code: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Error ending assigned session: $e');
      return false;
    }
    // Assignment status is best-effort: the session itself is closed, a
    // pre-migration dashboard simply won't show the completed flag yet.
    await _setAssignmentStatus('completed', assignmentId);
    return true;
  }

  Future<void> _setAssignmentStatus(String status, String? assignmentId) async {
    if (assignmentId == null) return;
    try {
      await supabase
          .from('workout_assignments')
          .update({'status': status})
          .eq('id', assignmentId);
    } on PostgrestException catch (e) {
      if (e.code != _missingTable) {
        debugPrint(
          'Supabase error updating assignment status: '
          '${e.message} | code: ${e.code}',
        );
      }
    } catch (e) {
      debugPrint('Error updating assignment status: $e');
    }
  }

  /// The customer explicitly declines a scheduled workout — the assignment
  /// flips to 'skipped' and NO workout_sessions row is ever created for it,
  /// so the coach's dashboard reads it as declined rather than missing.
  Future<bool> skipWorkout(String assignmentId) async {
    if (currentUserId == null) return false;
    try {
      await supabase
          .from('workout_assignments')
          .update({'status': 'skipped'})
          .eq('id', assignmentId)
          .eq('client_id', currentUserId!);
      return true;
    } on PostgrestException catch (e) {
      debugPrint(
        'Supabase error skipping assignment: ${e.message} | code: ${e.code}',
      );
      return false;
    } catch (e) {
      debugPrint('Error skipping assignment: $e');
      return false;
    }
  }

  /// The assignment list behind the program tab's schedule section:
  /// upcoming (assigned, dated today or later — today's own card handles
  /// the resumable 'started' state), then completed and skipped, newest
  /// first. Exercises are deliberately not fetched — the list only shows
  /// name/date/status; opening one for detail is the today-card's job.
  Future<List<AssignedWorkout>> fetchAssignmentHistory() async {
    if (currentUserId == null) return [];
    try {
      final rows = await supabase
          .from('workout_assignments')
          .select(
            'id, status, scheduled_date, '
            'workout_templates(name, target_muscles)',
          )
          .eq('client_id', currentUserId!)
          .order('scheduled_date', ascending: false)
          .limit(30);
      return rows
          .whereType<Map<String, dynamic>>()
          .map(AssignedWorkout.fromMap)
          .toList();
    } on PostgrestException catch (e) {
      if (e.code != _missingTable) {
        debugPrint(
          'Supabase error fetching assignment history: '
          '${e.message} | code: ${e.code}',
        );
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching assignment history: $e');
      return [];
    }
  }
}
