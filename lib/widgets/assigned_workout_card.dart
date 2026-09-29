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
/// Redesign goals vs. the previous version:
/// - ONE visual hero (the workout name) instead of five competing elements.
/// - No internal borders/dividers — spacing alone separates sections.
/// - Muscle tags collapsed to a glance (max 2 + "+n"), not a full row.
/// - Stats read as icon + value, not bare numbers next to a label.
/// - The CTA is unmistakably the most prominent thing on the card: full-
///   bleed Electric Volt gradient with a soft glow, so it reads as an
///   invitation to tap rather than a footnote.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final muscles = workout.targetMuscles.map(_muscleLabel).toList();
    final font = AppText.fontFamily(isArabic: isArabic);
    final visibleMuscles = muscles.take(2).toList();
    final extraCount = muscles.length - visibleMuscles.length;

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
              // ── Status badge (quiet — supports, doesn't compete) ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // Neutral status dot — informational; the volt
                            // stays on the CTA button only (2026-09-27).
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          l10n.assignedWorkoutTitle,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: AppColors.onPrimaryContainer,
                            fontFamily: font,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (visibleMuscles.isNotEmpty)
                    Text(
                      extraCount > 0
                          ? '${visibleMuscles.join(' · ')} +$extraCount'
                          : visibleMuscles.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        fontFamily: font,
                      ),
                    ),
                ],
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

              const SizedBox(height: 16),

              // ── Stats as icon + value chips — scannable, not a data row ──
              Row(
                children: [
                  _StatChip(
                    icon: Icons.fitness_center_rounded,
                    value: '${workout.exercises.length}',
                    font: font,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.repeat_rounded,
                    value: '${workout.totalSets}',
                    font: font,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.schedule_rounded,
                    value:
                        '~${workout.estimatedMinutes}${isArabic ? ' د' : 'm'}',
                    font: font,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── CTA — the most prominent element on the card ──
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: AppColors.primaryActionGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
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

/// Compact icon+value chip used for the stat row — reads at a glance,
/// no separate label needed since the icon carries the meaning.
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? font;

  const _StatChip({required this.icon, required this.value, this.font});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: font,
            ),
          ),
        ],
      ),
    );
  }
}
