import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/chat_providers.dart';

class ChatRoomScreen extends StatefulWidget {
  final ConversationEntity conversation;

  const ChatRoomScreen({super.key, required this.conversation});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late final ChatNotifier _chatNotifier;
  late final AnimationController _inputBarAnimController;
  late final AnimationController _typingAnimController;
  bool _isComposing = false;
  bool _showJumpToBottom = false;

  @override
  void initState() {
    super.initState();
    _chatNotifier = ChatNotifier(
      context.read<ChatRepoProvider>().repo,
      widget.conversation.id,
    );
    _inputBarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _textController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
    _markAsRead();
  }

  void _onScroll() {
    final atBottom = _scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100;
    if (_showJumpToBottom == atBottom) return;
    setState(() => _showJumpToBottom = !atBottom);
  }

  void _onTextChanged() {
    final composing = _textController.text.trim().isNotEmpty;
    if (composing != _isComposing) {
      setState(() => _isComposing = composing);
      if (composing) {
        _inputBarAnimController.forward();
      } else {
        _inputBarAnimController.reverse();
      }
    }
  }

  Future<void> _markAsRead() async {
    final userId = chatCurrentUserId();
    if (userId == null) return;
    await _chatNotifier.chatRepo
        .markConversationRead(widget.conversation.id, userId);
    if (mounted) {
      context.read<ConversationsNotifier>().refresh();
      context.read<UnreadCountNotifier>().load();
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    _chatNotifier.dispose();
    _inputBarAnimController.dispose();
    _typingAnimController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _textController.clear();
    _focusNode.requestFocus();
    _chatNotifier.sendMessage(text);
    _scrollToBottom(immediate: true);
  }

  void _scrollToBottom({bool immediate = false}) {
    Future.delayed(Duration(milliseconds: immediate ? 20 : 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: immediate ? 120 : 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final userId = chatCurrentUserId() ?? '';
    final isClient = userId == widget.conversation.clientId;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _ChatAppBar(
        conversation: widget.conversation,
        isClient: isClient,
        l: l,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Messages
                ListenableBuilder(
                  listenable: _chatNotifier,
                  builder: (_, __) {
                    if (_chatNotifier.isLoading) {
                      return const _LoadingView();
                    }
                    if (_chatNotifier.error != null) {
                      return _ErrorView(
                        error: _chatNotifier.error!,
                        onRetry: _chatNotifier.refresh,
                        l: l,
                      );
                    }
                    if (_chatNotifier.messages.isEmpty) {
                      return _EmptyView(l: l, isClient: isClient);
                    }
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _scrollToBottom());
                    return _MessageList(
                      scrollController: _scrollController,
                      messages: _chatNotifier.messages,
                      userId: userId,
                      typingAnimController: _typingAnimController,
                    );
                  },
                ),

                // Jump to bottom FAB
                if (_showJumpToBottom)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _JumpToBottomButton(
                        onTap: () {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _MessageInputBar(
            l: l,
            controller: _textController,
            focusNode: _focusNode,
            onSend: _sendMessage,
            isSending: _chatNotifier.isSending,
            isComposing: _isComposing,
            animController: _inputBarAnimController,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppBar
// ---------------------------------------------------------------------------
class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ConversationEntity conversation;
  final bool isClient;
  final AppLocalizations l;

  const _ChatAppBar({
    required this.conversation,
    required this.isClient,
    required this.l,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final otherName = isClient
        ? (conversation.coachName ?? l.coach)
        : (conversation.clientName ?? l.client);
    final otherAvatar =
        isClient ? conversation.coachAvatarUrl : conversation.clientAvatarUrl;

    return AppBar(
      backgroundColor: AppColors.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      leadingWidth: 48,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.onSurface, size: 20),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          _Avatar(name: otherName, avatarUrl: otherAvatar, radius: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  otherName,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isClient ? l.coach : l.client,
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_vert_rounded,
              color: AppColors.onSurfaceVariant, size: 22),
          onPressed: () => _showChatOptions(context),
          tooltip: 'More options',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  void _showChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChatOptionsSheet(isClient: isClient, l: l),
    );
  }
}

class _ChatOptionsSheet extends StatelessWidget {
  final bool isClient;
  final AppLocalizations l;

  const _ChatOptionsSheet({required this.isClient, required this.l});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _OptionTile(
              icon: Icons.person_outline_rounded,
              label: 'View ${isClient ? "coach" : "client"} profile',
              onTap: () {
                Navigator.pop(context);
                // TODO: navigate to profile
              },
            ),
            _OptionTile(
              icon: Icons.notifications_outlined,
              label: 'Notification settings',
              onTap: () {
                Navigator.pop(context);
                // TODO: navigate to notification settings
              },
            ),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete conversation',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                // TODO: confirm and delete
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.onSurface;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      dense: true,
    );
  }
}

// ---------------------------------------------------------------------------
// Message list
// ---------------------------------------------------------------------------
class _MessageList extends StatelessWidget {
  final ScrollController scrollController;
  final List<MessageEntity> messages;
  final String userId;
  final AnimationController typingAnimController;

  const _MessageList({
    required this.scrollController,
    required this.messages,
    required this.userId,
    required this.typingAnimController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (ctx, index) {
        final msg = messages[index];
        final isMe = msg.senderId == userId;
        final showDate = index == 0 ||
            !_isSameDay(messages[index - 1].createdAt, msg.createdAt);
        final showAvatar = !isMe &&
            (index == messages.length - 1 ||
                messages[index + 1].senderId != msg.senderId);
        final isFirstInGroup = index == 0 ||
            messages[index - 1].senderId != msg.senderId ||
            showDate;
        final isLastInGroup = index == messages.length - 1 ||
            messages[index + 1].senderId != msg.senderId;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate) _DateDivider(date: msg.createdAt),
            _MessageBubble(
              message: msg,
              isMe: isMe,
              showAvatar: showAvatar,
              isFirstInGroup: isFirstInGroup,
              isLastInGroup: isLastInGroup,
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: AppColors.primaryFixed,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 12),
          Text(
            'Loading messages...',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

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
              child:
                  Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load messages',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
  final AppLocalizations l;
  final bool isClient;

  const _EmptyView({required this.l, required this.isClient});

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
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 40, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(
              l.sayHello,
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send your first message to ${isClient ? "your coach" : "your client"}!',
              style: TextStyle(
                  color: AppColors.onSurfaceVariant, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date divider
// ---------------------------------------------------------------------------
class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: AppColors.outlineVariant.withValues(alpha: 0.4),
              thickness: 1,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatDate(date),
            style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: AppColors.outlineVariant.withValues(alpha: 0.4),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) return 'Today';
    if (_isSameDay(dt, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('EEEE, MMM d').format(dt);
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ---------------------------------------------------------------------------
// Jump to bottom
// ---------------------------------------------------------------------------
class _JumpToBottomButton extends StatelessWidget {
  final VoidCallback onTap;

  const _JumpToBottomButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.primaryFixed),
              const SizedBox(width: 4),
              Text(
                'Jump to latest',
                style: TextStyle(
                  color: AppColors.primaryFixed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar
// ---------------------------------------------------------------------------
class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;

  const _Avatar(
      {required this.name, required this.avatarUrl, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryFixed.withValues(alpha: 0.15),
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: AppColors.primaryFixed,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.75,
              ),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------
class _MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final bool showAvatar;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(20);
    const rSmall = Radius.circular(6);

    final bubbleRadius = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: isMe ? r : isLastInGroup ? rSmall : r,
      bottomRight: isMe ? (isLastInGroup ? rSmall : r) : r,
    );

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? 8 : 2,
        bottom: isLastInGroup ? 8 : 2,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            SizedBox(
              width: 34,
              child: showAvatar
                  ? _Avatar(
                      name: message.senderId,
                      avatarUrl: null,
                      radius: 17,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 6),
          ],

          // Bubble
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primaryFixed
                    : AppColors.surfaceContainerHighest,
                borderRadius: bubbleRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? AppColors.onPrimary : AppColors.onSurface,
                      fontSize: 15.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('h:mm a').format(message.createdAt),
                        style: TextStyle(
                          color: isMe
                              ? AppColors.onPrimary.withValues(alpha: 0.55)
                              : AppColors.onSurfaceVariant,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 14,
                          color: message.isRead
                              ? AppColors.onPrimary.withValues(alpha: 0.9)
                              : AppColors.onPrimary.withValues(alpha: 0.4),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar
// ---------------------------------------------------------------------------
class _MessageInputBar extends StatelessWidget {
  final AppLocalizations l;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isSending;
  final bool isComposing;
  final AnimationController animController;

  const _MessageInputBar({
    required this.l,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.isSending,
    required this.isComposing,
    required this.animController,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomInset + 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attach button
          _AttachButton(),
          const SizedBox(width: 8),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isComposing
                      ? AppColors.primaryFixed.withValues(alpha: 0.4)
                      : AppColors.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 15.5,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        hintText: l.typeMessage,
                        hintStyle: TextStyle(
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.65),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      maxLines: 5,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  // Character / emoji hint
                  Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 10),
                    child: Text(
                      '${controller.text.length}',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          AnimatedBuilder(
            animation: animController,
            builder: (_, __) {
              final scale = Tween<double>(begin: 0.8, end: 1.0)
                  .evaluate(CurvedAnimation(
                parent: animController,
                curve: Curves.easeOutBack,
              ));
              final opacity = Tween<double>(begin: 0.4, end: 1.0)
                  .evaluate(animController);

              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: _SendButton(
                    isSending: isSending,
                    isComposing: isComposing,
                    onTap: onSend,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attach button
// ---------------------------------------------------------------------------
class _AttachButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Attach file',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _showAttachMenu(context);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_circle_outline_rounded,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  void _showAttachMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachOption(
                    icon: Icons.image_outlined,
                    label: 'Photo',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: image picker
                    },
                  ),
                  _AttachOption(
                    icon: Icons.folder_outlined,
                    label: 'Document',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: file picker
                    },
                  ),
                  _AttachOption(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: camera
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Send button
// ---------------------------------------------------------------------------
class _SendButton extends StatelessWidget {
  final bool isSending;
  final bool isComposing;
  final VoidCallback onTap;

  const _SendButton({
    required this.isSending,
    required this.isComposing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canSend = isComposing && !isSending;

    return Semantics(
      button: true,
      label: 'Send message',
      child: Material(
        color: canSend
            ? AppColors.primaryFixed
            : AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        elevation: canSend ? 2 : 0,
        child: InkWell(
          onTap: canSend ? onTap : null,
          borderRadius: BorderRadius.circular(22),
          splashColor: AppColors.onPrimary.withValues(alpha: 0.15),
          child: SizedBox(
            width: 44,
            height: 44,
            child: isSending
                ? Padding(
                    padding: const EdgeInsets.all(13),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.surfaceContainerHighest,
                    ),
                  )
                : Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: canSend
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
          ),
        ),
      ),
    );
  }
}
