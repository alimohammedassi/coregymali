/// Result of an AI voice food log — mirrors the two-table shape returned by
/// the `log-food-voice` Edge Function (`voice_food_logs` + `voice_food_log_items` rows).
class VoiceFoodLogResult {
  final String logId;
  final String audioPath;
  final String? transcript;
  final bool isFood;
  final VoiceLogConfidence confidence;
  final String? notes;
  final List<VoiceFoodLogItem> items;

  const VoiceFoodLogResult({
    required this.logId,
    required this.audioPath,
    this.transcript,
    required this.isFood,
    required this.confidence,
    this.notes,
    required this.items,
  });

  factory VoiceFoodLogResult.fromJson(Map<String, dynamic> json) {
    return VoiceFoodLogResult(
      logId: (json['log_id'] ?? '').toString(),
      audioPath: (json['audio_path'] ?? '').toString(),
      transcript: json['transcript']?.toString(),
      isFood: json['is_food'] == true,
      confidence: voiceLogConfidenceFromString(json['confidence']?.toString()),
      notes: json['notes']?.toString(),
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VoiceFoodLogItem.fromJson)
          .toList(),
    );
  }

  double get totalCalories => items.fold(0, (s, i) => s + i.calories);
  double get totalProteinG => items.fold(0, (s, i) => s + i.proteinG);
  double get totalCarbsG => items.fold(0, (s, i) => s + i.carbsG);
  double get totalFatG => items.fold(0, (s, i) => s + i.fatG);
}

class VoiceFoodLogItem {
  /// Real `voice_food_log_items.id` from the DB — needed to write
  /// `nutrition_log_id` back onto the exact row after saving.
  final String id;
  final String name;
  final String? nameAr;
  final double estimatedWeightG;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const VoiceFoodLogItem({
    required this.id,
    required this.name,
    this.nameAr,
    required this.estimatedWeightG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory VoiceFoodLogItem.fromJson(Map<String, dynamic> json) {
    return VoiceFoodLogItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameAr: json['name_ar']?.toString(),
      estimatedWeightG: _num(json['estimated_weight_g']),
      calories: _num(json['calories']),
      proteinG: _num(json['protein_g']),
      carbsG: _num(json['carbs_g']),
      fatG: _num(json['fat_g']),
    );
  }
}

VoiceLogConfidence voiceLogConfidenceFromString(String? value) {
  switch (value) {
    case 'low':
      return VoiceLogConfidence.low;
    case 'high':
      return VoiceLogConfidence.high;
    default:
      return VoiceLogConfidence.medium;
  }
}

enum VoiceLogConfidence { low, medium, high }

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

// ── Errors ───────────────────────────────────────────────────────────────────

enum VoiceLogErrorType {
  network,
  unauthorized,
  microphone,
  notFood,
  analysisFailed,
  serverError,
  unknown,
}

class VoiceLogException implements Exception {
  final VoiceLogErrorType type;
  final String message;

  const VoiceLogException(this.type, this.message);

  factory VoiceLogException.fromType(VoiceLogErrorType type) =>
      VoiceLogException(type, _messageFor(type));

  static const Map<VoiceLogErrorType, String> _defaultMessages = {
    VoiceLogErrorType.network:
        'No internet connection. Check your network and try again.',
    VoiceLogErrorType.unauthorized:
        'Please sign in first to use the voice logger.',
    VoiceLogErrorType.microphone:
        'Microphone access is needed to record your meal. Enable it in Settings.',
    VoiceLogErrorType.notFood:
        "We couldn't hear any food in that recording. Try describing your meal again.",
    VoiceLogErrorType.analysisFailed:
        "We couldn't understand that recording. Please try again.",
    VoiceLogErrorType.serverError:
        'The recording was analyzed but saving failed. Please try again.',
    VoiceLogErrorType.unknown:
        'Something unexpected went wrong. Please try again.',
  };

  static String _messageFor(VoiceLogErrorType type) =>
      _defaultMessages[type] ?? _defaultMessages[VoiceLogErrorType.unknown]!;
}
