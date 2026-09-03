import 'package:flutter/material.dart';

/// Kinetic Obsidian — Electric Volt Design System Colors
///
/// Single source of truth. Premium near-black surface hierarchy
/// (#000000 → #2C2C2C) with an Electric Volt (#D1FC00) primary accent,
/// cyan/gold secondaries, and per-muscle-group gradients.
///
/// MODE-AWARE: every surface/text token resolves through [apply] to the
/// active brightness, so widgets can keep consuming `AppColors.x` statically
/// while the whole palette flips between the dark "Obsidian" identity and its
/// light sibling. Call [apply] before painting a new brightness (the app does
/// this in the MaterialApp builder) and key the widget tree on the resolved
/// brightness so a switch rebuilds everything.
///
/// Token API notes:
/// - `primary` is the ACCENT (icons/text/selected borders). It stays volt on
///   dark but darkens to a legible olive-volt on light surfaces.
/// - `primaryFixed` / `primaryGreen` are the FILL volt (#D1FC00) in both
///   modes — always pair them with [onPrimary] (near-black ink).
/// - Muscle gradients and the data-viz accents (`accent*`, `redAccent`, …)
///   are intentionally constant: they read correctly on both canvases, like
///   the pixel-art palette.
class AppColors {
  AppColors._();

  static Brightness _brightness = Brightness.dark;
  static Brightness get brightness => _brightness;
  static bool get isLight => _brightness == Brightness.light;

  /// Re-resolves every mode-aware token. Cheap — call before each paint of a
  /// different brightness.
  static void apply(Brightness brightness) {
    _brightness = brightness;
    final bool light = brightness == Brightness.light;

    // ── Surface Hierarchy ──
    background = light ? const Color(0xFFF4F5EF) : const Color(0xFF000000);
    surfaceLowest = light ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    surface = light ? const Color(0xFFFFFFFF) : const Color(0xFF0E0E0E);
    surfaceDim = light ? const Color(0xFFE9EAE2) : const Color(0xFF0E0E0E);
    surfaceContainerLow =
        light ? const Color(0xFFF2F3EC) : const Color(0xFF131313);
    surfaceContainer =
        light ? const Color(0xFFF5F6F0) : const Color(0xFF1A1919);
    surfaceContainerHigh =
        light ? const Color(0xFFF8F9F3) : const Color(0xFF201F1F);
    surfaceContainerHighest =
        light ? const Color(0xFFEDEFE6) : const Color(0xFF262626);
    surfaceBright = light ? const Color(0xFFFFFFFF) : const Color(0xFF2C2C2C);

    // ── Primary — Electric Volt ──
    // Accent vs fill split (see class doc).
    primary = light ? const Color(0xFF556A00) : const Color(0xFFD1FC00);
    primaryGreen = const Color(0xFFD1FC00); // legacy fill alias → volt
    secondaryGreen = const Color(0xFFC7EF00); // legacy fill alias → volt dim
    primaryFixed = const Color(0xFFD1FC00);
    primaryDim = const Color(0xFFC7EF00);
    primaryContainer = const Color(0xFFD1FC00);
    onPrimary = const Color(0xFF0A0A0A); // ink on volt — both modes
    onPrimaryContainer =
        light ? const Color(0xFF556A00) : const Color(0xFFD1FC00);
    // Pale volt-tinted glass for selected states / soft containers.
    lightGreen = light
        ? const Color(0x1F556A00)
        : const Color(0x1AD1FC00); // 10% volt on obsidian

    // ── Secondary — Cyan Electric ──
    secondary = light ? const Color(0xFF00808A) : const Color(0xFF00EEFC);
    secondaryFixed = const Color(0xFF00EEFC);
    secondaryDim = light ? const Color(0xFF00747D) : const Color(0xFF00DEEC);

    // ── Tertiary — Gold ──
    // Darkened in light mode so gold text/accents keep contrast; fills keep
    // pairing with black ink either way.
    tertiary = light ? const Color(0xFFA87E00) : const Color(0xFFFCDC43);
    tertiaryFixed = const Color(0xFFFCDC43);
    tertiaryDim = light ? const Color(0xFF9C7400) : const Color(0xFFEDCE35);
    tertiaryContainer = const Color(0xFFFCDC43);

    // ── Error ──
    error = light ? const Color(0xFFC63D1B) : const Color(0xFFFF7351);
    errorDim = const Color(0xFFD53D18);

    // ── Text & Content Hierarchy ──
    textPrimary = light ? const Color(0xFF17180F) : const Color(0xFFF5F5F5);
    textSecondary = light ? const Color(0xFF5D5E54) : const Color(0xFFADAAAA);
    textMuted = light ? const Color(0xFF8B8C82) : const Color(0xFF777575);
    onSurface = light ? const Color(0xFF0E0F09) : const Color(0xFFFFFFFF);
    onSurfaceVariant =
        light ? const Color(0xFF5D5E54) : const Color(0xFFADAAAA);
    onBackground = light ? const Color(0xFF17180F) : const Color(0xFFFFFFFF);

    // ── Outlines & Borders ──
    borderSubtle = light ? const Color(0xFFDFE1D4) : const Color(0xFF2E2E2E);
    borderLight = light
        ? const Color(0x14000000)
        : const Color(0x14FFFFFF);
    outline = light ? const Color(0xFF8B8C82) : const Color(0xFF777575);
    outlineVariant = light ? const Color(0xFFC5C7BA) : const Color(0xFF494847);

    // ── Glow & Soft Shadow System ──
    primaryGlow = const Color(0xFFD1FC00).withValues(
        alpha: light ? 0.30 : 0.15);
    secondaryGlow = const Color(0xFF00EEFC)
        .withValues(alpha: light ? 0.18 : 0.10);
    errorGlow = const Color(0xFFFF7351)
        .withValues(alpha: light ? 0.16 : 0.10);
    cardShadow = const Color(0xFF000000)
        .withValues(alpha: light ? 0.10 : 0.35);
    glowOrbPrimary = const Color(0xFFD1FC00)
        .withValues(alpha: light ? 0.10 : 0.05);
    glowOrbSecondary = const Color(0xFF00EEFC)
        .withValues(alpha: light ? 0.06 : 0.03);

    // ── Glass Compatibility Tokens ──
    // White-alpha sheen on obsidian flips to black-alpha depth on light.
    glass1 = light
        ? const Color(0x05000000)
        : const Color(0x0AFFFFFF); // 4% white
    glass2 = light
        ? const Color(0x0A000000)
        : const Color(0x14FFFFFF); // 8% white
    glass3 = light
        ? const Color(0x12000000)
        : const Color(0x1FFFFFFF); // 12% white
    glassBorder = light
        ? const Color(0x0F000000)
        : const Color(0x14FFFFFF); // 8% white border
    glassBorderActive = light
        ? const Color(0x4D556A00) // 30% olive-volt border
        : const Color(0x4DD1FC00); // 30% volt border
  }

  // ── Mode-aware token fields (set by [apply]; dark defaults below) ──

  // Surface Hierarchy (darkest → brightest)
  static Color background = const Color(0xFF000000);
  static Color surfaceLowest = const Color(0xFF000000);
  static Color surface = const Color(0xFF0E0E0E);
  static Color surfaceDim = const Color(0xFF0E0E0E);
  static Color surfaceContainerLow = const Color(0xFF131313);
  static Color surfaceContainer = const Color(0xFF1A1919);
  static Color surfaceContainerHigh = const Color(0xFF201F1F);
  static Color surfaceContainerHighest = const Color(0xFF262626);
  static Color surfaceBright = const Color(0xFF2C2C2C);

  // Primary — Electric Volt
  static Color primary = const Color(0xFFD1FC00);
  static Color primaryGreen = const Color(0xFFD1FC00); // legacy name → volt
  static Color secondaryGreen = const Color(0xFFC7EF00); // legacy name → volt dim
  static Color primaryFixed = const Color(0xFFD1FC00);
  static Color primaryDim = const Color(0xFFC7EF00);
  static Color primaryContainer = const Color(0xFFD1FC00);
  static Color onPrimary = const Color(0xFF0A0A0A); // near-black ink on volt
  static Color onPrimaryContainer = const Color(0xFFD1FC00);
  static Color lightGreen = const Color(0x1AD1FC00); // 10% volt glass

  // Secondary — Cyan Electric
  static Color secondary = const Color(0xFF00EEFC);
  static Color secondaryFixed = const Color(0xFF00EEFC);
  static Color secondaryDim = const Color(0xFF00DEEC);

  // Tertiary — Gold
  static Color tertiary = const Color(0xFFFCDC43);
  static Color tertiaryFixed = const Color(0xFFFCDC43);
  static Color tertiaryDim = const Color(0xFFEDCE35);
  static Color tertiaryContainer = const Color(0xFFFCDC43);

  // Error
  static Color error = const Color(0xFFFF7351);
  static Color errorDim = const Color(0xFFD53D18);

  // Text & Content Hierarchy
  static Color textPrimary = const Color(0xFFF5F5F5);
  static Color textSecondary = const Color(0xFFADAAAA);
  static Color textMuted = const Color(0xFF777575);
  static Color onSurface = const Color(0xFFFFFFFF);
  static Color onSurfaceVariant = const Color(0xFFADAAAA);
  static Color onBackground = const Color(0xFFFFFFFF);

  // Outlines & Borders
  static Color borderSubtle = const Color(0xFF2E2E2E);
  static Color borderLight = const Color(0x14FFFFFF);
  static Color outline = const Color(0xFF777575);
  static Color outlineVariant = const Color(0xFF494847);

  // ── Nutrition & Fitness Data Accents (data-viz semantics, mode-safe) ──
  static const Color accentCalories = Color(0xFFFF8A00); // Calories (Pixel Fire)
  static const Color accentProtein = Color(0xFFFF6B6B);  // Protein (Pixel Meat)
  static const Color accentCarbs = Color(0xFF3B82F6);    // Carbs (Pixel Grain)
  static const Color accentFat = Color(0xFF22A06B);      // Fat (Pixel Avocado)
  static const Color accentWater = Color(0xFF00EEFC);    // Water → cyan electric
  static const Color accentSteps = Color(0xFF6C5CE7);    // Steps → obsidian purple
  static const Color accentWorkout = Color(0xFFFF8A00);  // Workout (Pixel Dumbbell)

  // ── Semantic Aliases & Backward Compatibility (data-viz, mode-safe) ──
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
  static Color glass1 = const Color(0x0AFFFFFF); // 4% white
  static Color glass2 = const Color(0x14FFFFFF); // 8% white
  static Color glass3 = const Color(0x1FFFFFFF); // 12% white
  static Color glassBorder = const Color(0x14FFFFFF); // 8% white border
  static Color glassBorderActive = const Color(0x4DD1FC00); // 30% volt border

  // ── Muscle Group Gradients (data-viz, identical in both modes) ──
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

  // ── Primary Action Gradient (volt fill, both modes) ──
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
