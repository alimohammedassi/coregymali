import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/supabase_client.dart';
import '../../domain/entities/review_entity.dart';
import '../models/review_model.dart';

class ReviewRepositoryException implements Exception {
  final String message;
  ReviewRepositoryException(this.message);
  @override
  String toString() => 'ReviewRepositoryException: $message';
}

class ReviewRepository {
  final SupabaseClient _client;
  ReviewRepository({SupabaseClient? client}) : _client = client ?? supabase;

  Future<List<ReviewEntity>> fetchReviews(String coachId) async {
    try {
      // Try with profile join to show author name if available
      dynamic res;
      try {
        res = await _client
            .from('reviews')
            .select('*, profiles!reviews_client_id_fkey(name, avatar_url)')
            .eq('coach_id', coachId)
            .order('created_at', ascending: false)
            .limit(20);
      } catch (_) {
        res = await _client
            .from('reviews')
            .select()
            .eq('coach_id', coachId)
            .order('created_at', ascending: false)
            .limit(20);
      }
      return (res as List)
          .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>).toEntity())
          .toList();
    } on PostgrestException catch (e) {
      throw ReviewRepositoryException('Database error: ${e.message}');
    } catch (e) {
      throw ReviewRepositoryException('Failed to fetch reviews: $e');
    }
  }

  Future<ReviewEntity?> fetchMyReview(String coachId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await _client
          .from('reviews')
          .select()
          .eq('coach_id', coachId)
          .eq('client_id', uid)
          .maybeSingle();
      if (res == null) return null;
      return ReviewModel.fromJson(res).toEntity();
    } on PostgrestException catch (e) {
      // If table missing or policy blocks, treat as no review
      if (e.code == 'PGRST205' || e.code == '42501') return null;
      throw ReviewRepositoryException('Database error: ${e.message}');
    } catch (e) {
      throw ReviewRepositoryException('Failed to fetch my review: $e');
    }
  }

  Future<ReviewEntity> submitReview({
    required String coachId,
    required int rating,
    String? comment,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw ReviewRepositoryException('User not authenticated');
    if (rating < 1 || rating > 5) throw ReviewRepositoryException('Rating must be 1-5');

    final trimmed = comment?.trim();
    final payload = {
      'coach_id': coachId,
      'client_id': uid,
      'rating': rating,
      if (trimmed != null && trimmed.isNotEmpty) 'comment': trimmed,
    };

    try {
      // Check existing review for upsert logic
      final existing = await _client
          .from('reviews')
          .select('id')
          .eq('coach_id', coachId)
          .eq('client_id', uid)
          .maybeSingle();

      Map<String, dynamic> row;
      if (existing != null) {
        // Update existing review
        row = await _client
            .from('reviews')
            .update({
              'rating': rating,
              'comment': trimmed?.isEmpty == true ? null : trimmed,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id'])
            .select()
            .single();
      } else {
        // Insert new review
        row = await _client.from('reviews').insert(payload).select().single();
      }

      // Recompute average rating and update coaches table (best-effort)
      try {
        final all = await _client.from('reviews').select('rating').eq('coach_id', coachId);
        final allList = all as List;
        if (allList.isNotEmpty) {
          final avg = allList
                  .map((e) => (e['rating'] as num).toDouble())
                  .fold<double>(0, (a, b) => a + b) /
              allList.length;
          await _client.from('coaches').update({'rating': avg}).eq('id', coachId);
        }
      } catch (_) {}

      return ReviewModel.fromJson(row).toEntity();
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Unique violation (coach_id, client_id) — retry as update
        final existing = await _client
            .from('reviews')
            .select('id')
            .eq('coach_id', coachId)
            .eq('client_id', uid)
            .maybeSingle();
        if (existing != null) {
          final row = await _client
              .from('reviews')
              .update({'rating': rating, 'comment': trimmed, 'updated_at': DateTime.now().toIso8601String()})
              .eq('id', existing['id'])
              .select()
              .single();
          return ReviewModel.fromJson(row).toEntity();
        }
      }
      throw ReviewRepositoryException('Database error: ${e.message}');
    } catch (e) {
      if (e is ReviewRepositoryException) rethrow;
      throw ReviewRepositoryException('Failed to submit review: $e');
    }
  }

  Future<void> deleteReview(String reviewId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw ReviewRepositoryException('User not authenticated');
    try {
      await _client.from('reviews').delete().eq('id', reviewId).eq('client_id', uid);
      // Optionally recompute rating after delete — best effort, ignore errors
    } on PostgrestException catch (e) {
      throw ReviewRepositoryException('Database error: ${e.message}');
    }
  }
}
