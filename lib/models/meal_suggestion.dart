/// One complete AI-suggested meal — mirrors the JSON returned by the
/// stateless `suggest-meal` Edge Function (OpenRouter; the server validates
/// ids against the foods catalog and recomputes every total itself, so the
/// numbers here are catalog-derived, never model-claimed).
class MealSuggestion {
  final List<MealSuggestionItem> items;
  final String explanationEn;
  final String explanationAr;
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  const MealSuggestion({
    required this.items,
    required this.explanationEn,
    required this.explanationAr,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
  });

  factory MealSuggestion.fromJson(Map<String, dynamic> json) {
    return MealSuggestion(
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MealSuggestionItem.fromJson)
          .toList(),
      explanationEn: json['explanation_en']?.toString() ?? '',
      explanationAr: json['explanation_ar']?.toString() ?? '',
      totalCalories: (json['total_calories'] as num?)?.toInt() ?? 0,
      totalProtein: (json['total_protein'] as num?)?.toDouble() ?? 0,
      totalCarbs: (json['total_carbs'] as num?)?.toDouble() ?? 0,
      totalFat: (json['total_fat'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MealSuggestionItem {
  final String foodId;
  final String name;
  final String? nameAr;

  /// foods.category — drives the dot color in the suggestion card.
  final String category;

  /// Catalog photo (food-images bucket) for the result row thumbnail.
  final String? imageUrl;

  /// In SERVINGS of the catalog row (1.0 = one listed serving).
  final double quantityMultiplier;
  final double? servingSize;
  final String? servingUnit;

  /// Already scaled by [quantityMultiplier] server-side.
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const MealSuggestionItem({
    required this.foodId,
    required this.name,
    required this.category,
    required this.quantityMultiplier,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.nameAr,
    this.servingSize,
    this.servingUnit,
    this.imageUrl,
  });

  factory MealSuggestionItem.fromJson(Map<String, dynamic> json) {
    return MealSuggestionItem(
      foodId: json['food_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameAr: json['name_ar']?.toString(),
      category: json['category']?.toString() ?? 'other',
      imageUrl: json['image_url']?.toString(),
      quantityMultiplier: (json['quantity_multiplier'] as num?)?.toDouble() ?? 1,
      servingSize: (json['serving_size'] as num?)?.toDouble(),
      servingUnit: json['serving_unit']?.toString(),
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
    );
  }
}
