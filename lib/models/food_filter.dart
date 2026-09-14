/// Filter set for the food library browse/search.
///
/// Every dimension combines with AND logic server-side: NutritionService
/// builds one PostgREST query from this filter (`.eq` for category, `.gte` /
/// `.lte` for macro ranges), so a food only shows up when it matches ALL of
/// the active dimensions together with the search term.
class FoodFilter {
  /// DB category value, or 'all' for no category constraint.
  final String category;

  /// Open-ended below/above when null.
  final double? minCalories;
  final double? maxCalories;
  final double? minProtein;
  final double? maxProtein;

  /// Inclusive upper bounds of the filter sheet sliders. Selecting the full
  /// range means "no constraint" (the bound is stored as null), so foods
  /// above the slider max (e.g. a 900 kcal milkshake) still show up.
  static const double calorieSliderMax = 800;
  static const double proteinSliderMax = 60;

  const FoodFilter({
    this.category = 'all',
    this.minCalories,
    this.maxCalories,
    this.minProtein,
    this.maxProtein,
  });

  /// True when any dimension is constraining the result set.
  bool get hasActiveFilters =>
      category.toLowerCase() != 'all' ||
      hasCalorieRange ||
      hasProteinRange;

  bool get hasCalorieRange => minCalories != null || maxCalories != null;
  bool get hasProteinRange => minProtein != null || maxProtein != null;

  /// Number of ACTIVE macro-range dimensions (for the filter badge).
  int get macroRangeCount =>
      (hasCalorieRange ? 1 : 0) + (hasProteinRange ? 1 : 0);

  FoodFilter copyWith({
    String? category,
    double? minCalories,
    double? maxCalories,
    double? minProtein,
    double? maxProtein,
  }) {
    return FoodFilter(
      category: category ?? this.category,
      minCalories: minCalories ?? this.minCalories,
      maxCalories: maxCalories ?? this.maxCalories,
      minProtein: minProtein ?? this.minProtein,
      maxProtein: maxProtein ?? this.maxProtein,
    );
  }
}
