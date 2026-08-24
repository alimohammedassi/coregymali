import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../chat/domain/entities/notification_entity.dart';
import '../../../chat/domain/entities/conversation_entity.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../chat/presentation/screens/chat_room_screen.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = context.read<NotificationNotifier>();
      notifier.loadNotifications(force: true);
      notifier.refreshUnreadCount(force: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationNotifier>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 26,
            letterSpacing: -0.6,
          ),
        ),
        actions: [
          Consumer<NotificationNotifier>(
            builder: (_, notifier, __) {
              if (notifier.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  notifier.markAllAsRead();
                },
                child: Text(
                  'Mark all read',
                  style: TextStyle(
                    color: AppColors.primaryFixed,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      body: Consumer<NotificationNotifier>(
        builder: (ctx, notifier, _) {
          if (notifier.isLoading && notifier.notifications.isEmpty) {
            return const _SkeletonList();
          }

          if (notifier.error != null && notifier.notifications.isEmpty) {
            return _ErrorView(
              error: notifier.error!,
              onRetry: () => notifier.loadNotifications(force: true),
              l: l,
            );
          }

          if (notifier.notifications.isEmpty) {
            return _EmptyView();
          }

          return RefreshIndicator(
            onRefresh: () => notifier.loadNotifications(force: true),
            color: AppColors.primaryFixed,
            backgroundColor: AppColors.surfaceContainer,
            displacement: 40,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifier.notifications.length +
                  (notifier.hasMore ? 1 : 0),
              itemBuilder: (ctx, index) {
                if (index == notifier.notifications.length) {
                  return const _LoadMoreIndicator();
                }
                final notification = notifier.notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () => _handleTap(ctx, notification, notifier),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _handleTap(
    BuildContext ctx,
    NotificationEntity notification,
    NotificationNotifier notifier,
  ) {
    HapticFeedback.selectionClick();

    if (!notification.isRead) {
      notifier.markAsRead(notification.id);
    }

    if (notification.type == NotificationType.message &&
        notification.conversationId != null) {
      // Navigate to chat — pass a minimal stub conversation so
      // ChatRoomScreen doesn't crash. Profile data is resolved via
      // the ConversationsNotifier on the list screen.
      Navigator.of(ctx).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => ChatNotifier(
              ctx.read<ChatRepoProvider>().repo,
              notification.conversationId!,
            ),
            child: ChatRoomScreen(
              conversation: ConversationEntity(
                id: notification.conversationId!,
                clientId: notification.userId,
                coachId: notification.coachId ?? '',
                clientUnread: 0,
                coachUnread: 0,
                isActive: true,
                coachName: notification.coachName,
                coachAvatarUrl: notification.coachAvatarUrl,
              ),
            ),
          ),
        ),
      );
    } else if (notification.type == NotificationType.plan &&
        notification.planId != null) {
      // TODO: navigate to plan detail screen
    }
  }
}

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------
class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, __) {
        final shimmerColor = Color.lerp(
          AppColors.surfaceContainerHighest,
          AppColors.surfaceContainerHighest.withValues(alpha: 0.35),
          ((_shimmerController.value * 2) - 1).abs(),
        )!;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: 10,
          itemBuilder: (_, index) => _SkeletonTile(shimmerColor: shimmerColor),
        );
      },
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  final Color shimmerColor;

  const _SkeletonTile({required this.shimmerColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: shimmerColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 13,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 11,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error / Empty
// ---------------------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final AppLocalizations l;

  const _ErrorView(
      {required this.error, required this.onRetry, required this.l});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              "Couldn't load notifications",
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              style: TextStyle(
                  color: AppColors.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l.retry),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryFixed,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 44,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All caught up!',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You have no new notifications',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification tile
// ---------------------------------------------------------------------------
class _NotificationTile extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primaryFixed.withValues(alpha: 0.06),
        highlightColor: AppColors.primaryFixed.withValues(alpha: 0.03),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isUnread
                ? AppColors.primaryFixed.withValues(alpha: 0.04)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              _NotificationIcon(type: notification.type),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryFixed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 14.5,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(notification.createdAt),
                          style: TextStyle(
                            color: isUnread
                                ? AppColors.primaryFixed
                                : AppColors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight:
                                isUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (notification.coachName != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _MiniAvatar(
                            name: notification.coachName!,
                            avatarUrl: notification.coachAvatarUrl,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            notification.coachName!,
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.MMMd().format(dt);
  }
}

// ---------------------------------------------------------------------------
// Notification icon
// ---------------------------------------------------------------------------
class _NotificationIcon extends StatelessWidget {
  final NotificationType type;

  const _NotificationIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      NotificationType.message => (
          Icons.chat_bubble_outline_rounded,
          AppColors.primaryFixed,
        ),
      NotificationType.plan => (
          Icons.fitness_center_rounded,
          Colors.teal,
        ),
    };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini avatar (for coach name row)
// ---------------------------------------------------------------------------
class _MiniAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _MiniAvatar({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 10,
      backgroundColor: AppColors.primaryFixed.withValues(alpha: 0.12),
      backgroundImage:
          avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: AppColors.primaryFixed,
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
            )
          : null,
    );
  }
}