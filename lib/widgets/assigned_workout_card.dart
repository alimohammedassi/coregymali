import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/assigned_workout_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_text.dart';

/// Today's coach-assigned workout card — the HERO of the workout page's
/// My Program tab and Home (the client entry point of the coach workflow).
///
/// Anatomy follows the calories-card design language (solid surface, flat
/// tinted squircle badge, no glows): an overline status row with a quiet
/// icon stamp, the biggest name on the page, muscle tags as neutral pills
/// carrying a semantic color dot, a hairline-divided 3-stat row (exercises /
/// sets / estimated time) and the standard volt CTA that spells out the
/// action (start — or resume when the session was already begun). The only
/// accent-tinted border on the page stays here — this card is THE active
/// commitment and reads as such in both modes. The whole card is tappable.
class AssignedWorkoutCard extends StatelessWidget {
  final AssignedWorkout workout;
  final bool isArabic;
  final VoidCallback onTap;

  const AssignedWorkoutCard({
    super.key,
    required this.workout,
    required this.isArabic,
    required this.onTap,
  });

  /// 'full_body' / 'Full Body' / 'CHEST' → 'Full Body' / 'Chest' for the
  /// semantic muscle-color lookup (same normalization as the detail screen).
  String _muscleLabel(String raw) {
    final cleaned = raw.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return cleaned;
    return cleaned
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final muscles = workout.targetMuscles.map(_muscleLabel).toList();
    final font = AppText.fontFamily(isArabic: isArabic);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            // The only accent-tinted border on the page — this card is THE
            // active commitment and reads as such in both modes.
            border: Border.all(color: AppColors.glassBorderActive, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Overline: status dot + label, icon stamp on the far end ──
              // The label stays inflexible: a Flexible here would split the
              // free space with the Spacer (both flex:1) and leave the stamp
              // floating mid-row instead of pinned to the far edge.
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.assignedWorkoutTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: AppColors.onPrimaryContainer,
                      fontFamily: font,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppColors.glassBorderActive),
                    ),
                    child: Icon(
                      Icons.fitness_center_rounded,
                      color: AppColors.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Name — the biggest text on the page ──
              Text(
                workout.templateName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                  fontFamily: font,
                ),
              ),

              if (muscles.isNotEmpty) ...[
                const SizedBox(height: 11),
                // Neutral pills — the muscle hue lives in a small dot so four
                // groups read as one calm row instead of a rainbow.
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in muscles.take(4))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppSemanticColors.forMuscle(m),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              m,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                fontFamily: font,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 15),
              Divider(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: 12),

              // ── Stat row: exercises · sets · estimated time ──
              Row(
                children: [
                  _Stat(
                    value: '${workout.exercises.length}',
                    label: l10n.assignedStatExercises,
                    isArabic: isArabic,
                  ),
                  _hairline(),
                  _Stat(
                    value: '${workout.totalSets}',
                    label: l10n.assignedStatSets,
                    isArabic: isArabic,
                  ),
                  _hairline(),
                  _Stat(
                    value: '~${workout.estimatedMinutes}${isArabic ? ' د' : ' min'}',
                    label: l10n.assignedStatTime,
                    isArabic: isArabic,
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // ── CTA — spells out the action; the whole card opens it too ──
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: AppColors.primaryActionGradient,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      workout.isResumable
                          ? Icons.play_arrow_rounded
                          : Icons.bolt_rounded,
                      size: 19,
                      color: AppColors.onPrimary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      workout.isResumable
                          ? l10n.assignedResume
                          : l10n.startWorkout,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onPrimary,
                        fontFamily: font,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hairline() => Container(
    width: 1,
    height: 26,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: AppColors.borderSubtle,
  );
}

/// One stat column: bold value over a muted label, centered.
class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool isArabic;

  const _Stat({
    required this.value,
    required this.label,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final font = AppText.fontFamily(isArabic: isArabic);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              height: 1,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontFamily: font,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              fontFamily: font,
            ),
          ),
        ],
      ),
    );
  }
}
