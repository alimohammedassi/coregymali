import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/assigned_workout_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_text.dart';

/// Today's coach-assigned workout card — the HERO of the workout page's
/// My Program tab (and the client entry point of the coach workflow).
///
/// Designed to outrank every other card on the tab: volt-tinted border +
/// lime glow, gradient icon tile, the biggest name on the page, a divided
/// 3-stat row (exercises / sets / estimated time) and a full-width lime CTA
/// that spells out the action (start — or resume when the session was
/// already begun). The whole card is tappable.
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
            borderRadius: BorderRadius.circular(24),
            // The only accent-tinted border on the tab — this card is THE
            // active commitment and reads as such in both modes.
            border: Border.all(color: AppColors.glassBorderActive, width: 1.3),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.primaryGlow,
                blurRadius: 22,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Eyebrow: gradient tile + badge + chevron ──
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryActionGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryFixed.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.fitness_center_rounded,
                      color: AppColors.onPrimary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              l10n.assignedWorkoutTitle,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: AppColors.onPrimaryContainer,
                                fontFamily: font,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          workout.isResumable
                              ? l10n.assignedResume
                              : l10n.assignedReadyHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                            fontFamily: font,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Name — the biggest text on the tab ──
              Text(
                workout.templateName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                  fontFamily: font,
                ),
              ),

              if (muscles.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in muscles.take(4))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppSemanticColors.forMuscle(
                            m,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          m,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppSemanticColors.forMuscle(m),
                            fontFamily: font,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: 12),

              // ── Stat row: exercises · sets · estimated time ──
              Row(
                children: [
                  _Stat(
                    icon: Icons.list_alt_rounded,
                    value: '${workout.exercises.length}',
                    label: l10n.assignedStatExercises,
                    isArabic: isArabic,
                  ),
                  _divider(),
                  _Stat(
                    icon: Icons.repeat_rounded,
                    value: '${workout.totalSets}',
                    label: l10n.assignedStatSets,
                    isArabic: isArabic,
                  ),
                  _divider(),
                  _Stat(
                    icon: Icons.schedule_rounded,
                    value: '~${workout.estimatedMinutes}${isArabic ? ' د' : ' min'}',
                    label: l10n.assignedStatTime,
                    isArabic: isArabic,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── CTA — spells out the action; the whole card opens it too ──
              Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: AppColors.primaryActionGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryFixed.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      workout.isResumable
                          ? Icons.play_arrow_rounded
                          : Icons.bolt_rounded,
                      size: 20,
                      color: AppColors.onPrimary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      workout.isResumable
                          ? l10n.assignedResume
                          : l10n.startWorkout,
                      style: TextStyle(
                        fontSize: 13.5,
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

  Widget _divider() => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: AppColors.borderSubtle,
  );
}

/// One stat column: icon + bold value over a muted label, centered.
class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isArabic;

  const _Stat({
    required this.icon,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    fontFamily: font,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
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
