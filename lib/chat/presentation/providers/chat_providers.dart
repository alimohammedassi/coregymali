import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/repositories/i_chat_repository.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/conversation_entity.dart';

// ---------------------------------------------------------------------------
// Current user — no BuildContext dependency
// ---------------------------------------------------------------------------
String? chatCurrentUserId() =>
    Supabase.instance.client.auth.currentUser?.id;

// ---------------------------------------------------------------------------
// Chat repository provider — single instance per app
// ---------------------------------------------------------------------------
class ChatRepoProvider extends ChangeNotifier {
  late final IChatRepository _repo = ChatRepository(Supabase.instance.client);
  IChatRepository get repo => _repo;
}

// ---------------------------------------------------------------------------
// Conversations list
// ---------------------------------------------------------------------------
class ConversationsNotifier extends ChangeNotifier {
  final IChatRepository _repo;

  List<ConversationEntity> _conversations = [];
  bool _isLoading = false;
  String? _error;

  List<ConversationEntity> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ConversationsNotifier(this._repo);

  Future<void> load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _conversations = await _repo.getConversations(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void refresh() => load();
}

// ---------------------------------------------------------------------------
// Unread count
// ---------------------------------------------------------------------------
class UnreadCountNotifier extends ChangeNotifier {
  final IChatRepository _repo;
  int _count = 0;
  int get count => _count;

  UnreadCountNotifier(this._repo);

  Future<void> load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      _count = await _repo.getUnreadCount(userId);
      notifyListeners();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Chat notifier (per conversation)
// ---------------------------------------------------------------------------
class ChatNotifier extends ChangeNotifier {
  final IChatRepository _repo;
  final String _userId;
  final String conversationId;

  List<MessageEntity> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  RealtimeChannel? _channel;

  List<MessageEntity> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  ChatNotifier(this._repo, this.conversationId)
      : _userId = Supabase.instance.client.auth.currentUser?.id ?? '' {
    _loadMessages();
    _subscribeRealtime();
  }

  Future<void> _loadMessages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _messages = await _repo.getMessages(conversationId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeRealtime() {
    _channel = Supabase.instance.client.channel('chat:$conversationId');

    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final record = payload.newRecord;
        if (record['conversation_id'] != conversationId) return;

        final newMsg = MessageEntity(
          id: record['id'] ?? '',
          conversationId: record['conversation_id'] ?? '',
          senderId: record['sender_id'] ?? '',
          content: record['content'] ?? '',
          type: record['type'] ?? 'text',
          fileUrl: record['file_url'] as String?,
          isRead: record['is_read'] ?? false,
          isDeleted: record['is_deleted'] ?? false,
          createdAt: DateTime.parse(
              record['created_at'] ?? DateTime.now().toIso8601String()),
        );

        // O(1) deduplication — check by ID before allocating new list
        if (_messages.isEmpty || _messages.last.id != newMsg.id) {
          _messages = [..._messages, newMsg];
          notifyListeners();
        }

        if (newMsg.senderId != _userId) {
          _repo.markConversationRead(conversationId, _userId);
        }
      },
    );

    _channel!.subscribe();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    _isSending = true;
    notifyListeners();

    try {
      final message = await _repo.sendMessage(
        conversationId: conversationId,
        senderId: _userId,
        content: content.trim(),
      );
      _messages = [..._messages, message];
      _isSending = false;
      // Single notifyListeners — not three separate calls
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _messages.isEmpty) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final older = await _repo.getMessages(
        conversationId,
        beforeMessageId: _messages.first.id,
      );
      _hasMore = older.isNotEmpty;
      if (older.isNotEmpty) {
        _messages = [...older, ..._messages];
      }
      _isLoadingMore = false;
      notifyListeners();
    } catch (_) {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void refresh() => _loadMessages();

  IChatRepository get chatRepo => _repo;

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}