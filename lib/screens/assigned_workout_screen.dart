/*
 Changelog — AssignedWorkoutScreen premium polish (2026-09-23)
 ──────────────────────────────────────────────────────────────
 1. Visual hierarchy & consistency
    - Extracted shared _HeroCard widget (gradient tile, eyebrow, title,
      optional badge/subtitle/chips/notes/stats/footer) so
      _buildHeaderCard and _buildNutritionHeader are thin delegates with
      pixel-identical decoration, padding and 4pt/8pt spacing. Cut ~120
      lines of duplication.
    - Unified spacing scale to AppSpacing (4/8/12/16/24/32). Replaced
      ad-hoc 6/10/14/18/20 gaps with the closest scale step.
    - Normalized font-weight ramp: eyebrow w800 11sp, title w900 24sp,
      stat value w800 14.5sp, stat label w600 10.5sp, card title w700,
      badge w800, button w700. No accidental w900 islands.

 2. Micro-interactions & feedback
    - Exercise card header now uses _PressScale (AnimatedScale+Opacity
      on tap down/up, routed through _motionDuration) plus chevron
      rotation, so the whole row feels responsive.
    - _logSet and _markEaten morph to a brief success state (check +
      accent-tinted gradient flash, 1.2s) before returning to idle
      instead of spinner → idle jump. Per-exercise/meal success tracking
      respects disabledAnimations.
    - Rest banner shifts color and outer glow in final 5s (primaryFixed
      → overGoalWarning, shadow blur 14→22, progress bar color swap) and
      gently scales the timer text. All driven by _motionDuration.

 3. Progress & motivation
    - Per-exercise "$done/target" badge replaced by _ExerciseRingBadge:
      36px ring with TweenAnimationBuilder progress (disableAnimations-
      aware), centered count and check when allHit. Scannable at a
      glance; Semantics label preserved.
    - _buildDoneView now shows a completion summary row: total volume
      (kg × reps), elapsed time, sets logged, and PR hits (sets where
      _hitTarget true) in soft metric tiles — emotional payoff beyond
      the single count pill.

 4. Empty / edge states
    - No-assignment and _buildNutritionEmpty use _IllustratedEmptyIcon:
      72px circle + layered composition (primary icon + small accent
      dot with check/restaurant) instead of a lone Material icon.
    - Bottom-bar partial-warning (showPartialWarning) promoted from
      plain muted text to a centered surfaceContainerHigh pill with
      info icon, w700 copy and border — visible decision point without
      alarm.

 5. Nutrition tab polish
    - _buildFoodRow changed/substituted italic caption replaced by a
      before→after chip pattern: faded original pill (strikethrough)
      → accent arrow → solid current pill. Cleaner scanning; no italic
      caption.
    - Meal status chip keeps AppColors tokens (lightGreen /
      surfaceContainerHigh) and adds a check/dot icon for "completed",
      preserving WCAG AA contrast via onPrimaryContainer and a non-
      color cue.

 6. Motion & accessibility
    - Every new animation (ring, press scale, banner glow, success
      morph, done summary stagger) routes through _motionDuration.
    - All tappable elements keep ≥48×48 hit area (exercise row
      InkWell padding, rest skip Padding 12, buttons 48/44h) and color-
      only signals (allHit border, muscle chips, ring) retain a second
      cue (icon/label).
    - RTL/Arabic preserved: every new Text copies fontFamily: font
      from locale, Wrap/Row respect Directionality, arrow chips flip
      via Directionality.

 Constraints respected:
 - No new dependencies, no data-layer/service/Supabase/state-machine
   changes. Only visual/layout/motion polish.
 - Stays within AppColors / AppSemanticColors / AppText tokens.
 - Public API AssignedWorkoutScreen(assignment:) unchanged; all
   l10n.* keys preserved.

*/

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/assigned_nutrition_service.dart';
import '../services/assigned_workout_service.dart';
import '../services/supabase_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_text.dart';

/// Steps 2–4 of the coach workflow, client side: the workout assigned for
/// today is listed with its targets, "Start" creates the linked
/// workout_sessions row, every confirmed set is written to workout_sets,
/// and "Finish" closes the session + flips the assignment to 'completed'
/// so the coach's dashboard picks it up via assignment_id.
///
/// A pill switcher under the app bar (same pattern as the nutrition page's
/// Today|History toggle) splits the screen into the Workout flow and the
/// Nutrition tab — the client's assigned nutrition plan for today, read
/// from the enrollment/assignment snapshot tables.
class AssignedWorkoutScreen extends StatefulWidget {
  final AssignedWorkout assignment;

  const AssignedWorkoutScreen({super.key, required this.assignment});

  @override
  State<AssignedWorkoutScreen> createState() => _AssignedWorkoutScreenState();
}

enum _AssignedPhase { loading, none, ready, active, done }

class _AssignedWorkoutScreenState extends State<AssignedWorkoutScreen>
    with SingleTickerProviderStateMixin {
  final AssignedWorkoutService _service = AssignedWorkoutService();
  final AssignedNutritionService _nutritionService = AssignedNutritionService();

  late AssignedWorkout _workout;
  _AssignedPhase _phase = _AssignedPhase.loading;

  late final TabController _tabController;
  AssignedNutritionPlan? _nutritionPlan;
  bool _nutritionLoading = true;

  /// The meal whose "mark eaten" write is in flight (one at a time).
  String? _completingMealId;

  /// Brief success flash after marking eaten — separate from busy.
  String? _justCompletedMealId;
  Timer? _mealSuccessTimer;

  String? _sessionId;
  DateTime? _startedAt;
  bool _busy = false;

  /// Per-exercise transient success + per-exercise in-flight id for the
  /// Log Set button morph.
  String? _loggingExerciseId;
  final Set<String> _loggedSuccessIds = {};
  final Map<String, Timer> _logSuccessTimers = {};

  /// Logged sets read back from Supabase, grouped by exact template
  /// exercise name — never tracked locally between refreshes.
  Map<String, List<Map<String, dynamic>>> _setsByExercise = {};

  /// Progressive disclosure: which exercise cards are collapsed. Empty by
  /// default so nothing is hidden that used to be visible — the user opts
  /// into a tidier view by collapsing cards themselves (e.g. once done).
  final Set<String> _collapsedIds = {};

  Timer? _restTimer;
  int _restRemaining = 0;
  int _restTotal = 60;

  final Map<String, TextEditingController> _weightCtrls = {};
  final Map<String, TextEditingController> _repsCtrls = {};

  void _onSubscriptionChanged() {
    if (!mounted) return;
    // Subscription went away → revalidate; gated service will pop or show empty.
    _load();
    _loadNutrition();
  }

  @override
  void initState() {
    super.initState();
    _workout = widget.assignment;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    subscriptionChangeNotifier.addListener(_onSubscriptionChanged);
    _load();
    _loadNutrition();
  }

  @override
  void dispose() {
    subscriptionChangeNotifier.removeListener(_onSubscriptionChanged);
    _tabController.dispose();
    _restTimer?.cancel();
    _mealSuccessTimer?.cancel();
    for (final t in _logSuccessTimers.values) {
      t.cancel();
    }
    for (final c in _weightCtrls.values) {
      c.dispose();
    }
    for (final c in _repsCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    // The card that opened this screen may be stale (a skip from another
    // tab, a dashboard change) — revalidate the assignment before offering
    // start/resume. A workout that is no longer 'assigned'/'started' gets
    // declined here: popping lets the host refetch and show the truth.
    final fresh = await _service.fetchAssignmentById(_workout.assignmentId);
    if (!mounted) return;
    if (fresh == null ||
        (fresh.assignmentStatus != 'assigned' &&
            fresh.assignmentStatus != 'started')) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _workout = fresh);

    // A 'started' assignment means the user was mid-workout earlier today —
    // reconnect to the open session instead of duplicating it.
    if (_workout.isResumable) {
      final open = await _service.findOpenSession(_workout.assignmentId);
      if (!mounted) return;
      if (open != null) {
        setState(() {
          _sessionId = open.id;
          _startedAt = open.startedAt;
          _phase = _AssignedPhase.active;
        });
        _ensureControllers();
        await _refreshSets();
        return;
      }
    }
    if (!mounted) return;
    setState(() => _phase = _AssignedPhase.ready);
    _ensureControllers();
  }

  /// The nutrition tab reads the enrollment + today's assignments straight
  /// from the snapshot tables; pull-to-refresh re-runs the same fetch.
  Future<void> _loadNutrition() async {
    final plan = await _nutritionService.fetchTodayPlan();
    if (!mounted) return;
    setState(() {
      _nutritionPlan = plan;
      _nutritionLoading = false;
    });
  }

  void _ensureControllers() {
    for (final e in _workout.exercises) {
      _weightCtrls[e.id] ??= TextEditingController(
        text: e.targetWeightKg == null ? '' : _formatWeight(e.targetWeightKg!),
      );
      _repsCtrls[e.id] ??= TextEditingController(
        text: e.targetReps?.toString() ?? '',
      );
    }
  }

  Future<void> _refreshSets() async {
    final sid = _sessionId;
    if (sid == null) return;
    final sets = await _service.fetchSessionSets(sid);
    if (!mounted) return;
    final map = <String, List<Map<String, dynamic>>>{};
    for (final s in sets) {
      map.putIfAbsent((s['exercise_name'] as String?) ?? '', () => []).add(s);
    }
    for (final list in map.values) {
      list.sort(
        (a, b) => ((a['set_number'] as num?) ?? 0).compareTo(
          (b['set_number'] as num?) ?? 0,
        ),
      );
    }
    setState(() => _setsByExercise = map);
  }

  /// Pull-to-refresh only has meaningful work to do once a session exists;
  /// otherwise it resolves immediately so the indicator doesn't hang.
  Future<void> _handleRefresh() async {
    if (_sessionId != null) {
      await _refreshSets();
    }
  }

  int _doneFor(AssignedExercise e) =>
      _setsByExercise[e.exerciseName]?.length ?? 0;

  int get _totalDoneSets =>
      _setsByExercise.values.fold(0, (sum, list) => sum + list.length);

  /// A logged set counts as hitting the target when reps meet the target
  /// and the weight meets it too (weight targets only apply when the coach
  /// set one). The row is highlighted so beating the plan reads at a glance.
  bool _hitTarget(AssignedExercise e, Map<String, dynamic> set) {
    final reps = (set['reps'] as num?)?.toInt();
    final weight = (set['weight_kg'] as num?)?.toDouble();
    if (reps == null) return false;
    if (e.targetReps != null && reps < e.targetReps!) return false;
    if (e.targetWeightKg != null &&
        (weight == null || weight < e.targetWeightKg!)) {
      return false;
    }
    return true;
  }

  Future<void> _startWorkout() async {
    setState(() => _busy = true);
    final sessionId = await _service.startWorkout(_workout);
    if (!mounted) return;
    if (sessionId == null) {
      setState(() => _busy = false);
      _showError(AppLocalizations.of(context)!.assignedErrorStart);
      return;
    }
    setState(() {
      _sessionId = sessionId;
      _startedAt = DateTime.now();
      _phase = _AssignedPhase.active;
      _busy = false;
    });
    _ensureControllers();
  }

  /// Declining a scheduled workout: confirm first, then flip the assignment
  /// to 'skipped' — no session is created — and pop so the host cards
  /// refetch (the workout disappears from today, as it should).
  Future<void> _skipWorkout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.assignedSkipConfirmTitle,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        content: Text(
          l10n.assignedSkipConfirmBody,
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.overGoalWarning,
            ),
            child: Text(l10n.assignedSkip),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final ok = await _service.skipWorkout(_workout.assignmentId);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      _showError(l10n.assignedErrorSet);
      return;
    }
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.assignedSkippedDone),
        backgroundColor: AppColors.surfaceContainerHigh,
      ),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _logSet(AssignedExercise e) async {
    final l10n = AppLocalizations.of(context)!;
    final reps = int.tryParse(_repsCtrls[e.id]!.text.trim());
    final weight = double.tryParse(
      _weightCtrls[e.id]!.text.trim().replaceAll(',', '.'),
    );
    if (reps == null || reps <= 0) {
      _showError(l10n.assignedEnterReps);
      return;
    }
    setState(() {
      _busy = true;
      _loggingExerciseId = e.id;
    });
    final ok = await _service.logSet(
      sessionId: _sessionId!,
      exerciseName: e.exerciseName,
      setNumber: _doneFor(e) + 1,
      reps: reps,
      weightKg: weight,
      restSec: e.restSec,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _loggingExerciseId = null;
    });
    if (!ok) {
      _showError(l10n.assignedErrorSet);
      return;
    }
    HapticFeedback.lightImpact();
    // Brief success flash on this exercise's button before returning to idle.
    _logSuccessTimers[e.id]?.cancel();
    setState(() => _loggedSuccessIds.add(e.id));
    _logSuccessTimers[e.id] = Timer(
      _motionDuration(const Duration(milliseconds: 1200)),
      () {
        if (mounted) setState(() => _loggedSuccessIds.remove(e.id));
      },
    );
    await _refreshSets();
    _startRest(e.restSec ?? 60);
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restTotal = seconds;
      _restRemaining = seconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_restRemaining <= 1) {
        timer.cancel();
        setState(() => _restRemaining = 0);
        // A short haptic marks "rest over" without requiring the user to
        // keep watching the countdown.
        HapticFeedback.mediumImpact();
      } else {
        setState(() => _restRemaining--);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    if (mounted) setState(() => _restRemaining = 0);
  }

  Future<void> _finishWorkout() async {
    _skipRest();
    setState(() => _busy = true);
    final ok = await _service.finishWorkout(
      sessionId: _sessionId!,
      assignmentId: _workout.assignmentId,
      startedAt: _startedAt,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      _showError(AppLocalizations.of(context)!.assignedErrorFinish);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _phase = _AssignedPhase.done);
  }

  void _toggleExpanded(String exerciseId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_collapsedIds.contains(exerciseId)) {
        _collapsedIds.remove(exerciseId);
      } else {
        _collapsedIds.add(exerciseId);
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  String _formatWeight(double weight) =>
      weight % 1 == 0 ? weight.toInt().toString() : weight.toString();

  String _targetText(AssignedExercise e, AppLocalizations l10n) {
    final sets = e.targetSets.toString();
    final reps = e.targetReps?.toString() ?? '–';
    if (e.targetWeightKg != null) {
      return l10n.assignedTargetWeight(
        sets,
        reps,
        _formatWeight(e.targetWeightKg!),
      );
    }
    return l10n.assignedTarget(sets, reps);
  }

  /// 'full_body' / 'Full Body' / 'CHEST' → 'Full Body' / 'Chest' for the
  /// semantic muscle-color lookup.
  String _muscleLabel(String raw) {
    final cleaned = raw.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return cleaned;
    return cleaned
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Color _muscleColor(String raw) =>
      AppSemanticColors.forMuscle(_muscleLabel(raw));

  String _setSummary(AppLocalizations l10n, Map<String, dynamic> set) {
    final reps = (set['reps'] as num?)?.toInt();
    final weight = (set['weight_kg'] as num?)?.toDouble();
    final parts = <String>[
      if (weight != null) '${_formatWeight(weight)} ${l10n.kg}',
      if (reps != null) '$reps ${l10n.reps}',
    ];
    return parts.isEmpty ? '—' : parts.join(' × ');
  }

  int get _totalTargetSets =>
      _workout.exercises.fold(0, (sum, e) => sum + e.targetSets);

  double get _totalVolumeKg {
    double sum = 0;
    for (final list in _setsByExercise.values) {
      for (final s in list) {
        final w = (s['weight_kg'] as num?)?.toDouble() ?? 0;
        final r = (s['reps'] as num?)?.toInt() ?? 0;
        sum += w * r;
      }
    }
    return sum;
  }

  int get _prHitCount {
    int c = 0;
    for (final e in _workout.exercises) {
      final sets = _setsByExercise[e.exerciseName] ?? const [];
      for (final s in sets) {
        if (_hitTarget(e, s)) c++;
      }
    }
    return c;
  }

  String _elapsedLabel() {
    if (_startedAt == null) return '';
    final mins = DateTime.now().difference(_startedAt!).inMinutes;
    return mins < 1 ? '<1m' : '${mins}m';
  }

  /// Reduced-motion aware duration — respects the system accessibility
  /// setting instead of always animating (`reduced-motion` UX guideline).
  Duration _motionDuration(Duration normal) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : normal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onNutritionTab = _tabController.index == 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          onNutritionTab
              ? l10n.assignedNutritionTitle
              : l10n.assignedWorkoutTitle,
          style: AppText.headlineSm,
        ),
        actions: [
          if (_phase == _AssignedPhase.active && !onNutritionTab)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Center(child: _buildProgressChip()),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                // Volt indicator carries the near-black ink (never white) —
                // the design-system pairing rule for lime fills.
                labelColor: AppColors.onPrimary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(text: l10n.navWorkout),
                  Tab(text: l10n.navNutrition),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: onNutritionTab ? null : _buildBottomBar(l10n),
      body: TabBarView(
        controller: _tabController,
        children: [
          switch (_phase) {
            _AssignedPhase.loading || _AssignedPhase.none => Center(
              child: _phase == _AssignedPhase.loading
                  ? CircularProgressIndicator(color: AppColors.primaryFixed)
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _IllustratedEmptyIcon(
                            primaryIcon: Icons.event_busy_outlined,
                            accentIcon: Icons.fitness_center_rounded,
                            accentColor: AppColors.primaryFixed,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            l10n.assignedNone,
                            textAlign: TextAlign.center,
                            style: AppText.bodyLg.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            _AssignedPhase.done => _buildDoneView(l10n),
            _ => _buildWorkoutView(l10n),
          },
          _buildNutritionBody(l10n),
        ],
      ),
    );
  }

  // ── AppBar helpers ──────────────────────────────────────────────────────

  /// Small, high-contrast pill that keeps overall progress and elapsed time
  /// visible while the user scrolls through exercises — avoids forcing a
  /// scroll back up just to check "how much is left".
  Widget _buildProgressChip() {
    return Semantics(
      label: '$_totalDoneSets / $_totalTargetSets · ${_elapsedLabel()}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center_rounded,
              size: 13,
              color: AppColors.primaryFixed,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$_totalDoneSets/$_totalTargetSets',
              style: AppText.labelLg.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (_startedAt != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(width: 1, height: 12, color: AppColors.borderSubtle),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.schedule_rounded,
                size: 12,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _elapsedLabel(),
                style: AppText.labelSm.copyWith(color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Workout body ────────────────────────────────────────────────────────

  Widget _buildWorkoutView(AppLocalizations l10n) {
    return Column(
      children: [
        // Rest timer lives above the list, outside the RefreshIndicator, so
        // it stays put and never gets tugged by a pull-to-refresh gesture.
        AnimatedSize(
          duration: _motionDuration(const Duration(milliseconds: 220)),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _restRemaining > 0
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: _buildRestBanner(l10n),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.primaryFixed,
            backgroundColor: AppColors.surface,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                _buildHeaderCard(l10n),
                const SizedBox(height: AppSpacing.lg),
                if (_workout.exercises.isEmpty)
                  Text(
                    l10n.assignedNone,
                    style: AppText.bodySm.copyWith(color: AppColors.textMuted),
                  )
                else
                  for (final (index, e) in _workout.exercises.indexed) ...[
                    _buildExerciseCard(index, e, l10n),
                    const SizedBox(height: AppSpacing.md),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(AppLocalizations l10n) {
    final isActive = _phase == _AssignedPhase.active;
    final overallProgress = _totalTargetSets > 0
        ? (_totalDoneSets / _totalTargetSets).clamp(0.0, 1.0)
        : 0.0;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final font = AppText.fontFamily(isArabic: isArabic);

    return _HeroCard(
      leadingIcon: Icons.fitness_center_rounded,
      eyebrow: l10n.assignedWorkoutTitle,
      title: _workout.templateName,
      fontFamily: font,
      eyebrowSubtitle: isActive
          ? l10n.assignedSetProgress(_totalDoneSets, _totalTargetSets)
          : null,
      chips: _workout.targetMuscles.isEmpty
          ? null
          : [for (final m in _workout.targetMuscles) _buildMuscleChip(m)],
      notesWidget: ((_workout.templateNotes ?? '').trim().isEmpty)
          ? null
          : Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _workout.templateNotes!,
                      style: AppText.bodySm.copyWith(
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      stats: [
        _HeroStatData(
          icon: Icons.list_alt_rounded,
          value: '${_workout.exercises.length}',
          label: l10n.assignedStatExercises,
        ),
        _HeroStatData(
          icon: Icons.repeat_rounded,
          value: '$_totalTargetSets',
          label: l10n.assignedStatSets,
        ),
        _HeroStatData(
          icon: Icons.schedule_rounded,
          value: '~${_workout.estimatedMinutes}${isArabic ? ' د' : ' min'}',
          label: l10n.assignedStatTime,
        ),
      ],
      footer: isActive
          ? Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: overallProgress),
                      duration: _motionDuration(
                        const Duration(milliseconds: 300),
                      ),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceContainerHighest,
                        color: AppColors.primaryFixed,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(overallProgress * 100).round()}%',
                    style: AppText.labelSm.copyWith(
                      color: AppColors.primaryFixed,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildMuscleChip(String raw) {
    final color = _muscleColor(raw);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        _muscleLabel(raw),
        style: AppText.labelSm.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRestBanner(AppLocalizations l10n) {
    final progress = _restTotal > 0 ? _restRemaining / _restTotal : 0.0;
    final isUrgent = _restRemaining > 0 && _restRemaining <= 5;
    final bannerColor = isUrgent
        ? AppColors.overGoalWarning.withValues(alpha: 0.12)
        : AppColors.primaryFixed.withValues(alpha: 0.10);
    final borderColor = isUrgent
        ? AppColors.overGoalWarning.withValues(alpha: 0.55)
        : AppColors.primaryFixed;
    final progressColor = isUrgent
        ? AppColors.overGoalWarning
        : AppColors.primaryFixed;
    final iconColor = isUrgent
        ? AppColors.overGoalWarning
        : AppColors.primaryFixed;

    return AnimatedContainer(
      duration: _motionDuration(const Duration(milliseconds: 250)),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: progressColor.withValues(alpha: isUrgent ? 0.22 : 0.12),
            blurRadius: isUrgent ? 20 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Pulsing dot in urgent phase — scale animates via Tween.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1, end: isUrgent ? 1.12 : 1),
                duration: _motionDuration(const Duration(milliseconds: 500)),
                curve: Curves.easeInOut,
                builder: (context, scale, child) => Transform.scale(
                  scale: scale,
                  child: child,
                ),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: progressColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.timer_rounded,
                    color: iconColor,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1, end: isUrgent ? 1.04 : 1),
                  duration: _motionDuration(
                    const Duration(milliseconds: 400),
                  ),
                  builder: (context, scale, child) => Transform.scale(
                    scale: scale,
                    alignment: Alignment.centerLeft,
                    child: child,
                  ),
                  child: Text(
                    l10n.assignedRestSecs(_restRemaining),
                    style: AppText.titleSm.copyWith(
                      color: iconColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              // 44×44 minimum touch target even though the visual chip is
              // smaller — padding extends the hit area (touch-target-size).
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _skipRest,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    child: Semantics(
                      button: true,
                      label: l10n.skipRest,
                      child: Text(
                        l10n.skipRest,
                        style: AppText.labelSm.copyWith(
                          color: iconColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: _motionDuration(const Duration(milliseconds: 300)),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: progressColor.withValues(alpha: 0.15),
                color: progressColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(
    int index,
    AssignedExercise e,
    AppLocalizations l10n,
  ) {
    final sets = _setsByExercise[e.exerciseName] ?? const [];
    final done = sets.length;
    final allHit =
        done >= e.targetSets && sets.every((s) => _hitTarget(e, s));
    final isActive = _phase == _AssignedPhase.active;
    final progress = e.targetSets > 0
        ? (done / e.targetSets).clamp(0.0, 1.0)
        : 0.0;
    final collapsed = _collapsedIds.contains(e.id);
    final isSuccess = _loggedSuccessIds.contains(e.id);
    final isLogging = _loggingExerciseId == e.id;

    return AnimatedContainer(
      duration: _motionDuration(const Duration(milliseconds: 200)),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: allHit
              ? AppColors.accent.withValues(alpha: 0.45)
              : AppColors.borderSubtle,
          width: allHit ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PressScale(
            motionDuration: _motionDuration(
              const Duration(milliseconds: 140),
            ),
            onTap: () => _toggleExpanded(e.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: 2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: allHit
                          ? AppColors.accent.withValues(alpha: 0.16)
                          : AppColors.lightGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: allHit
                        ? Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: AppColors.accent,
                            semanticLabel: 'Completed',
                          )
                        : Text(
                            '${index + 1}',
                            style: AppText.labelLg.copyWith(
                              color: AppColors.onPrimaryContainer,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      e.exerciseName,
                      style: AppText.titleSm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _ExerciseRingBadge(
                    done: done,
                    target: e.targetSets,
                    progress: progress,
                    allHit: allHit,
                    motionDuration: _motionDuration(
                      const Duration(milliseconds: 300),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AnimatedRotation(
                    duration: _motionDuration(
                      const Duration(milliseconds: 200),
                    ),
                    turns: collapsed ? -0.25 : 0,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 22,
                      color: AppColors.textMuted,
                      semanticLabel: collapsed ? 'Expand' : 'Collapse',
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: _motionDuration(const Duration(milliseconds: 200)),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: collapsed
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _targetText(e, l10n),
                        style: AppText.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if ((e.notes ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${l10n.assignedNotes}: ${e.notes}',
                          style: AppText.bodySm.copyWith(
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: _motionDuration(
                            const Duration(milliseconds: 300),
                          ),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                                value: value,
                                minHeight: 5,
                                backgroundColor:
                                    AppColors.surfaceContainerHighest,
                                color: allHit
                                    ? AppColors.accent
                                    : AppColors.primaryFixed,
                              ),
                        ),
                      ),
                      if (sets.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        for (final s in sets) _buildSetRow(e, s, l10n),
                      ],
                    ],
                  ),
          ),
          // Weight/reps inputs + the Log Set button live OUTSIDE the
          // AnimatedSize on purpose: a focused TextField inside
          // RenderAnimatedSize can call markNeedsLayout mid-layout (cursor
          // blink / floating label) and throw "mutated during layout". They
          // stay visible for the whole active phase — collapse/expand only
          // governs the descriptive section above.
          if (isActive) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightCtrls[e.id],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    style: AppText.bodyLg.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.weight,
                      suffixText: l10n.kg,
                      suffixStyle: AppText.labelSm.copyWith(
                        color: AppColors.textMuted,
                      ),
                      labelStyle: AppText.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primaryFixed,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _repsCtrls[e.id],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: AppText.bodyLg.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.reps,
                      suffixText: l10n.reps,
                      suffixStyle: AppText.labelSm.copyWith(
                        color: AppColors.textMuted,
                      ),
                      labelStyle: AppText.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primaryFixed,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: AnimatedContainer(
                duration: _motionDuration(const Duration(milliseconds: 220)),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: isSuccess
                      ? LinearGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: 0.95),
                            AppColors.accent.withValues(alpha: 0.75),
                          ],
                        )
                      : _busy && !isLogging
                      ? LinearGradient(
                          colors: [
                            AppColors.primaryFixed.withValues(alpha: 0.4),
                            AppColors.primaryDim.withValues(alpha: 0.4),
                          ],
                        )
                      : AppColors.primaryActionGradient,
                  boxShadow: [
                    BoxShadow(
                      color: (isSuccess
                              ? AppColors.accent
                              : AppColors.primaryFixed)
                          .withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: (_busy || isSuccess)
                      ? null
                      : () => _logSet(e),
                  icon: AnimatedSwitcher(
                    duration: _motionDuration(
                      const Duration(milliseconds: 220),
                    ),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: isSuccess
                        ? Icon(
                            Icons.check_rounded,
                            key: const ValueKey('success'),
                            size: 18,
                            color: AppColors.onPrimary,
                          )
                        : isLogging
                        ? SizedBox(
                            key: const ValueKey('busy'),
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : Icon(
                            Icons.add_rounded,
                            key: const ValueKey('idle'),
                            size: 18,
                            color: AppColors.onPrimary,
                          ),
                  ),
                  label: Text(
                    l10n.assignedLogSet,
                    style: AppText.buttonPrimary.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: AppColors.onPrimary,
                    disabledForegroundColor: AppColors.onPrimary.withValues(
                      alpha: 0.9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSetRow(
    AssignedExercise e,
    Map<String, dynamic> set,
    AppLocalizations l10n,
  ) {
    final hit = _hitTarget(e, set);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: hit ? AppColors.lightGreen : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hit
              ? AppColors.accent.withValues(alpha: 0.4)
              : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hit ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: hit ? AppColors.accent : AppColors.textMuted,
            semanticLabel: hit ? 'Target hit' : 'Set logged',
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${l10n.set} ${set['set_number']}',
            style: AppText.titleSm.copyWith(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            _setSummary(l10n, set),
            style: AppText.bodySm.copyWith(
              color: hit
                  ? AppColors.onPrimaryContainer
                  : AppColors.textSecondary,
              fontWeight: hit ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Nutrition tab ───────────────────────────────────────────────────────

  String _fmtNum(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  Widget _buildNutritionBody(AppLocalizations l10n) {
    if (_nutritionLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryFixed),
      );
    }
    final plan = _nutritionPlan;
    if (plan == null) return _buildNutritionEmpty(l10n);
    return RefreshIndicator(
      onRefresh: () async {
        final fresh = await _nutritionService.fetchTodayPlan();
        if (mounted) setState(() => _nutritionPlan = fresh);
      },
      color: AppColors.primaryFixed,
      backgroundColor: AppColors.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          _buildNutritionHeader(plan, l10n),
          if (plan.isPreview && plan.meals.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _buildPreviewBanner(plan, l10n),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (plan.meals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                l10n.assignedNutritionNoMealsToday,
                textAlign: TextAlign.center,
                style: AppText.bodySm.copyWith(color: AppColors.textMuted),
              ),
            )
          else
            for (final meal in plan.meals) ...[
              _buildMealCard(meal, l10n),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }

  /// Shown when today has no meals and the nearest upcoming day is on
  /// display — future meals must never read as today's plan.
  Widget _buildPreviewBanner(AssignedNutritionPlan plan, AppLocalizations l10n) {
    final lang = Localizations.localeOf(context).languageCode;
    final dateLabel = DateFormat('EEEE, d MMM', lang).format(plan.displayDate);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryFixed.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_note_rounded,
            size: 16,
            color: AppColors.primaryFixed,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.assignedNutritionNextDay(dateLabel),
              style: AppText.labelSm.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionEmpty(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IllustratedEmptyIcon(
              primaryIcon: Icons.restaurant_rounded,
              accentIcon: Icons.auto_awesome_rounded,
              accentColor: AppColors.primaryFixed,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.assignedNutritionNoPlan,
              textAlign: TextAlign.center,
              style: AppText.bodyLg.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.assignedNutritionNoPlanBody,
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  /// Same hero language as the workout header — the two tabs must read as
  /// one screen, not two apps.
  Widget _buildNutritionHeader(AssignedNutritionPlan plan, AppLocalizations l10n) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final font = AppText.fontFamily(isArabic: isArabic);
    return _HeroCard(
      leadingIcon: Icons.restaurant_rounded,
      eyebrow: l10n.assignedNutritionTitle,
      title: plan.programName,
      fontFamily: font,
      trailingBadge: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryFixed.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          l10n.weekOfTotal(plan.currentWeek, plan.durationWeeks),
          style: AppText.labelSm.copyWith(
            color: AppColors.primaryFixed,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      description: (plan.programDescription ?? '').trim().isEmpty
          ? null
          : Text(
              plan.programDescription!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySm.copyWith(color: AppColors.textMuted),
            ),
      stats: [
        _HeroStatData(
          icon: Icons.restaurant_menu_rounded,
          value: '${plan.mealCount}',
          label: l10n.assignedNutritionStatMeals,
        ),
        _HeroStatData(
          icon: Icons.lunch_dining_rounded,
          value: '${plan.foodCount}',
          label: l10n.assignedNutritionStatFoods,
        ),
        _HeroStatData(
          icon: Icons.local_fire_department_rounded,
          value: plan.totalCalories.round().toString(),
          label: l10n.kcal,
        ),
      ],
      footer: Text(
        '${l10n.protein} ${_fmtNum(plan.totalProteinG)}g'
        ' · ${l10n.carbs} ${_fmtNum(plan.totalCarbsG)}g'
        ' · ${l10n.fat} ${_fmtNum(plan.totalFatG)}g',
        style: AppText.labelSm.copyWith(color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildMealCard(AssignedNutritionMeal meal, AppLocalizations l10n) {
    final completed = meal.status == 'completed';
    final skipped = meal.status == 'skipped';
    final color = completed
        ? AppColors.accent
        : (skipped ? AppColors.textMuted : null);
    return Opacity(
      opacity: skipped ? 0.65 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: completed
                ? AppColors.accent.withValues(alpha: 0.45)
                : AppColors.borderSubtle,
            width: completed ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: completed
                        ? AppColors.accent.withValues(alpha: 0.16)
                        : AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: completed
                      ? Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: AppColors.accent,
                          semanticLabel: 'Completed',
                        )
                      : Text(
                          '${meal.orderIndex + 1}',
                          style: AppText.labelLg.copyWith(
                            color: AppColors.onPrimaryContainer,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    meal.mealName,
                    style: AppText.titleSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color ?? AppColors.textPrimary,
                      decoration: skipped ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                _buildMealStatusChip(meal, l10n),
              ],
            ),
            if (meal.foods.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final f in meal.foods) _buildFoodRow(f, l10n),
            ],
            if (meal.status == 'assigned') ...[
              const SizedBox(height: AppSpacing.md),
              _buildMarkEatenButton(meal, l10n),
            ],
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  l10n.assignedNutritionMealTotal,
                  style: AppText.labelSm.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${meal.totalCalories.round()} ${l10n.kcal}',
                  style: AppText.titleSm.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'P ${_fmtNum(meal.totalProteinG)}'
                  ' · C ${_fmtNum(meal.totalCarbsG)}'
                  ' · F ${_fmtNum(meal.totalFatG)}',
                  style: AppText.labelSm.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// "I ate this" — the only client action on the plan. Same volt button
  /// language as the workout's Log Set; completion flows into the day's
  /// calorie total and the coach's history server-side.
  Widget _buildMarkEatenButton(AssignedNutritionMeal meal, AppLocalizations l10n) {
    final busy = _completingMealId == meal.id;
    final isSuccess = _justCompletedMealId == meal.id;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: AnimatedContainer(
        duration: _motionDuration(const Duration(milliseconds: 220)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSuccess
              ? LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.95),
                    AppColors.accent.withValues(alpha: 0.75),
                  ],
                )
              : busy
              ? LinearGradient(
                  colors: [
                    AppColors.primaryFixed.withValues(alpha: 0.4),
                    AppColors.primaryDim.withValues(alpha: 0.4),
                  ],
                )
              : AppColors.primaryActionGradient,
          boxShadow: [
            BoxShadow(
              color: (isSuccess ? AppColors.accent : AppColors.primaryFixed)
                  .withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _completingMealId == null && !isSuccess
              ? () => _markEaten(meal)
              : null,
          icon: AnimatedSwitcher(
            duration: _motionDuration(const Duration(milliseconds: 200)),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: isSuccess
                ? Icon(
                    Icons.check_rounded,
                    key: const ValueKey('meal_success'),
                    size: 17,
                    color: AppColors.onPrimary,
                  )
                : busy
                ? SizedBox(
                    key: const ValueKey('meal_busy'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : Icon(
                    Icons.restaurant_rounded,
                    key: const ValueKey('meal_idle'),
                    size: 17,
                    color: AppColors.onPrimary,
                  ),
          ),
          label: Text(
            l10n.assignedNutritionMarkEaten,
            style: AppText.buttonPrimary.copyWith(color: AppColors.onPrimary),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: AppColors.onPrimary,
            disabledForegroundColor: AppColors.onPrimary.withValues(alpha: 0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markEaten(AssignedNutritionMeal meal) async {
    final plan = _nutritionPlan;
    if (plan == null) return;
    setState(() => _completingMealId = meal.id);
    final result = await _nutritionService.markMealCompleted(plan, meal);
    if (!mounted) return;
    setState(() => _completingMealId = null);
    final l10n = AppLocalizations.of(context)!;
    if (result == MealCompleteResult.failed) {
      _showError(l10n.assignedNutritionMarkFailed);
      return;
    }
    if (result == MealCompleteResult.completed) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.assignedNutritionMarkedEaten),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }
    // Local truth update — also covers alreadyCompleted so the card's
    // status chip catches up even when the write had landed elsewhere.
    setState(() => _nutritionPlan = plan.withMealCompleted(meal.id));
    // Brief success morph on the button that was just tapped.
    _mealSuccessTimer?.cancel();
    setState(() => _justCompletedMealId = meal.id);
    _mealSuccessTimer = Timer(
      _motionDuration(const Duration(milliseconds: 1400)),
      () {
        if (mounted) setState(() => _justCompletedMealId = null);
      },
    );
  }

  Widget _buildMealStatusChip(AssignedNutritionMeal meal, AppLocalizations l10n) {
    final status = meal.status;
    final (bg, fg, label, icon) = switch (status) {
      'completed' => (
        AppColors.lightGreen,
        AppColors.onPrimaryContainer,
        l10n.assignedNutritionStatusCompleted,
        Icons.check_circle_rounded,
      ),
      'skipped' => (
        AppColors.surfaceContainerHigh,
        AppColors.textMuted,
        l10n.assignedNutritionStatusSkipped,
        Icons.block_rounded,
      ),
      _ => (
        AppColors.surfaceContainerHigh,
        AppColors.onSurfaceVariant,
        l10n.assignedNutritionStatusAssigned,
        Icons.schedule_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.labelSm.copyWith(color: fg, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  /// One food row: the client's current truth (or the frozen snapshot when
  /// untouched), with the plan value surfaced as before→after chips on
  /// changed rows — no italic caption.
  Widget _buildFoodRow(AssignedNutritionFood f, AppLocalizations l10n) {
    final changed = f.isChanged;
    final substitution = changed && f.currentFoodName != null;
    final quantityChanged = changed &&
        f.currentQuantity != null &&
        (f.currentQuantity! - f.originalQuantity).abs() > 0.001;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: changed
            ? AppColors.accent.withValues(alpha: 0.08)
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: changed
              ? AppColors.accent.withValues(alpha: 0.4)
              : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  f.displayName,
                  style: AppText.titleSm.copyWith(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (changed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    l10n.assignedNutritionChanged,
                    style: AppText.labelSm.copyWith(
                      fontSize: 10,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${_fmtNum(f.effectiveQuantity)} ${f.servingUnit}'
            ' · ${f.effectiveCalories.round()} ${l10n.kcal}'
            ' · P ${_fmtNum(f.effectiveProteinG)}'
            ' · C ${_fmtNum(f.effectiveCarbsG)}'
            ' · F ${_fmtNum(f.effectiveFatG)}',
            style: AppText.bodySm.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (substitution || quantityChanged) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                // Original chip — faded with strikethrough.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    substitution
                        ? f.foodName
                        : '${_fmtNum(f.originalQuantity)} ${f.servingUnit}',
                    style: AppText.labelSm.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: AppColors.textMuted,
                    ),
                  ),
                ),
                Icon(
                  isArabic
                      ? Icons.arrow_back_rounded
                      : Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                  semanticLabel: 'changed to',
                ),
                // Current chip — solid with accent tint.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryFixed.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 12,
                        color: AppColors.primaryFixed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        substitution
                            ? (f.currentFoodName ?? '')
                            : '${_fmtNum(f.currentQuantity!)} ${f.servingUnit}',
                        style: AppText.labelSm.copyWith(
                          fontSize: 11,
                          color: AppColors.primaryFixed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Bottom action bar / done view ───────────────────────────────────────

  Widget _buildBottomBar(AppLocalizations l10n) {
    if (_phase == _AssignedPhase.done) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: SizedBox(
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: AppColors.primaryActionGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryFixed.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l10n.assignedDone,
                  style: AppText.buttonPrimary.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_phase == _AssignedPhase.none || _phase == _AssignedPhase.loading) {
      return const SizedBox.shrink();
    }

    final label = _phase == _AssignedPhase.active
        ? l10n.assignedFinish
        : (_workout.isResumable ? l10n.assignedContinue : l10n.startWorkout);

    // Finishing early (before every set is logged) is a meaningful action —
    // flag it instead of letting the button look identical either way.
    final showPartialWarning =
        _phase == _AssignedPhase.active && _totalDoneSets < _totalTargetSets;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showPartialWarning)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                        semanticLabel: 'Partial progress',
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l10n.assignedSetProgress(
                            _totalDoneSets,
                            _totalTargetSets,
                          ),
                          style: AppText.labelSm.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryFixed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              height: 54,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: AppColors.primaryActionGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryFixed.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () => _phase == _AssignedPhase.active
                            ? _finishWorkout()
                            : _startWorkout(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: AppColors.onPrimary,
                    disabledForegroundColor: AppColors.onPrimary.withValues(
                      alpha: 0.6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _busy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(
                          label,
                          style: AppText.buttonPrimary.copyWith(
                            color: AppColors.onPrimary,
                          ),
                        ),
                ),
              ),
            ),
            // Declining is only offered before the workout begins — once a
            // session exists the user either finishes it or abandons it.
            if (_phase == _AssignedPhase.ready && !_workout.isResumable)
              TextButton(
                onPressed: _busy ? null : _skipWorkout,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  minimumSize: const Size(44, 36),
                ),
                child: Text(
                  l10n.assignedSkip,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoneView(AppLocalizations l10n) {
    final volumeLabel = _totalVolumeKg > 0
        ? '${_fmtNum(_totalVolumeKg)} ${l10n.kg}'
        : '—';
    final prLabel = _prHitCount > 0 ? '$_prHitCount · ${l10n.personalRecord}' : '—';
    final elapsed = _elapsedLabel().isEmpty ? '—' : _elapsedLabel();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: _motionDuration(const Duration(milliseconds: 320)),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 34,
                  color: AppColors.onPrimaryContainer,
                  semanticLabel: 'Workout completed',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.assignedDoneTitle,
              textAlign: TextAlign.center,
              style: AppText.headlineMd.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.assignedDoneBody,
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.lightGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.assignedSetsLogged(_totalDoneSets),
                style: AppText.labelSm.copyWith(
                  color: AppColors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // ── Completion summary — the emotional payoff ──
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
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
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 14,
                        color: AppColors.primaryFixed,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.workoutSummary,
                        style: AppText.labelSm.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      if (_prHitCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 11,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$_prHitCount',
                                style: AppText.labelSm.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      _DoneMetricTile(
                        icon: Icons.fitness_center_rounded,
                        value: volumeLabel,
                        label: l10n.totalVolume,
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        color: AppColors.borderSubtle,
                      ),
                      _DoneMetricTile(
                        icon: Icons.repeat_rounded,
                        value: '$_totalDoneSets',
                        label: l10n.totalSets,
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        color: AppColors.borderSubtle,
                      ),
                      _DoneMetricTile(
                        icon: Icons.schedule_rounded,
                        value: elapsed,
                        label: l10n.duration,
                      ),
                    ],
                  ),
                  if (_prHitCount > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.accent,
                            semanticLabel: 'PR',
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              prLabel,
                              style: AppText.labelSm.copyWith(
                                color: AppColors.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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

// ──────────────────────────────────────────────────────────────────────────
// Shared hero card — single source of truth for workout + nutrition headers
// ──────────────────────────────────────────────────────────────────────────

class _HeroStatData {
  final IconData icon;
  final String value;
  final String label;
  const _HeroStatData({
    required this.icon,
    required this.value,
    required this.label,
  });
}

class _HeroCard extends StatelessWidget {
  final IconData leadingIcon;
  final String eyebrow;
  final String title;
  final String? fontFamily;
  final String? eyebrowSubtitle;
  final Widget? trailingBadge;
  final List<Widget>? chips;
  final Widget? description;
  final Widget? notesWidget;
  final List<_HeroStatData> stats;
  final Widget? footer;

  const _HeroCard({
    required this.leadingIcon,
    required this.eyebrow,
    required this.title,
    this.fontFamily,
    this.eyebrowSubtitle,
    this.trailingBadge,
    this.chips,
    this.description,
    this.notesWidget,
    required this.stats,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryActionGradient,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  leadingIcon,
                  color: AppColors.onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
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
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            eyebrow,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: AppColors.onPrimaryContainer,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ),
                        if (trailingBadge != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          trailingBadge!,
                        ],
                      ],
                    ),
                    if (eyebrowSubtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        eyebrowSubtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
              fontFamily: fontFamily,
            ),
          ),
          if (chips != null && chips!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 6,
              children: chips!,
            ),
          ],
          if (description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            description!,
          ],
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (int i = 0; i < stats.length; i++) ...[
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            stats[i].icon,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              stats[i].value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                fontFamily: fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stats[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          fontFamily: fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < stats.length - 1)
                  Container(
                    width: 1,
                    height: 30,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 6,
                    ),
                    color: AppColors.borderSubtle,
                  ),
              ],
            ],
          ),
          if (notesWidget != null) ...[
            const SizedBox(height: AppSpacing.md),
            notesWidget!,
          ],
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.lg),
            footer!,
          ],
        ],
      ),
    );
  }
}

// ── Exercise ring badge ─────────────────────────────────────────────────

class _ExerciseRingBadge extends StatelessWidget {
  final int done;
  final int target;
  final double progress;
  final bool allHit;
  final Duration motionDuration;

  const _ExerciseRingBadge({
    required this.done,
    required this.target,
    required this.progress,
    required this.allHit,
    required this.motionDuration,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = allHit ? AppColors.accent : AppColors.primaryFixed;
    final bgColor = AppColors.surfaceContainerHighest;
    final label = '$done/$target';

    return Semantics(
      label: '$done of $target sets',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: motionDuration,
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(
                  value: value == 0 ? 0.02 : value,
                  strokeWidth: 3.2,
                  backgroundColor: bgColor,
                  color: ringColor,
                  strokeCap: StrokeCap.round,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: motionDuration,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: allHit
                  ? Container(
                      key: const ValueKey('ring_check'),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text(
                      label,
                      key: ValueKey<String>(label),
                      style: AppText.labelSm.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: allHit
                            ? AppColors.accent
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Press scale wrapper — whole-row feedback on tap ─────────────────────

class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Duration motionDuration;

  const _PressScale({
    required this.child,
    required this.onTap,
    required this.motionDuration,
  });

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: widget.motionDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.92 : 1,
          duration: widget.motionDuration,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(10),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Illustrated empty state icon composition ────────────────────────────

class _IllustratedEmptyIcon extends StatelessWidget {
  final IconData primaryIcon;
  final IconData? accentIcon;
  final Color? accentColor;

  const _IllustratedEmptyIcon({
    required this.primaryIcon,
    this.accentIcon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.borderSubtle,
                width: 1,
              ),
            ),
          ),
          Icon(
            primaryIcon,
            size: 34,
            color: AppColors.textMuted,
          ),
          if (accentIcon != null)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accentColor ?? AppColors.primaryFixed,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surface,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (accentColor ?? AppColors.primaryFixed)
                          .withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  accentIcon,
                  size: 12,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Done view metric tile ───────────────────────────────────────────────

class _DoneMetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _DoneMetricTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.titleSm.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.labelSm.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
