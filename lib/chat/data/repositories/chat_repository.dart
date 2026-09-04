import 'dart:io';

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

  @override
  Future<String> uploadVoiceNote({
    required String conversationId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    final storagePath = '$conversationId/$fileName';

    await _client.storage
        .from('chat-voice-notes')
        .upload(
          storagePath,
          file,
          fileOptions: const FileOptions(
            contentType: 'audio/m4a',
            upsert: false,
          ),
        );
    return storagePath;
  }

  @override
  Future<String> getVoiceSignedUrl(String storagePath) async {
    // 1 year expiry so bubbles keep working without re-fetching constantly
    final url = await _client.storage
        .from('chat-voice-notes')
        .createSignedUrl(storagePath, 60 * 60 * 24 * 365);
    return url;
  }

  @override
  Future<MessageEntity> sendVoiceMessage({
    required String conversationId,
    required String senderId,
    required String storagePath,
    required int durationSeconds,
  }) async {
    return sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      content: durationSeconds.toString(),
      type: 'voice',
      fileUrl: storagePath,
    );
  }

  @override
  Future<String> uploadImage({
    required String conversationId,
    required String filePath,
  }) async {
    final file = File(filePath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    final storagePath = '$conversationId/$fileName';

    await _client.storage.from('chat-images').upload(
          storagePath,
          file,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    return storagePath;
  }

  @override
  Future<String> getImageSignedUrl(String storagePath) async {
    return await _client.storage.from('chat-images').createSignedUrl(storagePath, 60 * 60 * 24 * 365);
  }

  @override
  Future<MessageEntity> sendImageMessage({
    required String conversationId,
    required String senderId,
    required String storagePath,
    String caption = '',
  }) async {
    return sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      content: caption,
      type: 'image',
      fileUrl: storagePath,
    );
  }

  @override
  Future<String> uploadFile({
    required String conversationId,
    required String filePath,
    required String fileName,
  }) async {
    final file = File(filePath);
    final storagePath = '$conversationId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from('chat-files').upload(
          storagePath,
          file,
          fileOptions: FileOptions(
            contentType: 'application/pdf',
            upsert: false,
          ),
        );
    return storagePath;
  }

  @override
  Future<String> getFileSignedUrl(String storagePath) async {
    return await _client.storage.from('chat-files').createSignedUrl(storagePath, 60 * 60 * 24 * 365);
  }

  @override
  Future<MessageEntity> sendFileMessage({
    required String conversationId,
    required String senderId,
    required String storagePath,
    required String fileName,
    required int fileSize,
  }) async {
    // Store file info as JSON in content so bubble can parse filename + size
    final content = '{"name":"${fileName.replaceAll('"', '\\"')}","size":$fileSize}';
    return sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      type: 'file',
      fileUrl: storagePath,
    );
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
