import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Kinetic Obsidian — Typography System
/// Headline: Epilogue (italic, bold, tight tracking)
/// Body/Label: Inter (clean instrument-panel aesthetic)
class AuthAppText {
  AuthAppText._();

  // ── Display (Epilogue — Huge Impact Numbers) ──
  static const TextStyle displayLg = TextStyle(
    fontFamily: 'Epilogue',
    fontSize: 56,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    letterSpacing: -2.5,
    color: AppColors.onSurface,
    height: 1.0,
  );

  static const TextStyle displayMd = TextStyle(
    fontFamily: 'Epilogue',
    fontSize: 40,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    letterSpacing: -2.0,
    color: AppColors.onSurface,
    height: 1.0,
  );

  static const TextStyle displaySm = TextStyle(
    fontFamily: 'Epilogue',
    fontSize: 32,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    letterSpacing: -1.5,
    color: AppColors.onSurface,
    height: 1.1,
  );

  // ── Headline (Epilogue — Section Headers) ──
  static const TextStyle headlineLg = TextStyle(
    fontFamily: 'Epilogue',
    fontSize: 28,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    letterSpacing: -1.0,
    color: AppColors.onSurface,
    height: 1.15,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: 'Epilogue',
    fontSize: 24,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    letterSpacing: -0.8,
    color: AppColors.onSurface,
    height: 1.2,
  );

  static const TextStyle headlineSm = TextStyle(
    fontFamily: 'Epilogue',
    fontSize: 20,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.italic,
    letterSpacing: -0.5,
    color: AppColors.onSurface,
    height: 1.2,
  );

  // ── Title (Inter — Subheads / Card Titles) ──
  static const TextStyle titleLg = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.0,
    color: AppColors.onSurface,
  );

  static const TextStyle titleMd = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.0,
    color: AppColors.onSurface,
  );

  static const TextStyle titleSm = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: AppColors.onSurface,
  );

  // ── Body (Inter — Readable Content) ──
  static const TextStyle bodyLg = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    color: AppColors.onSurfaceVariant,
    height: 1.5,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    color: AppColors.onSurfaceVariant,
    height: 1.4,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    color: AppColors.onSurfaceVariant,
    height: 1.4,
  );

  // ── Label (Inter — Tiny Tags / Badges / Navigation) ──
  static const TextStyle labelLg = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.0,
    color: AppColors.onSurfaceVariant,
  );

  static const TextStyle labelMd = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: AppColors.onSurfaceVariant,
  );

  static const TextStyle labelSm = TextStyle(
    fontFamily: 'Inter',
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.5,
    color: AppColors.outline,
  );

  // ── Button Text ──
  static const TextStyle buttonPrimary = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.0,
    color: AppColors.onPrimary,
  );

  static const TextStyle buttonSecondary = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: AppColors.onSurface,
  );

  // ── Metric / Stat Values ──
  static const TextStyle metricLg = TextStyle(
    fontFamily: 'Epilogue',
    fontSize: 48,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    letterSpacing: -2.0,
    color: AppColors.primaryFixed,
    height: 1.0,
  );

  static const TextStyle metricMd = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.onSurface,
    height: 1.0,
  );

  static const TextStyle metricUnit = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: AppColors.onSurfaceVariant,
  );
}
