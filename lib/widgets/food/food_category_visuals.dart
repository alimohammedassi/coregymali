import 'package:flutter/material.dart';

import '../../theme/app_semantic_colors.dart';

/// Single source of truth for the food category vocabulary used by the
/// browse/filter UI: the DB `category` value plus its emoji. Colours live in
/// AppSemanticColors.foodCategory (semantic layer, like muscle/level/goal).
class FoodCategoryVisuals {
  final String db;
  final String emoji;

  const FoodCategoryVisuals._(this.db, this.emoji);

  /// All known categories, in filter-row display order (most-used first).
  /// If the DB gains a category that isn't listed here, FoodCategoryChips
  /// still renders it via [forDb]'s fallback plate.
  static const List<FoodCategoryVisuals> all = [
    FoodCategoryVisuals._('all', '🍽'),
    FoodCategoryVisuals._('arabic', '🧆'),
    FoodCategoryVisuals._('protein', '🍗'),
    FoodCategoryVisuals._('carbs', '🍚'),
    FoodCategoryVisuals._('vegetables', '🥦'),
    FoodCategoryVisuals._('fruits', '🍎'),
    FoodCategoryVisuals._('dairy', '🧀'),
    FoodCategoryVisuals._('fats', '🥑'),
    FoodCategoryVisuals._('fastfood', '🍔'),
    FoodCategoryVisuals._('drinks', '🥤'),
    FoodCategoryVisuals._('snacks', '🍿'),
    FoodCategoryVisuals._('desserts', '🍰'),
    FoodCategoryVisuals._('street_food', '🌯'),
    FoodCategoryVisuals._('burgers', '🍔'),
    FoodCategoryVisuals._('pizza', '🍕'),
    FoodCategoryVisuals._('pasta', '🍝'),
    FoodCategoryVisuals._('sandwiches', '🥪'),
    FoodCategoryVisuals._('sushi', '🍣'),
    FoodCategoryVisuals._('fried_chicken', '🍗'),
    FoodCategoryVisuals._('breakfast', '🍳'),
    FoodCategoryVisuals._('other', '🍽'),
  ];

  static const FoodCategoryVisuals _fallback = FoodCategoryVisuals._('', '🍽');

  /// Lookup by DB value; unknown categories keep their key so chips can still
  /// be built for them (generic plate emoji, lime accent), but render with
  /// the generic plate emoji.
  static FoodCategoryVisuals forDb(String? db) {
    final key = (db ?? '').toLowerCase().trim();
    for (final v in all) {
      if (v.db == key) return v;
    }
    return FoodCategoryVisuals._(key, _fallback.emoji);
  }

  Color get color =>
      AppSemanticColors.forFoodCategory(db.isEmpty ? 'other' : db);
}
