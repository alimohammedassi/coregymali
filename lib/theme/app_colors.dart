import 'package:flutter/material.dart';

/// Graphite & Soft Volt — CoreGym Design System Colors (v2.1)
///
/// Single source of truth. Successor to "Kinetic Obsidian & Electric Volt":
/// the 100%-saturation neon primary caused eye strain, so the dark mode runs
/// on a soft olive-graphite surface ladder with a muted-lime fill (#B2D742).
/// The Home redesign (2026-09) revised the LIGHT mode to a neutral paper
/// system (#FAFAFA canvas, pure-white cards, #1A1A1A/#6B6B6B ink) and
/// reintroduced the volt identity as [accent]: #D1FC00 on dark, darkened to
/// #8FB800 on light, for progress rings and active states only. The original
/// volt (#D1FC00) survives directly as [volt] — micro-accent for the streak
/// flame and tiny badges; never for buttons or large fills.
///
/// MODE-AWARE: every surface/text token resolves through [apply] to the
/// active brightness; widgets consume `AppColors.x` statically. Call [apply]
/// before painting a new brightness (the MaterialApp builder does this) and
/// key the widget tree on the resolved brightness so a switch rebuilds.
///
/// Token API notes:
/// - `accent` is the Home redesign's ring/active-state accent (graphics).
///   Accent-colored TEXT must use [onPrimaryContainer] to stay AA on light.
/// - `primary` is the app-wide chrome accent: soft lime on dark, dark
///   olive-lime on light.
/// - `primaryFixed` / `primaryGreen` are the FILL lime (#B2D742) in BOTH
///   modes — always pair them with [onPrimary] (near-black ink), never white.
/// - Muscle gradients are intentionally constant. The data-viz accents
///   (`accent*`, `redAccent`, …) form one coherent mid-saturation family
///   (coral/gold/green/teal/orange) that reads on both canvases.
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

    // ── Surface Hierarchy ──
    // Dark: olive-graphite ladder (v2 base, kept per Home redesign spec).
    // Light: neutral paper per Home redesign spec — #FAFAFA canvas, pure
    // white cards; the old sage cast is gone so white cards read on a
    // neutral, not tinted, ground.
    background = light ? const Color(0xFFFAFAFA) : const Color(0xFF121310);
    surfaceLowest =
        light ? const Color(0xFFFAFAFA) : const Color(0xFF121310);
    surface = light ? const Color(0xFFFFFFFF) : const Color(0xFF171814);
    surfaceDim = light ? const Color(0xFFEFEFEF) : const Color(0xFF151612);
    surfaceContainerLow =
        light ? const Color(0xFFF4F4F4) : const Color(0xFF1B1C17);
    surfaceContainer =
        light ? const Color(0xFFF7F7F7) : const Color(0xFF1F201B);
    surfaceContainerHigh =
        light ? const Color(0xFFFAFAFA) : const Color(0xFF252620);
    surfaceContainerHighest =
        light ? const Color(0xFFF1F1F1) : const Color(0xFF2B2C26);
    surfaceBright = light ? const Color(0xFFFFFFFF) : const Color(0xFF31322C);

    // ── Home Accent (progress rings & active states) ──
    // The spec's accent pair: Electric Volt on dark, darkened volt on light
    // (the neon #D1FC00 is illegible on white). GRAPHIC use only — rings,
    // active icons, borders. Accent-colored TEXT goes through
    // [onPrimaryContainer], which stays AA on both canvases.
    accent = light ? const Color(0xFF8FB800) : const Color(0xFFD1FC00);

    // ── Primary — Soft Volt (muted lime) ──
    // Accent vs fill split (see class doc). `primary` remains the app-wide
    // chrome accent; the Home redesign's brighter ring/active accent is
    // [accent] above.
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

    // ── Warning — over-goal (warm amber, not error red) ──
    // Used for "over calories" border/pill/text. Red is reserved for real
    // errors (failed loads, destructive actions).
    overGoalWarning = light ? const Color(0xFFB45309) : const Color(0xFFF59E0B);
    overGoalWarningBg = light
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFFFF7ED).withValues(alpha: 0.12);
    overGoalWarningBorder = light
        ? const Color(0xFFB45309).withValues(alpha: 0.45)
        : const Color(0xFFF59E0B).withValues(alpha: 0.45);

    // ── Text & Content Hierarchy ──
    // Light pair from the Home redesign spec (#1A1A1A / #6B6B6B); muted is
    // the darkest gray that still passes AA 4.5:1 on white. Dark textMuted
    // lifted to #8A8E82 for the same reason (was ~3.3:1 on graphite).
    textPrimary = light ? const Color(0xFF1A1A1A) : const Color(0xFFECEEE2);
    textSecondary = light ? const Color(0xFF6B6B6B) : const Color(0xFFA9ADA0);
    textMuted = light ? const Color(0xFF767676) : const Color(0xFF8A8E82);
    onSurface = light ? const Color(0xFF1A1A1A) : const Color(0xFFF1F3E9);
    onSurfaceVariant =
        light ? const Color(0xFF6B6B6B) : const Color(0xFFA9ADA0);
    onBackground = light ? const Color(0xFF1A1A1A) : const Color(0xFFECEEE2);

    // ── Outlines & Borders ──
    borderSubtle = light ? const Color(0xFFE8E8E8) : const Color(0xFF2C2D27);
    borderLight = light
        ? const Color(0x14000000)
        : const Color(0x14FFFFFF);
    outline = light ? const Color(0xFF9E9E9E) : const Color(0xFF6E7268);
    outlineVariant = light ? const Color(0xFFD6D6D6) : const Color(0xFF45473E);

    // ── Glow & Soft Shadow System ──
    // Light card shadow is the Home spec's soft elevation: 4% black,
    // blur 12 / offset (0,4) at the call sites — white cards separate from
    // the #FAFAFA canvas by shadow + hairline border, not heavy tint.
    primaryGlow = const Color(0xFFB2D742)
        .withValues(alpha: light ? 0.25 : 0.08);
    secondaryGlow = const Color(0xFF4FD1C5)
        .withValues(alpha: light ? 0.15 : 0.08);
    errorGlow = const Color(0xFFEE7F60)
        .withValues(alpha: light ? 0.12 : 0.08);
    cardShadow = const Color(0xFF000000)
        .withValues(alpha: light ? 0.04 : 0.30);
    glowOrbPrimary = const Color(0xFFB2D742)
        .withValues(alpha: light ? 0.05 : 0.04);
    glowOrbSecondary = const Color(0xFF4FD1C5)
        .withValues(alpha: light ? 0.03 : 0.03);

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

  // Home Accent — rings/active-state graphics; volt on dark, darkened on light
  static Color accent = const Color(0xFFD1FC00);

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

  // Warning — over-goal (warm amber, not error red)
  static Color overGoalWarning = const Color(0xFFF59E0B);
  static Color overGoalWarningBg = const Color(0xFFFFF7ED);
  static Color overGoalWarningBorder = const Color(0xFFF59E0B);

  // Text & Content Hierarchy
  static Color textPrimary = const Color(0xFFECEEE2);
  static Color textSecondary = const Color(0xFFA9ADA0);
  static Color textMuted = const Color(0xFF8A8E82);
  static Color onSurface = const Color(0xFFF1F3E9);
  static Color onSurfaceVariant = const Color(0xFFA9ADA0);
  static Color onBackground = const Color(0xFFECEEE2);

  // Outlines & Borders
  static Color borderSubtle = const Color(0xFF2C2D27);
  static Color borderLight = const Color(0x14FFFFFF);
  static Color outline = const Color(0xFF6E7268);
  static Color outlineVariant = const Color(0xFF45473E);

  // ── Nutrition & Fitness Data Accents (one coherent data-viz family) ──
  // Home redesign spec: semantic metrics use distinct but RELATED hues at a
  // shared mid-saturation/lightness band — coral → gold → green → teal →
  // orange — instead of unrelated pastels. Carbs moved off blue (it collided
  // with water/teal) to the gold shared with the tertiary token; steps moved
  // off violet to the same gold.
  static const Color accentCalories = Color(0xFFF5A623); // Calories (Pixel Fire)
  static const Color accentProtein = Color(0xFFEA7A72);  // Protein (Pixel Meat)
  static const Color accentCarbs = Color(0xFFE8C468);    // Carbs (Pixel Grain)
  static const Color accentFat = Color(0xFF36B37E);      // Fat (Pixel Avocado)
  static const Color accentWater = Color(0xFF4FD1C5);    // Water → calm teal
  static const Color accentSteps = Color(0xFFE8C468);    // Steps → gold
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
  static Color cardShadowMedium = const Color(0x140F172A);
  static Color cardShadowLight = const Color(0x0F0F172A);
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

  // ── Volt Gradient — Electric Volt #D1FC00 sparing high-contrast accent ──
  // Use for AI Scan button / active nav icon in light theme for pop (see spec)
  static const LinearGradient voltGradient = LinearGradient(
    colors: [Color(0xFFD1FC00), Color(0xFFB2D742)],
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
