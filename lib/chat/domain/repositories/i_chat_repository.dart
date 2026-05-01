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
