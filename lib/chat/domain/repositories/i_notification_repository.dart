import '../entities/notification_entity.dart';

/// Single RPC that returns ALL notifications the user needs in ONE call.
abstract class INotificationRepository {
  /// Fetch paginated notifications for the user.
  /// Drives both the notification bell and the notification list screen.
  Future<List<NotificationEntity>> getNotifications(
    String userId, {
    int limit = 30,
    String? beforeId,
  });

  /// Mark a single notification as read.
  Future<void> markAsRead(String notificationId, String userId);

  /// Mark all notifications as read in one shot.
  Future<void> markAllAsRead(String userId);

  /// Get unread count — returns null when rate-limited so caller can fall
  /// back to cached count instead of making a new request.
  Future<int?> getUnreadCount(String userId);
}