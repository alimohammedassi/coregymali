import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
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
  String _searchQuery = '';
  bool _isSearching = false;

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

  List<ConversationEntity> _filtered(List<ConversationEntity> convs) {
    if (_searchQuery.isEmpty) return convs;
    return convs.where((c) {
      final name = (c.clientName ?? c.coachName ?? '').toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: AppColors.surfaceContainer,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            expandedHeight: _isSearching ? 0 : 72,
            floating: false,
            leadingWidth: 0,
            leading: const SizedBox.shrink(),
            title: _isSearching
                ? _SearchField(
                    initialValue: _searchQuery,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    onClear: () => setState(() {
                      _searchQuery = '';
                      _isSearching = false;
                    }),
                  )
                : Row(
                    children: [
                      Text(
                        l.chatTitle,
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.search_rounded,
                            color: AppColors.onSurfaceVariant, size: 22),
                        onPressed: () => setState(() => _isSearching = true),
                        tooltip: 'Search',
                      ),
                    ],
                  ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
                height: 1,
              ),
            ),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: () => context.read<ConversationsNotifier>().load(),
          color: AppColors.primaryFixed,
          backgroundColor: AppColors.surfaceContainer,
          displacement: 40,
          child: Consumer<ConversationsNotifier>(
            builder: (ctx, notifier, _) {
              if (notifier.isLoading && notifier.conversations.isEmpty) {
                return _SkeletonList();
              }
              if (notifier.error != null && notifier.conversations.isEmpty) {
                return _ErrorView(
                  error: notifier.error!,
                  onRetry: notifier.load,
                  l: l,
                );
              }

              final filtered = _filtered(notifier.conversations);
              if (filtered.isEmpty) {
                return _EmptyView(l: l, isSearching: _searchQuery.isNotEmpty);
              }

              final userId = chatCurrentUserId() ?? '';

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Unread section header
                  if (filtered.any((c) => c.unreadFor(userId) > 0)) ...[
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        label: 'Unread',
                        count: filtered
                            .where((c) => c.unreadFor(userId) > 0)
                            .length,
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          final conv = filtered
                              .where((c) => c.unreadFor(userId) > 0)
                              .toList()[index];
                          return _ConversationTile(
                            conversation: conv,
                            currentUserId: userId,
                            l: l,
                            index: index,
                            onTap: () => _openChat(ctx, conv),
                          );
                        },
                        childCount: filtered
                            .where((c) => c.unreadFor(userId) > 0)
                            .length,
                      ),
                    ),
                    SliverToBoxAdapter(child: _Divider()),
                    SliverToBoxAdapter(
                      child: _SectionHeader(label: 'All'),
                    ),
                  ],
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) {
                        final unread = filtered
                            .where((c) => c.unreadFor(userId) > 0)
                            .toList();
                        final readIndex = filtered
                            .where((c) => c.unreadFor(userId) == 0)
                            .toList()[index];
                        return _ConversationTile(
                          conversation: readIndex,
                          currentUserId: userId,
                          l: l,
                          index: unread.length + index,
                          onTap: () => _openChat(ctx, readIndex),
                        );
                      },
                      childCount:
                          filtered.where((c) => c.unreadFor(userId) == 0).length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String label;
  final int? count;

  const _SectionHeader({required this.label, this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: AppColors.primaryFixed,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 1,
      color: AppColors.outlineVariant.withValues(alpha: 0.25),
    );
  }
}

// ---------------------------------------------------------------------------
// Search field
// ---------------------------------------------------------------------------
class _SearchField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.initialValue,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.onSurface),
          onPressed: widget.onClear,
        ),
        Expanded(
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: widget.onChanged,
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Search conversations...',
              hintStyle: TextStyle(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 16,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
        if (_ctrl.text.isNotEmpty)
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 18, color: AppColors.onSurfaceVariant),
            onPressed: () {
              _ctrl.clear();
              widget.onChanged('');
            },
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton loading
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
          AppColors.surfaceContainerHighest.withValues(alpha: 0.35),
          ((_shimmerController.value * 2) - 1).abs(),
        )!;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: 8,
          itemBuilder: (_, index) => _SkeletonTile(
            shimmerColor: shimmerColor,
            hasUnread: index == 0 || index == 3,
          ),
        );
      },
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  final Color shimmerColor;
  final bool hasUnread;

  const _SkeletonTile({
    required this.shimmerColor,
    this.hasUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (hasUnread)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 110,
                      height: 13,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 42,
                      height: 11,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        height: 12,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ],
                  ],
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
              child:
                  Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              "Couldn't load chats",
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l.retry),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryFixed,
                foregroundColor: AppColors.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
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
  final bool isSearching;

  const _EmptyView({required this.l, this.isSearching = false});

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
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.forum_outlined,
                size: 44,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearching ? 'No results found' : l.noConversations,
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
              isSearching
                  ? 'Try a different name or keyword'
                  : l.noConversationsHint,
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
// Conversation tile
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
      duration: const Duration(milliseconds: 340),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    final delay = Duration(
      milliseconds: (widget.index * 35).clamp(0, 180),
    );
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

    // isLastFromMe would require lastMessageSenderId on entity

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Dismissible(
          key: Key(conv.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: AppColors.primaryFixed.withValues(alpha: 0.08),
            child: Icon(Icons.archive_outlined,
                color: AppColors.primaryFixed, size: 22),
          ),
          confirmDismiss: (_) async {
            HapticFeedback.mediumImpact();
            return true;
          },
          onDismissed: (_) {
            // Future: archive conversation
          },
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
        highlightColor: AppColors.primaryFixed.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with online dot
              _AvatarWithDot(
                name: otherName,
                avatarUrl: otherAvatar,
                showDot: isUnread,
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            otherName,
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontWeight:
                                  isUnread ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 15.5,
                              letterSpacing: -0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (lastMessageAt != null)
                          Text(
                            _formatRelativeTime(lastMessageAt!),
                            style: TextStyle(
                              color: isUnread
                                  ? AppColors.primaryFixed
                                  : AppColors.onSurfaceVariant,
                              fontSize: 11.5,
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w400,
                            ),
                            semanticsLabel: _fullDateTime(lastMessageAt!),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        // Role chip (coach/client)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            isClient ? l.coach : l.client,
                            style: TextStyle(
                              color: AppColors.primaryFixed,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lastMessage ?? '',
                            style: TextStyle(
                              color: isUnread
                                  ? AppColors.onSurface.withValues(alpha: 0.85)
                                  : AppColors.onSurfaceVariant,
                              fontSize: 13.5,
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

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return DateFormat.jm().format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat.E().format(dt);
    return DateFormat.MMMd().format(dt);
  }

  String _fullDateTime(DateTime dt) {
    return DateFormat('MMM d, yyyy at h:mm a').format(dt);
  }
}

// ---------------------------------------------------------------------------
// Avatar with unread indicator
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
            backgroundColor: AppColors.primaryFixed.withValues(alpha: 0.12),
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
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Unread badge
// ---------------------------------------------------------------------------
class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: count > 9 ? 5 : 7,
        vertical: 3,
      ),
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryFixed.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: AppColors.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}