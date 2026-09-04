import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Voice recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _recordTimer;
  String? _recordPath;

  @override
  void initState() {
    super.initState();
    _chatNotifier = ChatNotifier(
      context.read<ChatRepoProvider>().repo,
      widget.conversation.id,
    );
    // Send failures surface as a transient SnackBar — the conversation list
    // must never be replaced by an error screen because one message failed.
    _chatNotifier.addListener(_onChatNotifierChanged);
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

  void _onChatNotifierChanged() {
    final sendError = _chatNotifier.sendError;
    if (sendError == null || !mounted) return;
    _chatNotifier.clearSendError();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Message failed to send — check your connection and try again',
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
    _chatNotifier.removeListener(_onChatNotifierChanged);
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _chatNotifier.dispose();
    _inputBarAnimController.dispose();
    _typingAnimController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _focusNode.requestFocus();
    // Clear only once the message is actually persisted — if the send
    // fails the user keeps what they typed instead of losing it.
    final ok = await _chatNotifier.sendMessage(text);
    if (!ok || !mounted) return;
    _textController.clear();
    _scrollToBottom(immediate: true);
  }

  // ── Voice recording ────────────────────────────────────────────────
  Future<void> _startVoiceRecording() async {
    HapticFeedback.mediumImpact();
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Microphone permission is required to send voice notes'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (!await _audioRecorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Microphone not available'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      _recordPath =
          '${dir.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 96000,
        ),
        path: _recordPath!,
      );
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordDuration += const Duration(seconds: 1));
        // Auto-stop at 2 minutes to keep files reasonable
        if (_recordDuration.inSeconds >= 120) {
          _stopVoiceRecording();
        }
      });
    } catch (e) {
      debugPrint('❌ chat voice start failed: $e');
      setState(() {
        _isRecording = false;
        _recordDuration = Duration.zero;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start recording: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _stopVoiceRecording({bool cancel = false}) async {
    _recordTimer?.cancel();
    _recordTimer = null;
    final path = _recordPath;
    final duration = _recordDuration;
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
      _recordPath = null;
    });

    if (path == null) return;
    try {
      await _audioRecorder.stop();
    } catch (_) {}

    if (cancel) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      HapticFeedback.lightImpact();
      return;
    }

    final file = File(path);
    if (!await file.exists()) return;
    final len = await file.length();
    if (len == 0) {
      try {
        await file.delete();
      } catch (_) {}
      return;
    }
    if (duration.inSeconds < 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Voice note too short'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      try {
        await file.delete();
      } catch (_) {}
      return;
    }

    HapticFeedback.lightImpact();
    try {
      await _chatNotifier.sendVoiceMessage(
        filePath: path,
        durationSeconds: duration.inSeconds,
      );
      _scrollToBottom(immediate: true);
      // Cleanup local temp after upload (keep for a moment in case retry needed)
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send voice note: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _cancelVoiceRecording() => _stopVoiceRecording(cancel: true);

  // ── Image picking (gallery / camera) — compressed before upload
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null) return;
      HapticFeedback.lightImpact();
      await _chatNotifier.sendImageMessage(filePath: picked.path);
      _scrollToBottom(immediate: true);
    } catch (e) {
      debugPrint('❌ chat image pick failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send image: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _pickPdf() async {
    try {
      // FileType.custom / allowedExtensions is mishandled by several Android
      // OEM pickers (Realme/OPPO included — PDFs show greyed out or the pick
      // errors), so open the picker unfiltered and validate the extension
      // ourselves.
      final result = await FilePicker.pickFiles(withData: false);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final path = file.path;
      if (path == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read PDF file')),
        );
        return;
      }
      if (!file.name.toLowerCase().endsWith('.pdf')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please pick a PDF file'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      HapticFeedback.lightImpact();
      await _chatNotifier.sendFileMessage(
        filePath: path,
        fileName: file.name,
        // withData:false can report -1 size from some providers
        fileSize: file.size > 0 ? file.size : 0,
      );
      _scrollToBottom(immediate: true);
    } catch (e) {
      debugPrint('❌ chat pdf pick failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send file: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showImageSourceSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Send file',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ImageSourceTile(
                      icon: Icons.photo_camera_rounded,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImageSourceTile(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImageSourceTile(
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'PDF',
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickPdf();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
            isRecording: _isRecording,
            recordingDuration: _recordDuration,
            onStartVoice: _startVoiceRecording,
            onStopVoice: _stopVoiceRecording,
            onCancelVoice: _cancelVoiceRecording,
            onPickImage: _showImageSourceSheet,
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
      // The ⋮ options sheet was removed: every action in it (view profile,
      // notification settings, delete conversation) was a dead TODO no-op.
      // Fake menus are worse than no menu — restore when the actions exist.
      actions: const [],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
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

    // Voice messages get a dedicated bubble with playback
    if (message.isVoiceMessage) {
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
                    ? _Avatar(name: message.senderId, avatarUrl: null, radius: 17)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 6),
            ],
            _VoiceBubble(
              message: message,
              isMe: isMe,
              bubbleRadius: bubbleRadius,
            ),
            if (isMe) const SizedBox(width: 6),
          ],
        ),
      );
    }

    if (message.isImageMessage) {
      return Padding(
        padding: EdgeInsets.only(
          top: isFirstInGroup ? 8 : 2,
          bottom: isLastInGroup ? 8 : 2,
        ),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              SizedBox(
                width: 34,
                child: showAvatar
                    ? _Avatar(name: message.senderId, avatarUrl: null, radius: 17)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 6),
            ],
            _ImageBubble(
              message: message,
              isMe: isMe,
              bubbleRadius: bubbleRadius,
            ),
            if (isMe) const SizedBox(width: 6),
          ],
        ),
      );
    }

    if (message.isFileMessage) {
      return Padding(
        padding: EdgeInsets.only(
          top: isFirstInGroup ? 8 : 2,
          bottom: isLastInGroup ? 8 : 2,
        ),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              SizedBox(
                width: 34,
                child: showAvatar
                    ? _Avatar(name: message.senderId, avatarUrl: null, radius: 17)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 6),
            ],
            _FileBubble(
              message: message,
              isMe: isMe,
              bubbleRadius: bubbleRadius,
            ),
            if (isMe) const SizedBox(width: 6),
          ],
        ),
      );
    }

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
// Voice bubble — play/pause + progress + duration
// ---------------------------------------------------------------------------
class _VoiceBubble extends StatefulWidget {
  final MessageEntity message;
  final bool isMe;
  final BorderRadius bubbleRadius;

  const _VoiceBubble({
    required this.message,
    required this.isMe,
    required this.bubbleRadius,
  });

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  AudioPlayer? _player;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.message.voiceDurationSeconds);
    _prepare();
  }

  Future<void> _prepare() async {
    final path = widget.message.fileUrl;
    if (path == null || path.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'No audio';
      });
      return;
    }
    try {
      // Private bucket: create signed URL on the fly
      final url = await Supabase.instance.client.storage
          .from('chat-voice-notes')
          .createSignedUrl(path, 60 * 60 * 24 * 365);
      if (!mounted) return;
      _player = AudioPlayer();
      await _player!.setUrl(url);
      final d = _player!.duration;
      if (d != null && d.inSeconds > 0) {
        _duration = d;
      }
      _player!.positionStream.listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
      });
      _player!.playerStateStream.listen((state) {
        if (!mounted) return;
        final playing = state.playing;
        final completed = state.processingState == ProcessingState.completed;
        setState(() => _isPlaying = playing && !completed);
        if (completed) {
          _player!.seek(Duration.zero);
          _player!.pause();
        }
      });
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final accent = isMe ? AppColors.onPrimary : AppColors.primaryFixed;
    final bg = isMe ? AppColors.primaryFixed : AppColors.surfaceContainerHighest;
    final fgSecondary = isMe
        ? AppColors.onPrimary.withValues(alpha: 0.7)
        : AppColors.onSurfaceVariant;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.68,
        minWidth: 220,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: widget.bubbleRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Play / pause
                Material(
                  color: isMe
                      ? AppColors.onPrimary.withValues(alpha: 0.15)
                      : AppColors.primaryFixed.withValues(alpha: 0.12),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isLoading || _error != null || _player == null
                        ? null
                        : () async {
                            if (_isPlaying) {
                              await _player!.pause();
                            } else {
                              if (_position >= _duration && _duration.inSeconds > 0) {
                                await _player!.seek(Duration.zero);
                              }
                              await _player!.play();
                            }
                          },
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: _isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accent,
                              ),
                            )
                          : Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 24,
                              color: _error != null ? Colors.red : accent,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Waveform / progress + duration
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Simple waveform placeholder + progress bar
                      Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 28,
                            decoration: BoxDecoration(
                              color: isMe
                                  ? AppColors.onPrimary.withValues(alpha: 0.12)
                                  : AppColors.outlineVariant.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(18, (i) {
                                final h = 6 + (i % 4) * 4.0 + (i % 3) * 2.0;
                                final active = _duration.inMilliseconds > 0 &&
                                    (i / 18) < (_position.inMilliseconds / _duration.inMilliseconds);
                                return Container(
                                  width: 3,
                                  height: h,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? accent
                                        : accent.withValues(alpha: isMe ? 0.35 : 0.25),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            ),
                          ),
                          if (_duration.inMilliseconds > 0)
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 28,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                                overlayShape: SliderComponentShape.noOverlay,
                                activeTrackColor: Colors.transparent,
                                inactiveTrackColor: Colors.transparent,
                                thumbColor: Colors.transparent,
                              ),
                              child: Slider(
                                value: _position.inMilliseconds
                                    .clamp(0, _duration.inMilliseconds)
                                    .toDouble(),
                                min: 0,
                                max: _duration.inMilliseconds.toDouble(),
                                onChanged: (v) async {
                                  await _player?.seek(Duration(milliseconds: v.toInt()));
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isPlaying ? '${_fmt(_position)} / ${_fmt(_duration)}' : _fmt(_duration),
                        style: TextStyle(
                          color: fgSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.mic_rounded, size: 14, color: fgSecondary),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                'Audio unavailable',
                style: TextStyle(color: Colors.red.withValues(alpha: 0.8), fontSize: 11),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(widget.message.createdAt),
                  style: TextStyle(
                    color: isMe
                        ? AppColors.onPrimary.withValues(alpha: 0.55)
                        : AppColors.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    widget.message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: widget.message.isRead
                        ? AppColors.onPrimary.withValues(alpha: 0.9)
                        : AppColors.onPrimary.withValues(alpha: 0.4),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar — text + voice
// ---------------------------------------------------------------------------
class _MessageInputBar extends StatelessWidget {
  final AppLocalizations l;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final bool isSending;
  final bool isComposing;
  final AnimationController animController;
  final bool isRecording;
  final Duration recordingDuration;
  final VoidCallback onStartVoice;
  final Future<void> Function({bool cancel}) onStopVoice;
  final VoidCallback onCancelVoice;
  final VoidCallback onPickImage;

  const _MessageInputBar({
    required this.l,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.isSending,
    required this.isComposing,
    required this.animController,
    this.isRecording = false,
    this.recordingDuration = Duration.zero,
    required this.onStartVoice,
    required this.onStopVoice,
    required this.onCancelVoice,
    required this.onPickImage,
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
      child: isRecording
          ? _RecordingBar(
              duration: recordingDuration,
              onCancel: onCancelVoice,
              onStop: () => onStopVoice(cancel: false),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Image attach
                _AttachButton(
                  isSending: isSending,
                  onTap: onPickImage,
                ),
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
                // Mic OR Send — WhatsApp-style toggle
                if (isComposing)
                  AnimatedBuilder(
                    animation: animController,
                    builder: (_, __) {
                      final scale = Tween<double>(begin: 0.8, end: 1.0).evaluate(
                          CurvedAnimation(parent: animController, curve: Curves.easeOutBack));
                      final opacity =
                          Tween<double>(begin: 0.4, end: 1.0).evaluate(animController);
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
                  )
                else
                  _MicButton(
                    isSending: isSending,
                    onTap: onStartVoice,
                  ),
              ],
            ),
    );
  }
}

class _RecordingBar extends StatefulWidget {
  final Duration duration;
  final VoidCallback onCancel;
  final VoidCallback onStop;

  const _RecordingBar({
    required this.duration,
    required this.onCancel,
    required this.onStop,
  });

  @override
  State<_RecordingBar> createState() => _RecordingBarState();
}

class _RecordingBarState extends State<_RecordingBar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Cancel (trash)
        Material(
          color: AppColors.error.withValues(alpha: 0.1),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onCancel,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.6 + _pulseCtrl.value * 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Recording',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                // Fake waveform bars
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(14, (i) {
                      final h = 6 + (i % 3) * 6.0;
                      return Container(
                        width: 3,
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _fmt(widget.duration),
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Stop & send
        Material(
          color: AppColors.primaryFixed,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onStop,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.send_rounded, size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Send / Mic buttons
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
        color: canSend ? AppColors.primaryFixed : AppColors.surfaceContainerHighest,
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
                    color: canSend ? AppColors.onPrimary : AppColors.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool isSending;
  final VoidCallback onTap;

  const _MicButton({required this.isSending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Record voice note',
      child: Material(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        child: InkWell(
          onTap: isSending ? null : onTap,
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
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Icon(Icons.mic_rounded, size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  final bool isSending;
  final VoidCallback onTap;

  const _AttachButton({required this.isSending, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Attach image',
      child: Material(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: isSending ? null : onTap,
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.image_outlined,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: AppColors.primaryFixed),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
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
// Image bubble — thumbnail + full-screen viewer
// ---------------------------------------------------------------------------
class _ImageBubble extends StatefulWidget {
  final MessageEntity message;
  final bool isMe;
  final BorderRadius bubbleRadius;

  const _ImageBubble({required this.message, required this.isMe, required this.bubbleRadius});

  @override
  State<_ImageBubble> createState() => _ImageBubbleState();
}

class _ImageBubbleState extends State<_ImageBubble> {
  String? _signedUrl;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final path = widget.message.fileUrl;
    if (path == null || path.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No image';
      });
      return;
    }
    try {
      final url = await Supabase.instance.client.storage
          .from('chat-images')
          .createSignedUrl(path, 60 * 60 * 24 * 365);
      if (!mounted) return;
      setState(() {
        _signedUrl = url;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openFullScreen() {
    if (_signedUrl == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
          imageUrl: _signedUrl!,
          heroTag: widget.message.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.62,
        maxHeight: 280,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryFixed : AppColors.surfaceContainerHighest,
          borderRadius: widget.bubbleRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image thumbnail
            GestureDetector(
              onTap: _loading || _error != null ? null : _openFullScreen,
              child: Hero(
                tag: widget.message.id,
                child: AspectRatio(
                  aspectRatio: 1.1,
                  child: Container(
                    color: isMe
                        ? AppColors.primaryFixed.withValues(alpha: 0.15)
                        : AppColors.surfaceContainerHighest,
                    child: _loading
                        ? Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isMe ? AppColors.onPrimary : AppColors.primaryFixed,
                              ),
                            ),
                          )
                        : _error != null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.broken_image_outlined,
                                        size: 32, color: Colors.red.withValues(alpha: 0.6)),
                                    const SizedBox(height: 4),
                                    Text('Failed to load',
                                        style: TextStyle(
                                            color: Colors.red.withValues(alpha: 0.7), fontSize: 11)),
                                  ],
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: _signedUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryFixed,
                                  ),
                                ),
                                errorWidget: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_outlined, size: 32),
                                ),
                              ),
                  ),
                ),
              ),
            ),
            // Caption if any
            if (widget.message.content.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Text(
                  widget.message.content,
                  style: TextStyle(
                    color: isMe ? AppColors.onPrimary : AppColors.onSurface,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
            ],
            // Timestamp + read receipt (overlayed like WhatsApp)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('h:mm a').format(widget.message.createdAt),
                    style: TextStyle(
                      color: isMe
                          ? AppColors.onPrimary.withValues(alpha: 0.7)
                          : AppColors.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      widget.message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 14,
                      color: widget.message.isRead
                          ? AppColors.onPrimary.withValues(alpha: 0.9)
                          : AppColors.onPrimary.withValues(alpha: 0.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _FullScreenImageViewer({required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: PhotoView(
            imageProvider: CachedNetworkImageProvider(imageUrl),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// File bubble — PDF / file sharing
// ---------------------------------------------------------------------------
class _FileBubble extends StatefulWidget {
  final MessageEntity message;
  final bool isMe;
  final BorderRadius bubbleRadius;

  const _FileBubble({required this.message, required this.isMe, required this.bubbleRadius});

  @override
  State<_FileBubble> createState() => _FileBubbleState();
}

class _FileBubbleState extends State<_FileBubble> {
  bool _isDownloading = false;

  String _fmtSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openFile() async {
    final path = widget.message.fileUrl;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not available')),
      );
      return;
    }
    setState(() => _isDownloading = true);
    try {
      final signedUrl = await Supabase.instance.client.storage
          .from('chat-files')
          .createSignedUrl(path, 60 * 60);
      // Download to temp (bounded — a hung connection used to spin forever)
      final resp = await http
          .get(Uri.parse(signedUrl))
          .timeout(const Duration(seconds: 60));
      if (resp.statusCode != 200) throw Exception('Download failed ${resp.statusCode}');
      final dir = await getTemporaryDirectory();
      final fileName = widget.message.fileName.isNotEmpty ? widget.message.fileName : path.split('/').last;
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(resp.bodyBytes);
      if (!mounted) return;
      setState(() => _isDownloading = false);
      // Open in-app PDF viewer if PDF, otherwise try to open via system
      if (fileName.toLowerCase().endsWith('.pdf')) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _PdfViewerScreen(filePath: file.path, fileName: fileName),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${file.path}')),
        );
      }
    } catch (e) {
      debugPrint('❌ chat file open failed: $e');
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final name = widget.message.fileName.isNotEmpty ? widget.message.fileName : 'File';
    final sizeStr = widget.message.fileSizeFormatted.isNotEmpty
        ? widget.message.fileSizeFormatted
        : _fmtSize(widget.message.fileSize);
    final bg = isMe ? AppColors.primaryFixed : AppColors.surfaceContainerHighest;
    final fg = isMe ? AppColors.onPrimary : AppColors.onSurface;
    final fgSecondary = isMe ? AppColors.onPrimary.withValues(alpha: 0.7) : AppColors.onSurfaceVariant;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.68,
        minWidth: 220,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: widget.bubbleRadius,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _isDownloading ? null : _openFile,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.onPrimary.withValues(alpha: 0.15) : AppColors.primaryFixed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      name.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                      size: 28,
                      color: isMe ? AppColors.onPrimary : AppColors.primaryFixed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sizeStr.isNotEmpty ? sizeStr : 'Tap to open',
                          style: TextStyle(color: fgSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isDownloading)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isMe ? AppColors.onPrimary : AppColors.primaryFixed,
                      ),
                    )
                  else
                    Icon(Icons.download_rounded, size: 20, color: fgSecondary),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(widget.message.createdAt),
                  style: TextStyle(color: fgSecondary, fontSize: 10.5),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    widget.message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: widget.message.isRead
                        ? AppColors.onPrimary.withValues(alpha: 0.9)
                        : AppColors.onPrimary.withValues(alpha: 0.4),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const _PdfViewerScreen({required this.filePath, required this.fileName});

  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainer,
        title: Text(
          widget.fileName,
          style: TextStyle(color: AppColors.onSurface, fontSize: 15, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: IconThemeData(color: AppColors.onSurface),
        elevation: 0,
      ),
      body: PDFView(
        filePath: widget.filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: false,
        pageFling: false,
        onError: (e) => debugPrint('PDF error: $e'),
      ),
    );
  }
}
