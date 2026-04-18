import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/supabase_client.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../models/subscription_model.dart';

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

      await _client
          .from('subscriptions')
          .update({'status': 'cancelled'})
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

      final response = await _client
          .from('subscriptions')
          .insert(data)
          .select()
          .single();

      return SubscriptionModel.fromJson(response).toEntity();
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

      return SubscriptionModel.fromJson(response).toEntity();
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
          .map((json) => SubscriptionModel.fromJson(json).toEntity())
          .toList();
    } on PostgrestException catch (e) {
      throw SubscriptionRepositoryException('Database error: ${e.message}');
    } catch (e) {
      if (e is SubscriptionRepositoryException) rethrow;
      throw SubscriptionRepositoryException('Failed to get subscribers: $e');
    }
  }
}
