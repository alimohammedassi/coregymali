import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../l10n/app_localizations.dart';
import '../services/nutrition_service.dart';
import '../services/stats_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/add_food_sheet.dart';
import '../widgets/app_background.dart';
import '../widgets/pixel_art_icons.dart';
import 'food_scan_screen.dart';

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
  late AnimationController _pulseController;
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
  int _selectedHistoryIndex = 0;

  // Track expanded meal sections
  final Set<String> _expandedMeals = {'breakfast', 'lunch', 'dinner', 'snack'};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));

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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _ringAnim = CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOutCubic,
    );

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _ringController.reset();
    _macroController.reset();
    _fadeController.reset();

    final results = await Future.wait([
      _nutritionService.getTodayLogs(),
      _statsService.getTodaySummary(),
      _statsService.getGoals(),
      _statsService.getWeeklyProgress(),
    ]);

    if (!mounted) return;
    setState(() {
      _todayLogs = results[0] as Map<String, List<Map<String, dynamic>>>;
      _summary = results[1] as Map<String, dynamic>;
      _goals = results[2] as Map<String, dynamic>;
      _weeklyProgress = List<Map<String, dynamic>>.from(results[3] as Iterable);
      _isLoading = false;
      if (_weeklyProgress.isNotEmpty) {
        _selectedHistoryIndex = _weeklyProgress.length - 1;
      }
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

  /// Light refresh of today's logs + summary, used when food was logged externally
  Future<void> refreshAfterExternalSave() async {
    final results = await Future.wait([
      _nutritionService.getTodayLogs(),
      _statsService.getTodaySummary(),
    ]);
    if (!mounted) return;
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
    _tabController.dispose();
    _ringController.dispose();
    _macroController.dispose();
    _fadeController.dispose();
    _lineChartController.dispose();
    _pulseController.dispose();
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
  double get _carbsGoal =>
      (_goals['daily_carbs_g'] as num?)?.toDouble() ?? 250;
  double get _fatConsumed => (_summary['fat_g'] as num?)?.toDouble() ?? 0;
  double get _fatGoal => (_goals['daily_fat_g'] as num?)?.toDouble() ?? 65;

  int get _waterConsumed => (_summary['water_ml'] as num?)?.toInt() ?? 0;
  int get _waterGoal => (_goals['daily_water_ml'] as num?)?.toInt() ?? 2500;

  double get _fiberConsumed => (_summary['fiber_g'] as num?)?.toDouble() ?? 0;
  double get _sugarConsumed => (_summary['sugar_g'] as num?)?.toDouble() ?? 0;
  double get _sodiumConsumed =>
      (_summary['sodium_mg'] as num?)?.toDouble() ?? 0;

  double get _calorieProgress =>
      _caloriesGoal > 0 ? (_caloriesConsumed / _caloriesGoal).clamp(0.0, 1.0) : 0;
  bool get _isOverGoal => _caloriesConsumed > _caloriesGoal;

  int get _totalFoodsLogged =>
      _todayLogs.values.fold(0, (s, list) => s + list.length);

  String get _motivationalMessage {
    if (_caloriesConsumed == 0) return 'Log your first meal to start your day! 🌟';
    if (_calorieProgress < 0.35) return 'Great start! Fuel up with clean nutrients 🌱';
    if (_calorieProgress < 0.7) return 'You are in the zone! Hit your protein target ⚡';
    if (_calorieProgress < 0.95) return 'Almost at your target! Finish strong 🎯';
    if (_calorieProgress <= 1.05) return 'Bullseye! Perfect nutrition day 🎉';
    return 'Over target — balance with light hydration 🧘';
  }

  // ─── Water Tracking ────────────────────────────────────────────────────────
  Future<void> _updateWater(int deltaMl) async {
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

  // ─── Quick Calories Dialog ─────────────────────────────────────────────────
  void _showQuickCaloriesDialog(String mealType) {
    HapticFeedback.lightImpact();
    final calCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: 'Quick Snack');
    final protCtrl = TextEditingController(text: '0');
    final carbCtrl = TextEditingController(text: '0');
    final fatCtrl = TextEditingController(text: '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentCalories.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const PixelArtIcon(
                      type: PixelIconType.fire,
                      size: 22,
                      color: AppColors.accentCalories,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quick Log Calories',
                            style: AppText.headlineSm.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        Text(
                          'Add calories directly to ${mealType.toUpperCase()}',
                          style: AppText.bodySm
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  filled: true,
                  fillColor: AppColors.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: calCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: AppText.displaySm.copyWith(
                    color: AppColors.accentCalories, fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  labelText: 'Calories (kcal)',
                  suffixText: 'kcal',
                  filled: true,
                  fillColor: AppColors.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: protCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Protein (g)',
                        filled: true,
                        fillColor: AppColors.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Carbs (g)',
                        filled: true,
                        fillColor: AppColors.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Fat (g)',
                        filled: true,
                        fillColor: AppColors.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
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
                    final cals = double.tryParse(calCtrl.text) ?? 0;
                    if (cals <= 0) return;
                    HapticFeedback.mediumImpact();
                    Navigator.pop(ctx);
                    await _nutritionService.logQuickCalories(
                      foodName: nameCtrl.text.trim().isEmpty
                          ? 'Quick Calories'
                          : nameCtrl.text.trim(),
                      mealType: mealType,
                      calories: cals,
                      proteinG: double.tryParse(protCtrl.text) ?? 0,
                      carbsG: double.tryParse(carbCtrl.text) ?? 0,
                      fatG: double.tryParse(fatCtrl.text) ?? 0,
                    );
                    _loadData();
                  },
                  child: const Text('Add to Log',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Edit Food Log Item ────────────────────────────────────────────────────
  void _showEditLogSheet(Map<String, dynamic> log) {
    HapticFeedback.lightImpact();
    final qtyCtrl = TextEditingController(
        text: ((log['quantity'] as num?)?.toDouble() ?? 100).toStringAsFixed(0));
    String currentMeal = log['meal_type'] ?? 'breakfast';
    final double originalQty =
        (log['quantity'] as num?)?.toDouble() ?? 100.0;
    final double originalCals =
        (log['calories'] as num?)?.toDouble() ?? 0.0;
    final double originalProtein =
        (log['protein_g'] as num?)?.toDouble() ?? 0.0;
    final double originalCarbs =
        (log['carbs_g'] as num?)?.toDouble() ?? 0.0;
    final double originalFat =
        (log['fat_g'] as num?)?.toDouble() ?? 0.0;

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
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
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
                              log['food_name'] ?? 'Food item',
                              style: AppText.headlineSm.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary),
                            ),
                            Text('Edit serving & meal section',
                                style: AppText.bodySm
                                    .copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.error),
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
                            'Calories',
                            '${(originalCals * f).toInt()}',
                            'kcal',
                            AppColors.accentCalories),
                        _editMacroTile(
                            'Protein',
                            (originalProtein * f).toStringAsFixed(1),
                            'g',
                            AppColors.accentProtein),
                        _editMacroTile(
                            'Carbs',
                            (originalCarbs * f).toStringAsFixed(1),
                            'g',
                            AppColors.accentCarbs),
                        _editMacroTile(
                            'Fat',
                            (originalFat * f).toStringAsFixed(1),
                            'g',
                            AppColors.accentFat),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Quantity
                  TextField(
                    controller: qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setSheetState(() {}),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18),
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
                                qtyCtrl.text =
                                    (originalQty * m).toStringAsFixed(0);
                              });
                            },
                            child: Text('${m}x',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: (q == originalQty * m)
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Meal Type Selector
                  Text('Assigned Meal',
                      style: AppText.labelMd.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _mealChoiceButton('breakfast', 'Breakfast', '🍳', currentMeal, (m) => setSheetState(() => currentMeal = m)),
                      _mealChoiceButton('lunch', 'Lunch', '🥗', currentMeal, (m) => setSheetState(() => currentMeal = m)),
                      _mealChoiceButton('dinner', 'Dinner', '🍽', currentMeal, (m) => setSheetState(() => currentMeal = m)),
                      _mealChoiceButton('snack', 'Snack', '🥜', currentMeal, (m) => setSheetState(() => currentMeal = m)),
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
                        Navigator.pop(ctx);
                        await _nutritionService.updateLog(
                          logId: log['id'].toString(),
                          quantity: newQty,
                          calories: originalCals * multiplier,
                          proteinG: originalProtein * multiplier,
                          carbsG: originalCarbs * multiplier,
                          fatG: originalFat * multiplier,
                          mealType: currentMeal,
                        );
                        _loadData();
                      },
                      child: const Text('Save Changes',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
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

  Widget _mealChoiceButton(String type, String label, String emoji, String selected, ValueChanged<String> onSelected) {
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

  Widget _editMacroTile(
      String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w900, color: color)),
        Text('$label ($unit)',
            style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
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
                children: [
                  _buildTodayTab(),
                  _buildHistoryTab(),
                ],
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
                  '${_caloriesGoal.toInt()} kcal goal',
                  style: const TextStyle(
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
                ? 'Syncing nutrition data...'
                : '$_totalFoodsLogged items logged · ${_caloriesRemaining.toInt()} kcal remaining',
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
            child: const Icon(Icons.tune_rounded,
                color: AppColors.textPrimary, size: 20),
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
                    fontWeight: FontWeight.w800, fontSize: 13),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
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
          _shimmerBox(210, radius: 24),
          const SizedBox(height: 16),
          _shimmerBox(85, radius: 20),
          const SizedBox(height: 16),
          _shimmerBox(130, radius: 24),
          const SizedBox(height: 16),
          _shimmerBox(100, radius: 20),
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
            const SizedBox(height: 14),
            _FadeSlideIn(
              parent: _fadeController,
              delayMs: 230,
              child: _buildMicronutrientsCard(),
            ),
            const SizedBox(height: 22),
            _FadeSlideIn(
              parent: _fadeController,
              delayMs: 280,
              child: Row(
                children: [
                  Text(
                    'Daily Meals',
                    style: AppText.headlineMd.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_totalFoodsLogged items logged',
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
                const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero Calories Card ────────────────────────────────────────────────────
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(23)),
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
                          color: statusColor.withValues(alpha: 0.5), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _motivationalMessage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                                begin: 0, end: _caloriesConsumed.toDouble()),
                            duration: const Duration(milliseconds: 1400),
                            curve: Curves.easeOutCubic,
                            builder: (context, val, _) {
                              return Text(
                                val.toInt().toString(),
                                style: AppText.displaySm.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                  height: 1,
                                ),
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
                            'of ${_caloriesGoal.toInt()}',
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
                        label: 'Eaten',
                        value: '${_caloriesConsumed.toInt()}',
                        unit: 'kcal',
                        icon: PixelIconType.fire,
                        color: AppColors.accentCalories,
                      ),
                      const SizedBox(height: 10),
                      _heroStatRow(
                        label: 'Burned',
                        value: '${_caloriesBurned.toInt()}',
                        unit: 'kcal',
                        icon: PixelIconType.dumbbell,
                        color: AppColors.accentWorkout,
                      ),
                      const SizedBox(height: 10),
                      _heroStatRow(
                        label: _isOverGoal ? 'Over Budget' : 'Remaining',
                        value: _isOverGoal
                            ? '+${(_caloriesConsumed - _caloriesGoal).toInt()}'
                            : '${_caloriesRemaining.toInt()}',
                        unit: 'kcal',
                        icon: PixelIconType.bolt,
                        color: _isOverGoal ? AppColors.error : AppColors.primary,
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
                    Text('0 kcal',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                    Text('Target: ${_caloriesGoal.toInt()} kcal',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
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
    final progress =
        _waterGoal > 0 ? (_waterConsumed / _waterGoal).clamp(0.0, 1.0) : 0.0;

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
                    Text('Water Hydration',
                        style: AppText.headlineSm.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    Text('Daily target: $_waterGoal ml',
                        style: AppText.bodySm
                            .copyWith(color: AppColors.textSecondary)),
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
                  Text('ml logged',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
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
                  AppColors.accentWater),
            ),
          ),
          const SizedBox(height: 14),

          // Quick Action Water Buttons
          Row(
            children: [
              Expanded(
                child: _waterQuickButton(
                  label: '+250 ml',
                  sub: 'Glass 🥛',
                  onTap: () => _updateWater(250),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _waterQuickButton(
                  label: '+500 ml',
                  sub: 'Bottle 💧',
                  onTap: () => _updateWater(500),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _updateWater(-250),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: const Icon(Icons.undo_rounded,
                      size: 18, color: AppColors.textSecondary),
                ),
              ),
            ],
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
          border: Border.all(color: AppColors.accentWater.withValues(alpha: 0.2)),
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

  // ─── Target Macros Card ────────────────────────────────────────────────────
  Widget _buildMacrosCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Text(
                'Macronutrients',
                style: AppText.headlineSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'Daily Goal Targets',
                style: AppText.bodySm.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _macroProgressRow(
            label: 'Protein',
            current: _proteinConsumed,
            goal: _proteinGoal,
            color: AppColors.accentProtein,
            icon: PixelIconType.chicken,
            kcalFactor: 4,
          ),
          const SizedBox(height: 18),
          _macroProgressRow(
            label: 'Carbohydrates',
            current: _carbsConsumed,
            goal: _carbsGoal,
            color: AppColors.accentCarbs,
            icon: PixelIconType.grain,
            kcalFactor: 4,
          ),
          const SizedBox(height: 18),
          _macroProgressRow(
            label: 'Fats',
            current: _fatConsumed,
            goal: _fatGoal,
            color: AppColors.accentFat,
            icon: PixelIconType.avocado,
            kcalFactor: 9,
          ),
        ],
      ),
    );
  }

  Widget _macroProgressRow({
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '$cals kcal · ${remaining.toInt()}g left',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${current.toInt()}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  ' / ${goal.toInt()}g',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: AppColors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ─── Micronutrients Card ───────────────────────────────────────────────────
  Widget _buildMicronutrientsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: Column(
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
                  const Color(0xFF10B981),
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
                  const Color(0xFFEC4899),
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
    final totalCals =
        logs.fold(0.0, (s, l) => s + ((l['calories'] as num?) ?? 0));
    final totalProtein =
        logs.fold(0.0, (s, l) => s + ((l['protein_g'] as num?) ?? 0));
    final totalCarbs =
        logs.fold(0.0, (s, l) => s + ((l['carbs_g'] as num?) ?? 0));
    final totalFat =
        logs.fold(0.0, (s, l) => s + ((l['fat_g'] as num?) ?? 0));
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
                          horizontal: 10, vertical: 4),
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

                  // Action: AI Scan Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FoodScanScreen(initialMealType: mealType),
                        ),
                      ).then((_) => _loadData());
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.accentWorkout.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: AppColors.accentWorkout, size: 16),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Action: Add Button
                  GestureDetector(
                    onTap: () =>
                        _showAddFoodBottomSheet(preselectedMeal: mealType),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                  ),
                  const SizedBox(width: 4),

                  AnimatedRotation(
                    turns: isExpanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary, size: 20),
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
                          Icon(Icons.restaurant_outlined,
                              size: 16,
                              color: AppColors.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('No food logged yet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ),
                          TextButton.icon(
                            onPressed: () => _showAddFoodBottomSheet(
                                preselectedMeal: mealType),
                            icon: const Icon(Icons.add_rounded, size: 14),
                            label: const Text('Add'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: () =>
                                _showQuickCaloriesDialog(mealType),
                            icon: const Icon(Icons.bolt_rounded, size: 14),
                            label: const Text('Quick'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.accentCalories,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
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
                      child: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error, size: 24),
                    ),
                    confirmDismiss: (_) =>
                        _showDeleteConfirm(context, log['food_name'] ?? ''),
                    onDismissed: (_) => _deleteLog(log['id'].toString()),
                    child: _buildLogItem(log, accentColor),
                  );
                }),

                if (hasLogs)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(19)),
                      border: Border(
                          top: BorderSide(color: AppColors.borderSubtle)),
                    ),
                    child: Row(
                      children: [
                        Text('Meal totals:',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        const Spacer(),
                        _mealTotalPill(
                            '${totalCals.toInt()} kcal', accentColor),
                        const SizedBox(width: 4),
                        _mealTotalPill(
                            'P ${totalProtein.toStringAsFixed(0)}g',
                            AppColors.accentProtein),
                        const SizedBox(width: 4),
                        _mealTotalPill(
                            'C ${totalCarbs.toStringAsFixed(0)}g',
                            AppColors.accentCarbs),
                        const SizedBox(width: 4),
                        _mealTotalPill('F ${totalFat.toStringAsFixed(0)}g',
                            AppColors.accentFat),
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

  Widget _buildLogItem(Map<String, dynamic> log, Color accentColor) {
    return InkWell(
      onTap: () => _showEditLogSheet(log),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderLight)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                _foodEmoji(log['category'] ?? ''),
                style: const TextStyle(fontSize: 18),
              ),
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
                      _microPill('${(log['quantity'] as num?)?.toInt() ?? 100}g',
                          AppColors.textSecondary),
                      _microPill(
                          'P ${((log['protein_g'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}g',
                          AppColors.accentProtein),
                      _microPill(
                          'C ${((log['carbs_g'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}g',
                          AppColors.accentCarbs),
                      _microPill(
                          'F ${((log['fat_g'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}g',
                          AppColors.accentFat),
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
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  String _foodEmoji(String category) {
    const map = {
      'protein': '🍗',
      'carbs': '🍚',
      'vegetables': '🥦',
      'fruits': '🍎',
      'dairy': '🧀',
      'fats': '🥑',
      'fastfood': '🍔',
      'drinks': '🥤',
      'arabic': '🧆',
      'breakfast': '🍳',
    };
    return map[category.toLowerCase()] ?? '🍽';
  }

  Widget _microPill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w800,
          ),
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
          style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Future<bool?> _showDeleteConfirm(BuildContext ctx, String name) {
    return showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove item?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text('Remove "$name" from today\'s log?',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ─── HISTORY TAB ──────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    if (_weeklyProgress.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noHistory,
                style: AppText.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('Log meals to see your weekly trends and analytics',
                style: AppText.bodySm.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final maxY = (_weeklyProgress.fold(0.0, (m, d) {
          final c = (d['calories_consumed'] as num?)?.toDouble() ?? 0;
          return c > m ? c : m;
        }) *
        1.3).clamp(100.0, double.infinity);

    final avgCals = _weeklyProgress.isEmpty
        ? 0.0
        : _weeklyProgress.fold(
                0.0,
                (s, d) =>
                    s + ((d['calories_consumed'] as num?)?.toDouble() ?? 0)) /
            _weeklyProgress.length;

    // Account for: bottom safe area + nav bar (68) + nav margin (12) + gap (16)
    final bottomPad = MediaQuery.of(context).padding.bottom + 68 + 12 + 16;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weekly Summary Cards
          _buildWeeklyStatsRow(avgCals),
          const SizedBox(height: 16),

          // Weekly Chart Card
          Container(
            padding: const EdgeInsets.all(20),
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
                    Text(
                      AppLocalizations.of(context)!.last7Days,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Target: ${_caloriesGoal.toInt()} kcal',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 200,
                  child: AnimatedBuilder(
                    animation: _lineChartController,
                    builder: (context, child) {
                      final progress = _lineChartController.value;
                      final spots = _weeklyProgress.asMap().entries.map((e) {
                        final cals =
                            (e.value['calories_consumed'] as num?)?.toDouble() ??
                                0;
                        return FlSpot(e.key.toDouble(), cals);
                      }).toList();

                      final animatedSpots = spots
                          .where((s) => s.x <= (spots.length - 1) * progress)
                          .toList();
                      if (animatedSpots.isEmpty && spots.isNotEmpty) {
                        animatedSpots.add(spots.first);
                      }

                      return LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: maxY / 4,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: AppColors.borderLight,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final i = value.toInt();
                                  if (i >= 0 && i < _weeklyProgress.length) {
                                    final dateStr = _weeklyProgress[i]
                                            ['summary_date']
                                        .toString();
                                    final displayDate = dateStr.length >= 10
                                        ? dateStr.substring(5, 10)
                                        : dateStr;
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        displayDate,
                                        style: TextStyle(
                                          color: (i == _selectedHistoryIndex)
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                          fontSize: 10,
                                          fontWeight:
                                              (i == _selectedHistoryIndex)
                                                  ? FontWeight.w900
                                                  : FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: (_weeklyProgress.length - 1).toDouble(),
                          minY: 0,
                          maxY: maxY,
                          lineBarsData: [
                            LineChartBarData(
                              spots: animatedSpots,
                              isCurved: true,
                              curveSmoothness: 0.35,
                              color: AppColors.primary,
                              barWidth: 3.5,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter:
                                    (spot, percent, barData, index) {
                                  final isSelected =
                                      index == _selectedHistoryIndex;
                                  return FlDotCirclePainter(
                                    radius: isSelected ? 7 : 4,
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.white,
                                    strokeWidth: 2.5,
                                    strokeColor: AppColors.primary,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.25 * progress),
                                    AppColors.primary.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          extraLinesData: ExtraLinesData(
                            horizontalLines: [
                              HorizontalLine(
                                y: _caloriesGoal,
                                color: AppColors.accentCalories.withValues(alpha: 0.6),
                                strokeWidth: 1.5,
                                dashArray: [6, 4],
                              ),
                            ],
                          ),
                          lineTouchData: LineTouchData(
                            touchCallback: (event, response) {
                              if (response?.lineBarSpots != null &&
                                  response!.lineBarSpots!.isNotEmpty) {
                                setState(() {
                                  _selectedHistoryIndex =
                                      response.lineBarSpots!.first.spotIndex;
                                });
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Daily Breakdown Title
          Text('Daily Breakdown',
              style: AppText.headlineMd.copyWith(
                  fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 12),

          ..._weeklyProgress.reversed.toList().asMap().entries.map((entry) {
            final day = entry.value;
            final cals = (day['calories_consumed'] as num?)?.toDouble() ?? 0;
            final protein = (day['protein_g'] as num?)?.toDouble() ?? 0;
            final carbs = (day['carbs_g'] as num?)?.toDouble() ?? 0;
            final fat = (day['fat_g'] as num?)?.toDouble() ?? 0;
            final goalCal = _caloriesGoal;
            final pct = goalCal > 0 ? (cals / goalCal).clamp(0.0, 1.0) : 0.0;
            final isWorkout = day['workout_done'] == true;
            final dateStr = day['summary_date'].toString();
            final isToday = entry.key == 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isToday
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.borderSubtle,
                  width: isToday ? 1.5 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isToday)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.today,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            dateStr,
                            style: AppText.headlineSm.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textPrimary),
                          ),
                        ),
                        if (isWorkout)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accentWorkout.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const PixelArtIcon(
                                  type: PixelIconType.dumbbell,
                                  size: 12,
                                  color: AppColors.accentWorkout,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Workout',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.accentWorkout,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          '${cals.toInt()} kcal',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: pct >= 1.0
                                ? AppColors.accentCalories
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pct >= 1.0
                              ? AppColors.accentCalories
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _historyMacroPill('P ${protein.toInt()}g',
                            AppColors.accentProtein),
                        _historyMacroPill(
                            'C ${carbs.toInt()}g', AppColors.accentCarbs),
                        _historyMacroPill(
                            'F ${fat.toInt()}g', AppColors.accentFat),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeeklyStatsRow(double avgCals) {
    final daysOnTrack = _weeklyProgress.where((d) {
      final c = (d['calories_consumed'] as num?)?.toDouble() ?? 0;
      final g = _caloriesGoal;
      return c >= g * 0.85 && c <= g * 1.15;
    }).length;

    final workoutDays =
        _weeklyProgress.where((d) => d['workout_done'] == true).length;

    return Row(
      children: [
        Expanded(
          child: _weeklyStatCard(
            'Avg Calories',
            '${avgCals.toInt()}',
            'kcal / day',
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _weeklyStatCard(
            'On Track',
            '$daysOnTrack',
            'days in zone',
            AppColors.accentCalories,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _weeklyStatCard(
            'Workouts',
            '$workoutDays',
            'this week',
            AppColors.accentWorkout,
          ),
        ),
      ],
    );
  }

  Widget _weeklyStatCard(
      String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1)),
          const SizedBox(height: 3),
          Text(sub,
              style: TextStyle(
                  fontSize: 9,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _historyMacroPill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
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
    _calories = (widget.currentGoals['daily_calories'] as num?)?.toDouble() ?? 2000;
    _protein = (widget.currentGoals['daily_protein_g'] as num?)?.toDouble() ?? 150;
    _carbs = (widget.currentGoals['daily_carbs_g'] as num?)?.toDouble() ?? 250;
    _fat = (widget.currentGoals['daily_fat_g'] as num?)?.toDouble() ?? 65;
    _water = (widget.currentGoals['daily_water_ml'] as num?)?.toDouble() ?? 2500;
  }

  void _applyPreset({
    required double cal,
    required double p,
    required double c,
    required double f,
  }) {
    HapticFeedback.lightImpact();
    setState(() {
      _calories = cal;
      _protein = p;
      _carbs = c;
      _fat = f;
    });
  }

  @override
  Widget build(BuildContext context) {
    final calculatedCals = (_protein * 4) + (_carbs * 4) + (_fat * 9);

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
                      Text('Configure Nutrition Goals',
                          style: AppText.headlineSm.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      Text('Customize daily caloric & macronutrient targets',
                          style: AppText.bodySm
                              .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
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
                  Text('QUICK PRESETS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.1)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _presetChip(
                          title: '🔥 Fat Loss',
                          sub: '1750 kcal',
                          onTap: () => _applyPreset(
                              cal: 1750, p: 160, c: 140, f: 50),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _presetChip(
                          title: '⚖️ Maintain',
                          sub: '2100 kcal',
                          onTap: () => _applyPreset(
                              cal: 2100, p: 150, c: 220, f: 65),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _presetChip(
                          title: '💪 Bulk / Gain',
                          sub: '2600 kcal',
                          onTap: () => _applyPreset(
                              cal: 2600, p: 175, c: 320, f: 75),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Daily Calorie Target
                  _sliderTarget(
                    label: 'Daily Calories',
                    value: _calories,
                    min: 1000,
                    max: 4500,
                    step: 50,
                    unit: 'kcal',
                    color: AppColors.primary,
                    onChanged: (v) => setState(() => _calories = v),
                  ),
                  const SizedBox(height: 16),

                  // Protein Target
                  _sliderTarget(
                    label: 'Daily Protein',
                    value: _protein,
                    min: 50,
                    max: 300,
                    step: 5,
                    unit: 'g (${(_protein * 4).toInt()} kcal)',
                    color: AppColors.accentProtein,
                    onChanged: (v) => setState(() => _protein = v),
                  ),
                  const SizedBox(height: 16),

                  // Carbs Target
                  _sliderTarget(
                    label: 'Daily Carbohydrates',
                    value: _carbs,
                    min: 50,
                    max: 500,
                    step: 5,
                    unit: 'g (${(_carbs * 4).toInt()} kcal)',
                    color: AppColors.accentCarbs,
                    onChanged: (v) => setState(() => _carbs = v),
                  ),
                  const SizedBox(height: 16),

                  // Fat Target
                  _sliderTarget(
                    label: 'Daily Fats',
                    value: _fat,
                    min: 20,
                    max: 150,
                    step: 5,
                    unit: 'g (${(_fat * 9).toInt()} kcal)',
                    color: AppColors.accentFat,
                    onChanged: (v) => setState(() => _fat = v),
                  ),
                  const SizedBox(height: 16),

                  // Water Target
                  _sliderTarget(
                    label: 'Daily Water Intake',
                    value: _water,
                    min: 1000,
                    max: 5000,
                    step: 250,
                    unit: 'ml',
                    color: AppColors.accentWater,
                    onChanged: (v) => setState(() => _water = v),
                  ),
                  const SizedBox(height: 20),

                  // Macro Balance Indicator
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Macro sum: ${calculatedCals.toInt()} kcal vs Goal: ${_calories.toInt()} kcal',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: (calculatedCals - _calories).abs() < 100
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _saving
                    ? null
                    : () async {
                        final nav = Navigator.of(context);
                        setState(() => _saving = true);
                        HapticFeedback.mediumImpact();
                        final newGoals = {
                          'daily_calories': _calories.toInt(),
                          'daily_protein_g': _protein.toInt(),
                          'daily_carbs_g': _carbs.toInt(),
                          'daily_fat_g': _fat.toInt(),
                          'daily_water_ml': _water.toInt(),
                        };
                        await _statsService.updateGoals(newGoals);
                        widget.onGoalsSaved(newGoals);
                        nav.pop();
                      },
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Save Goals',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip({
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ],
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
    required ValueChanged<double> onChanged,
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
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${value.toInt()} $unit',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
          SliderTheme(
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
