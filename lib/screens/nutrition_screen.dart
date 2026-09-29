import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/nutrition_service.dart';
import '../services/stats_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/add_food_sheet.dart';
import '../widgets/app_background.dart';
import '../widgets/food/food_thumbnail.dart';
import '../widgets/not_today_banner.dart';
import '../widgets/pixel_art_icons.dart';
import 'nutrition_history_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NutritionScreen — Next-Gen CoreGym Fitness & Macro Tracker
// ─────────────────────────────────────────────────────────────────────────────

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  NutritionScreenState createState() => NutritionScreenState();
}

class NutritionScreenState extends State<NutritionScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _ringController;
  late AnimationController _macroController;
  late AnimationController _fadeController;
  late AnimationController _lineChartController;
  late Animation<double> _ringAnim;

  final _nutritionService = NutritionService();
  final _statsService = StatsService();

  Map<String, List<Map<String, dynamic>>> _todayLogs = {
    'breakfast': [],
    'lunch': [],
    'dinner': [],
    'snack': [],
  };
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _goals = {};
  List<Map<String, dynamic>> _weeklyProgress = [];
  bool _isLoading = true;

  /// The day this screen's data was loaded for — mirrors the Home week
  /// strip's selection (the shared selected-log-date state). Everything on
  /// the TODAY tab (logs, totals, hero, micros) is attributed to it.
  DateTime _loadedDate = DateTime.now();

  /// Water edits stay today-only (updateTodaySummary always writes today's
  /// row) — the same read-only rule the Home activity cards apply to past
  /// days via canEditDaily.
  bool get _canEditWater => _isSameDay(_loadedDate, DateTime.now());

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Hero card pager — page 1 = calories (gauge / net energy / progress),
  // page 2 = the fiber/sugar/sodium tiles merged in from the old standalone
  // micronutrients card (2026-09-27 redesign). keepPage:false so a fresh
  // open always lands on the calories page, like the Home card.
  final PageController _heroPageController = PageController(keepPage: false);
  int _heroPage = 0;

  /// Fixed viewport height for both hero pages: page 1's natural content
  /// (135 gauge + paddings + progress track ≈ 214) with headroom.
  static const double _heroPageHeight = 218;

  // Track expanded meal sections
  final Set<String> _expandedMeals = {'breakfast', 'lunch', 'dinner', 'snack'};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Perf pass G3: the old per-tick `addListener(setState)` rebuilt the
    // whole ~3.3k-line screen on every controller tick. Nothing outside the
    // TabBar/TabBarView reads the index, so no explicit rebuild is needed —
    // both widgets animate themselves through the shared controller.

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _macroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _lineChartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Perf pass G6: the unused _pulseController (repeat(reverse: true)) was
    // removed — it scheduled frames at display rate forever while driving
    // nothing.

    _ringAnim = CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOutCubic,
    );

    // Follow the Home week strip: the shared selected-log-date notifier
    // fires when the user picks another day, so the TODAY tab always shows
    // the day being viewed.
    NutritionService.selectedLogDate.addListener(_onSelectedDateChanged);

    _loadData();
  }

  void _onSelectedDateChanged() {
    if (!mounted) return;
    if (_isSameDay(NutritionService.currentLogDate, _loadedDate)) return;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _ringController.reset();
    _macroController.reset();
    _fadeController.reset();

    // Capture the day up front: the notifier can move again mid-fetch (fast
    // strip taps) — results for a day that is no longer selected are dropped.
    final d = NutritionService.currentLogDate;
    _loadedDate = d;

    final results = await Future.wait([
      _nutritionService.getTodayLogs(date: d),
      _statsService.getTodaySummary(date: d),
      _statsService.getGoals(),
      _statsService.getWeeklyProgress(),
    ]);

    if (!mounted) return;
    if (!_isSameDay(d, NutritionService.currentLogDate)) return;
    setState(() {
      _todayLogs = results[0] as Map<String, List<Map<String, dynamic>>>;
      _summary = results[1] as Map<String, dynamic>;
      _goals = results[2] as Map<String, dynamic>;
      _weeklyProgress = List<Map<String, dynamic>>.from(results[3] as Iterable);
      _isLoading = false;
    });

    _ringController.forward();
    _macroController.forward();
    _fadeController.forward();
    _lineChartController.forward();
  }

  Future<void> _deleteLog(String id) async {
    HapticFeedback.mediumImpact();
    await _nutritionService.deleteLog(id);
    await _loadData();
  }

  /// Light refresh of the selected day's logs + summary, used when food was
  /// logged externally
  Future<void> refreshAfterExternalSave() async {
    final d = NutritionService.currentLogDate;
    final results = await Future.wait([
      _nutritionService.getTodayLogs(date: d),
      _statsService.getTodaySummary(date: d),
    ]);
    if (!mounted) return;
    if (!_isSameDay(d, _loadedDate)) return;
    setState(() {
      _todayLogs = results[0] as Map<String, List<Map<String, dynamic>>>;
      _summary = results[1];
    });
    _ringController
      ..reset()
      ..forward();
    _macroController
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    NutritionService.selectedLogDate.removeListener(_onSelectedDateChanged);
    _tabController.dispose();
    _ringController.dispose();
    _macroController.dispose();
    _fadeController.dispose();
    _lineChartController.dispose();
    _heroPageController.dispose();
    super.dispose();
  }

  // ─── Computed Values ───────────────────────────────────────────────────────
  double get _caloriesConsumed =>
      (_summary['calories_consumed'] as num?)?.toDouble() ?? 0;
  double get _caloriesGoal =>
      (_goals['daily_calories'] as num?)?.toDouble() ?? 2000;
  double get _caloriesRemaining =>
      (_caloriesGoal - _caloriesConsumed).clamp(0, double.infinity);
  double get _caloriesBurned =>
      (_summary['calories_burned'] as num?)?.toDouble() ?? 0;

  double get _proteinConsumed =>
      (_summary['protein_g'] as num?)?.toDouble() ?? 0;
  double get _proteinGoal =>
      (_goals['daily_protein_g'] as num?)?.toDouble() ?? 150;
  double get _carbsConsumed => (_summary['carbs_g'] as num?)?.toDouble() ?? 0;
  double get _carbsGoal => (_goals['daily_carbs_g'] as num?)?.toDouble() ?? 250;
  double get _fatConsumed => (_summary['fat_g'] as num?)?.toDouble() ?? 0;
  double get _fatGoal => (_goals['daily_fat_g'] as num?)?.toDouble() ?? 65;

  int get _waterConsumed => (_summary['water_ml'] as num?)?.toInt() ?? 0;
  int get _waterGoal => (_goals['daily_water_ml'] as num?)?.toInt() ?? 2500;

  double get _fiberConsumed => (_summary['fiber_g'] as num?)?.toDouble() ?? 0;
  // Column is `sugars_g` in both nutrition_logs and daily_summary.
  double get _sugarConsumed => (_summary['sugars_g'] as num?)?.toDouble() ?? 0;
  double get _sodiumConsumed =>
      (_summary['sodium_mg'] as num?)?.toDouble() ?? 0;

  double get _calorieProgress => _caloriesGoal > 0
      ? (_caloriesConsumed / _caloriesGoal).clamp(0.0, 1.0)
      : 0;
  bool get _isOverGoal => _caloriesConsumed > _caloriesGoal;

  int get _totalFoodsLogged =>
      _todayLogs.values.fold(0, (s, list) => s + list.length);

  String _motivationalMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_caloriesConsumed == 0) return l10n.motivationEmpty;
    if (_calorieProgress < 0.35) return l10n.motivationStart;
    if (_calorieProgress < 0.7) return l10n.motivationZone;
    if (_calorieProgress < 0.95) return l10n.motivationAlmost;
    if (_calorieProgress <= 1.05) return l10n.motivationBullseye;
    return l10n.motivationOver;
  }

  // ─── Water Tracking ────────────────────────────────────────────────────────
  Future<void> _updateWater(int deltaMl) async {
    // Water writes always land on today's summary row — editing while a past
    // day is selected would silently retarget the write. Past days are
    // read-only here (buttons are dimmed too).
    if (!_canEditWater) return;
    HapticFeedback.lightImpact();
    final newAmount = max(0, _waterConsumed + deltaMl);
    setState(() {
      _summary['water_ml'] = newAmount;
    });
    await _statsService.updateWater(newAmount);
  }

  // ─── Goal Editor Modal ─────────────────────────────────────────────────────
  void _showGoalsEditorModal() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NutritionGoalsSheet(
        currentGoals: _goals,
        onGoalsSaved: (newGoals) {
          setState(() {
            _goals = newGoals;
          });
          _loadData();
        },
      ),
    );
  }

  // ─── Add Food Bottom Sheet ─────────────────────────────────────────────────
  void _showAddFoodBottomSheet({String? preselectedMeal}) {
    HapticFeedback.lightImpact();
    AddFoodSheet.show(
      context,
      preselectedMeal: preselectedMeal ?? 'breakfast',
      onFoodLogged: _loadData,
    );
  }

  // ─── Edit Food Log Item ────────────────────────────────────────────────────
  void _showEditLogSheet(Map<String, dynamic> log) {
    HapticFeedback.lightImpact();
    final qtyCtrl = TextEditingController(
      text: ((log['quantity'] as num?)?.toDouble() ?? 100).toStringAsFixed(0),
    );
    String currentMeal = log['meal_type'] ?? 'breakfast';
    final double originalQty = (log['quantity'] as num?)?.toDouble() ?? 100.0;
    final double originalCals = (log['calories'] as num?)?.toDouble() ?? 0.0;
    final double originalProtein =
        (log['protein_g'] as num?)?.toDouble() ?? 0.0;
    final double originalCarbs = (log['carbs_g'] as num?)?.toDouble() ?? 0.0;
    final double originalFat = (log['fat_g'] as num?)?.toDouble() ?? 0.0;

    double factor(double currentQty) =>
        originalQty > 0 ? (currentQty / originalQty) : 1.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final q = double.tryParse(qtyCtrl.text) ?? originalQty;
          final f = factor(q);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log['food_name'] ?? AppLocalizations.of(ctx)!.foodItemFallback,
                              style: AppText.headlineSm.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              AppLocalizations.of(ctx)!.editServingMeal,
                              style: AppText.bodySm.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteLog(log['id'].toString());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Live Macro Preview Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _editMacroTile(
                          AppLocalizations.of(context)!.caloriesLabel,
                          '${(originalCals * f).toInt()}',
                          'kcal',
                          AppColors.accentCalories,
                        ),
                        _editMacroTile(
                          AppLocalizations.of(context)!.protein,
                          (originalProtein * f).toStringAsFixed(1),
                          'g',
                          AppColors.accentProtein,
                        ),
                        _editMacroTile(
                          AppLocalizations.of(context)!.carbs,
                          (originalCarbs * f).toStringAsFixed(1),
                          'g',
                          AppColors.accentCarbs,
                        ),
                        _editMacroTile(
                          AppLocalizations.of(context)!.fat,
                          (originalFat * f).toStringAsFixed(1),
                          'g',
                          AppColors.accentFat,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Quantity
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setSheetState(() {}),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Serving Amount (grams / units)',
                      suffixText: 'g',
                      filled: true,
                      fillColor: AppColors.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Multiplier quick chips
                  Row(
                    children: [0.5, 1.0, 1.5, 2.0].map((m) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: BorderSide(
                                color: (q == originalQty * m)
                                    ? AppColors.primary
                                    : AppColors.borderSubtle,
                              ),
                              backgroundColor: (q == originalQty * m)
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              setSheetState(() {
                                qtyCtrl.text = (originalQty * m)
                                    .toStringAsFixed(0);
                              });
                            },
                            child: Text(
                              '${m}x',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: (q == originalQty * m)
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Meal Type Selector
                  Text(
                    'Assigned Meal',
                    style: AppText.labelMd.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _mealChoiceButton(
                        'breakfast',
                        'Breakfast',
                        '🍳',
                        currentMeal,
                        (m) => setSheetState(() => currentMeal = m),
                      ),
                      _mealChoiceButton(
                        'lunch',
                        'Lunch',
                        '🥗',
                        currentMeal,
                        (m) => setSheetState(() => currentMeal = m),
                      ),
                      _mealChoiceButton(
                        'dinner',
                        'Dinner',
                        '🍽',
                        currentMeal,
                        (m) => setSheetState(() => currentMeal = m),
                      ),
                      _mealChoiceButton(
                        'snack',
                        'Snack',
                        '🥜',
                        currentMeal,
                        (m) => setSheetState(() => currentMeal = m),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final newQty =
                            double.tryParse(qtyCtrl.text) ?? originalQty;
                        final multiplier = factor(newQty);
                        HapticFeedback.mediumImpact();
                        final navigator = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(ctx);
                        final ok = await _nutritionService.updateLog(
                          logId: log['id'].toString(),
                          quantity: newQty,
                          calories: originalCals * multiplier,
                          proteinG: originalProtein * multiplier,
                          carbsG: originalCarbs * multiplier,
                          fatG: originalFat * multiplier,
                          mealType: currentMeal,
                        );
                        if (!ok) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text(
                                '❌ حدث خطأ عند الحفظ — تأكد من الاتصال بالإنترنت',
                              ),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return; // keep the edit sheet open
                        }
                        navigator.pop();
                        _loadData();
                      },
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mealChoiceButton(
    String type,
    String label,
    String emoji,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    final sel = selected == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelected(type),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: sel ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editMacroTile(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          '$label ($unit)',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ─── Build UI ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: AppBackground(
        child: _isLoading
            ? _buildShimmer()
            : TabBarView(
                controller: _tabController,
                children: [_buildTodayTab(), _buildHistoryTab()],
              ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.navNutrition,
                style: AppText.headlineLg.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  AppLocalizations.of(context)!.kcalGoalLabel('${_caloriesGoal.toInt()}'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          Text(
            _isLoading
                ? AppLocalizations.of(context)!.syncingNutrition
                : '${AppLocalizations.of(context)!.itemsLoggedCount('$_totalFoodsLogged')} · ${AppLocalizations.of(context)!.kcalRemainingShort('${_caloriesRemaining.toInt()}')}',
            style: AppText.bodySm.copyWith(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Icon(
              Icons.tune_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
          onPressed: _showGoalsEditorModal,
          tooltip: 'Configure Goals',
        ),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: AppLocalizations.of(context)!.today),
                  Tab(text: AppLocalizations.of(context)!.historyTab),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Shimmer Loading ───────────────────────────────────────────────────────
  Widget _buildShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Mirrors the redesigned layout: tall 2-page hero, hydration,
          // macros carousel. The old 4th block (standalone micros card) is
          // gone — micros now live inside the hero card.
          _shimmerBox(280, radius: 24),
          const SizedBox(height: 16),
          _shimmerBox(85, radius: 20),
          const SizedBox(height: 16),
          _shimmerBox(190, radius: 24),
        ],
      ),
    );
  }

  Widget _shimmerBox(double h, {double radius = 16}) => Container(
    width: double.infinity,
    height: h,
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.borderSubtle),
    ),
  );

  // ─── TODAY TAB ─────────────────────────────────────────────────────────────
  Widget _buildTodayTab() {
    // Account for: bottom safe area + nav bar (68) + nav margin (12) + FAB (56) + gap (16)
    final bottomPad = MediaQuery.of(context).padding.bottom + 68 + 12 + 56 + 16;
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "Not today" banner — while the Home week strip targets a past
            // day, this whole tab mirrors that day and every new entry lands
            // on it, so say so. Disappears the moment today is selected.
            if (!_isSameDay(_loadedDate, DateTime.now()))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: LoggingNotTodayBanner(
                  date: _loadedDate,
                  isArabic:
                      Localizations.localeOf(context).languageCode == 'ar',
                ),
              ),
            _FadeSlideIn(
              parent: _fadeController,
              delayMs: 50,
              child: _buildHeroCaloriesCard(),
            ),
            const SizedBox(height: 14),
            _FadeSlideIn(
              parent: _fadeController,
              delayMs: 120,
              child: _buildHydrationCard(),
            ),
            const SizedBox(height: 14),
            _FadeSlideIn(
              parent: _fadeController,
              delayMs: 180,
              child: _buildMacrosCard(),
            ),
            const SizedBox(height: 22),
            _FadeSlideIn(
              parent: _fadeController,
              delayMs: 280,
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.dailyMeals,
                    style: AppText.headlineMd.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    AppLocalizations.of(context)!.itemsLoggedCount('$_totalFoodsLogged'),
                    style: AppText.bodySm.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _FadeSlideIn(
              parent: _fadeController,
              delayMs: 320,
              child: _buildMealSection(
                AppLocalizations.of(context)!.breakfast,
                'breakfast',
                Icons.wb_sunny_rounded,
                const Color(0xFFFF9800),
              ),
            ),
            const SizedBox(height: 10),
            _FadeSlideIn(
              parent: _fadeController,
              delayMs: 380,
              child: _buildMealSection(
                AppLocalizations.of(context)!.lunch,
                'lunch',
                Icons.restaurant_rounded,
                const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 10),
            _FadeSlideIn(
              parent: _fadeController,
              delayMs: 440,
              child: _buildMealSection(
                AppLocalizations.of(context)!.dinner,
                'dinner',
                Icons.nights_stay_rounded,
                const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(height: 10),
            _FadeSlideIn(
              parent: _fadeController,
              delayMs: 500,
              child: _buildMealSection(
                AppLocalizations.of(context)!.snack,
                'snack',
                Icons.eco_rounded,
                AppColors.accentFat,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero Calories Card ────────────────────────────────────────────────────
  // One card, two swipeable pages (2026-09-27 redesign): page 1 = calories
  // (gauge, net energy, progress track), page 2 = the fiber/sugar/sodium
  // tiles that used to be a standalone card in the scroll body. Same token
  // system as before — surface card + hairline border, no glass surfaces.
  // The status banner stays fixed above both pages.
  Widget _buildHeroCaloriesCard() {
    final statusColor = _calorieProgress > 1.0
        ? AppColors.error
        : _calorieProgress >= 0.85
        ? AppColors.accentCalories
        : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Coaching Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(23),
              ),
              border: Border(
                bottom: BorderSide(color: statusColor.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _motivationalMessage(context),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(_calorieProgress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Two-page body — swipe horizontally (flips automatically in RTL).
          SizedBox(
            height: _heroPageHeight,
            child: PageView(
              controller: _heroPageController,
              onPageChanged: (page) => setState(() => _heroPage = page),
              children: [
                _buildHeroCaloriesPage(statusColor),
                _buildHeroMicronutrientsPage(),
              ],
            ),
          ),

          // 2-dot page indicator — neutral ink: a pager dot is informational
          // and the volt accent stays reserved for actionable elements.
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (page) {
                final active = _heroPage == page;
                return GestureDetector(
                  onTap: () => _heroPageController.animateToPage(
                    page,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: active ? 18 : 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.textPrimary
                          : AppColors.textMuted.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero page 1 — calories: gauge, net energy breakdown, progress track ──
  Widget _buildHeroCaloriesPage(Color statusColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              // Calorie Gauge Ring
              SizedBox(
                width: 135,
                height: 135,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _ringAnim,
                      builder: (_, __) {
                        return CustomPaint(
                          size: const Size(135, 135),
                          painter: _ModernCalorieRingPainter(
                            progress: _calorieProgress * _ringAnim.value,
                            ringColor: statusColor,
                            trackColor: AppColors.surfaceContainerHigh,
                            strokeWidth: 12,
                          ),
                        );
                      },
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: _caloriesConsumed.toDouble(),
                          ),
                          duration: const Duration(milliseconds: 1400),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, _) {
                            final number = Text(
                              val.toInt().toString(),
                              style: AppText.displaySm.copyWith(
                                fontWeight: FontWeight.w900,
                                // Mask base — the volt sweep below recolors
                                // it; flat error red when over goal so the
                                // warning reads instantly.
                                color: _isOverGoal
                                    ? AppColors.error
                                    : Colors.white,
                                height: 1,
                              ),
                            );
                            if (_isOverGoal) return number;
                            // The one volt moment on the card: a subtle
                            // Electric-Volt → soft-volt sweep on the kcal
                            // number (2026-09-27 redesign).
                            return ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  AppColors.accent,
                                  AppColors.primary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              blendMode: BlendMode.srcIn,
                              child: number,
                            );
                          },
                        ),
                        Text(
                          AppLocalizations.of(context)!.kcal,
                          style: AppText.bodySm.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context)!.ofGoal('${_caloriesGoal.toInt()}'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 22),

              // Net Energy Breakdown Columns
              Expanded(
                child: Column(
                  children: [
                    _heroStatRow(
                      label: AppLocalizations.of(context)!.eaten,
                      value: '${_caloriesConsumed.toInt()}',
                      unit: 'kcal',
                      icon: PixelIconType.fire,
                      color: AppColors.accentCalories,
                    ),
                    const SizedBox(height: 10),
                    _heroStatRow(
                      label: AppLocalizations.of(context)!.burned,
                      value: '${_caloriesBurned.toInt()}',
                      unit: 'kcal',
                      icon: PixelIconType.dumbbell,
                      color: AppColors.accentWorkout,
                    ),
                    const SizedBox(height: 10),
                    _heroStatRow(
                      label: _isOverGoal ? AppLocalizations.of(context)!.overBudget : AppLocalizations.of(context)!.caloriesRemaining,
                      value: _isOverGoal
                          ? '+${(_caloriesConsumed - _caloriesGoal).toInt()}'
                          : '${_caloriesRemaining.toInt()}',
                      unit: 'kcal',
                      icon: PixelIconType.bolt,
                      color: _isOverGoal
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Calorie Progress Track Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _calorieProgress,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '0 kcal',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.targetKcal('${_caloriesGoal.toInt()}'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Hero page 2 — micronutrients merged from the old standalone card ──────
  Widget _buildHeroMicronutrientsPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADDITIONAL NUTRIENTS',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _micronutrientTile(
                  'Fiber',
                  _fiberConsumed,
                  30,
                  'g',
                  AppColors.accentFat,
                  Icons.spa_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _micronutrientTile(
                  'Sugar',
                  _sugarConsumed,
                  50,
                  'g',
                  const Color(0xFFFD79A8),
                  Icons.cake_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _micronutrientTile(
                  'Sodium',
                  _sodiumConsumed,
                  2300,
                  'mg',
                  const Color(0xFFF59E0B),
                  Icons.grain_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStatRow({
    required String label,
    required String value,
    required String unit,
    required PixelIconType icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: PixelArtIcon(type: icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Hydration Card ────────────────────────────────────────────────────────
  Widget _buildHydrationCard() {
    final progress = _waterGoal > 0
        ? (_waterConsumed / _waterGoal).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentWater.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const PixelArtIcon(
                  type: PixelIconType.waterDrop,
                  size: 20,
                  color: AppColors.accentWater,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.water,
                      style: AppText.headlineSm.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.dailyTargetMl('$_waterGoal'),
                      style: AppText.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$_waterConsumed',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accentWater,
                    ),
                  ),
                  Text(
                    'ml logged',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Water Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.accentWater,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Quick Action Water Buttons — dimmed + inert on a past day
          // (water edits are today-only; see _updateWater).
          IgnorePointer(
            ignoring: !_canEditWater,
            child: Opacity(
              opacity: _canEditWater ? 1.0 : 0.4,
              child: Row(
                children: [
                  Expanded(
                    child: _waterQuickButton(
                      label: '+250 ml',
                      sub: AppLocalizations.of(context)!.waterGlassSub,
                      onTap: () => _updateWater(250),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _waterQuickButton(
                      label: '+500 ml',
                      sub: AppLocalizations.of(context)!.waterBottleSub,
                      onTap: () => _updateWater(500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _updateWater(-250),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Icon(
                        Icons.undo_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waterQuickButton({
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.accentWater.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.accentWater.withValues(alpha: 0.2),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentWater,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.accentWater.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Target Macros Card — horizontal carousel (2026-09-27 redesign) ───────
  // One compact card per macro (protein/carbs/fat), horizontally scrollable
  // on narrow screens. Same per-macro accents as before; each card carries a
  // rounded-square icon badge, current/goal and a compact progress bar.
  Widget _buildMacrosCard() {
    final macros = [
      (
        label: AppLocalizations.of(context)!.protein,
        current: _proteinConsumed,
        goal: _proteinGoal,
        color: AppColors.accentProtein,
        icon: PixelIconType.chicken,
        kcalFactor: 4,
      ),
      (
        label: AppLocalizations.of(context)!.carbs,
        current: _carbsConsumed,
        goal: _carbsGoal,
        color: AppColors.accentCarbs,
        icon: PixelIconType.grain,
        kcalFactor: 4,
      ),
      (
        label: AppLocalizations.of(context)!.fat,
        current: _fatConsumed,
        goal: _fatGoal,
        color: AppColors.accentFat,
        icon: PixelIconType.avocado,
        kcalFactor: 9,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.macronutrients,
                  style: AppText.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  AppLocalizations.of(context)!.dailyGoalTargets,
                  style: AppText.bodySm.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: macros.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final m = macros[i];
                return _macroCarouselCard(
                  label: m.label,
                  current: m.current,
                  goal: m.goal,
                  color: m.color,
                  icon: m.icon,
                  kcalFactor: m.kcalFactor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroCarouselCard({
    required String label,
    required double current,
    required double goal,
    required Color color,
    required PixelIconType icon,
    required int kcalFactor,
  }) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final remaining = (goal - current).clamp(0.0, double.infinity);
    final cals = (current * kcalFactor).toInt();

    return Container(
      width: 156,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rounded-square icon badge — squircles, not circles.
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: PixelArtIcon(type: icon, size: 15, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${current.toInt()}g',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '/ ${goal.toInt()}g',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            AppLocalizations.of(context)!.macroLeftKcal(
              '$cals',
              '${remaining.toInt()}',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _micronutrientTile(
    String label,
    double current,
    double goal,
    String unit,
    Color color,
    IconData icon,
  ) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${current.toStringAsFixed(current >= 10 ? 0 : 1)}$unit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Meal Section ──────────────────────────────────────────────────────────
  Widget _buildMealSection(
    String title,
    String mealType,
    IconData icon,
    Color accentColor,
  ) {
    final logs = _todayLogs[mealType] ?? [];
    final totalCals = logs.fold(
      0.0,
      (s, l) => s + ((l['calories'] as num?) ?? 0),
    );
    final totalProtein = logs.fold(
      0.0,
      (s, l) => s + ((l['protein_g'] as num?) ?? 0),
    );
    final totalCarbs = logs.fold(
      0.0,
      (s, l) => s + ((l['carbs_g'] as num?) ?? 0),
    );
    final totalFat = logs.fold(0.0, (s, l) => s + ((l['fat_g'] as num?) ?? 0));
    final hasLogs = logs.isNotEmpty;
    final isExpanded = _expandedMeals.contains(mealType);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasLogs
              ? accentColor.withValues(alpha: 0.3)
              : AppColors.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isExpanded) {
                  _expandedMeals.remove(mealType);
                } else {
                  _expandedMeals.add(mealType);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppText.headlineSm.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (hasLogs)
                          Text(
                            '${logs.length} item${logs.length > 1 ? 's' : ''} · ${totalProtein.toStringAsFixed(0)}g protein',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (hasLogs) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${totalCals.toInt()} kcal',
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Action: the single "+" entry — food logging app-wide goes
                  // through this flow (the FAB opens the same sheet).
                  GestureDetector(
                    onTap: () =>
                        _showAddFoodBottomSheet(preselectedMeal: mealType),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  AnimatedRotation(
                    turns: isExpanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Logged Food Items
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                if (!hasLogs)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.restaurant_outlined,
                            size: 16,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.noFoodLogged,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showAddFoodBottomSheet(
                              preselectedMeal: mealType,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 14),
                            label: Text(AppLocalizations.of(context)!.addLabel),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                ...logs.asMap().entries.map((entry) {
                  final log = entry.value;
                  return Dismissible(
                    key: Key(log['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: AppColors.error.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 24,
                      ),
                    ),
                    confirmDismiss: (_) =>
                        _showDeleteConfirm(context, log['food_name'] ?? ''),
                    onDismissed: (_) => _deleteLog(log['id'].toString()),
                    child: _buildLogItem(log),
                  );
                }),

                if (hasLogs)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(19),
                      ),
                      border: Border(
                        top: BorderSide(color: AppColors.borderSubtle),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.mealTotals,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        _mealTotalPill(
                          '${totalCals.toInt()} kcal',
                          accentColor,
                        ),
                        const SizedBox(width: 4),
                        _mealTotalPill(
                          'P ${totalProtein.toStringAsFixed(0)}g',
                          AppColors.accentProtein,
                        ),
                        const SizedBox(width: 4),
                        _mealTotalPill(
                          'C ${totalCarbs.toStringAsFixed(0)}g',
                          AppColors.accentCarbs,
                        ),
                        const SizedBox(width: 4),
                        _mealTotalPill(
                          'F ${totalFat.toStringAsFixed(0)}g',
                          AppColors.accentFat,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    return InkWell(
      onTap: () => _showEditLogSheet(log),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderLight)),
        ),
        child: Row(
          children: [
            // Real catalog photo when the log came from the foods table
            // (image_url resolved in getTodayLogs); category-emoji tile
            // otherwise — same thumbnail language as AddFoodSheet.
            FoodThumbnail(
              imageUrl: log['image_url']?.toString(),
              category: log['category']?.toString(),
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log['food_name'] ?? '',
                    style: AppText.headlineSm.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _microPill(
                        '${(log['quantity'] as num?)?.toInt() ?? 100}g',
                        AppColors.textSecondary,
                      ),
                      _microPill(
                        'P ${((log['protein_g'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}g',
                        AppColors.accentProtein,
                      ),
                      _microPill(
                        'C ${((log['carbs_g'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}g',
                        AppColors.accentCarbs,
                      ),
                      _microPill(
                        'F ${((log['fat_g'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}g',
                        AppColors.accentFat,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${((log['calories'] as num?)?.toDouble() ?? 0).toInt()}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.kcal,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _microPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w800),
    ),
  );

  Widget _mealTotalPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w800),
    ),
  );

  Future<bool?> _showDeleteConfirm(BuildContext ctx, String name) {
    return showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.of(ctx)!.removeItem,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Text(
          AppLocalizations.of(ctx)!.removeLogConfirm(name),
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx)!.removeLabel),
          ),
        ],
      ),
    );
  }

  // ─── HISTORY TAB ──────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    // Delegates to dedicated History page — edit `lib/screens/nutrition_history_page.dart` for chart tweaks.
    // Pass raw weeklyProgress; the page normalizes to exactly 7 chronological days itself.
    return NutritionHistoryPage(
      weeklyProgress: _weeklyProgress,
      caloriesGoal: _caloriesGoal,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nutrition Goals Modal Sheet (Interactive Goal Setting)
// ─────────────────────────────────────────────────────────────────────────────
class _NutritionGoalsSheet extends StatefulWidget {
  final Map<String, dynamic> currentGoals;
  final ValueChanged<Map<String, dynamic>> onGoalsSaved;

  const _NutritionGoalsSheet({
    required this.currentGoals,
    required this.onGoalsSaved,
  });

  @override
  State<_NutritionGoalsSheet> createState() => _NutritionGoalsSheetState();
}

// A named preset so we can detect "is this preset currently active" and
// apply water alongside the macros — the original only touched three fields.
class _GoalPreset {
  final String emoji;
  final String titleEn;
  final String titleAr;
  final double cal, protein, carbs, fat, water;
  const _GoalPreset({
    required this.emoji,
    required this.titleEn,
    required this.titleAr,
    required this.cal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.water,
  });
}

const _presets = [
  _GoalPreset(
    emoji: '🔥',
    titleEn: 'Fat Loss',
    titleAr: 'خسارة دهون',
    cal: 1750,
    protein: 160,
    carbs: 140,
    fat: 50,
    water: 2500,
  ),
  _GoalPreset(
    emoji: '⚖️',
    titleEn: 'Maintain',
    titleAr: 'ثبات الوزن',
    cal: 2100,
    protein: 150,
    carbs: 220,
    fat: 65,
    water: 2500,
  ),
  _GoalPreset(
    emoji: '💪',
    titleEn: 'Bulk / Gain',
    titleAr: 'زيادة عضلات',
    cal: 2600,
    protein: 175,
    carbs: 320,
    fat: 75,
    water: 3000,
  ),
];

class _NutritionGoalsSheetState extends State<_NutritionGoalsSheet> {
  final _statsService = StatsService();
  late double _calories;
  late double _protein;
  late double _carbs;
  late double _fat;
  late double _water;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _calories =
        (widget.currentGoals['daily_calories'] as num?)?.toDouble() ?? 2000;
    _protein =
        (widget.currentGoals['daily_protein_g'] as num?)?.toDouble() ?? 150;
    _carbs = (widget.currentGoals['daily_carbs_g'] as num?)?.toDouble() ?? 250;
    _fat = (widget.currentGoals['daily_fat_g'] as num?)?.toDouble() ?? 65;
    _water =
        (widget.currentGoals['daily_water_ml'] as num?)?.toDouble() ?? 2500;
  }

  bool get _isArabic => Localizations.localeOf(context).languageCode == 'ar';

  double get _macroCalories => (_protein * 4) + (_carbs * 4) + (_fat * 9);

  double get _macroDelta => (_macroCalories - _calories);

  bool get _macroBalanced => _macroDelta.abs() < 100;

  void _applyPreset(_GoalPreset p) {
    HapticFeedback.mediumImpact();
    setState(() {
      _calories = p.cal;
      _protein = p.protein;
      _carbs = p.carbs;
      _fat = p.fat;
      _water = p.water;
    });
  }

  bool _isActivePreset(_GoalPreset p) =>
      _calories == p.cal &&
      _protein == p.protein &&
      _carbs == p.carbs &&
      _fat == p.fat;

  /// Sets the calorie target to match the macro sum in one tap — the
  /// original sheet only *told* the user the numbers disagreed and left
  /// them to fix it by hand.
  void _autoBalanceCalories() {
    HapticFeedback.mediumImpact();
    setState(() => _calories = _macroCalories.clamp(1000, 4500));
  }

  Future<void> _editValue({
    required String title,
    required double current,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onSaved,
  }) async {
    final controller = TextEditingController(text: current.toInt().toString());
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: AppText.fontFamily(isArabic: _isArabic),
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          decoration: InputDecoration(
            suffixText: unit,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) =>
              Navigator.pop(ctx, double.tryParse(controller.text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            // L10N: 'إلغاء' / 'Cancel'
            child: Text(_isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            // L10N: 'تم' / 'Done'
            child: Text(_isArabic ? 'تم' : 'Done'),
          ),
        ],
      ),
    );
    if (result != null) {
      HapticFeedback.selectionClick();
      onSaved(result.clamp(min, max));
    }
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final newGoals = {
      'daily_calories': _calories.toInt(),
      'daily_protein_g': _protein.toInt(),
      'daily_carbs_g': _carbs.toInt(),
      'daily_fat_g': _fat.toInt(),
      'daily_water_ml': _water.toInt(),
    };
    final ok = await _statsService.updateGoals(newGoals);
    if (!mounted) return;
    if (!ok) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          // L10N: keep the Arabic message but make it bilingual-aware
          content: Text(
            _isArabic
                ? '❌ حدث خطأ عند الحفظ — تأكد من الاتصال بالإنترنت'
                : '❌ Couldn\'t save — check your internet connection',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: _isArabic ? 'إعادة المحاولة' : 'Retry',
            textColor: Colors.white,
            onPressed: _save,
          ),
        ),
      );
      return; // Leave the sheet open so the user doesn't lose their edits.
    }
    widget.onGoalsSaved(newGoals);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // L10N: 'إعداد أهداف التغذية' / 'Configure Nutrition Goals'
                      Text(
                        isArabic
                            ? 'إعداد أهداف التغذية'
                            : 'Configure Nutrition Goals',
                        style: AppText.headlineSm.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          fontFamily: AppText.fontFamily(isArabic: isArabic),
                        ),
                      ),
                      // L10N: subtitle
                      Text(
                        isArabic
                            ? 'اضبط السعرات والماكروز اليومية — اضغط على أي رقم لكتابته يدوياً'
                            : 'Tap any number to type it directly, or drag to adjust',
                        style: AppText.bodySm.copyWith(
                          color: AppColors.textSecondary,
                          fontFamily: AppText.fontFamily(isArabic: isArabic),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'اختيارات سريعة' : 'QUICK PRESETS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.1,
                      fontFamily: AppText.fontFamily(isArabic: isArabic),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _presets
                        .map(
                          (p) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: p == _presets.last ? 0 : 8,
                              ),
                              child: _presetChip(
                                preset: p,
                                isArabic: isArabic,
                                active: _isActivePreset(p),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),

                  _sliderTarget(
                    label: isArabic ? 'السعرات اليومية' : 'Daily Calories',
                    value: _calories,
                    min: 1000,
                    max: 4500,
                    step: 50,
                    unit: 'kcal',
                    color: AppColors.primary,
                    isArabic: isArabic,
                    onChanged: (v) => setState(() => _calories = v),
                  ),
                  const SizedBox(height: 16),

                  _sliderTarget(
                    label: isArabic ? 'البروتين اليومي' : 'Daily Protein',
                    value: _protein,
                    min: 50,
                    max: 300,
                    step: 5,
                    unit: 'g',
                    subLabel: '${(_protein * 4).toInt()} kcal',
                    color: AppColors.accentProtein,
                    isArabic: isArabic,
                    onChanged: (v) => setState(() => _protein = v),
                  ),
                  const SizedBox(height: 16),

                  _sliderTarget(
                    label: isArabic
                        ? 'الكربوهيدرات اليومية'
                        : 'Daily Carbohydrates',
                    value: _carbs,
                    min: 50,
                    max: 500,
                    step: 5,
                    unit: 'g',
                    subLabel: '${(_carbs * 4).toInt()} kcal',
                    color: AppColors.accentCarbs,
                    isArabic: isArabic,
                    onChanged: (v) => setState(() => _carbs = v),
                  ),
                  const SizedBox(height: 16),

                  _sliderTarget(
                    label: isArabic ? 'الدهون اليومية' : 'Daily Fats',
                    value: _fat,
                    min: 20,
                    max: 150,
                    step: 5,
                    unit: 'g',
                    subLabel: '${(_fat * 9).toInt()} kcal',
                    color: AppColors.accentFat,
                    isArabic: isArabic,
                    onChanged: (v) => setState(() => _fat = v),
                  ),
                  const SizedBox(height: 16),

                  _sliderTarget(
                    label: isArabic
                        ? 'كمية المياه اليومية'
                        : 'Daily Water Intake',
                    value: _water,
                    min: 1000,
                    max: 5000,
                    step: 250,
                    unit: 'ml',
                    color: AppColors.accentWater,
                    isArabic: isArabic,
                    onChanged: (v) => setState(() => _water = v),
                  ),
                  const SizedBox(height: 20),

                  _macroBalanceCard(isArabic: isArabic),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.onPrimary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        isArabic ? 'حفظ الأهداف' : 'Save Goals',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          fontFamily: AppText.fontFamily(isArabic: isArabic),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Live macro-vs-calorie balance indicator. Unlike the original (a static
  /// info line), this shows a clear visual state (green/amber) AND gives
  /// the user a one-tap way to fix a mismatch instead of dragging sliders
  /// back and forth by trial and error.
  Widget _macroBalanceCard({required bool isArabic}) {
    final balanced = _macroBalanced;
    final color = balanced ? AppColors.primary : AppColors.overGoalWarning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            balanced ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // L10N
                  isArabic
                      ? 'مجموع الماكروز: ${_macroCalories.toInt()} سعرة — الهدف: ${_calories.toInt()} سعرة'
                      : 'Macro sum: ${_macroCalories.toInt()} kcal vs Goal: ${_calories.toInt()} kcal',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFamily: AppText.fontFamily(isArabic: isArabic),
                  ),
                ),
                if (!balanced) ...[
                  const SizedBox(height: 2),
                  Text(
                    isArabic
                        ? 'الماكروز ${_macroDelta > 0 ? "أعلى" : "أقل"} من هدف السعرات بـ ${_macroDelta.abs().toInt()} سعرة'
                        : 'Macros are ${_macroDelta.abs().toInt()} kcal ${_macroDelta > 0 ? "over" : "under"} the calorie goal',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                      fontFamily: AppText.fontFamily(isArabic: isArabic),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!balanced) ...[
            const SizedBox(width: 6),
            TextButton(
              onPressed: _autoBalanceCalories,
              style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              // L10N: 'ظبط' / 'Fix'
              child: Text(
                isArabic ? 'ظبط' : 'Fix',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontFamily: AppText.fontFamily(isArabic: isArabic),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _presetChip({
    required _GoalPreset preset,
    required bool isArabic,
    required bool active,
  }) {
    return Semantics(
      button: true,
      selected: active,
      label: isArabic ? preset.titleAr : preset.titleEn,
      child: GestureDetector(
        onTap: () => _applyPreset(preset),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.borderSubtle,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '${preset.emoji} ${isArabic ? preset.titleAr : preset.titleEn}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.primary : AppColors.textPrimary,
                  fontFamily: AppText.fontFamily(isArabic: isArabic),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${preset.cal.toInt()} kcal',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sliderTarget({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required String unit,
    required Color color,
    required bool isArabic,
    required ValueChanged<double> onChanged,
    String? subLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppText.fontFamily(isArabic: isArabic),
                  ),
                ),
              ),
              // Tapping the value opens a precise numeric-entry dialog —
              // the original only offered coarse drag-to-adjust.
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _editValue(
                  title: label,
                  current: value,
                  min: min,
                  max: max,
                  unit: unit,
                  onSaved: onChanged,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${value.toInt()} $unit',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.edit_rounded, size: 12, color: color),
                        ],
                      ),
                      if (subLabel != null)
                        Text(
                          subLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Semantics(
            label: label,
            value: '${value.toInt()} $unit',
            slider: true,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.15),
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: ((max - min) / step).toInt(),
                onChanged: onChanged,
                // Haptic only fires once the user releases the thumb, not
                // on every intermediate value — dragging the original
                // slider end-to-end fired dozens of setState calls with no
                // tactile pacing.
                onChangeEnd: (_) => HapticFeedback.selectionClick(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Calorie Ring Painter
// ─────────────────────────────────────────────────────────────────────────────
class _ModernCalorieRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  const _ModernCalorieRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Progress Arc
    final sweep = 2 * pi * progress.clamp(0.0, 1.0);
    final progressPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ModernCalorieRingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fade Slide In Transition Helper
// ─────────────────────────────────────────────────────────────────────────────
class _FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int delayMs;
  final Animation<double> parent;

  const _FadeSlideIn({
    required this.child,
    required this.delayMs,
    required this.parent,
  });

  @override
  Widget build(BuildContext context) {
    final start = (delayMs / 1000.0).clamp(0.0, 0.8);
    final end = ((delayMs + 400) / 1000.0).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: parent,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - anim.value)),
          child: child,
        ),
      ),
    );
  }
}
