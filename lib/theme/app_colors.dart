import 'package:flutter/material.dart';

/// Kinetic Obsidian — Electric Volt Design System Colors
///
/// Single source of truth. Premium near-black surface hierarchy
/// (#000000 → #2C2C2C) with an Electric Volt (#D1FC00) primary accent,
/// cyan/gold secondaries, and per-muscle-group gradients.
///
/// NOTE: token NAMES are the stable API consumed across the app; token VALUES
/// were briefly swapped to a light "Kalee" palette and have been restored to
/// the canonical obsidian system. Do not re-point these at light-theme values —
/// glass surfaces, auth typography (AuthAppText) and the glow backgrounds all
/// assume a dark canvas.
class AppColors {
  AppColors._();

  // ── Surface Hierarchy (darkest → brightest) ──
  static const Color background = Color(0xFF000000);
  static const Color surfaceLowest = Color(0xFF000000);
  static const Color surface = Color(0xFF0E0E0E);
  static const Color surfaceDim = Color(0xFF0E0E0E);
  static const Color surfaceContainerLow = Color(0xFF131313);
  static const Color surfaceContainer = Color(0xFF1A1919);
  static const Color surfaceContainerHigh = Color(0xFF201F1F);
  static const Color surfaceContainerHighest = Color(0xFF262626);
  static const Color surfaceBright = Color(0xFF2C2C2C);

  // ── Primary — Electric Volt ──
  static const Color primary = Color(0xFFD1FC00);
  static const Color primaryGreen = Color(0xFFD1FC00); // legacy name → volt
  static const Color secondaryGreen = Color(0xFFC7EF00); // legacy name → volt dim
  static const Color primaryFixed = Color(0xFFD1FC00);
  static const Color primaryDim = Color(0xFFC7EF00);
  static const Color primaryContainer = Color(0xFFD1FC00);
  static const Color onPrimary = Color(0xFF0A0A0A); // near-black ink on volt
  static const Color onPrimaryContainer = Color(0xFFD1FC00); // volt on volt-tinted glass
  /// Pale volt-tinted glass used for selected states / soft containers.
  static const Color lightGreen = Color(0x1AD1FC00); // 10% volt on obsidian

  // ── Secondary — Cyan Electric ──
  static const Color secondary = Color(0xFF00EEFC);
  static const Color secondaryFixed = Color(0xFF00EEFC);
  static const Color secondaryDim = Color(0xFF00DEEC);

  // ── Tertiary — Gold ──
  static const Color tertiary = Color(0xFFFCDC43);
  static const Color tertiaryFixed = Color(0xFFFCDC43);
  static const Color tertiaryDim = Color(0xFFEDCE35);
  static const Color tertiaryContainer = Color(0xFFFCDC43);

  // ── Error ──
  static const Color error = Color(0xFFFF7351);
  static const Color errorDim = Color(0xFFD53D18);

  // ── Text & Content Hierarchy ──
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFADAAAA);
  static const Color textMuted = Color(0xFF777575);
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color onSurfaceVariant = Color(0xFFADAAAA);
  static const Color onBackground = Color(0xFFFFFFFF);

  // ── Outlines & Borders ──
  static const Color borderSubtle = Color(0xFF2E2E2E);
  static const Color borderLight = Color(0x14FFFFFF);
  static const Color outline = Color(0xFF777575);
  static const Color outlineVariant = Color(0xFF494847);

  // ── Nutrition & Fitness Data Accents (data-viz semantics, dark-safe) ──
  static const Color accentCalories = Color(0xFFFF8A00); // Calories (Pixel Fire)
  static const Color accentProtein = Color(0xFFFF6B6B);  // Protein (Pixel Meat)
  static const Color accentCarbs = Color(0xFF3B82F6);    // Carbs (Pixel Grain)
  static const Color accentFat = Color(0xFF22A06B);      // Fat (Pixel Avocado)
  static const Color accentWater = Color(0xFF00EEFC);    // Water → cyan electric
  static const Color accentSteps = Color(0xFF6C5CE7);    // Steps → obsidian purple
  static const Color accentWorkout = Color(0xFFFF8A00);  // Workout (Pixel Dumbbell)

  // ── Semantic Aliases & Backward Compatibility ──
  static const Color redAccent = Color(0xFFFF6B6B);
  static const Color orangeAccent = Color(0xFFFF8A00);
  static const Color greenAccent = Color(0xFFD1FC00); // legacy name → volt
  static const Color purpleAccent = Color(0xFF6C5CE7);

  // ── Glow & Soft Shadow System ──
  static Color primaryGlow = const Color(0xFFD1FC00).withValues(alpha: 0.15);
  static Color secondaryGlow = const Color(0xFF00EEFC).withValues(alpha: 0.10);
  static Color errorGlow = const Color(0xFFFF7351).withValues(alpha: 0.10);
  static Color cardShadow = const Color(0xFF000000).withValues(alpha: 0.35);
  static Color glowOrbPrimary = const Color(0xFFD1FC00).withValues(alpha: 0.05);
  static Color glowOrbSecondary = const Color(0xFF00EEFC).withValues(alpha: 0.03);

  // ── Glass Compatibility Tokens ──
  static const Color glass1 = Color(0x0AFFFFFF); // 4% white
  static const Color glass2 = Color(0x14FFFFFF); // 8% white
  static const Color glass3 = Color(0x1FFFFFFF); // 12% white
  static const Color glassBorder = Color(0x14FFFFFF); // 8% white border
  static const Color glassBorderActive = Color(0x4DD1FC00); // 30% volt border

  // ── Muscle Group Gradients ──
  static const LinearGradient chestGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFEE5A52)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient armsGradient = LinearGradient(
    colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient legsGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient coreGradient = LinearGradient(
    colors: [Color(0xFFFD79A8), Color(0xFFE84393)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Primary Action Gradient ──
  static const LinearGradient primaryActionGradient = LinearGradient(
    colors: [Color(0xFFD1FC00), Color(0xFFC7EF00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Dark Mode Aliases (kept for call sites that name them explicitly) ──
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF0E0E0E);
  static const Color darkSurfaceCard = Color(0xFF1A1919);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFADAAAA);
  static const Color darkBorder = Color(0xFF2E2E2E);
}
