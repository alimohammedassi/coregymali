import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/supabase_client.dart';
import '../../domain/entities/coach_entity.dart';
import '../../domain/repositories/coach_repository.dart';
import '../models/coach_model.dart';

class CoachRepositoryException implements Exception {
  final String message;
  CoachRepositoryException(this.message);

  @override
  String toString() => 'CoachRepositoryException: $message';
}

class CoachRepositoryImpl implements ICoachRepository {
  final SupabaseClient _client;

  CoachRepositoryImpl({SupabaseClient? client})
      : _client = client ?? supabase;

  @override
  Future<List<CoachEntity>> getCoaches({
    String? specialization,
    double? maxPrice,
    double? minRating,
  }) async {
    try {
      var query = _client
          .from('coaches')
          .select('*, profiles(name, avatar_url)')
          .eq('is_active', true);

      if (specialization != null && specialization.isNotEmpty) {
        query = query.contains('specialization', [specialization]);
      }

      if (maxPrice != null) {
        query = query.lte('price_monthly', maxPrice);
      }

      if (minRating != null) {
        query = query.gte('rating', minRating);
      }

      final response = await query.order('rating', ascending: false);

      return response.map((json) => CoachModel.fromJson(json).toEntity()).toList();
    } on PostgrestException catch (e) {
      throw CoachRepositoryException('Database error: ${e.message}');
    } catch (e) {
      throw CoachRepositoryException('Failed to fetch coaches: $e');
    }
  }

  @override
  Future<CoachEntity> getCoachById(String coachId) async {
    try {
      final response = await _client
          .from('coaches')
          .select('*, profiles(name, avatar_url)')
          .eq('id', coachId)
          .single();

      return CoachModel.fromJson(response).toEntity();
    } on PostgrestException catch (e) {
      throw CoachRepositoryException('Database error: ${e.message}');
    } catch (e) {
      throw CoachRepositoryException('Failed to fetch coach: $e');
    }
  }

  @override
  Future<CoachEntity> createCoachProfile(CoachEntity coach) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw CoachRepositoryException('User not authenticated');
      }

      final data = {
        'user_id': userId,
        'bio': coach.bio,
        'price_monthly': coach.priceMonthly,
        'specialization': coach.specialization,
        'rating': coach.rating,
        'is_active': coach.isActive,
        'stripe_account_id': coach.stripeAccountId,
      };

      final response = await _client
          .from('coaches')
          .insert(data)
          .select('*, profiles(name, avatar_url)')
          .single();

      await _client
          .from('profiles')
          .update({'role': 'coach'})
          .eq('id', userId);

      return CoachModel.fromJson(response).toEntity();
    } on PostgrestException catch (e) {
      throw CoachRepositoryException('Database error: ${e.message}');
    } catch (e) {
      if (e is CoachRepositoryException) rethrow;
      throw CoachRepositoryException('Failed to create coach profile: $e');
    }
  }

  @override
  Future<CoachEntity> updateCoachProfile(CoachEntity coach) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw CoachRepositoryException('User not authenticated');
      }

      final data = {
        'bio': coach.bio,
        'price_monthly': coach.priceMonthly,
        'specialization': coach.specialization,
        'rating': coach.rating,
        'is_active': coach.isActive,
        'stripe_account_id': coach.stripeAccountId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('coaches')
          .update(data)
          .eq('user_id', userId)
          .select('*, profiles(name, avatar_url)')
          .single();

      return CoachModel.fromJson(response).toEntity();
    } on PostgrestException catch (e) {
      throw CoachRepositoryException('Database error: ${e.message}');
    } catch (e) {
      if (e is CoachRepositoryException) rethrow;
      throw CoachRepositoryException('Failed to update coach profile: $e');
    }
  }
}
