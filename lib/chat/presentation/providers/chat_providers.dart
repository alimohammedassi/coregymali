import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/repositories/i_chat_repository.dart';
import '../../domain/repositories/i_notification_repository.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/notification_entity.dart';

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
// Notifications — one RPC, unified feed, lazy + rate-limit fallbacks
// ---------------------------------------------------------------------------

/// Central notification notifier. Drives both the bell badge and the
/// notification list. Single shared instance via MultiProvider in main.dart.
///
/// Request-minimisation strategy:
/// 1. Count is cached locally and only refreshed when:
///    - User opens the notification list screen
///    - A Realtime subscription signals a new notification row
///    - App comes back from background (via AppLifecycleState observer)
/// 2. getNotifications() is only called when the list is actually visible
/// 3. markAsRead / markAllAsRead are fire-and-forget (no await needed)
class NotificationNotifier extends ChangeNotifier {
  final INotificationRepository _repo;

  List<NotificationEntity> _notifications = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int _unreadCount = 0;
  DateTime? _lastCountRefresh;
  DateTime? _lastListRefresh;
  bool _disposed = false;

  static const _minRefreshInterval = Duration(seconds: 30);
  static const _countCacheMaxAge = Duration(minutes: 2);

  List<NotificationEntity> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get unreadCount => _unreadCount;
  bool get hasNotifications => _notifications.isNotEmpty;

  NotificationNotifier(this._repo);

  /// Load notification list — debounced to prevent rapid successive calls.
  Future<void> loadNotifications({bool force = false}) async {
    if (_isLoading) return;
    if (!force && _lastListRefresh != null &&
        DateTime.now().difference(_lastListRefresh!) < _minRefreshInterval) {
      return;
    }
    final userId = chatCurrentUserId();
    if (userId == null) return;

    _isLoading = true;
    _error = null;
    if (force) notifyListeners();

    try {
      _notifications = await _repo.getNotifications(userId);
      _hasMore = _notifications.length >= 30;
      _lastListRefresh = DateTime.now();
      _isLoading = false;
      if (!_disposed) notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Refresh unread count — cached for 2 min so tab-bar badge doesn't
  /// hammer the DB on every frame.
  Future<void> refreshUnreadCount({bool force = false}) async {
    final userId = chatCurrentUserId();
    if (userId == null) return;

    final now = DateTime.now();
    if (!force &&
        _lastCountRefresh != null &&
        now.difference(_lastCountRefresh!) < _countCacheMaxAge) {
      return;
    }

    try {
      final count = await _repo.getUnreadCount(userId);
      if (count != null) {
        _unreadCount = count;
        _lastCountRefresh = now;
        if (!_disposed) notifyListeners();
      }
    } catch (_) {
      // Rate-limited — keep showing stale count, don't crash
    }
  }

  /// Decrement count locally after reading a notification — no API call needed.
  void decrementUnread() {
    if (_unreadCount > 0) {
      _unreadCount--;
      if (!_disposed) notifyListeners();
    }
  }

  /// Increment count locally when Realtime confirms a new notification.
  void incrementUnread() {
    _unreadCount++;
    if (!_disposed) notifyListeners();
  }

  Future<void> markAsRead(String notificationId, {String? conversationId}) async {
    // Optimistic local update
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx] = NotificationEntity(
        id: _notifications[idx].id,
        userId: _notifications[idx].userId,
        type: _notifications[idx].type,
        title: _notifications[idx].title,
        body: _notifications[idx].body,
        conversationId: _notifications[idx].conversationId,
        planId: _notifications[idx].planId,
        coachId: _notifications[idx].coachId,
        coachName: _notifications[idx].coachName,
        coachAvatarUrl: _notifications[idx].coachAvatarUrl,
        isRead: true,
        createdAt: _notifications[idx].createdAt,
      );
      if (_unreadCount > 0) _unreadCount--;
      if (!_disposed) notifyListeners();
    }

    // Fire-and-forget — don't block UI
    final userId = chatCurrentUserId();
    if (userId != null) {
      _repo.markAsRead(notificationId, userId);
    }
  }

  Future<void> markAllAsRead() async {
    // Optimistic local update
    _unreadCount = 0;
    _notifications = _notifications
        .map((n) => n.isRead
            ? n
            : NotificationEntity(
                id: n.id,
                userId: n.userId,
                type: n.type,
                title: n.title,
                body: n.body,
                conversationId: n.conversationId,
                planId: n.planId,
                coachId: n.coachId,
                coachName: n.coachName,
                coachAvatarUrl: n.coachAvatarUrl,
                isRead: true,
                createdAt: n.createdAt,
              ))
        .toList();
    if (!_disposed) notifyListeners();

    final userId = chatCurrentUserId();
    if (userId != null) {
      _repo.markAllAsRead(userId);
    }
  }

  /// Load more (pagination).
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore || _notifications.isEmpty) return;
    final userId = chatCurrentUserId();
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final older = await _repo.getNotifications(
        userId,
        beforeId: _notifications.last.id,
      );
      _hasMore = older.isNotEmpty;
      if (older.isNotEmpty) {
        _notifications = [..._notifications, ...older];
      }
      _isLoading = false;
      if (!_disposed) notifyListeners();
    } catch (_) {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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