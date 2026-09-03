import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Kinetic Obsidian — Typography System
/// Headline: Epilogue (italic, bold, tight tracking)
/// Body/Label: Inter (clean instrument-panel aesthetic)
///
/// Loaded via google_fonts (matching AppText's Poppins/Cairo approach) so the
/// families actually render — they are not bundled as raw assets in pubspec.
class AuthAppText {
  AuthAppText._();

  // ── Display (Epilogue — Huge Impact Numbers) ──
  static TextStyle get displayLg => GoogleFonts.epilogue(
        fontSize: 56,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: -2.5,
        color: AppColors.onSurface,
        height: 1.0,
      );

  static TextStyle get displayMd => GoogleFonts.epilogue(
        fontSize: 40,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: -2.0,
        color: AppColors.onSurface,
        height: 1.0,
      );

  static TextStyle get displaySm => GoogleFonts.epilogue(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: -1.5,
        color: AppColors.onSurface,
        height: 1.1,
      );

  // ── Headline (Epilogue — Section Headers) ──
  static TextStyle get headlineLg => GoogleFonts.epilogue(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: -1.0,
        color: AppColors.onSurface,
        height: 1.15,
      );

  static TextStyle get headlineMd => GoogleFonts.epilogue(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: -0.8,
        color: AppColors.onSurface,
        height: 1.2,
      );

  static TextStyle get headlineSm => GoogleFonts.epilogue(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: -0.5,
        color: AppColors.onSurface,
        height: 1.2,
      );

  // ── Title (Inter — Subheads / Card Titles) ──
  static TextStyle get titleLg => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.0,
        color: AppColors.onSurface,
      );

  static TextStyle get titleMd => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.0,
        color: AppColors.onSurface,
      );

  static TextStyle get titleSm => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.onSurface,
      );

  // ── Body (Inter — Readable Content) ──
  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: AppColors.onSurfaceVariant,
        height: 1.5,
      );

  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: AppColors.onSurfaceVariant,
        height: 1.4,
      );

  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
        color: AppColors.onSurfaceVariant,
        height: 1.4,
      );

  // ── Label (Inter — Tiny Tags / Badges / Navigation) ──
  static TextStyle get labelLg => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.0,
        color: AppColors.onSurfaceVariant,
      );

  static TextStyle get labelMd => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: AppColors.onSurfaceVariant,
      );

  static TextStyle get labelSm => GoogleFonts.inter(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.5,
        color: AppColors.outline,
      );

  // ── Button Text ──
  static TextStyle get buttonPrimary => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.0,
        color: AppColors.onPrimary,
      );

  static TextStyle get buttonSecondary => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: AppColors.onSurface,
      );

  // ── Metric / Stat Values ──
  static TextStyle get metricLg => GoogleFonts.epilogue(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: -2.0,
        color: AppColors.primaryFixed,
        height: 1.0,
      );

  static TextStyle get metricMd => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.onSurface,
        height: 1.0,
      );

  static TextStyle get metricUnit => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: AppColors.onSurfaceVariant,
      );
}
