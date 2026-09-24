import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/supabase_client.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/repositories/subscription_repository.dart';

class SubscriptionRepositoryException implements Exception {
  final String message;
  SubscriptionRepositoryException(this.message);

  @override
  String toString() => 'SubscriptionRepositoryException: $message';
}

class SubscriptionRepositoryImpl implements ISubscriptionRepository {
  final SupabaseClient _client;

  SubscriptionRepositoryImpl({SupabaseClient? client})
      : _client = client ?? supabase;

  @override
  Future<SubscriptionEntity> subscribeToCoach(String coachId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw SubscriptionRepositoryException('User not authenticated');
      }

      // One active subscription per client (DB enforces it with the
      // partial unique index on active rows): close the current one
      // before opening the new one.
      await _client
          .from('subscriptions')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('client_id', userId)
          .eq('status', 'active');

      final now = DateTime.now();
      final data = {
        'client_id': userId,
        'coach_id': coachId,
        'status': 'active',
        'tier': 'standard',
        'start_date': now.toIso8601String(),
        'end_date': now.add(const Duration(days: 30)).toIso8601String(),
      };

      try {
        final response = await _client
            .from('subscriptions')
            .insert(data)
            .select()
            .single();
        subscriptionChangeNotifier.value++;
        return response.toEntity();
      } on PostgrestException catch (e) {
        // Lost a double-submit race for the client's single active slot —
        // the winner's row is this coach's active subscription; returning
        // it makes a second confirm tap a no-op instead of an error.
        if (e.code == '23505') {
          final existing = await _client
              .from('subscriptions')
              .select()
              .eq('client_id', userId)
              .eq('coach_id', coachId)
              .eq('status', 'active')
              .limit(1)
              .maybeSingle();
          if (existing != null) {
            subscriptionChangeNotifier.value++;
            return existing.toEntity();
          }
        }
        rethrow;
      }
    } on PostgrestException catch (e) {
      throw SubscriptionRepositoryException('Database error: ${e.message}');
    } catch (e) {
      if (e is SubscriptionRepositoryException) rethrow;
      throw SubscriptionRepositoryException('Failed to subscribe: $e');
    }
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw SubscriptionRepositoryException('User not authenticated');
      }

      await _client
          .from('subscriptions')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', subscriptionId)
          .eq('client_id', userId);

      // Best-effort cascade so all coach data disappears immediately on cancel.
      // RLS on the enrollment table is dashboard-owned and may not allow the
      // client to update — failures are swallowed so the subscription cancel
      // itself is never rolled back. The service-layer gate in the assigned
      // services (active subscription check) already hides the data even if
      // this write is rejected, but closing the enrollment cleans up the
      // dashboard's view and any future fetch that bypasses the gate.
      try {
        await _client
            .from('client_nutrition_enrollments')
            .update({'status': 'cancelled'})
            .eq('client_id', userId)
            .eq('status', 'active');
      } catch (_) {}

      // Future workout assignments are the only ones safe to clean up client-
      // side (past completed/skipped are history). No delete policy exists for
      // the client, so we best-effort mark future 'assigned' rows as
      // 'skipped' — gated reads already hide them when no active subscription
      // exists, but this keeps the dashboard tidy.
      try {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        await _client
            .from('workout_assignments')
            .update({'status': 'skipped'})
            .eq('client_id', userId)
            .eq('status', 'assigned')
            .gte('scheduled_date', today);
      } catch (_) {}
      subscriptionChangeNotifier.value++;
    } on PostgrestException catch (e) {
      throw SubscriptionRepositoryException('Database error: ${e.message}');
    } catch (e) {
      if (e is SubscriptionRepositoryException) rethrow;
      throw SubscriptionRepositoryException('Failed to cancel subscription: $e');
    }
  }

  @override
  Future<SubscriptionEntity?> getActiveSubscription() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return null;
      }

      final response = await _client
          .from('subscriptions')
          .select()
          .eq('client_id', userId)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return response.toEntity();
    } on PostgrestException catch (e) {
      throw SubscriptionRepositoryException('Database error: ${e.message}');
    } catch (e) {
      throw SubscriptionRepositoryException('Failed to get subscription: $e');
    }
  }

  @override
  Future<List<SubscriptionEntity>> getCoachSubscribers() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw SubscriptionRepositoryException('User not authenticated');
      }

      final coachResponse = await _client
          .from('coaches')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (coachResponse == null) {
        return [];
      }

      final coachId = coachResponse['id'] as String;

      final response = await _client
          .from('subscriptions')
          .select()
          .eq('coach_id', coachId)
          .eq('status', 'active');

      return response
          .map((json) => json.toEntity())
          .toList();
    } on PostgrestException catch (e) {
      throw SubscriptionRepositoryException('Database error: ${e.message}');
    } catch (e) {
      if (e is SubscriptionRepositoryException) rethrow;
      throw SubscriptionRepositoryException('Failed to get subscribers: $e');
    }
  }
}

extension _ParseSubscription on Map<String, dynamic> {
  SubscriptionEntity toEntity() {
    return SubscriptionEntity(
      id: this['id'] as String,
      clientId: this['client_id'] as String,
      coachId: this['coach_id'] as String,
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == this['status'],
        orElse: () => SubscriptionStatus.pending,
      ),
      tier: this['tier'] as String? ?? 'standard',
      startDate: DateTime.parse(this['start_date'] as String),
      endDate: this['end_date'] != null ? DateTime.parse(this['end_date'] as String) : null,
      stripeSubId: this['stripe_sub_id'] as String?,
      createdAt: DateTime.parse(this['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: this['updated_at'] != null 
          ? DateTime.parse(this['updated_at'] as String) 
          : DateTime.parse(this['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
