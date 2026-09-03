import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Kinetic Obsidian — App Typography System
/// English: Poppins (Clean, rounded, friendly, modern)
/// Arabic: Cairo (Bold, crisp, geometric Arabic typography)
/// (Auth/splash/onboarding use AuthAppText: Epilogue display + Inter labels.)
class AppText {
  AppText._();

  /// Gets the font family based on whether the active locale is Arabic
  static String? fontFamily({bool isArabic = false}) {
    return isArabic
        ? GoogleFonts.cairo().fontFamily
        : GoogleFonts.poppins().fontFamily;
  }

  // ── Display (Huge Bold Hero Numbers: Calories, Weights) ──
  static TextStyle get displayLg => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: AppColors.textPrimary,
        height: 1.05,
      );

  static TextStyle get displayMd => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: AppColors.textPrimary,
        height: 1.1,
      );

  static TextStyle get displaySm => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
        height: 1.15,
      );

  // ── Headline (Section Titles & Hero Card Headers) ──
  static TextStyle get headlineLg => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle get headlineMd => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.25,
      );

  static TextStyle get headlineSm => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  // ── Titles (Card Headers / Metric Titles) ──
  static TextStyle get titleLg => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleMd => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleSm => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // ── Body (Readable Content & Subtitles) ──
  static TextStyle get bodyLg => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.45,
      );

  static TextStyle get bodyMd => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  static TextStyle get bodySm => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
        height: 1.35,
      );

  // ── Labels & Micro-Pills (Badges, Macros, Date Strip) ──
  static TextStyle get labelLg => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelMd => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );

  static TextStyle get labelSm => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      );

  // ── Button Text ──
  // Ink on the volt fill — never white (fails contrast on #D1FC00).
  static TextStyle get buttonPrimary => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: AppColors.onPrimary,
      );

  static TextStyle get buttonSecondary => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryGreen,
      );

  // ── Metric / Stat Values ──
  static TextStyle get metricLg => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 48,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
        color: AppColors.primaryGreen,
        height: 1.0,
      );

  static TextStyle get metricMd => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
        height: 1.0,
      );

  static TextStyle get metricUnit => TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      );

  // ── Configurable Helper Methods ──
  static TextStyle styledDisplayMd({bool isArabic = false, Color? color}) =>
      TextStyle(
        fontFamily: fontFamily(isArabic: isArabic),
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: color ?? AppColors.textPrimary,
        height: 1.1,
      );
  static TextStyle styleddisplayMd({bool isArabic = false, Color? color}) =>
      styledDisplayMd(isArabic: isArabic, color: color);

  static TextStyle styledHeadlineMd({bool isArabic = false, Color? color}) =>
      TextStyle(
        fontFamily: fontFamily(isArabic: isArabic),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimary,
        height: 1.25,
      );
  static TextStyle styledheadlineMd({bool isArabic = false, Color? color}) =>
      styledHeadlineMd(isArabic: isArabic, color: color);

  static TextStyle styledHeadlineSm({bool isArabic = false, Color? color}) =>
      TextStyle(
        fontFamily: fontFamily(isArabic: isArabic),
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimary,
        height: 1.3,
      );
  static TextStyle styledheadlineSm({bool isArabic = false, Color? color}) =>
      styledHeadlineSm(isArabic: isArabic, color: color);

  static TextStyle styledTitleMd({bool isArabic = false, Color? color}) =>
      TextStyle(
        fontFamily: fontFamily(isArabic: isArabic),
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
      );
  static TextStyle styledtitleMd({bool isArabic = false, Color? color}) =>
      styledTitleMd(isArabic: isArabic, color: color);

  static TextStyle styledTitleSm({bool isArabic = false, Color? color}) =>
      TextStyle(
        fontFamily: fontFamily(isArabic: isArabic),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
      );
  static TextStyle styledtitleSm({bool isArabic = false, Color? color}) =>
      styledTitleSm(isArabic: isArabic, color: color);

  static TextStyle styledBodySm({bool isArabic = false, Color? color}) =>
      TextStyle(
        fontFamily: fontFamily(isArabic: isArabic),
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textMuted,
        height: 1.35,
      );
  static TextStyle styledbodySm({bool isArabic = false, Color? color}) =>
      styledBodySm(isArabic: isArabic, color: color);

  static TextStyle styledLabelLg({bool isArabic = false, Color? color}) =>
      TextStyle(
        fontFamily: fontFamily(isArabic: isArabic),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: color ?? AppColors.textPrimary,
      );
  static TextStyle styledlabelLg({bool isArabic = false, Color? color}) =>
      styledLabelLg(isArabic: isArabic, color: color);
}
