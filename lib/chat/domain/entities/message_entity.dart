class MessageEntity {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String type; // 'text', 'image', 'file'
  final String? fileUrl;
  final bool isRead;
  final bool isDeleted;
  final DateTime createdAt;

  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.type,
    this.fileUrl,
    required this.isRead,
    required this.isDeleted,
    required this.createdAt,
  });

  bool get isTextMessage => type == 'text';
  bool get isImageMessage => type == 'image';
  bool get isFileMessage => type == 'file';
  bool get isVoiceMessage => type == 'voice';

  /// For voice messages, content holds duration in seconds as string (e.g. "12").
  /// Returns parsed duration or 0 if invalid.
  int get voiceDurationSeconds {
    if (!isVoiceMessage) return 0;
    return int.tryParse(content) ?? 0;
  }

  /// For file messages, content is JSON {"name":"...","size":123}. Fallback to raw content.
  String get fileName {
    if (!isFileMessage) return '';
    try {
      if (content.trim().startsWith('{')) {
        final m = RegExp(r'"name"\s*:\s*"([^"]+)"').firstMatch(content);
        if (m != null) return m.group(1)!;
      }
    } catch (_) {}
    return content;
  }

  int get fileSize {
    if (!isFileMessage) return 0;
    try {
      if (content.trim().startsWith('{')) {
        final m = RegExp(r'"size"\s*:\s*(\d+)').firstMatch(content);
        if (m != null) return int.tryParse(m.group(1)!) ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  String get fileSizeFormatted {
    final s = fileSize;
    if (s <= 0) return '';
    if (s < 1024) return '$s B';
    if (s < 1024 * 1024) return '${(s / 1024).toStringAsFixed(1)} KB';
    return '${(s / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
