import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';

import '../l10n/app_localizations.dart';
import '../models/meal_suggestion.dart';
import '../services/meal_suggestion_service.dart';
import '../services/nutrition_service.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Suggest-a-Meal flow sheet (owner v3, 2026-09-24): craving question → staged
// loading → rich result with a match-accuracy badge + per-item macros + a
// "different combo" regenerate action, or a goal-met state that skips the AI
// call entirely when there's nothing left to suggest for. Route mirrors
// FoodLogPopupRoute (animated backdrop blur + slide-up).
//
// NEW l10n keys this file expects (add to ar + en per owner rule §6):
//   suggestMatchLabel      e.g. "Match"        / "التطابق"
//   suggestRegenerate      e.g. "Different combo" / "جرب توليفة تانية"
//   suggestGoalMetTitle    e.g. "You're all set for today"
//                              / "خلصت هدفك النهارده"
//   suggestGoalMetBody     e.g. "No calories left to suggest a meal for. Log
//     tomorrow's first meal once your day resets."
//                              / "معندكش سعرات باقية نقترحلك عليها وجبة.
//     ارجع بكرة أول ما يومك يتصفّر."
// ─────────────────────────────────────────────────────────────────────────────

bool get _systemReduceMotion => WidgetsBinding
    .instance
    .platformDispatcher
    .accessibilityFeatures
    .disableAnimations;

class SuggestMealPopupRoute extends PopupRoute<void> {
  SuggestMealPopupRoute({
    required this.remainingKcal,
    required this.remainingProtein,
    required this.remainingCarbs,
    required this.remainingFat,
    this.onLogged,
  });

  final double remainingKcal;
  final double remainingProtein;
  final double remainingCarbs;
  final double remainingFat;
  final VoidCallback? onLogged;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.5);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss suggest meal sheet';

  @override
  Duration get transitionDuration => _systemReduceMotion
      ? const Duration(milliseconds: 1)
      : const Duration(milliseconds: 460);

  @override
  Duration get reverseTransitionDuration => _systemReduceMotion
      ? const Duration(milliseconds: 1)
      : const Duration(milliseconds: 240);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: curved,
              builder: (_, __) => BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 16 * curved.value,
                  sigmaY: 16 * curved.value,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: SuggestMealSheet(
              remainingKcal: remainingKcal,
              remainingProtein: remainingProtein,
              remainingCarbs: remainingCarbs,
              remainingFat: remainingFat,
              onLogged: onLogged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class SuggestMealSheet extends StatefulWidget {
  final double remainingKcal;
  final double remainingProtein;
  final double remainingCarbs;
  final double remainingFat;
  final VoidCallback? onLogged;

  const SuggestMealSheet({
    super.key,
    required this.remainingKcal,
    required this.remainingProtein,
    required this.remainingCarbs,
    required this.remainingFat,
    this.onLogged,
  });

  @override
  State<SuggestMealSheet> createState() => _SuggestMealSheetState();
}

enum _Stage { choose, loading, result, error }

class _SuggestMealSheetState extends State<SuggestMealSheet> {
  static const _slotIcons = <String, IconData>{
    'breakfast': Icons.wb_sunny_rounded,
    'lunch': Icons.restaurant_rounded,
    'dinner': Icons.nights_stay_rounded,
    'snack': Icons.eco_rounded,
  };

  final _suggestionService = MealSuggestionService();
  final _nutritionService = NutritionService();

  _Stage _stage = _Stage.choose;
  String _mealType = 'lunch';
  String _style = 'balanced';

  /// Share of the remaining budget this meal should cover (owner v2.1
  /// calorie picker) — the chips show the REAL kcal each share means.
  double _fraction = 1.0;

  // NEW 2026-09-24 — finish: user-typed calorie target (the "put his CAL" field).
  // When non-null & valid, this OVERRIDES remaining/fraction entirely. Valid
  // range 80..5000 kcal, enforced both client + server.
  late final TextEditingController _calorieController;
  final _calorieFocus = FocusNode();
  String? _calorieError;
  int? _lastTargetCalories; // snapshot used for loading badge + match %

  MealSuggestion? _suggestion;
  MealSuggestionError? _error;
  bool _logging = false;
  bool _logged = false;

  // Loading theatre: the stages mirror what the edge function really does.
  int _activeStep = 0;
  Timer? _stepTimer;

  bool get _goalMet => widget.remainingKcal <= 0;

  /// Parsed custom target, null if field empty. 80..5000 enforced.
  int? get _parsedCustomCalories {
    final raw = _calorieController.text.trim();
    if (raw.isEmpty) return null;
    final v = int.tryParse(raw);
    if (v == null) return null;
    if (v < 80 || v > 5000) return null;
    return v;
  }

  bool get _calorieFieldHasError {
    final raw = _calorieController.text.trim();
    if (raw.isEmpty) return false;
    final v = int.tryParse(raw);
    return v == null || v < 80 || v > 5000;
  }

  int get _effectiveTargetCalories =>
      _parsedCustomCalories ?? widget.remainingKcal.round().clamp(80, 5000);

  // True when we should show the "goal met" empty state instead of chooser.
  // With the new CAL field, a goal-met day is still usable — user can type a
  // custom target and get a suggestion anyway. We keep the legacy goal-met
  // widget available but prefer the inline helper inside _buildCalorieField, so
  // this now only fires when explicitly requested via the old path. For the
  // new finish flow, we always show the chooser so the field is visible.
  bool get _shouldShowGoalMet => false;

  @override
  void initState() {
    super.initState();
    final hour = DateTime.now().hour;
    _mealType = hour < 11
        ? 'breakfast'
        : hour < 16
        ? 'lunch'
        : hour < 21
        ? 'dinner'
        : 'snack';
    // Prefill with remaining when it is meaningful (>80). Goal-met days stay
    // empty so the hint + "use remaining" chip can guide the user.
    _calorieController = TextEditingController(
      text: widget.remainingKcal >= 80
          ? widget.remainingKcal.round().toString()
          : '',
    );
    _calorieFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _calorieController.dispose();
    _calorieFocus.dispose();
    super.dispose();
  }

  String get _slotLabel {
    final l10n = AppLocalizations.of(context)!;
    return switch (_mealType) {
      'breakfast' => l10n.breakfast,
      'dinner' => l10n.dinner,
      'snack' => l10n.snack,
      _ => l10n.lunch,
    };
  }

  Future<void> _request() async {
    // Guard: never let a second request fire while one is already in flight —
    // this is the only client-side protection on the shared Gemini ~20 RPM
    // budget, so it has to be airtight, not just a disabled button.
    if (_stage == _Stage.loading) return;

    // NEW: validate the CAL field. Empty = use remaining (legacy). Non-empty
    // but invalid = show inline error and abort. Goal-met only blocks when
    // there is no valid custom target.
    final l10n = AppLocalizations.of(context)!;
    final rawCal = _calorieController.text.trim();
    int? customCals;
    if (rawCal.isNotEmpty) {
      customCals = int.tryParse(rawCal);
      if (customCals == null || customCals < 80 || customCals > 5000) {
        setState(() => _calorieError = l10n.suggestCaloriesInvalid);
        HapticFeedback.mediumImpact();
        return;
      }
    }
    // If no custom target and remaining<=0, there's nothing to size from.
    if (customCals == null && _goalMet) {
      HapticFeedback.mediumImpact();
      return;
    }
    // Snapshot target for loading badge + match calc (prevents flicker if user
    // edits field while request is in flight).
    _lastTargetCalories =
        customCals ?? widget.remainingKcal.round().clamp(80, 5000);

    setState(() {
      _stage = _Stage.loading;
      _activeStep = 0;
      _error = null;
      _calorieError = null;
    });
    _calorieFocus.unfocus();
    HapticFeedback.lightImpact();

    // Stage timings: read (instant) → scan (~0.8s) → compose (the AI call) →
    // validate (a beat once the response lands). Result holds until the
    // stage story has had 1.6s to read — an instant flash reads as fake.
    _stepTimer = Timer.periodic(const Duration(milliseconds: 800), (t) {
      if (_activeStep < 2) setState(() => _activeStep += 1);
    });
    final minStory = Future<void>.delayed(const Duration(milliseconds: 1600));
    try {
      final suggestion = await _suggestionService.suggestMeal(
        mealType: _mealType,
        style: _style,
        calorieFraction: customCals == null ? _fraction : null,
        targetCalories: customCals,
      );
      await minStory;
      _stepTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _suggestion = suggestion;
        _logged = false;
        _activeStep = 3;
        _stage = _Stage.result;
      });
    } on MealSuggestionException catch (e) {
      await minStory;
      _stepTimer?.cancel();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _error = e.type;
        _stage = _Stage.error;
      });
    } catch (_) {
      await minStory;
      _stepTimer?.cancel();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _error = MealSuggestionError.unknown;
        _stage = _Stage.error;
      });
    }
  }

  /// One logging path for everything: NutritionService.logFood — same insert
  /// the food sheets use, so summary, streak, data bus and alerts all behave
  /// like a manual log.
  Future<void> _logMeal() async {
    final suggestion = _suggestion;
    if (suggestion == null || _logging || _logged) return;
    setState(() => _logging = true);
    HapticFeedback.mediumImpact();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    var allOk = true;
    for (final item in suggestion.items) {
      final ok = await _nutritionService.logFood(
        foodId: item.foodId,
        foodName: (isAr && item.nameAr != null && item.nameAr!.isNotEmpty)
            ? item.nameAr!
            : item.name,
        mealType: _mealType,
        quantity: item.quantityMultiplier,
        calories: item.calories.toDouble(),
        proteinG: item.proteinG,
        carbsG: item.carbsG,
        fatG: item.fatG,
      );
      if (!ok) allOk = false;
    }
    if (!mounted) return;
    setState(() {
      _logging = false;
      _logged = allOk;
    });
    if (allOk) {
      widget.onLogged?.call();
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _shouldShowGoalMet
                        ? _buildGoalMet(key: const ValueKey('goalMet'))
                        : switch (_stage) {
                            _Stage.choose => _buildChoose(
                              key: const ValueKey('choose'),
                            ),
                            _Stage.loading => _buildLoading(
                              key: const ValueKey('loading'),
                            ),
                            _Stage.result => _buildResult(
                              key: const ValueKey('result'),
                            ),
                            _Stage.error => _buildError(
                              key: const ValueKey('error'),
                            ),
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
          ),
          child: Icon(Icons.auto_awesome, size: 14, color: AppColors.accent),
        ),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            l10n.suggestSheetTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: MaterialLocalizations.of(context).closeButtonLabel,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(Icons.close, size: 19, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  // ── Goal-met: no AI call fired at all when there's nothing left to plan for ─
  Widget _buildGoalMet({Key? key}) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 22,
                color: AppColors.accent,
              ),
              SizedBox(height: 10),
              Text(
                l10n.suggestGoalMetTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                l10n.suggestGoalMetBody,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 1: craving question with real remaining context ──────────────────
  // NEW 2026-09-24 finish: the CAL field. User types the exact kcal they want
  // this meal to hit — AI sizes the meal to that number + the chosen style/
  // slot. Empty = legacy "use remaining" behavior. Range 80..5000, validated
  // inline + again in edge function.
  Widget _buildChoose({Key? key}) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _contextBanner(),
        SizedBox(height: 14),
        _sectionLabel(l10n.suggestMealSlot),
        SizedBox(height: 8),
        Row(
          children: [
            for (final slot in const [
              'breakfast',
              'lunch',
              'dinner',
              'snack',
            ]) ...[
              if (slot != 'breakfast') SizedBox(width: 8),
              Expanded(child: _slotChip(slot)),
            ],
          ],
        ),
        SizedBox(height: 14),
        _sectionLabel(l10n.suggestStyle),
        SizedBox(height: 8),
        // Wrapped 2x2 grid instead of a single row: "high_protein" runs long
        // in both languages and was fighting the other three chips for space.
        Row(
          children: [
            Expanded(child: _styleChip('balanced')),
            SizedBox(width: 8),
            Expanded(child: _styleChip('high_protein')),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _styleChip('light')),
            SizedBox(width: 8),
            Expanded(child: _styleChip('home')),
          ],
        ),
        SizedBox(height: 16),
        _sectionLabel(l10n.suggestCaloriesLabel),
        SizedBox(height: 6),
        _buildCalorieField(),
        SizedBox(height: 18),
        _ctaButton(
          label: l10n.suggestCta,
          icon: Icons.auto_awesome,
          onTap: _request,
        ),
      ],
    );
  }

  Widget _buildCalorieField() {
    final l10n = AppLocalizations.of(context)!;
    final hasError = _calorieError != null || _calorieFieldHasError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.glass2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasError
                  ? AppColors.accentCalories.withValues(alpha: 0.6)
                  : (_calorieFocus.hasFocus
                        ? AppColors.accent.withValues(alpha: 0.5)
                        : AppColors.glassBorder),
              width: hasError || _calorieFocus.hasFocus ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _calorieController,
                  focusNode: _calorieFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.suggestCaloriesHint,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted.withValues(alpha: 0.7),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    isDense: true,
                  ),
                  onChanged: (_) {
                    if (_calorieError != null) {
                      setState(() => _calorieError = null);
                    } else {
                      setState(() {});
                    }
                  },
                  onSubmitted: (_) => _request(),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  l10n.kcal,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        // Helper row: subtitle + "use remaining" quick-fill chip when it differs
        // from what's already typed. Keeps the field discoverable without
        // forcing the user to type when they just want the remaining budget.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                hasError
                    ? (_calorieError ?? l10n.suggestCaloriesInvalid)
                    : l10n.suggestCustomCaloriesSubtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: hasError
                      ? AppColors.accentCalories
                      : AppColors.textMuted,
                ),
              ),
            ),
            if (widget.remainingKcal >= 80 &&
                _calorieController.text.trim() !=
                    widget.remainingKcal.round().toString()) ...[
              SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _calorieController.text = widget.remainingKcal
                        .round()
                        .toString();
                    _calorieError = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    '${l10n.suggestUseRemaining} · ${widget.remainingKcal.round()} ${l10n.kcal}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (widget.remainingKcal < 80 && _parsedCustomCalories == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.suggestGoalMetBody,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _contextBanner() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.suggestTargetLabel}: ${widget.remainingKcal.round()} ${l10n.kcal} ${l10n.caloriesRemaining}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'P ${widget.remainingProtein.round()}g · C ${widget.remainingCarbs.round()}g · F ${widget.remainingFat.round()}g',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _slotChip(String slot) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (slot) {
      'breakfast' => l10n.breakfast,
      'dinner' => l10n.dinner,
      'snack' => l10n.snack,
      _ => l10n.lunch,
    };
    final selected = _mealType == slot;
    return _chip(
      label: label,
      icon: _slotIcons[slot],
      selected: selected,
      onTap: () => setState(() => _mealType = slot),
    );
  }

  Widget _styleChip(String style) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (style) {
      'high_protein' => l10n.styleHighProtein,
      'light' => l10n.styleLight,
      'home' => l10n.styleHome,
      _ => l10n.styleBalanced,
    };
    final selected = _style == style;
    return _chip(
      label: label,
      selected: selected,
      onTap: () => setState(() => _style = style),
    );
  }

  Widget _fractionChip(double f) {
    final l10n = AppLocalizations.of(context)!;
    final selected = _fraction == f;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _fraction = f);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 46,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.glass2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.glassBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${(f * 100).round()}%',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.onPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '${(widget.remainingKcal * f).round()} ${l10n.kcal}',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.onPrimary.withValues(alpha: 0.85)
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 36,
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.glass2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.glassBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: selected ? AppColors.onPrimary : AppColors.textMuted,
                ),
                SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? AppColors.onPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ctaButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.onPrimary),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 2: staged loading — real target, real function steps ─────────────
  Widget _buildLoading({Key? key}) {
    final l10n = AppLocalizations.of(context)!;
    final steps = [
      l10n.stageReadRemaining,
      l10n.stageScanCatalog,
      l10n.stageCompose,
      l10n.stageValidate,
    ];
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glass2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 15,
                color: AppColors.accentCalories,
              ),
              SizedBox(width: 7),
              Text(
                '${l10n.suggestTargetLabel}: ${_lastTargetCalories ?? _effectiveTargetCalories} ${l10n.kcal} · $_slotLabel',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0) SizedBox(height: 9),
            _loadingStep(
              steps[i],
              state: i < _activeStep ? 1 : (i == _activeStep ? 0 : -1),
            ),
          ],
        ],
      ),
    );
  }

  Widget _loadingStep(String label, {required int state}) {
    // state: 1 done · 0 active · -1 pending
    return Semantics(
      label: label,
      value: state == 1 ? 'done' : (state == 0 ? 'in progress' : 'pending'),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state == 1 ? AppColors.accent : Colors.transparent,
              border: Border.all(
                color: state == -1
                    ? AppColors.glassBorder
                    : (state == 1
                          ? AppColors.accent
                          : AppColors.accent.withValues(alpha: 0.5)),
                width: 1.4,
              ),
            ),
            child: state == 1
                ? Icon(Icons.check, size: 11, color: AppColors.onPrimary)
                : state == 0
                ? Padding(
                    padding: EdgeInsets.all(3.5),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: AppColors.accent,
                    ),
                  )
                : null,
          ),
          SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: state == -1 ? FontWeight.w600 : FontWeight.w700,
              color: state == -1 ? AppColors.textMuted : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: the result — match badge, photos, servings, totals, log ───────
  Widget _buildResult({Key? key}) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final suggestion = _suggestion!;
    final explanation = isAr
        ? suggestion.explanationAr
        : suggestion.explanationEn;

    // Match badge: mirrors the ±10% tolerance the edge function validates
    // against, so what the user sees here is honest about how the AI did —
    // not just a flat "here's your meal" with no accuracy signal.
    // Use the actual target the user asked for (custom CAL field) when
    // available, otherwise fall back to remaining.
    final target =
        (_lastTargetCalories ?? _effectiveTargetCalories).toDouble();
    final matchRatio = target > 0
        ? (1 - (suggestion.totalCalories - target).abs() / target).clamp(
            0.0,
            1.0,
          )
        : 1.0;
    final matchPercent = (matchRatio * 100).round();
    final matchColor = matchPercent >= 90
        ? AppColors.accent
        : AppColors.accentCalories;

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              l10n.suggestedMealTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: suggestion.totalCalories.toDouble()),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                '${value.round()} ${l10n.kcal}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: matchColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: matchColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.adjust_rounded, size: 11, color: matchColor),
              SizedBox(width: 5),
              Text(
                '$matchPercent% ${l10n.suggestMatchLabel}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: matchColor,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        for (final item in suggestion.items) ...[
          _resultItemRow(item, l10n),
          if (item != suggestion.items.last) SizedBox(height: 9),
        ],
        SizedBox(height: 12),
        Row(
          children: [
            _macroStat(
              '${_fmt(suggestion.totalProtein)}g',
              l10n.protein,
              AppColors.accentProtein,
            ),
            _macroStat(
              '${_fmt(suggestion.totalCarbs)}g',
              l10n.carbs,
              AppColors.accentCarbs,
            ),
            _macroStat(
              '${_fmt(suggestion.totalFat)}g',
              l10n.fat,
              AppColors.accentFat,
            ),
          ],
        ),
        if (explanation.isNotEmpty) ...[
          SizedBox(height: 12),
          Text(
            explanation,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        SizedBox(height: 16),
        _ctaButton(
          label: _logged ? l10n.mealLogged : l10n.logThisMeal,
          icon: _logged ? Icons.check_circle_rounded : Icons.restaurant_rounded,
          onTap: _logMeal,
        ),
        if (!_logged) ...[
          SizedBox(height: 9),
          _ghostButton(
            label: l10n.suggestRegenerate,
            icon: Icons.shuffle_rounded,
            onTap: _request,
          ),
        ],
      ],
    );
  }

  Widget _resultItemRow(MealSuggestionItem item, AppLocalizations l10n) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final name = (isAr && item.nameAr != null && item.nameAr!.isNotEmpty)
        ? item.nameAr!
        : item.name;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.glass2,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              width: 40,
              height: 40,
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.glass3),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.glass3,
                        child: Icon(
                          Icons.restaurant_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.glass3,
                      child: Icon(
                        Icons.restaurant_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _servingLabel(item, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  _macroLabel(item, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(
            '${item.calories} ${l10n.kcal}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ghostButton({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.glassBorder),
            color: AppColors.glass2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.textSecondary),
                SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Errors: honest message + a way forward ────────────────────────────────
  Widget _buildError({Key? key}) {
    final l10n = AppLocalizations.of(context)!;
    final message = switch (_error!) {
      MealSuggestionError.noRemaining => l10n.suggestNoRemaining,
      MealSuggestionError.noMatch => l10n.suggestNoMatch,
      MealSuggestionError.unavailable => l10n.suggestUnavailable,
      _ => l10n.suggestFailed,
    };
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accentCalories.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.accentCalories.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 17,
                color: AppColors.accentCalories,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        if (_error != MealSuggestionError.noRemaining)
          _ctaButton(
            label: l10n.tryAgain,
            icon: Icons.refresh_rounded,
            onTap: _request,
          ),
      ],
    );
  }

  String _servingLabel(MealSuggestionItem item, AppLocalizations l10n) {
    final mult = item.quantityMultiplier;
    final multText = mult == mult.roundToDouble()
        ? mult.toStringAsFixed(0)
        : mult
              .toStringAsFixed(2)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll(RegExp(r'\.$'), '');
    final serving = item.servingSize != null && item.servingUnit != null
        ? ' · ${_fmt(item.servingSize!)} ${item.servingUnit}'
        : '';
    return '×$multText ${l10n.servingUnitLabel}$serving';
  }

  String _macroLabel(MealSuggestionItem item, AppLocalizations l10n) {
    return 'P${_fmt(item.proteinG)} · C${_fmt(item.carbsG)} · F${_fmt(item.fatG)}';
  }

  String _fmt(num v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
