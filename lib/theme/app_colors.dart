import 'package:flutter/material.dart';

/// Graphite & Soft Volt — CoreGym Design System Colors (v2)
///
/// Single source of truth. Successor to "Kinetic Obsidian & Electric Volt":
/// the pure-black canvas and 100%-saturation neon primary caused eye strain,
/// so both modes now run on a soft olive-graphite surface ladder with a
/// muted-lime primary (#B2D742) that keeps the energetic identity without
/// glowing. The original volt (#D1FC00) survives ONLY as [volt] — a
/// micro-accent for the streak flame and tiny badges; never use it for
/// buttons, rings, or active tabs.
///
/// MODE-AWARE: every surface/text token resolves through [apply] to the
/// active brightness; widgets consume `AppColors.x` statically. Call [apply]
/// before painting a new brightness (the MaterialApp builder does this) and
/// key the widget tree on the resolved brightness so a switch rebuilds.
///
/// Token API notes:
/// - `primary` is the ACCENT (icons/text/selected borders): soft lime on
///   dark, dark olive-lime on light (AA on the light canvas).
/// - `primaryFixed` / `primaryGreen` are the FILL lime (#B2D742) in BOTH
///   modes — always pair them with [onPrimary] (near-black ink).
/// - Muscle gradients and the data-viz accents (`accent*`, `redAccent`, …)
///   are intentionally constant: one calm mid-saturation family that reads
///   on both canvases, like the pixel-art palette.
class AppColors {
  AppColors._();

  static Brightness _brightness = Brightness.dark;
  static Brightness get brightness => _brightness;
  static bool get isLight => _brightness == Brightness.light;

  /// The retired neon volt — MICRO-ACCENT ONLY (streak flame, small badges).
  /// Do not use for buttons, rings, tab indicators, or any large surface.
  static const Color volt = Color(0xFFD1FC00);

  /// Re-resolves every mode-aware token. Cheap — call before each paint of a
  /// different brightness.
  static void apply(Brightness brightness) {
    _brightness = brightness;
    final bool light = brightness == Brightness.light;

    // ── Surface Hierarchy (olive-graphite, never pure black/white) ──
    background = light ? const Color(0xFFF2F3E9) : const Color(0xFF121310);
    surfaceLowest =
        light ? const Color(0xFFF6F7EE) : const Color(0xFF121310);
    surface = light ? const Color(0xFFFBFCF5) : const Color(0xFF171814);
    surfaceDim = light ? const Color(0xFFE9EBDD) : const Color(0xFF151612);
    surfaceContainerLow =
        light ? const Color(0xFFF4F5EC) : const Color(0xFF1B1C17);
    surfaceContainer =
        light ? const Color(0xFFF7F8F0) : const Color(0xFF1F201B);
    surfaceContainerHigh =
        light ? const Color(0xFFFBFCF4) : const Color(0xFF252620);
    surfaceContainerHighest =
        light ? const Color(0xFFEFF1E3) : const Color(0xFF2B2C26);
    surfaceBright = light ? const Color(0xFFFFFFFF) : const Color(0xFF31322C);

    // ── Primary — Soft Volt (muted lime) ──
    // Accent vs fill split (see class doc).
    primary = light ? const Color(0xFF506B1A) : const Color(0xFFB2D742);
    primaryGreen = const Color(0xFFB2D742); // legacy fill alias → soft volt
    secondaryGreen = const Color(0xFF9CC338); // legacy fill alias → lime dim
    primaryFixed = const Color(0xFFB2D742);
    primaryDim = const Color(0xFF9CC338);
    primaryContainer = const Color(0xFFB2D742);
    onPrimary = const Color(0xFF161806); // ink on lime — both modes
    onPrimaryContainer =
        light ? const Color(0xFF506B1A) : const Color(0xFFB2D742);
    // Pale lime-tinted glass for selected states / soft containers.
    lightGreen = light
        ? const Color(0x1F506B1A)
        : const Color(0x1AB2D742); // 10% lime on graphite

    // ── Secondary — Calm Teal ──
    secondary = light ? const Color(0xFF0F766E) : const Color(0xFF4FD1C5);
    secondaryFixed = const Color(0xFF4FD1C5);
    secondaryDim = light ? const Color(0xFF0D6A63) : const Color(0xFF3FB9AE);

    // ── Tertiary — Muted Gold ──
    // Darkened in light mode so gold text/accents keep contrast; fills keep
    // pairing with black ink either way.
    tertiary = light ? const Color(0xFF8A6A1E) : const Color(0xFFE8C468);
    tertiaryFixed = const Color(0xFFE8C468);
    tertiaryDim = light ? const Color(0xFF7C5F1B) : const Color(0xFFD4B254);
    tertiaryContainer = const Color(0xFFE8C468);

    // ── Error ──
    error = light ? const Color(0xFFB84A30) : const Color(0xFFEE7F60);
    errorDim = light ? const Color(0xFFA8432B) : const Color(0xFFD96A47);

    // ── Text & Content Hierarchy ──
    textPrimary = light ? const Color(0xFF1B1D12) : const Color(0xFFECEEE2);
    textSecondary = light ? const Color(0xFF555947) : const Color(0xFFA9ADA0);
    textMuted = light ? const Color(0xFF83877A) : const Color(0xFF70746A);
    onSurface = light ? const Color(0xFF14160C) : const Color(0xFFF1F3E9);
    onSurfaceVariant =
        light ? const Color(0xFF555947) : const Color(0xFFA9ADA0);
    onBackground = light ? const Color(0xFF1B1D12) : const Color(0xFFECEEE2);

    // ── Outlines & Borders ──
    borderSubtle = light ? const Color(0xFFDBDDCC) : const Color(0xFF2C2D27);
    borderLight = light
        ? const Color(0x14000000)
        : const Color(0x14FFFFFF);
    outline = light ? const Color(0xFF83877A) : const Color(0xFF6E7268);
    outlineVariant = light ? const Color(0xFFC3C6B3) : const Color(0xFF45473E);

    // ── Glow & Soft Shadow System (halved vs v1 — no neon bloom) ──
    primaryGlow = const Color(0xFFB2D742)
        .withValues(alpha: light ? 0.25 : 0.08);
    secondaryGlow = const Color(0xFF4FD1C5)
        .withValues(alpha: light ? 0.15 : 0.08);
    errorGlow = const Color(0xFFEE7F60)
        .withValues(alpha: light ? 0.12 : 0.08);
    cardShadow = const Color(0xFF000000)
        .withValues(alpha: light ? 0.10 : 0.30);
    glowOrbPrimary = const Color(0xFFB2D742)
        .withValues(alpha: light ? 0.08 : 0.04);
    glowOrbSecondary = const Color(0xFF4FD1C5)
        .withValues(alpha: light ? 0.05 : 0.03);

    // ── Glass Compatibility Tokens ──
    // White-alpha sheen on graphite flips to black-alpha depth on light.
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
        ? const Color(0x4D506B1A) // 30% olive-lime border
        : const Color(0x4DB2D742); // 30% lime border
  }

  // ── Mode-aware token fields (set by [apply]; dark defaults below) ──

  // Surface Hierarchy
  static Color background = const Color(0xFF121310);
  static Color surfaceLowest = const Color(0xFF121310);
  static Color surface = const Color(0xFF171814);
  static Color surfaceDim = const Color(0xFF151612);
  static Color surfaceContainerLow = const Color(0xFF1B1C17);
  static Color surfaceContainer = const Color(0xFF1F201B);
  static Color surfaceContainerHigh = const Color(0xFF252620);
  static Color surfaceContainerHighest = const Color(0xFF2B2C26);
  static Color surfaceBright = const Color(0xFF31322C);

  // Primary — Soft Volt
  static Color primary = const Color(0xFFB2D742);
  static Color primaryGreen = const Color(0xFFB2D742); // legacy fill alias
  static Color secondaryGreen = const Color(0xFF9CC338); // legacy fill alias
  static Color primaryFixed = const Color(0xFFB2D742);
  static Color primaryDim = const Color(0xFF9CC338);
  static Color primaryContainer = const Color(0xFFB2D742);
  static Color onPrimary = const Color(0xFF161806); // ink on lime
  static Color onPrimaryContainer = const Color(0xFFB2D742);
  static Color lightGreen = const Color(0x1AB2D742); // 10% lime glass

  // Secondary — Calm Teal
  static Color secondary = const Color(0xFF4FD1C5);
  static Color secondaryFixed = const Color(0xFF4FD1C5);
  static Color secondaryDim = const Color(0xFF3FB9AE);

  // Tertiary — Muted Gold
  static Color tertiary = const Color(0xFFE8C468);
  static Color tertiaryFixed = const Color(0xFFE8C468);
  static Color tertiaryDim = const Color(0xFFD4B254);
  static Color tertiaryContainer = const Color(0xFFE8C468);

  // Error
  static Color error = const Color(0xFFEE7F60);
  static Color errorDim = const Color(0xFFD96A47);

  // Text & Content Hierarchy
  static Color textPrimary = const Color(0xFFECEEE2);
  static Color textSecondary = const Color(0xFFA9ADA0);
  static Color textMuted = const Color(0xFF70746A);
  static Color onSurface = const Color(0xFFF1F3E9);
  static Color onSurfaceVariant = const Color(0xFFA9ADA0);
  static Color onBackground = const Color(0xFFECEEE2);

  // Outlines & Borders
  static Color borderSubtle = const Color(0xFF2C2D27);
  static Color borderLight = const Color(0x14FFFFFF);
  static Color outline = const Color(0xFF6E7268);
  static Color outlineVariant = const Color(0xFF45473E);

  // ── Nutrition & Fitness Data Accents (calm data-viz, mode-safe) ──
  static const Color accentCalories = Color(0xFFF5A623); // Calories (Pixel Fire)
  static const Color accentProtein = Color(0xFFEA7A72);  // Protein (Pixel Meat)
  static const Color accentCarbs = Color(0xFF60A5FA);    // Carbs (Pixel Grain)
  static const Color accentFat = Color(0xFF36B37E);      // Fat (Pixel Avocado)
  static const Color accentWater = Color(0xFF4FD1C5);    // Water → calm teal
  static const Color accentSteps = Color(0xFF9B8AFB);    // Steps → soft violet
  static const Color accentWorkout = Color(0xFFF5A623);  // Workout (Pixel Dumbbell)

  // ── Semantic Aliases & Backward Compatibility (data-viz, mode-safe) ──
  static const Color redAccent = Color(0xFFEA7A72);
  static const Color orangeAccent = Color(0xFFF5A623);
  static const Color greenAccent = Color(0xFFB2D742); // legacy name → lime
  static const Color purpleAccent = Color(0xFF9B8AFB);

  // ── Glow & Soft Shadow System ──
  static Color primaryGlow = const Color(0xFFB2D742).withValues(alpha: 0.08);
  static Color secondaryGlow = const Color(0xFF4FD1C5).withValues(alpha: 0.08);
  static Color errorGlow = const Color(0xFFEE7F60).withValues(alpha: 0.08);
  static Color cardShadow = const Color(0xFF000000).withValues(alpha: 0.30);
  static Color glowOrbPrimary = const Color(0xFFB2D742).withValues(alpha: 0.04);
  static Color glowOrbSecondary = const Color(0xFF4FD1C5).withValues(alpha: 0.03);

  // ── Glass Compatibility Tokens ──
  static Color glass1 = const Color(0x0AFFFFFF); // 4% white
  static Color glass2 = const Color(0x14FFFFFF); // 8% white
  static Color glass3 = const Color(0x1FFFFFFF); // 12% white
  static Color glassBorder = const Color(0x14FFFFFF); // 8% white border
  static Color glassBorderActive = const Color(0x4DB2D742); // 30% lime border

  // ── Muscle Group Gradients (calm data-viz, identical in both modes) ──
  static const LinearGradient chestGradient = LinearGradient(
    colors: [Color(0xFFEA7A72), Color(0xFFD96A62)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient armsGradient = LinearGradient(
    colors: [Color(0xFF54C7BE), Color(0xFF3E9483)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient legsGradient = LinearGradient(
    colors: [Color(0xFF7E71E0), Color(0xFFA9A2F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient coreGradient = LinearGradient(
    colors: [Color(0xFFE87FA2), Color(0xFFD4578C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Primary Action Gradient (soft lime fill, both modes) ──
  static const LinearGradient primaryActionGradient = LinearGradient(
    colors: [Color(0xFFB2D742), Color(0xFF9CC338)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Dark Mode Aliases (kept for call sites that name them explicitly) ──
  static const Color darkBackground = Color(0xFF121310);
  static const Color darkSurface = Color(0xFF171814);
  static const Color darkSurfaceCard = Color(0xFF1F201B);
  static const Color darkTextPrimary = Color(0xFFECEEE2);
  static const Color darkTextSecondary = Color(0xFFA9ADA0);
  static const Color darkBorder = Color(0xFF2C2D27);
}
