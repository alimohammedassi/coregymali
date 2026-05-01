import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import 'package:coregym2/l10n/app_localizations.dart';
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
  late final ChatNotifier _chatNotifier;
  late final AnimationController _inputBarAnimController;
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    _chatNotifier = ChatNotifier(context.read<ChatRepoProvider>().repo, widget.conversation.id);
    _inputBarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _textController.addListener(_onTextChanged);
    _markAsRead();
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
    _scrollController.dispose();
    _chatNotifier.dispose();
    _inputBarAnimController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _textController.clear();
    _chatNotifier.sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
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
        chatNotifier: _chatNotifier,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListenableBuilder(
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
                  return _EmptyView(l: l);
                }
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return _MessageList(
                  scrollController: _scrollController,
                  messages: _chatNotifier.messages,
                  userId: userId,
                );
              },
            ),
          ),
          _MessageInputBar(
            l: l,
            controller: _textController,
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
// AppBar — extracted for clarity
// ---------------------------------------------------------------------------
class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ConversationEntity conversation;
  final bool isClient;
  final AppLocalizations l;
  final ChatNotifier chatNotifier;

  const _ChatAppBar({
    required this.conversation,
    required this.isClient,
    required this.l,
    required this.chatNotifier,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final otherName = isClient
        ? (conversation.coachName ?? l.coach)
        : (conversation.clientName ?? l.client);
    final otherAvatar = isClient
        ? conversation.coachAvatarUrl
        : conversation.clientAvatarUrl;

    return AppBar(
      backgroundColor: AppColors.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
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
          _Avatar(name: otherName, avatarUrl: otherAvatar, radius: 19),
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
                    fontSize: 15,
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

  const _MessageList({
    required this.scrollController,
    required this.messages,
    required this.userId,
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
// Loading / Error / Empty states
// ---------------------------------------------------------------------------
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: AppColors.primaryFixed,
        strokeWidth: 2.5,
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
              child: Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 32),
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
  final AppLocalizations l;

  const _EmptyView({required this.l});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 36, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            l.sayHello,
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start a conversation!',
            style: TextStyle(
                color: AppColors.onSurfaceVariant, fontSize: 13),
          ),
        ],
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
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
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
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
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
    return DateFormat('MMM d, yyyy').format(dt);
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ---------------------------------------------------------------------------
// Reusable Avatar
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
// Message bubble — grouped, with tails
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
    const r = Radius.circular(18);
    const rSmall = Radius.circular(4);

    final bubbleRadius = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: isMe
          ? r
          : isLastInGroup
              ? rSmall
              : r,
      bottomRight: isMe
          ? isLastInGroup
              ? rSmall
              : r
          : r,
    );

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? 6 : 2,
        bottom: isLastInGroup ? 6 : 2,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar placeholder (keep width consistent)
          if (!isMe) ...[
            SizedBox(
              width: 32,
              child: showAvatar
                  ? _Avatar(
                      name: message.senderId,
                      avatarUrl: null,
                      radius: 16,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 6),
          ],

          // Bubble
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primaryFixed
                    : AppColors.surfaceContainerHighest,
                borderRadius: bubbleRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
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
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('h:mm a').format(message.createdAt),
                        style: TextStyle(
                          color: isMe
                              ? AppColors.onPrimary.withValues(alpha: 0.55)
                              : AppColors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(
                          message.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 13,
                          color: message.isRead
                              ? AppColors.onPrimary.withValues(alpha: 0.9)
                              : AppColors.onPrimary.withValues(alpha: 0.45),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 4),
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
  final VoidCallback onSend;
  final bool isSending;
  final bool isComposing;
  final AnimationController animController;

  const _MessageInputBar({
    required this.l,
    required this.controller,
    required this.onSend,
    required this.isSending,
    required this.isComposing,
    required this.animController,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomInset + 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: controller,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 15,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: l.typeMessage,
                  hintStyle: TextStyle(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
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
          ),
          const SizedBox(width: 8),

          // Send button — animated
          AnimatedBuilder(
            animation: animController,
            builder: (_, __) {
              final scale = Tween<double>(begin: 0.85, end: 1.0)
                  .evaluate(CurvedAnimation(
                parent: animController,
                curve: Curves.easeOutBack,
              ));
              final opacity = Tween<double>(begin: 0.5, end: 1.0)
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
        color: canSend ? AppColors.primaryFixed : AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
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
                      color: AppColors.primaryFixed,
                    ),
                  )
                : Icon(
                    Icons.send_rounded,
                    size: 20,
                    color: canSend
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
          ),
        ),
      ),
    );
  }
}