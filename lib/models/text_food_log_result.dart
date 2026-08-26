/// Result of an AI text food log — mirrors the JSON shape returned by the
/// stateless `log-food-text` Edge Function (no persistence server-side).
class TextFoodLogResult {
  final bool isFood;
  final TextLogConfidence confidence;
  final String? notes;
  final List<TextFoodLogItem> items;

  const TextFoodLogResult({
    required this.isFood,
    required this.confidence,
    this.notes,
    required this.items,
  });

  factory TextFoodLogResult.fromJson(Map<String, dynamic> json) {
    return TextFoodLogResult(
      isFood: json['is_food'] == true,
      confidence: textLogConfidenceFromString(json['confidence']?.toString()),
      notes: json['notes']?.toString(),
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TextFoodLogItem.fromJson)
          .toList(),
    );
  }
}

class TextFoodLogItem {
  final String name;
  final String? nameAr;

  /// Portion weight the AI based its [calories]/macro estimates on.
  final double estimatedWeightG;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const TextFoodLogItem({
    required this.name,
    this.nameAr,
    required this.estimatedWeightG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory TextFoodLogItem.fromJson(Map<String, dynamic> json) {
    return TextFoodLogItem(
      name: (json['name'] ?? '').toString(),
      nameAr: json['name_ar']?.toString(),
      estimatedWeightG: _num(json['estimated_weight_g']),
      calories: _num(json['calories']),
      proteinG: _num(json['protein_g']),
      carbsG: _num(json['carbs_g']),
      fatG: _num(json['fat_g']),
    );
  }

  /// Macros are estimated for [estimatedWeightG]; scale proportionally when
  /// the user edits the portion (same idea as BarcodeProductResult.caloriesFor
  /// but relative to the item's own base weight).
  double _scale(double weightG) =>
      estimatedWeightG <= 0 ? 1 : weightG / estimatedWeightG;

  double caloriesFor(double weightG) => calories * _scale(weightG);
  double proteinFor(double weightG) => proteinG * _scale(weightG);
  double carbsFor(double weightG) => carbsG * _scale(weightG);
  double fatFor(double weightG) => fatG * _scale(weightG);
}

TextLogConfidence textLogConfidenceFromString(String? value) {
  switch (value) {
    case 'low':
      return TextLogConfidence.low;
    case 'high':
      return TextLogConfidence.high;
    default:
      return TextLogConfidence.medium;
  }
}

enum TextLogConfidence { low, medium, high }

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

// ── Errors ───────────────────────────────────────────────────────────────────

enum TextLogErrorType {
  network,
  unauthorized,
  notFood,
  analysisFailed,
  serverError,
  unknown,
}

class TextLogException implements Exception {
  final TextLogErrorType type;
  final String message;

  const TextLogException(this.type, this.message);

  factory TextLogException.fromType(TextLogErrorType type) =>
      TextLogException(type, _messageFor(type));

  static const Map<TextLogErrorType, String> _defaultMessages = {
    TextLogErrorType.network:
        'No internet connection. Check your network and try again.',
    TextLogErrorType.unauthorized:
        'Please sign in first to use the text logger.',
    TextLogErrorType.notFood:
        "We couldn't find any food in that text. Try describing your meal again.",
    TextLogErrorType.analysisFailed:
        "We couldn't understand that description. Please try again.",
    TextLogErrorType.serverError:
        'The meal was analyzed but saving failed. Please try again.',
    TextLogErrorType.unknown:
        'Something unexpected went wrong. Please try again.',
  };

  static String _messageFor(TextLogErrorType type) =>
      _defaultMessages[type] ?? _defaultMessages[TextLogErrorType.unknown]!;
}
