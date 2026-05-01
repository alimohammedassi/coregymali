import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:coregym2/theme/app_colors.dart';
import 'package:coregym2/l10n/app_localizations.dart';
import '../../domain/entities/conversation_entity.dart';
import '../providers/chat_providers.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationsNotifier>().load();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _ChatListAppBar(l: l),
      body: RefreshIndicator(
        onRefresh: () => context.read<ConversationsNotifier>().load(),
        color: AppColors.primaryFixed,
        backgroundColor: AppColors.surfaceContainer,
        displacement: 48,
        child: Consumer<ConversationsNotifier>(
          builder: (ctx, notifier, _) {
            if (notifier.isLoading) {
              return _SkeletonList();
            }

            if (notifier.error != null) {
              return _ErrorView(
                error: notifier.error!,
                onRetry: notifier.load,
                l: l,
              );
            }

            if (notifier.conversations.isEmpty) {
              return _EmptyView(l: l);
            }

            final userId = chatCurrentUserId() ?? '';

            return ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: notifier.conversations.length,
              itemBuilder: (ctx, index) {
                final conv = notifier.conversations[index];
                return _ConversationTile(
                  conversation: conv,
                  currentUserId: userId,
                  l: l,
                  index: index,
                  onTap: () => _openChat(ctx, conv),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _openChat(BuildContext ctx, ConversationEntity conv) {
    HapticFeedback.selectionClick();
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ChatNotifier(
            ctx.read<ChatRepoProvider>().repo,
            conv.id,
          ),
          child: ChatRoomScreen(conversation: conv),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppBar
// ---------------------------------------------------------------------------
class _ChatListAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppLocalizations l;

  const _ChatListAppBar({required this.l});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Text(
        l.chatTitle,
        style: TextStyle(
          color: AppColors.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          letterSpacing: -0.4,
        ),
      ),
      // Optional: unread badge from global notifier
      actions: [
        Consumer<UnreadCountNotifier>(
          builder: (_, unread, __) {
            if (unread.count == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${unread.count}',
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppColors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton loading list
// ---------------------------------------------------------------------------
class _SkeletonList extends StatefulWidget {
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
          AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
          ((_shimmerController.value * 2) - 1).abs(),
        )!;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 4),
          itemCount: 7,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
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
                Row(
                  children: [
                    Container(
                      width: 120,
                      height: 13,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 36,
                      height: 11,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
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
// Error state
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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load chats',
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

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyView extends StatelessWidget {
  final AppLocalizations l;

  const _EmptyView({required this.l});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 40,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l.noConversations,
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
              l.noConversationsHint,
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

// ---------------------------------------------------------------------------
// Conversation tile — staggered entrance + swipe-to-dismiss feel
// ---------------------------------------------------------------------------
class _ConversationTile extends StatefulWidget {
  final ConversationEntity conversation;
  final String currentUserId;
  final AppLocalizations l;
  final VoidCallback onTap;
  final int index;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.l,
    required this.onTap,
    required this.index,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    // Stagger by index (capped so late items don't wait too long)
    final delay = Duration(milliseconds: (widget.index * 40).clamp(0, 200));
    Future.delayed(delay, () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;
    final userId = widget.currentUserId;
    final l = widget.l;

    final unreadCount = conv.unreadFor(userId);
    final isUnread = unreadCount > 0;
    final isClient = userId == conv.clientId;
    final otherName = isClient
        ? (conv.coachName ?? l.coach)
        : (conv.clientName ?? l.client);
    final otherAvatar =
        isClient ? conv.coachAvatarUrl : conv.clientAvatarUrl;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: _TileContent(
          otherName: otherName,
          otherAvatar: otherAvatar,
          lastMessage: conv.lastMessage,
          lastMessageAt: conv.lastMessageAt,
          isUnread: isUnread,
          unreadCount: unreadCount,
          isClient: isClient,
          l: l,
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

class _TileContent extends StatelessWidget {
  final String otherName;
  final String? otherAvatar;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool isUnread;
  final int unreadCount;
  final bool isClient;
  final AppLocalizations l;
  final VoidCallback onTap;

  const _TileContent({
    required this.otherName,
    required this.otherAvatar,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.isUnread,
    required this.unreadCount,
    required this.isClient,
    required this.l,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primaryFixed.withValues(alpha: 0.06),
        highlightColor: AppColors.primaryFixed.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with unread indicator dot
              _AvatarWithDot(
                name: otherName,
                avatarUrl: otherAvatar,
                showDot: isUnread,
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row + time
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            otherName,
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 15,
                              letterSpacing: -0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (lastMessageAt != null)
                          Text(
                            _formatTime(lastMessageAt!),
                            style: TextStyle(
                              color: isUnread
                                  ? AppColors.primaryFixed
                                  : AppColors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: isUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Preview row + badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage ?? '',
                            style: TextStyle(
                              color: isUnread
                                  ? AppColors.onSurface
                                  : AppColors.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: isUnread
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          _UnreadBadge(count: unreadCount),
                        ],
                      ],
                    ),
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
    if (diff.inDays == 0) return DateFormat.jm().format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat.E().format(dt);
    return DateFormat.MMMd().format(dt);
  }
}

// ---------------------------------------------------------------------------
// Avatar with an unread indicator dot
// ---------------------------------------------------------------------------
class _AvatarWithDot extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool showDot;

  const _AvatarWithDot({
    required this.name,
    required this.avatarUrl,
    required this.showDot,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor:
                AppColors.primaryFixed.withValues(alpha: 0.12),
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppColors.primaryFixed,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          if (showDot)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Unread count badge
// ---------------------------------------------------------------------------
class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: count > 9 ? 6 : 7,
        vertical: 3,
      ),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: AppColors.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}