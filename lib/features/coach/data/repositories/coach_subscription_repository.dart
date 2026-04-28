import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription_model.dart';

class CoachSubscriptionRepository {
  final SupabaseClient _supabase;
  CoachSubscriptionRepository(this._supabase);

  Future<List<SubscriptionModel>> fetchSubscriptions() async {
    // Step 1: resolve coaches.id from auth uid
    final coachRow = await _supabase
      .from('coaches')
      .select('id')
      .eq('user_id', _supabase.auth.currentUser!.id)
      .single();
    final coachTableId = coachRow['id'] as String;

    // Step 2: fetch subscriptions with nested joins
    final data = await _supabase
      .from('subscriptions')
      .select('''
        id, status, payment_status, started_at, expires_at, goals, notes,
        client:profiles!client_id(id, name, avatar_url),
        plan:subscription_plans(name, price_usd),
        phases:subscription_phases(
          id, phase_number, title, type, description,
          duration_weeks, status, started_at, completed_at
        )
      ''')
      .eq('coach_id', coachTableId)
      .order('created_at', ascending: false);

    return (data as List)
      .map((row) => SubscriptionModel.fromMap(row))
      .toList();
  }
}
