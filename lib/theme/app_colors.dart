import 'package:flutter/material.dart';

/// Kalee-Inspired Energetic & Youthful Fitness Design System Colors
class AppColors {
  AppColors._();

  // ── Primary Brand Green ──
  static const Color primary = Color(0xFF18A957);
  static const Color primaryGreen = Color(0xFF18A957);
  static const Color secondaryGreen = Color(0xFF20B15A);
  static const Color lightGreen = Color(0xFFE8F7EE);
  static const Color primaryFixed = Color(0xFF18A957);
  static const Color primaryDim = Color(0xFF20B15A);
  static const Color primaryContainer = Color(0xFFE8F7EE);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF0D5F31);

  // ── Canvas / Background (Light & Crisp) ──
  static const Color background = Color(0xFFF7F9F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F3);
  static const Color surfaceContainerLow = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFF3F6F4);
  static const Color surfaceContainerHighest = Color(0xFFE5EBE7);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceLowest = Color(0xFFF7F9F8);

  // ── Text & Content Hierarchy ──
  static const Color textPrimary = Color(0xFF151515);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color onSurface = Color(0xFF151515);
  static const Color onSurfaceVariant = Color(0xFF6B7280);
  static const Color onBackground = Color(0xFF151515);

  // ── Outlines & Borders ──
  static const Color borderSubtle = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF0F2F1);
  static const Color outline = Color(0xFFE5E7EB);
  static const Color outlineVariant = Color(0xFFD1D5DB);

  // ── Nutrition & Fitness Data Accents ──
  static const Color accentCalories = Color(0xFFFF8A00); // Calories (Pixel Fire)
  static const Color accentProtein = Color(0xFFEF4444);  // Protein (Pixel Meat)
  static const Color accentCarbs = Color(0xFF3B82F6);    // Carbs (Pixel Grain)
  static const Color accentFat = Color(0xFF22A06B);      // Fat (Pixel Avocado)
  static const Color accentWater = Color(0xFF38BDF8);    // Water (Pixel Droplet)
  static const Color accentSteps = Color(0xFF8B5CF6);    // Steps (Pixel Sneaker)
  static const Color accentWorkout = Color(0xFFF97316);  // Workout (Pixel Dumbbell)

  // ── Semantic Aliases & Backward Compatibility ──
  static const Color secondary = Color(0xFF38BDF8);
  static const Color secondaryFixed = Color(0xFF38BDF8);
  static const Color secondaryDim = Color(0xFF0284C7);
  static const Color tertiary = Color(0xFFF59E0B);
  static const Color tertiaryFixed = Color(0xFFF59E0B);
  static const Color tertiaryDim = Color(0xFFD97706);
  static const Color tertiaryContainer = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorDim = Color(0xFFDC2626);

  // ── Glow & Soft Shadow System ──
  static Color primaryGlow = const Color(0xFF18A957).withValues(alpha: 0.15);
  static Color secondaryGlow = const Color(0xFF38BDF8).withValues(alpha: 0.12);
  static Color errorGlow = const Color(0xFFEF4444).withValues(alpha: 0.12);
  static Color cardShadow = const Color(0xFF000000).withValues(alpha: 0.04);
  static Color glowOrbPrimary = const Color(0xFF18A957).withValues(alpha: 0.12);
  static Color glowOrbSecondary = const Color(0xFF38BDF8).withValues(alpha: 0.10);

  // ── Glass Compatibility Tokens ──
  static const Color glass1 = Color(0x0AFFFFFF);
  static const Color glass2 = Color(0x14FFFFFF);
  static const Color glass3 = Color(0x1FFFFFFF);
  static const Color glassBorder = Color(0x14FFFFFF);
  static const Color glassBorderActive = Color(0x4D18A957);

  // ── Legacy Compatibility ──
  static const Color redAccent = Color(0xFFEF4444);
  static const Color orangeAccent = Color(0xFFFF8A00);
  static const Color greenAccent = Color(0xFF18A957);
  static const Color purpleAccent = Color(0xFF8B5CF6);

  // ── Muscle Group & Action Gradients ──
  static const LinearGradient primaryActionGradient = LinearGradient(
    colors: [Color(0xFF18A957), Color(0xFF20B15A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient chestGradient = LinearGradient(
    colors: [Color(0xFFFF8A00), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient armsGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient legsGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient coreGradient = LinearGradient(
    colors: [Color(0xFF18A957), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Dark Mode Palette ──
  static const Color darkBackground = Color(0xFF101412);
  static const Color darkSurface = Color(0xFF171C19);
  static const Color darkSurfaceCard = Color(0xFF1F2622);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkBorder = Color(0xFF26322B);
}
