/// Result of a barcode product lookup — mirrors the shape returned by the
/// `lookup-barcode` Edge Function (a row from the shared `barcode_products`
/// cache, Open Food Facts, or a Gemini estimate).
class BarcodeProductResult {
  final String barcode;
  final String productName;
  final String? productNameAr;
  final String? brand;
  final double servingSizeG;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  /// `cache` | `openfoodfacts` | `gemini_estimate` | `manual` — lets the UI
  /// distinguish verified data from AI estimates.
  final String source;
  final BarcodeConfidence confidence;
  final bool needsNameHint;

  const BarcodeProductResult({
    required this.barcode,
    required this.productName,
    this.productNameAr,
    this.brand,
    required this.servingSizeG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.source = 'openfoodfacts',
    this.confidence = BarcodeConfidence.high,
    this.needsNameHint = false,
  });

  factory BarcodeProductResult.fromJson(Map<String, dynamic> json) {
    return BarcodeProductResult(
      barcode: (json['barcode'] ?? '').toString(),
      productName: (json['product_name'] ?? '').toString(),
      productNameAr: json['product_name_ar']?.toString(),
      brand: json['brand']?.toString(),
      servingSizeG: _num(json['serving_size_g'], orElse: 100),
      calories: _num(json['calories']),
      proteinG: _num(json['protein_g']),
      carbsG: _num(json['carbs_g']),
      fatG: _num(json['fat_g']),
      source: (json['source'] ?? 'openfoodfacts').toString(),
      confidence: barcodeConfidenceFromString(json['confidence']?.toString()),
      needsNameHint: json['needs_name_hint'] == true,
    );
  }

  bool get isEstimate => source == 'gemini_estimate';

  /// Macros scaled proportionally to [quantityG] (per-100g base data).
  double caloriesFor(double quantityG) => calories * quantityG / 100;
  double proteinFor(double quantityG) => proteinG * quantityG / 100;
  double carbsFor(double quantityG) => carbsG * quantityG / 100;
  double fatFor(double quantityG) => fatG * quantityG / 100;
}

BarcodeConfidence barcodeConfidenceFromString(String? value) {
  switch (value) {
    case 'low':
      return BarcodeConfidence.low;
    case 'high':
      return BarcodeConfidence.high;
    default:
      return BarcodeConfidence.medium;
  }
}

enum BarcodeConfidence { low, medium, high }

double _num(dynamic v, {double orElse = 0}) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? orElse;
}

// ── Errors ───────────────────────────────────────────────────────────────────

enum BarcodeLookupErrorType {
  network,
  unauthorized,
  invalidRequest,
  upstreamUnreachable,
  analysisFailed,
  serverError,
  unknown,
}

class BarcodeLookupException implements Exception {
  final BarcodeLookupErrorType type;
  final String message;

  const BarcodeLookupException(this.type, this.message);

  factory BarcodeLookupException.fromType(BarcodeLookupErrorType type) =>
      BarcodeLookupException(type, _messageFor(type));

  static const Map<BarcodeLookupErrorType, String> _defaultMessages = {
    BarcodeLookupErrorType.network:
        'No internet connection. Check your network and try again.',
    BarcodeLookupErrorType.unauthorized:
        'Please sign in first to use the scanner.',
    BarcodeLookupErrorType.invalidRequest:
        'That barcode does not look valid. Try scanning again.',
    BarcodeLookupErrorType.upstreamUnreachable:
        "The product database is unreachable right now. Please try again.",
    BarcodeLookupErrorType.analysisFailed:
        "We couldn't identify that product. Please try again.",
    BarcodeLookupErrorType.serverError:
        'Something went wrong on our side. Please try again.',
    BarcodeLookupErrorType.unknown:
        'Something unexpected went wrong. Please try again.',
  };

  static String _messageFor(BarcodeLookupErrorType type) =>
      _defaultMessages[type] ?? _defaultMessages[BarcodeLookupErrorType.unknown]!;
}
