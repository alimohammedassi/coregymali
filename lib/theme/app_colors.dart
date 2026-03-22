import 'package:flutter/material.dart';

/// Kinetic Obsidian — Electric Volt Design System Colors
class AppColors {
  AppColors._();

  // ── Surface Hierarchy (darkest → brightest) ──
  static const Color surfaceLowest = Color(0xFF000000);
  static const Color surface = Color(0xFF0E0E0E);
  static const Color surfaceDim = Color(0xFF0E0E0E);
  static const Color surfaceContainerLow = Color(0xFF131313);
  static const Color surfaceContainer = Color(0xFF1A1919);
  static const Color surfaceContainerHigh = Color(0xFF201F1F);
  static const Color surfaceContainerHighest = Color(0xFF262626);
  static const Color surfaceBright = Color(0xFF2C2C2C);

  // ── Primary — Electric Volt / Lime ──
  static const Color primary = Color(0xFFF4FFC6);
  static const Color primaryFixed = Color(0xFFD1FC00);
  static const Color primaryDim = Color(0xFFC7EF00);
  static const Color primaryContainer = Color(0xFFD1FC00);
  static const Color onPrimary = Color(0xFF546600);
  static const Color onPrimaryContainer = Color(0xFF4C5D00);

  // ── Secondary — Cyan Electric ──
  static const Color secondary = Color(0xFF00EEFC);
  static const Color secondaryFixed = Color(0xFF00EEFC);
  static const Color secondaryDim = Color(0xFF00DEEC);

  // ── Tertiary — Gold ──
  static const Color tertiary = Color(0xFFFFEB9C);
  static const Color tertiaryFixed = Color(0xFFFCDC43);
  static const Color tertiaryDim = Color(0xFFEDCE35);
  static const Color tertiaryContainer = Color(0xFFFCDC43);

  // ── Error ──
  static const Color error = Color(0xFFFF7351);
  static const Color errorDim = Color(0xFFD53D18);

  // ── On-Surface / Text ──
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color onSurfaceVariant = Color(0xFFADAAAa);
  static const Color onBackground = Color(0xFFFFFFFF);

  // ── Outline / Borders ──
  static const Color outline = Color(0xFF777575);
  static const Color outlineVariant = Color(0xFF494847);

  // ── Glass System ──
  static const Color glass1 = Color(0x0AFFFFFF); // 4% white
  static const Color glass2 = Color(0x14FFFFFF); // 8% white
  static const Color glass3 = Color(0x1FFFFFFF); // 12% white
  static const Color glassBorder = Color(0x14FFFFFF); // 8% white border
  static const Color glassBorderActive = Color(0x4DD1FC00); // 30% primary border

  // ── Glow Effect Colors ──
  static Color primaryGlow = const Color(0xFFD1FC00).withValues(alpha: 0.15);
  static Color secondaryGlow = const Color(0xFF00EEFC).withValues(alpha: 0.10);
  static Color errorGlow = const Color(0xFFFF7351).withValues(alpha: 0.10);

  // ── Muscle Group Gradients ──
  static const LinearGradient chestGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFEE5A52)],
  );
  static const LinearGradient armsGradient = LinearGradient(
    colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
  );
  static const LinearGradient legsGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
  );
  static const LinearGradient coreGradient = LinearGradient(
    colors: [Color(0xFFFD79A8), Color(0xFFE84393)],
  );

  // ── Primary Action Gradient ──
  static const LinearGradient primaryActionGradient = LinearGradient(
    colors: [Color(0xFFD1FC00), Color(0xFFC7EF00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Background Glow Orbs ──
  static Color glowOrbPrimary = const Color(0xFFD1FC00).withValues(alpha: 0.10);
  static Color glowOrbSecondary = const Color(0xFF00EEFC).withValues(alpha: 0.05);
}
