import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../chat/domain/entities/conversation_entity.dart';
import '../supabase/supabase_config.dart';
import '../chat/presentation/screens/chat_room_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Task 7 — in-app notification inbox. Lists every push recorded in
/// `notification_log` (welcome, reminders, calorie alerts, chat), newest
/// first, with read/unread state. Chat entries deep-link into the
/// conversation; anything else just marks itself read on tap.
class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final rows = await SupabaseConfig.client
          .from('notification_log')
          .select()
          .eq('user_id', userId)
          .order('sent_at', ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(rows);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _markAllRead() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    HapticFeedback.selectionClick();
    await SupabaseConfig.client
        .from('notification_log')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', userId)
        .filter('read_at', 'is', null);
    await _load();
  }

  Future<void> _onTap(Map<String, dynamic> item) async {
    HapticFeedback.lightImpact();
    if (item['read_at'] == null) {
      await SupabaseConfig.client
          .from('notification_log')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', item['id'].toString());
    }
    final data = item['data'];
    final conversationId =
        data is Map ? data['conversation_id']?.toString() : null;
    if (item['type'] == 'chat' &&
        conversationId != null &&
        conversationId.isNotEmpty) {
      NotificationService.instance.openConversation(conversationId);
    } else if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          l?.notificationsTitle ?? 'Notifications',
          style: AppText.styledHeadlineSm(
            isArabic: false,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_items.any((i) => i['read_at'] == null))
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                l?.markAllRead ?? 'Mark all read',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorBox(error: _error!, onRetry: _load)
              : _items.isEmpty
                  ? _EmptyBox(label: l?.notificationsEmpty ?? 'No notifications yet')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final item = _items[i];
                          return _InboxTile(
                            item: item,
                            onTap: () => _onTap(item),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _InboxTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _InboxTile({required this.item, required this.onTap});

  (IconData, Color) get _visual {
    switch (item['type']?.toString()) {
      case 'welcome':
        return (Icons.waving_hand_rounded, AppColors.primary);
      case 'meal_reminder':
        return (Icons.restaurant_rounded, AppColors.accentCalories);
      case 'water_reminder':
        return (Icons.water_drop_rounded, AppColors.secondaryFixed);
      case 'calorie_alert':
        return (Icons.local_fire_department_rounded, AppColors.error);
      case 'chat':
        return (Icons.chat_bubble_rounded, AppColors.secondary);
      default:
        return (Icons.notifications_rounded, AppColors.primary);
    }
  }

  String _timeago(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('d MMM').format(at);
  }

  @override
  Widget build(BuildContext context) {
    final unread = item['read_at'] == null;
    final (icon, color) = _visual;
    final sentAt = DateTime.tryParse(item['sent_at']?.toString() ?? '');

    return Material(
      color: unread ? AppColors.surfaceContainerHigh : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['title']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (sentAt != null)
                          Text(
                            _timeago(sentAt),
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item['body']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBox({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 36),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String label;
  const _EmptyBox({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined,
              color: AppColors.textMuted, size: 44),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

/// Public helper so other surfaces (deep-link, inbox) can open a chat room
/// from a bare conversation id.
Future<ConversationEntity?> findConversationById(String conversationId) async {
  final userId = SupabaseConfig.client.auth.currentUser?.id;
  if (userId == null) return null;
  final row = await SupabaseConfig.client
      .from('conversations')
      .select(
        '*, client_profile:profiles!conversations_client_id_fkey(full_name, name, avatar_url), '
        'coach_profile:profiles!conversations_coach_id_fkey(full_name, name, avatar_url)',
      )
      .eq('id', conversationId)
      .maybeSingle();
  if (row == null) return null;
  final cp = row['client_profile'] as Map<String, dynamic>?;
  final kp = row['coach_profile'] as Map<String, dynamic>?;
  return ConversationEntity(
    id: row['id'].toString(),
    clientId: row['client_id'].toString(),
    coachId: row['coach_id'].toString(),
    lastMessage: row['last_message']?.toString(),
    lastMessageAt: row['last_message_at'] != null
        ? DateTime.tryParse(row['last_message_at'].toString())
        : null,
    clientUnread: (row['client_unread'] as num?)?.toInt() ?? 0,
    coachUnread: (row['coach_unread'] as num?)?.toInt() ?? 0,
    isActive: row['is_active'] as bool? ?? true,
    clientName: (cp?['full_name'] ?? cp?['name'])?.toString(),
    coachName: (kp?['full_name'] ?? kp?['name'])?.toString(),
    clientAvatarUrl: cp?['avatar_url']?.toString(),
    coachAvatarUrl: kp?['avatar_url']?.toString(),
  );
}

/// Opens a chat room by conversation id if it exists and involves the
/// current user (shared by the notification deep-link and the inbox).
Future<void> openChatById(BuildContext context, String conversationId) async {
  final conversation = await findConversationById(conversationId);
  if (conversation == null || !context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          ChatRoomScreen(conversation: conversation),
    ),
  );
}
