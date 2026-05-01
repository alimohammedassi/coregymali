class ConversationEntity {
  final String id;
  final String clientId;
  final String coachId;
  final String? subscriptionId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int clientUnread;
  final int coachUnread;
  final bool isActive;
  // Populated via join
  final String? coachName;
  final String? coachAvatarUrl;
  final String? clientName;
  final String? clientAvatarUrl;

  const ConversationEntity({
    required this.id,
    required this.clientId,
    required this.coachId,
    this.subscriptionId,
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

  int unreadFor(String userId) =>
      userId == clientId ? clientUnread : coachUnread;
}
