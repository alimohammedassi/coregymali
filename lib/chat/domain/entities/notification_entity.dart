/// Represents a single in-app notification.
///
/// Two categories:
/// - `message`  → triggered by a new chat message (no extra API call needed —
///                 already driven by the Realtime subscription in ChatNotifier)
/// - `plan`     → plan-related events: new plan, phase change, renewal, etc.
enum NotificationType { message, plan }

enum NotificationCategory {
  /// Plan status events: new_plan, phase_changed, plan_expiring, plan_renewed, etc.
  plan,
}

class NotificationEntity {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final String? conversationId; // for message type
  final String? planId;         // for plan type
  final String? coachId;
  final String? coachName;
  final String? coachAvatarUrl;
  final bool isRead;
  final DateTime createdAt;

  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.conversationId,
    this.planId,
    this.coachId,
    this.coachName,
    this.coachAvatarUrl,
    required this.isRead,
    required this.createdAt,
  });

  NotificationCategory get category =>
      type == NotificationType.message
          ? NotificationCategory.plan
          : NotificationCategory.plan;
}
