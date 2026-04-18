import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/supabase_client.dart';
import '../../domain/entities/client_full_data_entity.dart';
import '../../domain/entities/client_summary_entity.dart';
import '../../domain/entities/coach_entity.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';

class CoachDashboardRepositoryException implements Exception {
  final String message;
  CoachDashboardRepositoryException(this.message);

  @override
  String toString() => 'CoachDashboardRepositoryException: $message';
}

class CoachDashboardRepositoryImpl implements ICoachDashboardRepository {
  final SupabaseClient _client;

  CoachDashboardRepositoryImpl({SupabaseClient? client})
      : _client = client ?? supabase;

  // ── Helpers ──────────────────────────────────────────────

  /// Resolves the coach row `id` (PK of the `coaches` table) for the signed-in
  /// user. Throws if not found so callers get a clear error.
  Future<String> _resolveCoachId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw CoachDashboardRepositoryException('User not authenticated');
    }
    var row = await _client
        .from('coaches')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) {
      // Auto-create a basic coach entry for them
      try {
        row = await _client.from('coaches').insert({
          'user_id': userId,
        }).select('id').single();
      } catch (e) {
        throw CoachDashboardRepositoryException('Failed to auto-create Coach profile: $e');
      }
    }
    return row['id'] as String;
  }

  // ── ICoachDashboardRepository ─────────────────────────────

  @override
  Future<List<ClientSummary>> getActiveClients() async {
    try {
      final coachId = await _resolveCoachId();
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // JOIN subscriptions with profiles to get client name & avatar
      final subs = await _client
          .from('subscriptions')
          .select('client_id, start_date, profiles(name, avatar_url)')
          .eq('coach_id', coachId)
          .eq('status', 'active');

      if (subs.isEmpty) return [];

      final clientIds =
          (subs as List<dynamic>).map((r) => r['client_id'] as String).toList();

      // Fetch today's daily_summary for all clients in one query
      final todaySummaries = await _client
          .from('daily_summary')
          .select('user_id, calories_consumed, workout_done, summary_date')
          .inFilter('user_id', clientIds)
          .eq('summary_date', todayStr);

      // Also fetch the most-recent summary per client (for lastActive)
      final recentSummaries = await _client
          .from('daily_summary')
          .select('user_id, summary_date')
          .inFilter('user_id', clientIds)
          .order('summary_date', ascending: false);

      // Index today's data by clientId
      final Map<String, Map<String, dynamic>> todayByClient = {};
      for (final s in (todaySummaries as List<dynamic>)) {
        todayByClient[s['user_id'] as String] =
            s as Map<String, dynamic>;
      }

      // Index most-recent date by clientId
      final Map<String, DateTime?> lastActiveByClient = {};
      for (final s in (recentSummaries as List<dynamic>)) {
        final uid = s['user_id'] as String;
        if (!lastActiveByClient.containsKey(uid)) {
          lastActiveByClient[uid] =
              DateTime.tryParse(s['summary_date'] ?? '');
        }
      }

      return (subs as List<dynamic>).map((sub) {
        final clientId = sub['client_id'] as String;
        final profile = sub['profiles'] as Map<String, dynamic>? ?? {};
        final todayData = todayByClient[clientId];

        return ClientSummary(
          clientId: clientId,
          name: profile['name'] as String? ?? 'Unknown',
          avatarUrl: profile['avatar_url'] as String?,
          subscriptionSince:
              DateTime.tryParse(sub['start_date'] ?? '') ?? DateTime.now(),
          lastActive: lastActiveByClient[clientId],
          todayCalories:
              (todayData?['calories_consumed'] as num?)?.toDouble() ?? 0.0,
          todayWorkoutDone: todayData?['workout_done'] as bool? ?? false,
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw CoachDashboardRepositoryException('Database error: ${e.message}');
    } catch (e) {
      if (e is CoachDashboardRepositoryException) rethrow;
      throw CoachDashboardRepositoryException(
          'Failed to fetch active clients: $e');
    }
  }

  @override
  Future<ClientFullData> getClientData(
    String clientId, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final fromDate = from ?? DateTime.now().subtract(const Duration(days: 30));
      final toDate = to ?? DateTime.now();

      final fromStr =
          '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
      final toStr =
          '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';

      // Parallel fetches — no duplication of logic; just querying existing tables
      final results = await Future.wait([
        // 0 — client profile
        _client
            .from('profiles')
            .select('name, avatar_url')
            .eq('id', clientId)
            .maybeSingle(),

        // 1 — nutrition_logs
        _client
            .from('nutrition_logs')
            .select()
            .eq('user_id', clientId)
            .gte('logged_date', fromStr)
            .lte('logged_date', toStr)
            .order('logged_date', ascending: false),

        // 2 — workout_sessions
        _client
            .from('workout_sessions')
            .select()
            .eq('user_id', clientId)
            .gte('session_date', fromStr)
            .lte('session_date', toStr)
            .order('session_date', ascending: false),

        // 3 — body_measurements (no date filter — show all history)
        _client
            .from('body_measurements')
            .select()
            .eq('user_id', clientId)
            .order('measured_date', ascending: false),

        // 4 — daily_summary
        _client
            .from('daily_summary')
            .select()
            .eq('user_id', clientId)
            .gte('summary_date', fromStr)
            .lte('summary_date', toStr)
            .order('summary_date', ascending: false),
      ]);

      final profileJson =
          results[0] as Map<String, dynamic>? ?? {};

      final profile = CoachProfile(
        name: profileJson['name'] as String? ?? 'Client',
        avatarUrl: profileJson['avatar_url'] as String?,
      );

      final nutritionLogs = (results[1] as List<dynamic>)
          .map((j) => NutritionLog.fromJson(j as Map<String, dynamic>))
          .toList();

      final workoutSessions = (results[2] as List<dynamic>)
          .map((j) => WorkoutSession.fromJson(j as Map<String, dynamic>))
          .toList();

      final bodyMeasurements = (results[3] as List<dynamic>)
          .map((j) => BodyMeasurement.fromJson(j as Map<String, dynamic>))
          .toList();

      final dailySummaries = (results[4] as List<dynamic>)
          .map((j) => DailySummary.fromJson(j as Map<String, dynamic>))
          .toList();

      return ClientFullData(
        profile: profile,
        nutritionLogs: nutritionLogs,
        workoutSessions: workoutSessions,
        bodyMeasurements: bodyMeasurements,
        dailySummaries: dailySummaries,
      );
    } on PostgrestException catch (e) {
      throw CoachDashboardRepositoryException('Database error: ${e.message}');
    } catch (e) {
      if (e is CoachDashboardRepositoryException) rethrow;
      throw CoachDashboardRepositoryException(
          'Failed to fetch client data: $e');
    }
  }
}
