import '../../domain/entities/conversation_entity.dart';

class ConversationModel {
  final String id;
  final String clientId;
  final String coachId;
  final String? subscriptionId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int clientUnread;
  final int coachUnread;
  final bool isActive;
  final String? coachName;
  final String? coachAvatarUrl;
  final String? clientName;
  final String? clientAvatarUrl;

  const ConversationModel({
    required this.id,
    required this.clientId,
    required this.coachId,
    required this.subscriptionId,
    this.lastMessage,
    this.lastMessageAt,
    required this.clientUnread,
    required this.coachUnread,
    required this.isActive,
    this.coachName,
    this.coachAvatarUrl,
    this.clientName,
    this.clientAvatarUrl,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] ?? '',
      clientId: json['client_id'] ?? '',
      coachId: json['coach_id'] ?? '',
      subscriptionId: json['subscription_id'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
      clientUnread: json['client_unread'] ?? 0,
      coachUnread: json['coach_unread'] ?? 0,
      isActive: json['is_active'] ?? false,
      coachName: json['coach_name'] as String?,
      coachAvatarUrl: json['coach_avatar_url'] as String?,
      clientName: json['client_name'] as String?,
      clientAvatarUrl: json['client_avatar_url'] as String?,
    );
  }

  ConversationEntity toEntity() => ConversationEntity(
        id: id,
        clientId: clientId,
        coachId: coachId,
        subscriptionId: subscriptionId,
        lastMessage: lastMessage,
        lastMessageAt: lastMessageAt,
        clientUnread: clientUnread,
        coachUnread: coachUnread,
        isActive: isActive,
        coachName: coachName,
        coachAvatarUrl: coachAvatarUrl,
        clientName: clientName,
        clientAvatarUrl: clientAvatarUrl,
      );
}
