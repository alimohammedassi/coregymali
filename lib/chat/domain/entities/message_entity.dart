class MessageEntity {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String type; // 'text', 'image', 'file'
  final String? fileUrl;
  final bool isRead;
  final bool isDeleted;
  final DateTime createdAt;

  const MessageEntity({
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

  bool get isTextMessage => type == 'text';
  bool get isImageMessage => type == 'image';
  bool get isFileMessage => type == 'file';
}
