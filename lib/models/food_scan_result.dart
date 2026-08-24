/// Result of an AI food scan — mirrors the two-table shape returned by the
/// `analyze-food` Edge Function (`food_scans` + `food_scan_items` rows).
class FoodScanResult {
  final String scanId;
  final bool isFood;
  final FoodScanConfidence confidence;
  final String? notes;
  final List<FoodScanItem> items;

  const FoodScanResult({
    required this.scanId,
    required this.isFood,
    required this.confidence,
    this.notes,
    required this.items,
  });

  factory FoodScanResult.fromJson(Map<String, dynamic> json) {
    return FoodScanResult(
      scanId: (json['scan_id'] ?? '').toString(),
      isFood: json['is_food'] == true,
      confidence: foodScanConfidenceFromString(json['confidence']?.toString()),
      notes: json['notes']?.toString(),
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FoodScanItem.fromJson)
          .toList(),
    );
  }

  double get totalCalories => items.fold(0, (s, i) => s + i.calories);
  double get totalProteinG => items.fold(0, (s, i) => s + i.proteinG);
  double get totalCarbsG => items.fold(0, (s, i) => s + i.carbsG);
  double get totalFatG => items.fold(0, (s, i) => s + i.fatG);
}

class FoodScanItem {
  /// Real `food_scan_items.id` from the DB — needed to write
  /// `nutrition_log_id` back onto the exact row after saving.
  final String id;
  final String name;
  final String? nameAr;
  final double estimatedWeightG;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const FoodScanItem({
    required this.id,
    required this.name,
    this.nameAr,
    required this.estimatedWeightG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory FoodScanItem.fromJson(Map<String, dynamic> json) {
    return FoodScanItem(
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

FoodScanConfidence foodScanConfidenceFromString(String? value) {
  switch (value) {
    case 'low':
      return FoodScanConfidence.low;
    case 'high':
      return FoodScanConfidence.high;
    default:
      return FoodScanConfidence.medium;
  }
}

enum FoodScanConfidence { low, medium, high }

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

// ── Errors ───────────────────────────────────────────────────────────────────

enum FoodScanErrorType {
  network,
  unauthorized,
  notFood,
  analysisFailed,
  serverError,
  unknown,
}

class FoodScanException implements Exception {
  final FoodScanErrorType type;
  final String message;

  const FoodScanException(this.type, this.message);

  factory FoodScanException.fromType(FoodScanErrorType type) =>
      FoodScanException(type, _messageFor(type));

  static const Map<FoodScanErrorType, String> _defaultMessages = {
    FoodScanErrorType.network: 'No internet connection. Check your network and try again.',
    FoodScanErrorType.unauthorized: 'Please sign in first to use the scanner.',
    FoodScanErrorType.notFood: 'No clear food in the photo. Try another angle.',
    FoodScanErrorType.analysisFailed: "We couldn't analyze the photo. Please try again.",
    FoodScanErrorType.serverError: 'The photo was analyzed but saving failed. Please try again.',
    FoodScanErrorType.unknown: 'Something unexpected went wrong. Please try again.',
  };

  static String _messageFor(FoodScanErrorType type) =>
      _defaultMessages[type] ?? _defaultMessages[FoodScanErrorType.unknown]!;
}
