import '../../domain/entities/notification_entity.dart';

class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final String? conversationId;
  final String? planId;
  final String? coachId;
  final String? coachName;
  final String? coachAvatarUrl;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
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

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      type: json['type'] == 'message'
          ? NotificationType.message
          : NotificationType.plan,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      conversationId: json['conversation_id'] as String?,
      planId: json['plan_id'] as String?,
      coachId: json['coach_id'] as String?,
      coachName: json['coach_name'] as String?,
      coachAvatarUrl: json['coach_avatar_url'] as String?,
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  NotificationEntity toEntity() => NotificationEntity(
        id: id,
        userId: userId,
        type: type,
        title: title,
        body: body,
        conversationId: conversationId,
        planId: planId,
        coachId: coachId,
        coachName: coachName,
        coachAvatarUrl: coachAvatarUrl,
        isRead: isRead,
        createdAt: createdAt,
      );
}