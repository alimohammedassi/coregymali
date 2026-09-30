import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_animations.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';

/// Shared scaffold for the gym-attendance permission onboarding steps.
///
/// Layout contract (top to bottom):
///  1. Animation area — the top ~35% of the body, centered large glyph.
///  2. Headline + optional "Enabled" success chip (when [granted]).
///  3. Body paragraph.
///  4. "Why" micro-copy in a subtle container with an info icon.
///  5. Full-width primary CTA (AuthPrimaryButton chrome) + optional
///     secondary text button pinned to the bottom.
///
/// [granted] only switches the rendered success states (chip + CTA check);
/// the owning screen handles the request timing and then advances.
class PermissionOnboardingStep extends StatefulWidget {
  const PermissionOnboardingStep({
    super.key,
    required this.animation,
    required this.title,
    required this.body,
    required this.whyLine,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.granted = false,
  });

  final Widget animation;
  final String title;
  final String body;
  final String whyLine;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Shows the "Enabled" chip near the title and turns the primary CTA into
  /// a success state (check icon + label) for the hand-off moment.
  final bool granted;

  @override
  State<PermissionOnboardingStep> createState() =>
      _PermissionOnboardingStepState();
}

class _PermissionOnboardingStepState extends State<PermissionOnboardingStep> {
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
            // ── Animation area — top ~35% ──
            Expanded(
              flex: 35,
              child: Center(child: widget.animation),
            ),

            // ── Copy block ──
            Expanded(
              flex: 65,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Headline + granted chip
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              fontFamily: AppText.fontFamily(
                                isArabic: isArabic,
                              ),
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _GrantedChip(
                          label: l10n.gymAttPermGranted,
                          isArabic: isArabic,
                          visible: widget.granted,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      widget.body,
                      style: TextStyle(
                        fontFamily: AppText.fontFamily(isArabic: isArabic),
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    _WhyLine(text: widget.whyLine, isArabic: isArabic),
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
                  _PrimaryCta(
                    label: widget.granted
                        ? l10n.gymAttPermGranted
                        : widget.primaryLabel,
                    isArabic: isArabic,
                    granted: widget.granted,
                    onTap: widget.granted ? null : widget.onPrimary,
                  ),
                  if (widget.secondaryLabel != null &&
                      widget.onSecondary != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: widget.onSecondary,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        widget.secondaryLabel!,
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

/// Small "Enabled ✓" pill shown next to the headline once the permission
/// resolves — success reads as lime-tinted glass, never an emoji.
class _GrantedChip extends StatelessWidget {
  final String label;
  final bool isArabic;
  final bool visible;

  const _GrantedChip({
    required this.label,
    required this.isArabic,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1.0 : 0.6,
      duration: AppDurations.medium,
      curve: AppCurves.overshoot,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: AppDurations.medium,
        curve: AppCurves.standard,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.glassBorderActive),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_rounded,
                size: 14,
                color: AppColors.onPrimaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppText.fontFamily(isArabic: isArabic),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Why we need this" micro-copy — quiet container with an info icon,
/// matching the app's secondary/muted hierarchy.
class _WhyLine extends StatelessWidget {
  final String text;
  final bool isArabic;

  const _WhyLine({required this.text, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppText.fontFamily(isArabic: isArabic),
                fontSize: 12,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width primary CTA — same chrome as [AuthPrimaryButton] (lime
/// gradient fill + near-black ink, radius 16, soft lime glow), extended
/// with the success state (check icon + label) used during the granted
/// hand-off.
class _PrimaryCta extends StatelessWidget {
  final String label;
  final bool isArabic;
  final bool granted;
  final VoidCallback? onTap;

  const _PrimaryCta({
    required this.label,
    required this.isArabic,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.primaryActionGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryFixed.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: AppDurations.fast,
            child: granted
                ? Row(
                    key: const ValueKey('granted'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: AppColors.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: AppText.fontFamily(isArabic: isArabic),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  )
                : Text(
                    label,
                    key: const ValueKey('label'),
                    style: TextStyle(
                      fontFamily: AppText.fontFamily(isArabic: isArabic),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
