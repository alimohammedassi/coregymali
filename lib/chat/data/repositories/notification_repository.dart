import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/i_notification_repository.dart';
import '../../domain/entities/notification_entity.dart';
import '../models/notification_model.dart';

class NotificationRepository implements INotificationRepository {
  final SupabaseClient _client;

  NotificationRepository(this._client);

  @override
  Future<List<NotificationEntity>> getNotifications(
    String userId, {
    int limit = 30,
    String? beforeId,
  }) async {
    // Single query that joins profile data so the UI never needs a 2nd call.
    // Includes both message notifications (linked to conversation) and plan
    // notifications in one unified feed.
    var query = _client
        .from('notifications')
        .select('''
          *,
          coach_profile:profiles!notifications_coach_id_fkey(
            name, avatar_url, full_name
          ) as coach_profile_data
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    if (beforeId != null) {
      final anchor = await _client
          .from('notifications')
          .select('created_at')
          .eq('id', beforeId)
          .single();
      query = _client
          .from('notifications')
          .select('''
            *,
            coach_profile:profiles!notifications_coach_id_fkey(
              name, avatar_url, full_name
            ) as coach_profile_data
          ''')
          .eq('user_id', userId)
          .filter('created_at', 'lt', anchor['created_at'])
          .order('created_at', ascending: false)
          .limit(limit);
    }

    final res = await query;
    return (res as List).map((row) {
      final map = Map<String, dynamic>.from(row);
      // Flatten coach profile data if present
      if (map['coach_profile_data'] != null) {
        final cp = Map<String, dynamic>.from(map['coach_profile_data'] as Map);
        map['coach_name'] = cp['full_name'] ?? cp['name'];
        map['coach_avatar_url'] = cp['avatar_url'];
      }
      return NotificationModel.fromJson(map).toEntity();
    }).toList();
  }

  @override
  Future<void> markAsRead(String notificationId, String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', userId);
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  @override
  Future<int?> getUnreadCount(String userId) async {
    try {
      final res = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return res.count;
    } catch (_) {
      return null; // rate-limited — caller will fall back to cached value
    }
  }
}