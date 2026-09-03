import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Kinetic Obsidian — Semantic Color Mappings
///
/// Single source of truth for muscle-group, difficulty-level and training-goal
/// accent colors. These used to be duplicated (with diverging hex values) across
/// the workout tabs; every screen must read from here so the same concept is
/// always the same color app-wide.
class AppSemanticColors {
  AppSemanticColors._();

  /// Per-muscle-group accents. Anchored to the AppColors muscle gradients:
  /// chest red, arms teal, legs purple, core pink; back shares the purple
  /// family, shoulders take the cyan electric, full body takes the volt.
  /// Getters (not consts) so the volt entries follow the active theme mode.
  static Map<String, Color> get muscle => {
    'Chest': const Color(0xFFFF6B6B), // chestGradient start
    'Back': const Color(0xFFA29BFE), // purple family (legsGradient end)
    'Shoulders': const Color(0xFF00EEFC), // secondary — cyan electric
    'Arms': const Color(0xFF4ECDC4), // armsGradient start
    'Legs': const Color(0xFF6C5CE7), // legsGradient start
    'Core': const Color(0xFFFD79A8), // coreGradient start
    'Full Body': AppColors.primary, // Electric Volt
  };

  /// Difficulty ramp — cool → warm, mirroring the semantic status ramp
  /// (info cyan → warning gold → error coral). Deliberately NOT volt, so the
  /// volt stays reserved for primary actions.
  static Map<String, Color> get level => {
    'beginner': const Color(0xFF00EEFC),
    'intermediate': const Color(0xFFFCDC43),
    'advanced': const Color(0xFFFF7351),
    'All': AppColors.primary,
  };

  /// Training-goal accents.
  static Map<String, Color> get goal => {
    'strength': const Color(0xFFFF8A00),
    'muscle gain': const Color(0xFF6C5CE7),
    'weight loss': const Color(0xFF00EEFC),
    'All': AppColors.primary,
  };

  /// Safe lookup with volt fallback for unmapped labels.
  static Color forMuscle(String key) =>
      muscle[key] ?? muscle['Full Body']!;
  static Color forLevel(String key) => level[key.toLowerCase()] ?? AppColors.primary;
  static Color forGoal(String key) => goal[key.toLowerCase()] ?? AppColors.primary;
}
