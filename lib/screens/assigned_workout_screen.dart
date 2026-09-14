import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/assigned_workout_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_text.dart';

/// Steps 2–4 of the coach workflow, client side: the workout assigned for
/// today is listed with its targets, "Start" creates the linked
/// workout_sessions row, every confirmed set is written to workout_sets,
/// and "Finish" closes the session + flips the assignment to 'completed'
/// so the coach's dashboard picks it up via assignment_id.
class AssignedWorkoutScreen extends StatefulWidget {
  final AssignedWorkout assignment;

  const AssignedWorkoutScreen({super.key, required this.assignment});

  @override
  State<AssignedWorkoutScreen> createState() => _AssignedWorkoutScreenState();
}

enum _AssignedPhase { loading, none, ready, active, done }

class _AssignedWorkoutScreenState extends State<AssignedWorkoutScreen> {
  final AssignedWorkoutService _service = AssignedWorkoutService();

  late AssignedWorkout _workout;
  _AssignedPhase _phase = _AssignedPhase.loading;

  String? _sessionId;
  DateTime? _startedAt;
  bool _busy = false;

  /// Logged sets read back from Supabase, grouped by exact template
  /// exercise name — never tracked locally between refreshes.
  Map<String, List<Map<String, dynamic>>> _setsByExercise = {};

  Timer? _restTimer;
  int _restRemaining = 0;
  int _restTotal = 60;

  final Map<String, TextEditingController> _weightCtrls = {};
  final Map<String, TextEditingController> _repsCtrls = {};

  @override
  void initState() {
    super.initState();
    _workout = widget.assignment;
    _load();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    for (final c in _weightCtrls.values) {
      c.dispose();
    }
    for (final c in _repsCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
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
    setState(() => _busy = true);
    final ok = await _service.logSet(
      sessionId: _sessionId!,
      exerciseName: e.exerciseName,
      setNumber: _doneFor(e) + 1,
      reps: reps,
      weightKg: weight,
      restSec: e.restSec,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      _showError(l10n.assignedErrorSet);
      return;
    }
    HapticFeedback.lightImpact();
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  String _elapsedLabel() {
    if (_startedAt == null) return '';
    final mins = DateTime.now().difference(_startedAt!).inMinutes;
    return mins < 1 ? '<1m' : '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.assignedWorkoutTitle, style: AppText.headlineSm),
        actions: [
          if (_phase == _AssignedPhase.active)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: _buildProgressChip()),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(l10n),
      body: switch (_phase) {
        _AssignedPhase.loading || _AssignedPhase.none => Center(
          child: _phase == _AssignedPhase.loading
              ? CircularProgressIndicator(color: AppColors.primaryFixed)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 40,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.assignedNone,
                      style: AppText.bodyLg.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
        _AssignedPhase.done => _buildDoneView(l10n),
        _ => _buildWorkoutView(l10n),
      },
    );
  }

  // ── AppBar helpers ──────────────────────────────────────────────────────

  /// Small, high-contrast pill that keeps overall progress and elapsed time
  /// visible while the user scrolls through exercises — avoids forcing a
  /// scroll back up just to check "how much is left".
  Widget _buildProgressChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          const SizedBox(width: 5),
          Text(
            '$_totalDoneSets/$_totalTargetSets',
            style: AppText.labelLg.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (_startedAt != null) ...[
            const SizedBox(width: 8),
            Container(width: 1, height: 12, color: AppColors.borderSubtle),
            const SizedBox(width: 8),
            Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 3),
            Text(
              _elapsedLabel(),
              style: AppText.labelSm.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  // ── Workout body ────────────────────────────────────────────────────────

  Widget _buildWorkoutView(AppLocalizations l10n) {
    return Column(
      children: [
        if (_restRemaining > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: _buildRestChip(),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _buildHeaderCard(l10n),
              const SizedBox(height: 16),
              if (_workout.exercises.isEmpty)
                Text(
                  l10n.assignedNone,
                  style: AppText.bodySm.copyWith(color: AppColors.textMuted),
                )
              else
                for (final (index, e) in _workout.exercises.indexed) ...[
                  _buildExerciseCard(index, e, l10n),
                  const SizedBox(height: 14),
                ],
            ],
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _workout.templateName,
            style: AppText.titleLg.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (_workout.targetMuscles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in _workout.targetMuscles) _buildMuscleChip(m),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.list_alt_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                l10n.assignedCardMeta(
                  _workout.exercises.length,
                  _workout.estimatedMinutes,
                ),
                style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          if ((_workout.templateNotes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 6),
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
          ],
          // Overall workout progress — only meaningful once the session is
          // running; keeps the header from lying about "0 done" before start.
          if (isActive) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: overallProgress,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceContainerHighest,
                      color: AppColors.primaryFixed,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(overallProgress * 100).round()}%',
                  style: AppText.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMuscleChip(String raw) {
    final color = _muscleColor(raw);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
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

  Widget _buildRestChip() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryFixed),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _restTotal > 0 ? _restRemaining / _restTotal : 0,
                  strokeWidth: 2.5,
                  color: AppColors.primaryFixed,
                  backgroundColor: AppColors.primaryFixed.withValues(
                    alpha: 0.15,
                  ),
                ),
                Icon(Icons.timer, color: AppColors.primaryFixed, size: 13),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.assignedRestSecs(_restRemaining),
              style: AppText.titleSm.copyWith(color: AppColors.primaryFixed),
            ),
          ),
          GestureDetector(
            onTap: _skipRest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.skipRest,
                style: AppText.labelSm.copyWith(
                  color: AppColors.primaryFixed,
                  fontWeight: FontWeight.w800,
                ),
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
    final allHit = done >= e.targetSets && sets.every((s) => _hitTarget(e, s));
    final isActive = _phase == _AssignedPhase.active;
    final progress = e.targetSets > 0
        ? (done / e.targetSets).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: allHit
                      ? AppColors.accent.withValues(alpha: 0.16)
                      : AppColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: allHit
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppColors.accent,
                      )
                    : Text(
                        '${index + 1}',
                        style: AppText.labelSm.copyWith(
                          color: AppColors.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.exerciseName,
                  style: AppText.titleSm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Single source of truth for progress — a fraction badge next
              // to the name instead of a duplicate line further down.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: allHit
                      ? AppColors.accent.withValues(alpha: 0.14)
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$done/${e.targetSets}',
                  style: AppText.labelSm.copyWith(
                    color: allHit
                        ? AppColors.accent
                        : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _targetText(e, l10n),
            style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
          ),
          if ((e.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${l10n.assignedNotes}: ${e.notes}',
              style: AppText.bodySm.copyWith(
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.surfaceContainerHighest,
              color: allHit ? AppColors.accent : AppColors.primaryFixed,
            ),
          ),
          if (sets.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final s in sets) _buildSetRow(e, s, l10n),
          ],
          if (isActive) ...[
            const SizedBox(height: 10),
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
                        horizontal: 12,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                        horizontal: 12,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : () => _logSet(e),
                icon: Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.onPrimary,
                ),
                label: Text(
                  l10n.assignedLogSet,
                  style: AppText.buttonPrimary.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryFixed,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          ),
          const SizedBox(width: 8),
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

  // ── Bottom action bar / done view ───────────────────────────────────────

  Widget _buildBottomBar(AppLocalizations l10n) {
    if (_phase == _AssignedPhase.done) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: AppColors.primaryActionGradient,
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

    final label = _phase == _AssignedPhase.active
        ? l10n.assignedFinish
        : (_workout.isResumable ? l10n.assignedContinue : l10n.startWorkout);

    // Finishing early (before every set is logged) is a meaningful action —
    // flag it instead of letting the button look identical either way.
    final showPartialWarning =
        _phase == _AssignedPhase.active && _totalDoneSets < _totalTargetSets;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showPartialWarning)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.assignedSetProgress(_totalDoneSets, _totalTargetSets),
                  style: AppText.labelSm.copyWith(color: AppColors.textMuted),
                ),
              ),
            SizedBox(
              height: 54,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: AppColors.primaryActionGradient,
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
          ],
        ),
      ),
    );
  }

  Widget _buildDoneView(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
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
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.assignedDoneTitle,
              textAlign: TextAlign.center,
              style: AppText.headlineMd.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.assignedDoneBody,
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ],
        ),
      ),
    );
  }
}
