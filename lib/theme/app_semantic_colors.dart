import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Graphite & Soft Volt — Semantic Color Mappings
///
/// Single source of truth for muscle-group, difficulty-level and training-goal
/// accent colors. These used to be duplicated (with diverging hex values) across
/// the workout tabs; every screen must read from here so the same concept is
/// always the same color app-wide.
class AppSemanticColors {
  AppSemanticColors._();

  /// Per-muscle-group accents. Anchored to the AppColors muscle gradients:
  /// chest red, arms teal, legs purple, core pink; back shares the purple
  /// family, shoulders take the calm teal, full body takes the soft lime.
  /// Getters (not consts) so the lime entries follow the active theme mode.
  static Map<String, Color> get muscle => {
    'Chest': const Color(0xFFEA7A72), // chestGradient start
    'Back': const Color(0xFFA9A2F0), // purple family (legsGradient end)
    'Shoulders': const Color(0xFF4FD1C5), // secondary — calm teal
    'Arms': const Color(0xFF54C7BE), // armsGradient start
    'Legs': const Color(0xFF7E71E0), // legsGradient start
    'Core': const Color(0xFFE87FA2), // coreGradient start
    'Full Body': AppColors.primary, // Soft Volt
  };

  /// Difficulty ramp — cool → warm, mirroring the semantic status ramp
  /// (info teal → warning gold → error coral). Deliberately NOT the lime, so
  /// the primary stays reserved for primary actions.
  static Map<String, Color> get level => {
    'beginner': const Color(0xFF4FD1C5),
    'intermediate': const Color(0xFFE8C468),
    'advanced': const Color(0xFFEE7F60),
    'All': AppColors.primary,
  };

  /// Training-goal accents.
  static Map<String, Color> get goal => {
    'strength': const Color(0xFFF5A623),
    'muscle gain': const Color(0xFF7E71E0),
    'weight loss': const Color(0xFF4FD1C5),
    'All': AppColors.primary,
  };

  /// Food-category accents (foods.image_url fallback tiles, category chips).
  /// Data-viz colours — intentionally NOT mode-flipped, they read on both
  /// themes. Replaces three diverging hardcoded maps that used to live in
  /// add_food_sheet / food_logging_modal / nutrition_screen.
  static Map<String, Color> get foodCategory => {
    'protein': const Color(0xFFEA7A72),
    'carbs': const Color(0xFFE8C468),
    'vegetables': const Color(0xFF56B870),
    'fruits': const Color(0xFFE84393),
    'dairy': const Color(0xFF4A90D9),
    'fats': const Color(0xFF36B37E),
    'fastfood': const Color(0xFFEF8354),
    'drinks': const Color(0xFF6C5CE7),
    'arabic': const Color(0xFFC97B3D),
    'breakfast': const Color(0xFFF5A623),
    'desserts': const Color(0xFFE0568C),
    'street_food': const Color(0xFFD98E32),
    'snacks': const Color(0xFFB8860B),
    'burgers': const Color(0xFFA0522D),
    'sushi': const Color(0xFF2BBCD4),
    'pasta': const Color(0xFFD2691E),
    'sandwiches': const Color(0xFF9ACD32),
    'pizza': const Color(0xFFD64545),
    'fried_chicken': const Color(0xFFE67E22),
    'other': AppColors.primary,
  };

  /// Safe lookup with lime fallback for unmapped labels.
  static Color forMuscle(String key) =>
      muscle[key] ?? muscle['Full Body']!;
  static Color forLevel(String key) => level[key.toLowerCase()] ?? AppColors.primary;
  static Color forGoal(String key) => goal[key.toLowerCase()] ?? AppColors.primary;
  static Color forFoodCategory(String key) =>
      foodCategory[key.toLowerCase()] ?? AppColors.primary;
}
