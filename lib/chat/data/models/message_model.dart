import '../../domain/entities/message_entity.dart';

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String type;
  final String? fileUrl;
  final bool isRead;
  final bool isDeleted;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.type,
    this.fileUrl,
    required this.isRead,
    required this.isDeleted,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? '',
      conversationId: json['conversation_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      fileUrl: json['file_url'] as String?,
      isRead: json['is_read'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'type': type,
      if (fileUrl != null) 'file_url': fileUrl,
    };
  }

  MessageEntity toEntity() => MessageEntity(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        type: type,
        fileUrl: fileUrl,
        isRead: isRead,
        isDeleted: isDeleted,
        createdAt: createdAt,
      );
}
