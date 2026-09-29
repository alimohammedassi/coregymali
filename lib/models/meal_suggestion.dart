/// One complete AI-suggested meal — mirrors the JSON returned by the
/// stateless `suggest-meal` Edge Function (OpenRouter; the server validates
/// ids against the foods catalog and recomputes every total itself, so the
/// numbers here are catalog-derived, never model-claimed).
class MealSuggestion {
  final List<MealSuggestionItem> items;
  final String explanationEn;
  final String explanationAr;

  /// The AI's name for the composed dish ("Chicken Shawarma Plate" /
  /// "ساندوتش شاورما فراخ") — the result header shows it so the suggestion
  /// reads like a real meal, not a list of ingredients. Null = unnamed.
  final String? dishNameEn;
  final String? dishNameAr;
  final int totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  /// Micro-nutrient totals (already summed server-side from the catalog).
  /// Null/0 = catalog had no values — the result card hides empty pills.
  final double? totalFiber;
  final double? totalSugars;
  final double? totalSodium;

  const MealSuggestion({
    required this.items,
    required this.explanationEn,
    required this.explanationAr,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    this.dishNameEn,
    this.dishNameAr,
    this.totalFiber,
    this.totalSugars,
    this.totalSodium,
  });

  factory MealSuggestion.fromJson(Map<String, dynamic> json) {
    double? opt(dynamic v) => v is num ? v.toDouble() : null;
    return MealSuggestion(
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MealSuggestionItem.fromJson)
          .toList(),
      explanationEn: json['explanation_en']?.toString() ?? '',
      explanationAr: json['explanation_ar']?.toString() ?? '',
      dishNameEn: (json['dish_name_en'] as String?)?.trim(),
      dishNameAr: (json['dish_name_ar'] as String?)?.trim(),
      totalCalories: (json['total_calories'] as num?)?.toInt() ?? 0,
      totalProtein: (json['total_protein'] as num?)?.toDouble() ?? 0,
      totalCarbs: (json['total_carbs'] as num?)?.toDouble() ?? 0,
      totalFat: (json['total_fat'] as num?)?.toDouble() ?? 0,
      totalFiber: opt(json['total_fiber_g']),
      totalSugars: opt(json['total_sugars_g']),
      totalSodium: opt(json['total_sodium_mg']),
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

  /// Micro-nutrients, also scaled by [quantityMultiplier] server-side.
  /// Null = the catalog row has no value (unknown), never 0 — they ride into
  /// the log as SQL NULL exactly like every other logging path.
  final double? fiberG;
  final double? sugarsG;
  final double? sodiumMg;
  final double? potassiumMg;
  final double? calciumMg;
  final double? ironMg;
  final double? cholesterolMg;
  final double? caffeineMg;

  const MealSuggestionItem({
    required this.foodId,
    required this.name,
    required this.category,
    required this.quantityMultiplier,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fiberG,
    this.sugarsG,
    this.sodiumMg,
    this.potassiumMg,
    this.calciumMg,
    this.ironMg,
    this.cholesterolMg,
    this.caffeineMg,
    this.nameAr,
    this.servingSize,
    this.servingUnit,
    this.imageUrl,
  });

  factory MealSuggestionItem.fromJson(Map<String, dynamic> json) {
    double? opt(dynamic v) => v is num ? v.toDouble() : null;
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
      fiberG: opt(json['fiber_g']),
      sugarsG: opt(json['sugars_g']),
      sodiumMg: opt(json['sodium_mg']),
      potassiumMg: opt(json['potassium_mg']),
      calciumMg: opt(json['calcium_mg']),
      ironMg: opt(json['iron_mg']),
      cholesterolMg: opt(json['cholesterol_mg']),
      caffeineMg: opt(json['caffeine_mg']),
    );
  }
}
