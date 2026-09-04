import '../entities/message_entity.dart';
import '../entities/conversation_entity.dart';

abstract class IChatRepository {
  /// Fetch all conversations for a user (client or coach).
  Future<List<ConversationEntity>> getConversations(String userId);

  /// Fetch messages for a conversation, paginated.
  Future<List<MessageEntity>> getMessages(
    String conversationId, {
    int limit = 50,
    String? beforeMessageId,
  });

  /// Send a text message.
  Future<MessageEntity> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String type = 'text',
    String? fileUrl,
  });

  /// Upload a voice note file and return the storage path.
  Future<String> uploadVoiceNote({
    required String conversationId,
    required String filePath,
  });

  /// Get a signed URL for a voice file (private bucket).
  Future<String> getVoiceSignedUrl(String storagePath);

  /// Send a voice message (type='voice', content=duration, fileUrl=storagePath).
  Future<MessageEntity> sendVoiceMessage({
    required String conversationId,
    required String senderId,
    required String storagePath,
    required int durationSeconds,
  });

  /// Upload an image file (compressed) and return the storage path.
  Future<String> uploadImage({
    required String conversationId,
    required String filePath,
  });

  /// Get a signed URL for an image (private bucket).
  Future<String> getImageSignedUrl(String storagePath);

  /// Send an image message (type='image', fileUrl=storagePath, content=caption).
  Future<MessageEntity> sendImageMessage({
    required String conversationId,
    required String senderId,
    required String storagePath,
    String caption = '',
  });

  /// Upload a PDF/file and return storage path.
  Future<String> uploadFile({
    required String conversationId,
    required String filePath,
    required String fileName,
  });

  /// Get signed URL for a file.
  Future<String> getFileSignedUrl(String storagePath);

  /// Send a file/PDF message (type='file', fileUrl=storagePath, content=filename|size JSON).
  Future<MessageEntity> sendFileMessage({
    required String conversationId,
    required String senderId,
    required String storagePath,
    required String fileName,
    required int fileSize,
  });

  /// Create or get an existing conversation between a client and coach.
  Future<ConversationEntity?> getOrCreateConversation({
    required String clientId,
    required String coachId,
    String? subscriptionId,
  });

  /// Mark all messages in a conversation as read for the user.
  Future<void> markConversationRead(String conversationId, String userId);

  /// Get total unread count for a user.
  Future<int> getUnreadCount(String userId);
}
