import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

import '../l10n/app_localizations.dart';
import '../services/assigned_workout_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'food_log_fab.dart';

/// Today's coach-assigned workout card — the HERO of the workout page's
/// My Program tab and Home.
///
/// 2026-10-01 restyle to the "next up protocol" look: accent status pill,
/// the muscle targets as a subtitle under the name, three labelled stat
/// tiles (Est. time / Exercises / Sets) and a 2-exercise preview with
/// sets × reps targets — same [AssignedWorkout] input, same tap contract,
/// same FAB obstruction reporting; data and behavior unchanged.
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

  String _muscleLabel(String raw) {
    final cleaned = raw.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return cleaned;
    return cleaned
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// "4 sets × 8-10"-style target from the exercise's plan; falls back to a
  /// bare sets count when the coach left reps unset.
  String _targetLabel(AppLocalizations l10n, AssignedExercise exercise) {
    final sets = '${exercise.targetSets}';
    final reps = exercise.targetReps;
    final weight = exercise.targetWeightKg;
    if (reps != null && reps > 0 && weight != null && weight > 0) {
      return l10n.assignedTargetWeight(sets, '$reps', _weightLabel(weight));
    }
    if (reps != null && reps > 0) {
      return l10n.assignedTarget(sets, '$reps');
    }
    return '$sets ${l10n.assignedStatSets}';
  }

  static String _weightLabel(double kg) =>
      kg == kg.roundToDouble() ? kg.round().toString() : kg.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final muscles = workout.targetMuscles
        .map(_muscleLabel)
        .where((m) => m.isNotEmpty)
        .toList();
    final font = AppText.fontFamily(isArabic: isArabic);
    final preview = workout.exercises.take(2).toList();
    final extraCount = workout.exercises.length - preview.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _FabObstructionReporter(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              // Unified card chrome shared with every Home card (2026-09-27):
              // radius 20, neutral hairline border, soft blur-12 elevation —
              // only the CTA inside carries the volt, nothing structural.
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status pill — solid accent with dark ink ("NEXT UP").
                // A tiny badge is the accent token's sanctioned micro-fill.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.assignedWorkoutTitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: AppColors.onPrimary,
                      fontFamily: font,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Name — the ONLY hero element on the card ──
                Text(
                  workout.templateName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                    fontFamily: font,
                  ),
                ),

                if (muscles.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    muscles.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      fontFamily: font,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Stat tiles — icon, value, label; one third each ──
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.schedule_rounded,
                        iconColor: AppColors.accent,
                        value:
                            '~${workout.estimatedMinutes}${isArabic ? ' د' : 'm'}',
                        label: l10n.assignedStatTime,
                        font: font,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.fitness_center_rounded,
                        iconColor: AppColors.secondary,
                        value: '${workout.exercises.length}',
                        label: l10n.assignedStatExercises,
                        font: font,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.repeat_rounded,
                        iconColor: AppColors.tertiary,
                        value: '${workout.totalSets}',
                        label: l10n.assignedStatSets,
                        font: font,
                      ),
                    ),
                  ],
                ),

                // ── Exercise preview — first 2 in template order ──
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  for (var i = 0; i < preview.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _ExercisePreviewRow(
                      index: i + 1,
                      name: preview[i].exerciseName,
                      target: _targetLabel(l10n, preview[i]),
                      font: font,
                    ),
                  ],
                  if (extraCount > 0) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 36),
                      child: Text(
                        '+$extraCount',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          fontFamily: font,
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 16),

                // ── CTA — the most prominent element on the card ──
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: AppColors.primaryActionGradient,
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
                      const SizedBox(width: 8),
                      Text(
                        workout.isResumable
                            ? l10n.assignedResume
                            : l10n.startWorkout,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onPrimary,
                          fontFamily: font,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isArabic
                            ? Icons.arrow_back_rounded
                            : Icons.arrow_forward_rounded,
                        size: 18,
                        color: AppColors.onPrimary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reports whether this card's on-screen rect intersects the floating
/// food-log button's rect, so the button can scale away instead of floating
/// over the card's text ("Back · Shoulder…" was clipped at rest on tall
/// viewports — no fixed FAB position above the nav bar clears a card this
/// tall on every screen height, 2026-09-27).
///
/// Home and the workout tab both mount this card inside IndexedStacks, so
/// only the instance on the tab that is actually painting (TickerMode) may
/// drive [FoodLogFab.obstructed]; a hidden instance's geometry is stale.
class _FabObstructionReporter extends StatefulWidget {
  final Widget child;

  const _FabObstructionReporter({required this.child});

  @override
  State<_FabObstructionReporter> createState() =>
      _FabObstructionReporterState();
}

class _FabObstructionReporterState extends State<_FabObstructionReporter> {
  final GlobalKey _boxKey = GlobalKey();

  ScrollPosition? _scrollPosition;
  bool _evaluateScheduled = false;

  /// Whether THIS mounted instance's tab is the one actually painting.
  /// Read in build so the TickerMode inherited dependency is registered —
  /// a tab switch flips it and re-runs didChangeDependencies → re-evaluate.
  bool _isActiveTab = true;

  @override
  void initState() {
    super.initState();
    _scheduleEvaluate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode.of / MediaQuery.sizeOf here both register dependencies, so
    // a tab switch (hidden ↔ painting) or a viewport change re-evaluates.
    _listenToScrollable();
    _scheduleEvaluate();
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_scheduleEvaluate);
    super.dispose();
  }

  /// The card lives inside a scroll view, so its screen rect changes without
  /// any rebuild — follow the scroll position instead.
  void _listenToScrollable() {
    ScrollPosition? position;
    try {
      position = Scrollable.of(context).position;
    } catch (_) {
      position = null; // not inside a scrollable — static placement
    }
    if (identical(position, _scrollPosition)) return;
    _scrollPosition?.removeListener(_scheduleEvaluate);
    _scrollPosition = position;
    position?.addListener(_scheduleEvaluate);
  }

  void _scheduleEvaluate() {
    if (_evaluateScheduled || !mounted) return;
    _evaluateScheduled = true;
    // localToGlobal is only valid after layout — never read it mid-frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _evaluateScheduled = false;
      if (mounted) _evaluate();
    });
  }

  void _evaluate() {
    bool obstructs = false;
    // Only the active tab's instance may write the shared flag; an
    // IndexedStack sibling keeps its stale geometry after a tab switch.
    if (_isActiveTab) {
      final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.attached && box.hasSize) {
        final screen = MediaQuery.sizeOf(context);
        final reserved = LiquidTabBar.reservedHeight(context);
        // Mirrors FoodLogFab's Positioned: right 18, 58 circle, bottom
        // reserved + 10 — inflated slightly so "just touching" still yields.
        final fabRect = Rect.fromLTWH(
          screen.width - 18 - 58,
          screen.height - reserved - 10 - 58,
          58,
          58,
        ).inflate(8);
        final cardRect = box.localToGlobal(Offset.zero) & box.size;
        obstructs = cardRect.overlaps(fabRect);
      }
    }
    if (FoodLogFab.obstructed.value != obstructs) {
      FoodLogFab.obstructed.value = obstructs;
    }
  }

  @override
  Widget build(BuildContext context) {
    _isActiveTab = TickerMode.valuesOf(context).enabled;
    return KeyedSubtree(key: _boxKey, child: widget.child);
  }
}

/// Labelled stat tile — icon on top, value, then the small label; one third
/// of the card's stat row.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String? font;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.font,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontFamily: font,
            ),
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

/// Numbered exercise preview row — name on the left, its sets × reps target
/// on the right, sitting in the same soft container as the stat tiles.
class _ExercisePreviewRow extends StatelessWidget {
  final int index;
  final String name;
  final String target;
  final String? font;

  const _ExercisePreviewRow({
    required this.index,
    required this.name,
    required this.target,
    this.font,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.onPrimary,
                fontFamily: font,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: font,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            target,
            style: TextStyle(
              fontSize: 11.5,
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
