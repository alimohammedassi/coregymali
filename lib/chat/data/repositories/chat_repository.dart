import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/i_chat_repository.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';

class ChatRepository implements IChatRepository {
  final SupabaseClient _client;

  ChatRepository(this._client);

  // -------------------------------------------------------------------------
  // Conversations
  // -------------------------------------------------------------------------

  @override
  Future<List<ConversationEntity>> getConversations(String userId) async {
    final res = await _client
        .from('conversations')
        .select('''
          *,
          client_profile:profiles!conversations_client_id_fkey(name, avatar_url, full_name) as client_profile_data,
          coach_profile:profiles!conversations_coach_id_fkey(name, avatar_url, full_name) as coach_profile_data
        ''')
        .or('client_id.eq.$userId,coach_id.eq.$userId')
        .order('last_message_at', ascending: false);

    final list = (res as List).map((row) {
      final map = Map<String, dynamic>.from(row);
      // Flatten nested profile data
      if (map['client_profile_data'] != null) {
        final cp = Map<String, dynamic>.from(map['client_profile_data'] as Map);
        map['client_name'] = cp['full_name'] ?? cp['name'];
        map['client_avatar_url'] = cp['avatar_url'];
      }
      if (map['coach_profile_data'] != null) {
        final cp = Map<String, dynamic>.from(map['coach_profile_data'] as Map);
        map['coach_name'] = cp['full_name'] ?? cp['name'];
        map['coach_avatar_url'] = cp['avatar_url'];
      }
      return ConversationModel.fromJson(map).toEntity();
    }).toList();

    return list;
  }

  @override
  Future<ConversationEntity?> getOrCreateConversation({
    required String clientId,
    required String coachId,
    String? subscriptionId,
  }) async {
    // Check if a conversation already exists
    final existing = await _client
        .from('conversations')
        .select()
        .eq('client_id', clientId)
        .eq('coach_id', coachId)
        .maybeSingle();

    if (existing != null) {
      return ConversationModel.fromJson(Map<String, dynamic>.from(existing))
          .toEntity();
    }

    // Create a new one
    final newConv = await _client
        .from('conversations')
        .insert({
          'client_id': clientId,
          'coach_id': coachId,
          if (subscriptionId != null) 'subscription_id': subscriptionId,
          'is_active': true,
        })
        .select()
        .single();

    return ConversationModel.fromJson(Map<String, dynamic>.from(newConv))
        .toEntity();
  }

  // -------------------------------------------------------------------------
  // Messages
  // -------------------------------------------------------------------------

  @override
  Future<List<MessageEntity>> getMessages(
    String conversationId, {
    int limit = 50,
    String? beforeMessageId,
  }) async {
    dynamic query = _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .eq('is_deleted', false)
        .order('created_at', ascending: true)
        .limit(limit);

    if (beforeMessageId != null) {
      final anchor = await _client
          .from('messages')
          .select('created_at')
          .eq('id', beforeMessageId)
          .single();
      query = _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('is_deleted', false)
          .filter('created_at', 'lt',
              DateTime.parse(anchor['created_at']).toIso8601String())
          .order('created_at', ascending: true)
          .limit(limit);
    }

    final res = await query;
    return (res as List)
        .map((row) => MessageModel.fromJson(Map<String, dynamic>.from(row)))
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Future<MessageEntity> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String type = 'text',
    String? fileUrl,
  }) async {
    final res = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'content': content,
          'type': type,
          if (fileUrl != null) 'file_url': fileUrl,
          'is_read': false,
        })
        .select()
        .single();

    return MessageModel.fromJson(Map<String, dynamic>.from(res)).toEntity();
  }

  // -------------------------------------------------------------------------
  // Read status
  // -------------------------------------------------------------------------

  @override
  Future<void> markConversationRead(String conversationId, String userId) async {
    await _client.rpc('mark_conversation_read', params: {
      'p_conversation_id': conversationId,
      'p_user_id': userId,
    });
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    final res = await _client.rpc('unread_count', params: {
      'p_user_id': userId,
    });
    return (res as int?) ?? 0;
  }
}
