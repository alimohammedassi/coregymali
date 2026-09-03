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
  static const Map<String, Color> muscle = {
    'Chest': Color(0xFFFF6B6B), // chestGradient start
    'Back': Color(0xFFA29BFE), // purple family (legsGradient end)
    'Shoulders': Color(0xFF00EEFC), // secondary — cyan electric
    'Arms': Color(0xFF4ECDC4), // armsGradient start
    'Legs': Color(0xFF6C5CE7), // legsGradient start
    'Core': Color(0xFFFD79A8), // coreGradient start
    'Full Body': AppColors.primary, // Electric Volt
  };

  /// Difficulty ramp — cool → warm, mirroring the semantic status ramp
  /// (info cyan → warning gold → error coral). Deliberately NOT volt, so the
  /// volt stays reserved for primary actions.
  static const Map<String, Color> level = {
    'beginner': Color(0xFF00EEFC),
    'intermediate': Color(0xFFFCDC43),
    'advanced': Color(0xFFFF7351),
    'All': AppColors.primary,
  };

  /// Training-goal accents.
  static const Map<String, Color> goal = {
    'strength': Color(0xFFFF8A00),
    'muscle gain': Color(0xFF6C5CE7),
    'weight loss': Color(0xFF00EEFC),
    'All': AppColors.primary,
  };

  /// Safe lookup with volt fallback for unmapped labels.
  static Color forMuscle(String key) =>
      muscle[key] ?? muscle['Full Body']!;
  static Color forLevel(String key) => level[key.toLowerCase()] ?? AppColors.primary;
  static Color forGoal(String key) => goal[key.toLowerCase()] ?? AppColors.primary;
}
