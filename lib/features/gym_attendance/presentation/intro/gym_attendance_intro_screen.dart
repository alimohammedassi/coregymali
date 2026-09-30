import 'dart:ui' show lerpDouble;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_animations.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';

/// Static explainer that opens the gym-attendance setup: what automatic
/// attendance is, the one rule that governs it, and the privacy promise.
///
/// AppBar-less and immersive like the auth/onboarding screens; the flow host
/// decides how [onLater] exits. The compact glyph reuses the pin + geofence
/// ring motif from the permission steps.
class GymAttendanceIntroScreen extends StatefulWidget {
  const GymAttendanceIntroScreen({
    super.key,
    required this.onStart,
    this.onLater,
  });

  final VoidCallback onStart;
  final VoidCallback? onLater;

  @override
  State<GymAttendanceIntroScreen> createState() =>
      _GymAttendanceIntroScreenState();
}

class _GymAttendanceIntroScreenState extends State<GymAttendanceIntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glyph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _glyph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: _IntroPinGlyph(controller: _glyph),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      l10n.gymAttIntroTitle,
                      style: TextStyle(
                        fontFamily: AppText.fontFamily(isArabic: isArabic),
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.gymAttIntroBody,
                      style: TextStyle(
                        fontFamily: AppText.fontFamily(isArabic: isArabic),
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // "How it works" — one grouped card, standard chrome.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.glassBorder),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cardShadow,
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.route_rounded,
                                size: 18,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.gymAttIntroRuleTitle,
                                  style: TextStyle(
                                    fontFamily: AppText.fontFamily(
                                      isArabic: isArabic,
                                    ),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.gymAttIntroRuleBody,
                            style: TextStyle(
                              fontFamily: AppText.fontFamily(
                                isArabic: isArabic,
                              ),
                              fontSize: 13.5,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Privacy promise — quiet tertiary line with a shield.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.gymAttIntroPrivacy,
                            style: TextStyle(
                              fontFamily: AppText.fontFamily(
                                isArabic: isArabic,
                              ),
                              fontSize: 12,
                              height: 1.45,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom CTA stack ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onStart();
                    },
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryActionGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryFixed
                                .withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        l10n.gymAttIntroCta,
                        style: TextStyle(
                          fontFamily: AppText.fontFamily(isArabic: isArabic),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (widget.onLater != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: widget.onLater,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        l10n.gymAttPermSkip,
                        style: TextStyle(
                          fontFamily: AppText.fontFamily(isArabic: isArabic),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact intro glyph — the pin + geofence ring motif from the permission
// steps, simplified: a pin holding position while rings ping outward around
// it. Reduced motion shows the settled pose.
// ─────────────────────────────────────────────────────────────────────────────
class _IntroPinGlyph extends StatelessWidget {
  final AnimationController controller;

  const _IntroPinGlyph({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return CustomPaint(
        size: const Size(190, 130),
        painter: _IntroPinPainter(0.25),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        size: const Size(190, 130),
        painter: _IntroPinPainter(controller.value),
      ),
    );
  }
}

class _IntroPinPainter extends CustomPainter {
  final double t;

  _IntroPinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.40);

    // Two staggered pings breathing around the pin.
    for (final (start, radius) in [(0.0, 58.0), (0.5, 44.0)]) {
      final p = ((t - start) % 1.0);
      final eased = AppCurves.standard.transform(p);
      canvas.drawCircle(
        center,
        lerpDouble(16, radius, eased)!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.accent.withValues(alpha: (1 - eased) * 0.35),
      );
    }

    // Steady geofence ring.
    canvas.drawCircle(
      center,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.accent.withValues(alpha: 0.6),
    );

    // Gentle pin bob.
    final bob = math.sin(t * 2 * math.pi) * 2.5;
    final headCenter = Offset(center.dx, center.dy - 8 + bob);
    final pinPaint = Paint()..color = AppColors.accent;

    final pinPath = Path()
      ..moveTo(center.dx, center.dy + 16 + bob)
      ..quadraticBezierTo(
        headCenter.dx - 14,
        headCenter.dy + 2,
        headCenter.dx,
        headCenter.dy,
      )
      ..quadraticBezierTo(
        headCenter.dx + 14,
        headCenter.dy + 2,
        center.dx,
        center.dy + 16 + bob,
      )
      ..close();
    canvas.drawCircle(headCenter, 12, pinPaint);
    canvas.drawPath(pinPath, pinPaint);
    canvas.drawCircle(
      headCenter,
      4.5,
      Paint()..color = AppColors.onPrimary,
    );
  }

  @override
  bool shouldRepaint(_IntroPinPainter oldDelegate) => oldDelegate.t != t;
}
