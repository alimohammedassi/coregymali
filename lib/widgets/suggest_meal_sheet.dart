import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';

import '../l10n/app_localizations.dart';
import '../models/additional_nutrients.dart';
import '../models/meal_suggestion.dart';
import '../services/meal_suggestion_service.dart';
import '../services/nutrition_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'pixel_art_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Suggest-a-Meal flow sheet (owner v4 redesign, 2026-09-24): craving question →
// staged loading → rich result with a match-accuracy ring + per-item macros +
// a "different combo" regenerate action. Route mirrors FoodLogPopupRoute
// (animated backdrop blur + slide-up).
//
// Visual language = Kinetic Obsidian v2.1, same anatomy as the calories card:
// tinted outlined surfaces (_tintFill/_tintBorder), squircle badges, ONE volt
// hero surface (the CTA, like the FAB sheet's AI Scan hero), macro colors from
// the data-viz family. Pixel art glyphs (plate/fire/sparkles) carry the AI
// identity. Typography rides AppText so Arabic gets Cairo like the rest.
//
// The sheet optionally receives the route animation and staggers its sections
// in behind the slide — same pattern as the food-log sheet. Without it
// (widget tests build the sheet directly) everything renders statically.
//
// l10n keys consumed here must exist in ar + en per owner rule §6.
// ─────────────────────────────────────────────────────────────────────────────

bool get _systemReduceMotion => WidgetsBinding
    .instance
    .platformDispatcher
    .accessibilityFeatures
    .disableAnimations;

// Tinted-outlined card language shared with the calories card.
Color _tintFill(Color c) =>
    AppColors.isLight ? c.withValues(alpha: 0.12) : c.withValues(alpha: 0.18);

Color _tintBorder(Color c) =>
    AppColors.isLight ? c.withValues(alpha: 0.26) : c.withValues(alpha: 0.32);

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
              routeAnimation: animation,
              onLogged: onLogged,
            ),
          ),
        ),
      ],
    );
  }

  // The page handles its own entrance (blur + slide); a route-level fade
  // over a BackdropFilter looks muddy on some devices.
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

  /// Entrance animation of the host route — sections stagger in behind the
  /// slide. Null when the sheet is hosted standalone (tests).
  final Animation<double>? routeAnimation;

  const SuggestMealSheet({
    super.key,
    required this.remainingKcal,
    required this.remainingProtein,
    required this.remainingCarbs,
    required this.remainingFat,
    this.routeAnimation,
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
  /// calorie picker) — fixed at full remaining now that the fraction chips
  /// were replaced by the typed CAL field.
  final double _fraction = 1.0;

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

  String? get _ff =>
      AppText.fontFamily(isArabic:
          Localizations.localeOf(context).languageCode == 'ar');

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
  /// like a manual log. Item micro-nutrients arrive already scaled by the
  /// quantity multiplier (server-side), so they pass through unscaled.
  Future<void> _logMeal() async {
    final suggestion = _suggestion;
    if (suggestion == null || _logging || _logged) return;
    setState(() => _logging = true);
    HapticFeedback.mediumImpact();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    var allOk = true;
    for (final item in suggestion.items) {
      final extras = AdditionalNutrients(
        fiberG: item.fiberG,
        sugarsG: item.sugarsG,
        sodiumMg: item.sodiumMg,
        potassiumMg: item.potassiumMg,
        calciumMg: item.calciumMg,
        ironMg: item.ironMg,
        cholesterolMg: item.cholesterolMg,
        caffeineMg: item.caffeineMg,
      );
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
        extras: extras.hasAny ? extras : null,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  SizedBox(height: 16),
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _tintFill(AppColors.accent),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _tintBorder(AppColors.accent)),
          ),
          child: Center(
            child: PixelArtIcon(
              type: PixelIconType.sparkles,
              size: 18,
              color: AppColors.accent,
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            l10n.suggestSheetTitle,
            style: TextStyle(
              fontFamily: _ff,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: MaterialLocalizations.of(context).closeButtonLabel,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.glass2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Icon(Icons.close_rounded, size: 17, color: AppColors.textSecondary),
            ),
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
            color: _tintFill(AppColors.accent),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _tintBorder(AppColors.accent)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _tintFill(AppColors.accent),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _tintBorder(AppColors.accent)),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 19,
                  color: AppColors.accent,
                ),
              ),
              SizedBox(height: 12),
              Text(
                l10n.suggestGoalMetTitle,
                style: TextStyle(
                  fontFamily: _ff,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                l10n.suggestGoalMetBody,
                style: TextStyle(
                  fontFamily: _ff,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
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
  // Sections stagger in behind the route slide (same choreography as the
  // food-log sheet); standalone (tests) they render statically.
  Widget _buildChoose({Key? key}) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Entrance(
          animation: widget.routeAnimation,
          child: _remainingHero(),
        ),
        SizedBox(height: 18),
        _Entrance(
          animation: widget.routeAnimation,
          begin: 0.05,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(l10n.suggestMealSlot),
              SizedBox(height: 9),
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
            ],
          ),
        ),
        SizedBox(height: 18),
        _Entrance(
          animation: widget.routeAnimation,
          begin: 0.1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(l10n.suggestStyle),
              SizedBox(height: 9),
              // Wrapped grid: "high_protein" runs long in both languages and
              // was fighting the other chips for space. The treat chip
              // ("Junk food") sits on its own row — it's the deliberately
              // unhealthy option the owner asked for, calories still sized.
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
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _styleChip('treat')),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 18),
        _Entrance(
          animation: widget.routeAnimation,
          begin: 0.15,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(l10n.suggestCaloriesLabel),
              SizedBox(height: 8),
              _buildCalorieField(),
            ],
          ),
        ),
        SizedBox(height: 22),
        _Entrance(
          animation: widget.routeAnimation,
          begin: 0.2,
          child: _ctaButton(
            label: l10n.suggestCta,
            icon: Icons.auto_awesome,
            onTap: _request,
          ),
        ),
      ],
    );
  }

  // ── Remaining-budget hero — the context everything below sizes against ────
  Widget _remainingHero() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.isLight
            ? AppColors.accent.withValues(alpha: 0.07)
            : AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.isLight
              ? AppColors.accent.withValues(alpha: 0.20)
              : AppColors.accent.withValues(alpha: 0.26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PixelArtIcon(
                type: PixelIconType.plate,
                size: 15,
                color: AppColors.accent,
              ),
              SizedBox(width: 6),
              Text(
                l10n.caloriesRemaining,
                style: TextStyle(
                  fontFamily: _ff,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.remainingKcal.round().toString(),
                style: TextStyle(
                  fontFamily: _ff,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  height: 1.0,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 6),
              Text(
                l10n.kcal,
                style: TextStyle(
                  fontFamily: _ff,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _macroPill(AppColors.accentProtein,
                  '${widget.remainingProtein.round()}g'),
              SizedBox(width: 7),
              _macroPill(AppColors.accentCarbs,
                  '${widget.remainingCarbs.round()}g'),
              SizedBox(width: 7),
              _macroPill(AppColors.accentFat,
                  '${widget.remainingFat.round()}g'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroPill(Color color, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.glass2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontFamily: _ff,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? AppColors.accentCalories.withValues(alpha: 0.6)
                  : (_calorieFocus.hasFocus
                        ? AppColors.accent.withValues(alpha: 0.5)
                        : AppColors.glassBorder),
              width: hasError || _calorieFocus.hasFocus ? 1.5 : 1,
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
                    fontFamily: _ff,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.suggestCaloriesHint,
                    hintStyle: TextStyle(
                      fontFamily: _ff,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted.withValues(alpha: 0.7),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 17,
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
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.glass3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  l10n.kcal,
                  style: TextStyle(
                    fontFamily: _ff,
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
        SizedBox(height: 9),
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
                  fontFamily: _ff,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
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
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    '${l10n.suggestUseRemaining} · ${widget.remainingKcal.round()} ${l10n.kcal}',
                    style: TextStyle(
                      fontFamily: _ff,
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
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              l10n.suggestGoalMetBody,
              style: TextStyle(
                fontFamily: _ff,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: _ff,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
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
      'treat' => l10n.styleJunk,
      _ => l10n.styleBalanced,
    };
    final selected = _style == style;
    return _chip(
      label: label,
      selected: selected,
      onTap: () => setState(() => _style = style),
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
          height: 44,
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.glass2,
            borderRadius: BorderRadius.circular(14),
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
                  size: 14,
                  color: selected ? AppColors.onPrimary : AppColors.textMuted,
                ),
                SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _ff,
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
      child: _PressScale(
        onTap: onTap,
        reduceMotion: _systemReduceMotion,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: AppColors.voltGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: AppColors.onPrimary),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: _ff,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.glass2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _tintFill(AppColors.accentCalories),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _tintBorder(AppColors.accentCalories)),
                ),
                child: Center(
                  child: PixelArtIcon(
                    type: PixelIconType.fire,
                    size: 16,
                    color: AppColors.accentCalories,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${l10n.suggestTargetLabel}: ${_lastTargetCalories ?? _effectiveTargetCalories} ${l10n.kcal} · $_slotLabel',
                  style: TextStyle(
                    fontFamily: _ff,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // 4-segment story bar: one segment per real step the function runs.
          Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                if (i > 0) SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < _activeStep
                          ? AppColors.accent
                          : (i == _activeStep
                                ? AppColors.accent.withValues(alpha: 0.45)
                                : AppColors.glass3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 16),
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0) SizedBox(height: 10),
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
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state == 1 ? AppColors.accent : Colors.transparent,
              border: Border.all(
                color: state == -1
                    ? AppColors.glassBorder
                    : (state == 1
                          ? AppColors.accent
                          : AppColors.accent.withValues(alpha: 0.5)),
                width: 1.5,
              ),
            ),
            child: state == 1
                ? Icon(Icons.check, size: 12, color: AppColors.onPrimary)
                : state == 0
                ? Padding(
                    padding: EdgeInsets.all(4),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: AppColors.accent,
                    ),
                  )
                : null,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: _ff,
                fontSize: 12.5,
                fontWeight: state == -1 ? FontWeight.w600 : FontWeight.w700,
                color: state == -1 ? AppColors.textMuted : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: the result — match ring, photos, servings, totals, log ────────
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
        // Hero: match ring + animated kcal count-up — the accuracy is a dial,
        // not a footnote.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.glass2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              _MatchRing(
                ratio: matchRatio,
                percent: matchPercent,
                color: matchColor,
                matchLabel: l10n.suggestMatchLabel,
                fontFamily: _ff,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.suggestedMealTitle,
                      style: TextStyle(
                        fontFamily: _ff,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.textMuted,
                      ),
                    ),
                    SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: suggestion.totalCalories.toDouble(),
                      ),
                      duration: const Duration(milliseconds: 550),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        value.round().toString(),
                        style: TextStyle(
                          fontFamily: _ff,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          height: 1.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '${l10n.suggestTargetLabel} ${(_lastTargetCalories ?? _effectiveTargetCalories)} ${l10n.kcal} · $_slotLabel',
                      style: TextStyle(
                        fontFamily: _ff,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
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
            _macroBadge(
              '${_fmt(suggestion.totalProtein)}g',
              l10n.protein,
              AppColors.accentProtein,
            ),
            _macroBadge(
              '${_fmt(suggestion.totalCarbs)}g',
              l10n.carbs,
              AppColors.accentCarbs,
            ),
            _macroBadge(
              '${_fmt(suggestion.totalFat)}g',
              l10n.fat,
              AppColors.accentFat,
            ),
          ],
        ),
        if (explanation.isNotEmpty) ...[
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _tintFill(AppColors.accent),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _tintBorder(AppColors.accent)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelArtIcon(
                  type: PixelIconType.sparkles,
                  size: 13,
                  color: AppColors.accent,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    explanation,
                    style: TextStyle(
                      fontFamily: _ff,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.glass2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 46,
              height: 46,
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
                          size: 17,
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.glass3,
                      child: Icon(
                        Icons.restaurant_rounded,
                        size: 17,
                        color: AppColors.textMuted,
                      ),
                    ),
            ),
          ),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _ff,
                    fontSize: 13,
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
                    fontFamily: _ff,
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
                    fontFamily: _ff,
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
              fontFamily: _ff,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // Squircle macro total — same tinted anatomy as the calories-card nutrients.
  Widget _macroBadge(String value, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: _tintFill(color),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _tintBorder(color)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: _ff,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _ff,
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
      child: _PressScale(
        onTap: onTap,
        reduceMotion: _systemReduceMotion,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
                  fontFamily: _ff,
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
            color: _tintFill(AppColors.accentCalories),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _tintBorder(AppColors.accentCalories)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _tintFill(AppColors.accentCalories),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: _tintBorder(AppColors.accentCalories),
                  ),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 17,
                  color: AppColors.accentCalories,
                ),
              ),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: _ff,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
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

// ─── Shared pieces ────────────────────────────────────────────────────────────

/// Press feedback: scale-down on contact, release springs back. Skipped when
/// the system asks for reduced motion.
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool reduceMotion;

  const _PressScale({
    required this.child,
    required this.onTap,
    this.reduceMotion = false,
  });

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        if (!widget.reduceMotion) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      onTapCancel: () {
        if (_pressed) setState(() => _pressed = false);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Match-accuracy dial — the ±10% validation tolerance the server enforces,
/// shown as a ring instead of a bare number.
class _MatchRing extends StatelessWidget {
  final double ratio;
  final int percent;
  final Color color;
  final String matchLabel;
  final String? fontFamily;

  const _MatchRing({
    required this.ratio,
    required this.percent,
    required this.color,
    required this.matchLabel,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: ratio),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => SizedBox(
        width: 78,
        height: 78,
        child: CustomPaint(
          painter: _RingPainter(ratio: animated, color: color),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  matchLabel,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.textMuted,
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

class _RingPainter extends CustomPainter {
  final double ratio;
  final Color color;

  _RingPainter({required this.ratio, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 6) / 2;
    final stroke = 5.5;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.glass3;
    canvas.drawCircle(center, radius, track);

    if (ratio > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * ratio.clamp(0.0, 1.0),
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.ratio != ratio || oldDelegate.color != color;
}

/// Staggered entrance behind the route slide (food-log sheet choreography).
/// A null [animation] renders the child directly — the standalone/test path.
class _Entrance extends StatelessWidget {
  final Animation<double>? animation;
  final double begin;
  final Widget child;

  const _Entrance({
    required this.animation,
    this.begin = 0.0,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final anim = animation;
    if (anim == null) return child;
    final curved = CurvedAnimation(
      parent: anim,
      curve: Interval(begin, 1.0, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.14),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
