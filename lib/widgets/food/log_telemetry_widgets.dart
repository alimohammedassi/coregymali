import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared "Telemetry • Log" chrome for the AI food-logging screens (text /
// voice / barcode) — Stitch redesign 2026-10-01. Pure presentation only:
// every screen keeps its own state, services and save flow.
// ─────────────────────────────────────────────────────────────────────────────

class MealSlotSpec {
  final String type;
  final IconData icon;
  const MealSlotSpec(this.type, this.icon);
}

const List<MealSlotSpec> kMealSlots = [
  MealSlotSpec('breakfast', Icons.wb_twilight_rounded),
  MealSlotSpec('lunch', Icons.light_mode_rounded),
  MealSlotSpec('dinner', Icons.dark_mode_rounded),
  MealSlotSpec('snack', Icons.bolt_rounded),
];

String mealSlotName(AppLocalizations l10n, String type) {
  switch (type) {
    case 'breakfast':
      return l10n.breakfast;
    case 'lunch':
      return l10n.lunch;
    case 'dinner':
      return l10n.dinner;
    default:
      return l10n.snack;
  }
}

/// App bar title block: volt caps tag over the screen title (design's
/// "TELEMETRY • LOG" header stack).
class TelemetryAppBarTitle extends StatelessWidget {
  final String tag;
  final String title;
  final bool isArabic;

  const TelemetryAppBarTitle({
    super.key,
    required this.tag,
    required this.title,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tag,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: isArabic ? 0.3 : 1.1,
            color: AppColors.onPrimaryContainer,
            fontFamily: AppText.fontFamily(isArabic: isArabic),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 19,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
            fontFamily: AppText.fontFamily(isArabic: isArabic),
          ),
        ),
      ],
    );
  }
}

/// Volt circle back button for AppBar.leading.
class TelemetryBackButton extends StatelessWidget {
  const TelemetryBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceContainerLow.withValues(alpha: 0.6),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 22,
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
    );
  }
}

/// Uppercase caps section label — letter-spacing on Latin only (letter
/// spacing breaks Arabic joining).
class TelemetryCapsLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final bool isArabic;
  final double fontSize;

  const TelemetryCapsLabel(
    this.text, {
    super.key,
    this.color,
    required this.isArabic,
    this.fontSize = 10.5,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: isArabic ? 0.2 : 0.9,
        color: color ?? AppColors.textSecondary,
        fontFamily: AppText.fontFamily(isArabic: isArabic),
      ),
    );
  }
}

/// 4-up meal slot grid (text log + barcode result) — icon tiles; the active
/// slot sits in a lifted container with the volt dot and volt label.
class MealSlotGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final bool isArabic;

  const MealSlotGrid({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < kMealSlots.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _tile(context, kMealSlots[i])),
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, MealSlotSpec slot) {
    final l10n = AppLocalizations.of(context)!;
    final sel = selected == slot.type;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect(slot.type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.surfaceContainerHigh
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Icon(
                    slot.icon,
                    size: 17,
                    color: sel
                        ? AppColors.onPrimaryContainer
                        : AppColors.textSecondary,
                  ),
                  const Spacer(),
                  if (sel)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              mealSlotName(l10n, slot.type),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                color: sel
                    ? AppColors.onPrimaryContainer
                    : AppColors.textPrimary,
                fontFamily: AppText.fontFamily(isArabic: isArabic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal-scroll meal slot cards (voice log) — the active card carries
/// a glowing volt dot in its corner and an ACTIVE pill.
class MealSlotCarousel extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final bool isArabic;

  const MealSlotCarousel({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: kMealSlots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final slot = kMealSlots[i];
          final sel = selected == slot.type;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(slot.type);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 132,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.surfaceContainerHigh
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        slot.icon,
                        size: 19,
                        color: sel
                            ? AppColors.onPrimaryContainer
                            : AppColors.textSecondary,
                      ),
                      const Spacer(),
                      Text(
                        mealSlotName(l10n, slot.type),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: sel
                              ? AppColors.onPrimaryContainer
                              : AppColors.textPrimary,
                          fontFamily: AppText.fontFamily(isArabic: isArabic),
                        ),
                      ),
                    ],
                  ),
                  PositionedDirectional(
                    top: -2,
                    end: -2,
                    child: sel
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.8,
                                  ),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Solid volt primary button (design's kinetic CTA) — [onTap] == null gives
/// the disabled ghost styling.
class TelemetryPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isArabic;

  const TelemetryPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isArabic,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: enabled ? AppColors.primary : AppColors.surfaceContainerHigh,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 22,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 21,
                      color: enabled
                          ? AppColors.onPrimary
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: enabled
                              ? AppColors.onPrimary
                              : AppColors.textMuted,
                          fontFamily: AppText.fontFamily(isArabic: isArabic),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
