import 'dart:math';
import 'package:flutter/material.dart';
import 'package:coregym2/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/nutrition_service.dart';
import '../services/stats_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/app_background.dart';
import '../widgets/enhanced_charts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NutritionScreen — Redesigned for maximum clarity, delight & usability
// ─────────────────────────────────────────────────────────────────────────────

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _ringController;
  late AnimationController _macroController;
  late AnimationController _pageController;
  late Animation<double> _ringAnim;
  late Animation<double> _proteinAnim;
  late Animation<double> _carbsAnim;
  late Animation<double> _fatAnim;

  final _nutritionService = NutritionService();
  final _statsService = StatsService();

  Map<String, List<Map<String, dynamic>>> _todayLogs = {};
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _goals = {};
  List<Map<String, dynamic>> _weeklyProgress = [];
  bool _isLoading = true;

  // Track expanded meal sections
  final Set<String> _expandedMeals = {'breakfast', 'lunch', 'dinner', 'snack'};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));

    _ringController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _macroController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _pageController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    _ringAnim = CurvedAnimation(parent: _ringController, curve: Curves.easeOutExpo);
    _proteinAnim = CurvedAnimation(parent: _macroController, curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic));
    _carbsAnim = CurvedAnimation(parent: _macroController, curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic));
    _fatAnim = CurvedAnimation(parent: _macroController, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic));

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _ringController.reset();
    _macroController.reset();
    _pageController.reset();

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
      _weeklyProgress = List<Map<String, dynamic>>.from(results[3] as List);
      _isLoading = false;
    });

    _ringController.forward();
    _macroController.forward();
    _pageController.forward();
  }

  Future<void> _deleteLog(String id) async {
    HapticFeedback.mediumImpact();
    await _nutritionService.deleteLog(id);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ringController.dispose();
    _macroController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ─── computed helpers ─────────────────────────────────────────────────────
  double get _caloriesConsumed => (_summary['calories_consumed'] as num?)?.toDouble() ?? 0;
  double get _caloriesGoal => (_goals['daily_calories'] as num?)?.toDouble() ?? 2000;
  double get _caloriesRemaining => (_caloriesGoal - _caloriesConsumed).clamp(0, double.infinity);
  double get _caloriesBurned => (_summary['calories_burned'] as num?)?.toDouble() ?? 0;

  double get _proteinConsumed => (_summary['protein_g'] as num?)?.toDouble() ?? 0;
  double get _proteinGoal => (_goals['daily_protein_g'] as num?)?.toDouble() ?? 150;
  double get _carbsConsumed => (_summary['carbs_g'] as num?)?.toDouble() ?? 0;
  double get _carbsGoal => (_goals['daily_carbs_g'] as num?)?.toDouble() ?? 250;
  double get _fatConsumed => (_summary['fat_g'] as num?)?.toDouble() ?? 0;
  double get _fatGoal => (_goals['daily_fat_g'] as num?)?.toDouble() ?? 65;
  double get _fiberConsumed => (_summary['fiber_g'] as num?)?.toDouble() ?? 0;
  double get _sugarConsumed => (_summary['sugar_g'] as num?)?.toDouble() ?? 0;
  double get _sodiumConsumed => (_summary['sodium_mg'] as num?)?.toDouble() ?? 0;

  double get _calorieProgress => _caloriesGoal > 0 ? (_caloriesConsumed / _caloriesGoal).clamp(0.0, 1.0) : 0;
  bool get _isOverGoal => _caloriesConsumed > _caloriesGoal;

  Color get _ringColor {
    if (_calorieProgress >= 1.0) return const Color(0xFFFF5252);
    if (_calorieProgress > 0.85) return const Color(0xFFFFAB40);
    return AppColors.primaryFixed;
  }

  int get _totalFoodsLogged => _todayLogs.values.fold(0, (s, list) => s + list.length);

  String get _motivationalMessage {
    if (_caloriesConsumed == 0) return 'Start tracking your meals 💪';
    if (_calorieProgress < 0.3) return 'Great start! Keep going 🌱';
    if (_calorieProgress < 0.6) return 'Halfway there! Stay on track ⚡';
    if (_calorieProgress < 0.85) return 'Almost at your goal! 🎯';
    if (_calorieProgress < 1.0) return 'Nearly full! Choose wisely 🧘';
    return 'Goal reached! Great job today 🎉';
  }

  // ─── build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(),
      body: AppBackground(
        child: _isLoading
            ? _buildShimmer()
            : TabBarView(
                controller: _tabController,
                children: [_buildTodayTab(), _buildHistoryTab()],
              ),
      ),
      floatingActionButton: _tabController.index == 0 ? _buildFAB() : null,
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.navNutrition, style: AppText.headlineSm.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          Text(
            _isLoading ? 'Loading...' : '$_totalFoodsLogged items logged today',
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        IconButton(
          icon: Icon(Icons.tune_rounded, color: AppColors.onSurfaceVariant, size: 22),
          onPressed: () {/* open goals editor */},
          tooltip: 'Edit Goals',
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5),
              dividerColor: Colors.transparent,
              tabs: [Tab(text: AppLocalizations.of(context)!.today), Tab(text: AppLocalizations.of(context)!.historyTab)],
            ),
          ),
        ),
      ),
    );
  }

  // ─── FAB ──────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 96),
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showAddFoodBottomSheet(context);
        },
        backgroundColor: AppColors.primaryFixed,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('Add Food', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }

  // ─── Shimmer ──────────────────────────────────────────────────────────────
  Widget _buildShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _shimmerBox(200, radius: 22),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _shimmerBox(76, radius: 16)),
            const SizedBox(width: 10),
            Expanded(child: _shimmerBox(76, radius: 16)),
            const SizedBox(width: 10),
            Expanded(child: _shimmerBox(76, radius: 16)),
          ]),
          const SizedBox(height: 12),
          _shimmerBox(120, radius: 18),
          const SizedBox(height: 10),
          _shimmerBox(80, radius: 18),
          const SizedBox(height: 10),
          _shimmerBox(80, radius: 18),
        ],
      ),
    );
  }

  Widget _shimmerBox(double h, {double radius = 12}) => Container(
    width: double.infinity, height: h,
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(radius),
    ),
  );

  // ─── TODAY TAB ────────────────────────────────────────────────────────────
  Widget _buildTodayTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryFixed,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 220),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FadeSlideIn(parent: _pageController, delayMs: 0, child: _buildHeroCaloriesCard()),
            const SizedBox(height: 12),
            _FadeSlideIn(parent: _pageController, delayMs: 100, child: _buildQuickStatsRow()),
            const SizedBox(height: 12),
            _FadeSlideIn(parent: _pageController, delayMs: 180, child: _buildMacrosCard()),
            const SizedBox(height: 12),
            _FadeSlideIn(parent: _pageController, delayMs: 260, child: _buildMicronutrientsCard()),
            const SizedBox(height: 22),
            _FadeSlideIn(
              parent: _pageController, delayMs: 320,
              child: Row(
                children: [
                  Text('Meals', style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text(
                    '${_todayLogs.values.fold(0, (s, l) => s + l.length)} items',
                    style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _FadeSlideIn(parent: _pageController, delayMs: 360, child: _buildMealSection(AppLocalizations.of(context)!.breakfast, 'breakfast', Icons.wb_sunny_rounded, const Color(0xFFFFB347))),
            const SizedBox(height: 8),
            _FadeSlideIn(parent: _pageController, delayMs: 420, child: _buildMealSection(AppLocalizations.of(context)!.lunch, 'lunch', Icons.wb_cloudy_rounded, const Color(0xFF4A9EFF))),
            const SizedBox(height: 8),
            _FadeSlideIn(parent: _pageController, delayMs: 480, child: _buildMealSection(AppLocalizations.of(context)!.dinner, 'dinner', Icons.nights_stay_rounded, const Color(0xFF9C88FF))),
            const SizedBox(height: 8),
            _FadeSlideIn(parent: _pageController, delayMs: 540, child: _buildMealSection(AppLocalizations.of(context)!.snack, 'snack', Icons.local_cafe_rounded, const Color(0xFF66BB6A))),
          ],
        ),
      ),
    );
  }

  // ─── Hero Calories Card (redesigned with enhanced visuals) ─────────────────────────────────────
  Widget _buildHeroCaloriesCard() {
    // Gradient colors based on progress
    final gradientColors = _calorieProgress >= 1.0
        ? [const Color(0xFFFF5252), const Color(0xFFFF8A65)]
        : _calorieProgress > 0.85
            ? [const Color(0xFFFFAB40), const Color(0xFFFFD54F)]
            : [AppColors.primaryFixed, const Color(0xFFA8E600)];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Top motivational banner with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradientColors.first.withOpacity(0.18),
                  gradientColors.last.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: _ringColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _ringColor.withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _motivationalMessage,
                    style: TextStyle(fontSize: 12, color: _ringColor, fontWeight: FontWeight.w600),
                  ),
                ),
                AnimatedBuilder(
                  animation: _ringAnim,
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _ringColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(_calorieProgress * 100 * _ringAnim.value).toInt()}%',
                      style: TextStyle(fontSize: 11, color: _ringColor, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(
              children: [
                // Enhanced Ring with glow
                SizedBox(
                  width: 140, height: 140,
                  child: Stack(
                    children: [
                      AnimatedBuilder(
                        animation: _ringAnim,
                        builder: (_, __) => CustomPaint(
                          size: const Size(140, 140),
                          painter: EnhancedRingPainter(
                            progress: _calorieProgress * _ringAnim.value,
                            gradientColors: gradientColors,
                            trackColor: Colors.white.withOpacity(0.07),
                            strokeWidth: 12,
                            showGlow: true,
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _ringAnim,
                              builder: (_, __) => Text(
                                (_caloriesConsumed * _ringAnim.value).toInt().toString(),
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1),
                              ),
                            ),
                            Text(AppLocalizations.of(context)!.kcal, style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            AnimatedBuilder(
                              animation: _ringAnim,
                              builder: (_, __) => Text(
                                'of ${_caloriesGoal.toInt()}',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: gradientColors.first),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Stats column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _calorieStatRow(AppLocalizations.of(context)!.goal, '${_caloriesGoal.toInt()}', AppLocalizations.of(context)!.kcal, Colors.white70),
                      const SizedBox(height: 12),
                      _calorieStatRow('Eaten', '${_caloriesConsumed.toInt()}', AppLocalizations.of(context)!.kcal, AppColors.primaryFixed),
                      const SizedBox(height: 12),
                      _calorieStatRow(
                        _isOverGoal ? 'Over' : 'Left',
                        _isOverGoal
                            ? '+${(_caloriesConsumed - _caloriesGoal).toInt()}'
                            : '${_caloriesRemaining.toInt()}',
                        AppLocalizations.of(context)!.kcal,
                        _isOverGoal ? const Color(0xFFFF5252) : const Color(0xFF66BB6A),
                      ),
                      if (_caloriesBurned > 0) ...[
                        const SizedBox(height: 12),
                        _calorieStatRow('Burned', '${_caloriesBurned.toInt()}', AppLocalizations.of(context)!.kcal, const Color(0xFFFFAB40)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Progress bar at bottom with enhanced style
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: AnimatedBuilder(
              animation: _ringAnim,
              builder: (_, __) {
                final pct = _calorieProgress * _ringAnim.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: pct.clamp(0.0, 1.0),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradientColors),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: gradientColors.first.withOpacity(0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0', style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant)),
                        Text('${(_caloriesGoal / 2).toInt()}', style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant)),
                        Text('${_caloriesGoal.toInt()} kcal', style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _calorieStatRow(String label, String value, String unit, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Container(
          width: 3,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, height: 1.1)),
                const SizedBox(width: 3),
                Text(unit, style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ─── Quick Stats Row (new) ────────────────────────────────────────────────
  Widget _buildQuickStatsRow() {
    final meals = ['breakfast', 'lunch', 'dinner', 'snack'];
    final mealEmojis = ['🍳', '🥗', '🍽', '🥜'];
    return Row(
      children: List.generate(4, (i) {
        final logs = _todayLogs[meals[i]] ?? [];
        final cals = logs.fold(0.0, (s, l) => s + ((l['calories'] as num?) ?? 0));
        final logged = logs.isNotEmpty;
        return Expanded(
          child: Container(
            margin: EdgeInsetsDirectional.only(end: i < 3 ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: logged
                  ? AppColors.primaryFixed.withOpacity(0.12)
                  : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: logged ? AppColors.primaryFixed.withOpacity(0.3) : Colors.white.withOpacity(0.05),
              ),
            ),
            child: Column(
              children: [
                Text(mealEmojis[i], style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    logged ? '${cals.toInt()}' : '—',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: logged ? AppColors.primaryFixed : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                if (logged) Text(AppLocalizations.of(context)!.kcal, style: TextStyle(fontSize: 8, color: AppColors.onSurfaceVariant)),
                if (!logged) Text(meals[i].substring(0, 3).toUpperCase(), style: TextStyle(fontSize: 8, color: AppColors.onSurfaceVariant.withOpacity(0.5))),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ─── Macros Card (redesigned) ─────────────────────────────────────────────
  Widget _buildMacrosCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('MACRONUTRIENTS', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              const Spacer(),
              // Macro pie-donut summary
              _MacroPieIndicator(
                protein: _proteinConsumed * 4,
                carbs: _carbsConsumed * 4,
                fat: _fatConsumed * 9,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AnimatedMacroRow(
            label: AppLocalizations.of(context)!.proteinGoal,
            color: const Color(0xFFFF6B6B),
            current: _proteinConsumed,
            goal: _proteinGoal,
            animation: _proteinAnim,
            unit: 'g',
            icon: Icons.fitness_center_rounded,
          ),
          const SizedBox(height: 16),
          _AnimatedMacroRow(
            label: 'Carbohydrates',
            color: const Color(0xFF4A9EFF),
            current: _carbsConsumed,
            goal: _carbsGoal,
            animation: _carbsAnim,
            unit: 'g',
            icon: Icons.grain_rounded,
          ),
          const SizedBox(height: 16),
          _AnimatedMacroRow(
            label: AppLocalizations.of(context)!.fat,
            color: const Color(0xFFFFB84A),
            current: _fatConsumed,
            goal: _fatGoal,
            animation: _fatAnim,
            unit: 'g',
            icon: Icons.water_drop_rounded,
          ),
        ],
      ),
    );
  }

  // ─── Micronutrients Card (NEW) ────────────────────────────────────────────
  Widget _buildMicronutrientsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ADDITIONAL NUTRIENTS', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _micronutrientTile('Fiber', _fiberConsumed, 30, 'g', const Color(0xFF66BB6A), Icons.spa_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _micronutrientTile('Sugar', _sugarConsumed, 50, 'g', const Color(0xFFE91E8C), Icons.local_cafe_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _micronutrientTile('Sodium', _sodiumConsumed, 2300, 'mg', const Color(0xFFFF9800), Icons.water_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _micronutrientTile(String label, double current, double goal, String unit, Color color, IconData icon) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final isOver = current > goal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const Spacer(),
              if (isOver) Icon(Icons.warning_amber_rounded, size: 12, color: const Color(0xFFFFAB40)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${current.toStringAsFixed(current >= 10 ? 0 : 1)}$unit',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
          Text('/ ${goal.toInt()}$unit', style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Colors.white.withOpacity(0.07),
              valueColor: AlwaysStoppedAnimation(isOver ? const Color(0xFFFFAB40) : color),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Meal Section (redesigned with collapsible + better log items) ─────────
  Widget _buildMealSection(String title, String mealType, IconData icon, Color accentColor) {
    final logs = _todayLogs[mealType] ?? [];
    final totalCals = logs.fold(0.0, (s, l) => s + ((l['calories'] as num?) ?? 0));
    final totalProtein = logs.fold(0.0, (s, l) => s + ((l['protein_g'] as num?) ?? 0));
    final hasLogs = logs.isNotEmpty;
    final isExpanded = _expandedMeals.contains(mealType);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasLogs ? accentColor.withOpacity(0.25) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          // Header — tappable to collapse/expand
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isExpanded) _expandedMeals.remove(mealType);
                else _expandedMeals.add(mealType);
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                        if (hasLogs)
                          Text(
                            '${logs.length} item${logs.length > 1 ? 's' : ''} · ${totalProtein.toStringAsFixed(0)}g protein',
                            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasLogs) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${totalCals.toInt()} kcal',
                        style: TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Add button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showAddFoodBottomSheet(context);
                    },
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_rounded, color: AppColors.primaryFixed, size: 16),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isExpanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.onSurfaceVariant, size: 20),
                  ),
                ],
              ),
            ),
          ),
          // Log items (collapsible)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                if (!hasLogs)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.onSurfaceVariant.withOpacity(0.4)),
                        const SizedBox(width: 8),
                        Text('No food logged yet', style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant.withOpacity(0.6))),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _showAddFoodBottomSheet(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Add', style: TextStyle(fontSize: 12, color: AppColors.primaryFixed, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ...logs.asMap().entries.map((entry) {
                  final log = entry.value;
                  final isLast = entry.key == logs.length - 1;
                  return Dismissible(
                    key: Key(log['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsetsDirectional.only(end: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withOpacity(0.15),
                        borderRadius: isLast
                            ? const BorderRadius.vertical(bottom: Radius.circular(18))
                            : BorderRadius.zero,
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5252)),
                    ),
                    confirmDismiss: (_) async {
                      return await _showDeleteConfirm(context, log['food_name'] ?? '');
                    },
                    onDismissed: (_) => _deleteLog(log['id'].toString()),
                    child: _buildLogItem(log, isLast, accentColor),
                  );
                }),
                if (hasLogs) ...[
                  // Meal summary footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.summarize_rounded, size: 12, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text('Meal total:', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                        _mealTotalPill('${totalCals.toInt()} kcal', accentColor),
                        _mealTotalPill('P: ${totalProtein.toStringAsFixed(0)}g', const Color(0xFFFF6B6B)),
                        _mealTotalPill(
                          'C: ${logs.fold(0.0, (s, l) => s + ((l['carbs_g'] as num?) ?? 0)).toStringAsFixed(0)}g',
                          const Color(0xFF4A9EFF),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 280),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log, bool isLast, Color accentColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          // Food icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              _foodEmoji(log['category'] ?? ''),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          // Food details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log['food_name'] ?? '',
                  style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                // Macro pills row
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _microPill('${log['quantity']}g', Colors.white38),
                    _microPill('P ${((log['protein_g'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}g', const Color(0xFFFF6B6B)),
                    _microPill('C ${((log['carbs_g'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}g', const Color(0xFF4A9EFF)),
                    _microPill('F ${((log['fat_g'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}g', const Color(0xFFFFB84A)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Calorie badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${((log['calories'] as num?)?.toDouble() ?? 0).toInt()}',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.primaryFixed),
              ),
              Text(AppLocalizations.of(context)!.kcal, style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _deleteLog(log['id'].toString()),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(Icons.close_rounded, size: 16, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  String _foodEmoji(String category) {
    const map = {
      'protein': '🍗', 'carbs': '🍚', 'vegetables': '🥦', 'fruits': '🍎',
      'dairy': '🧀', 'fats': '🥜', 'fastfood': '🍔', 'drinks': '🥤',
      'arabic': '🌍', 'breakfast': '🍳',
    };
    return map[category.toLowerCase()] ?? '🍽';
  }

  Widget _microPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(text, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
  );

  Widget _mealTotalPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
  );

  Future<bool?> _showDeleteConfirm(BuildContext ctx, String name) {
    return showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove item?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text('Remove "$name" from your log?', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.w700)),
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
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bar_chart_rounded, size: 36, color: AppColors.onSurfaceVariant.withOpacity(0.4)),
            ),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.noHistory, style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Log meals to see your weekly trends', style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
      );
    }

    final maxY = (_weeklyProgress.fold(0.0, (m, d) {
      final c = (d['calories_consumed'] as num?)?.toDouble() ?? 0;
      return c > m ? c : m;
    }) * 1.3).clamp(100.0, double.infinity);

    final avgCals = _weeklyProgress.isEmpty ? 0.0 : _weeklyProgress.fold(0.0, (s, d) => s + ((d['calories_consumed'] as num?)?.toDouble() ?? 0)) / _weeklyProgress.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weekly summary cards (new)
          _FadeSlideIn(
            parent: _pageController, delayMs: 0,
            child: _buildWeeklyStatsRow(avgCals),
          ),
          const SizedBox(height: 12),
          // Chart
          _FadeSlideIn(
            parent: _pageController, delayMs: 100,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(AppLocalizations.of(context)!.last7Days, style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, letterSpacing: 1.2, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Avg ${avgCals.toInt()} kcal', style: TextStyle(fontSize: 10, color: AppColors.primaryFixed, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i >= 0 && i < _weeklyProgress.length) {
                                  final d = _weeklyProgress[i]['summary_date'].toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(d.substring(5, 10), style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 9)),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value == 0 || value == maxY) return const Text('');
                              return Text('${value.toInt()}', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 9));
                            },
                            reservedSize: 36,
                          )),
                        ),
                        gridData: FlGridData(
                          show: true,
                          horizontalInterval: maxY / 4,
                          getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.04), strokeWidth: 1),
                          drawVerticalLine: false,
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _weeklyProgress.asMap().entries.map((e) {
                          final cals = (e.value['calories_consumed'] as num?)?.toDouble() ?? 0;
                          final isGoalMet = cals >= (_goals['daily_calories'] as num? ?? 2000);
                          final isToday = e.key == _weeklyProgress.length - 1;
                          return BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: cals,
                                width: 20,
                                borderRadius: BorderRadius.circular(6),
                                color: isToday
                                    ? AppColors.primaryFixed
                                    : isGoalMet
                                    ? AppColors.primaryFixed.withOpacity(0.6)
                                    : AppColors.primaryFixed.withOpacity(0.25),
                                rodStackItems: isToday ? [
                                  BarChartRodStackItem(0, cals, AppColors.primaryFixed),
                                ] : [],
                              ),
                            ],
                          );
                        }).toList(),
                        // Goal line
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: (_goals['daily_calories'] as num?)?.toDouble() ?? 2000,
                              color: Colors.white.withOpacity(0.2),
                              strokeWidth: 1,
                              dashArray: [6, 4],
                              label: HorizontalLineLabel(
                                show: true,
                                alignment: Alignment.topRight,
                                labelResolver: (l) => AppLocalizations.of(context)!.goal,
                                style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.4)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _FadeSlideIn(
            parent: _pageController, delayMs: 200,
            child: Text('Daily Breakdown', style: AppText.titleMd.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          ..._weeklyProgress.reversed.toList().asMap().entries.map((entry) {
            final delay = 280 + entry.key * 60;
            final day = entry.value;
            final cals = (day['calories_consumed'] as num?)?.toDouble() ?? 0;
            final protein = (day['protein_g'] as num?)?.toDouble() ?? 0;
            final carbs = (day['carbs_g'] as num?)?.toDouble() ?? 0;
            final fat = (day['fat_g'] as num?)?.toDouble() ?? 0;
            final goalCal = (_goals['daily_calories'] as num?)?.toDouble() ?? 2000;
            final pct = goalCal > 0 ? (cals / goalCal).clamp(0.0, 1.0) : 0.0;
            final isWorkout = day['workout_done'] == true;
            final dateStr = day['summary_date'].toString();
            final isToday = entry.key == 0;

            return _FadeSlideIn(
              parent: _pageController, delayMs: delay,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isToday ? AppColors.primaryFixed.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                    width: isToday ? 1.5 : 0.5,
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
                              margin: const EdgeInsetsDirectional.only(end: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryFixed,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(AppLocalizations.of(context)!.today, style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                            ),
                          Expanded(child: Text(dateStr, style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          if (isWorkout)
                            Container(
                              margin: const EdgeInsetsDirectional.only(end: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryFixed.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.fitness_center_rounded, color: AppColors.primaryFixed, size: 11),
                                  const SizedBox(width: 4),
                                  Text(AppLocalizations.of(context)!.navWorkout, style: TextStyle(fontSize: 10, color: AppColors.primaryFixed, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          Text(
                            '${cals.toInt()} kcal',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: pct >= 1.0 ? const Color(0xFF66BB6A) : AppColors.primaryFixed),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Progress bar with goal marker
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: Colors.white.withOpacity(0.07),
                              valueColor: AlwaysStoppedAnimation(
                                pct >= 1.0 ? const Color(0xFF66BB6A) : AppColors.primaryFixed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('${(pct * 100).toInt()}% of goal', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                          const Spacer(),
                          Text('Goal: ${goalCal.toInt()} kcal', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _historyMacroPill('P ${protein.toInt()}g', const Color(0xFFFF6B6B)),
                          _historyMacroPill('C ${carbs.toInt()}g', const Color(0xFF4A9EFF)),
                          _historyMacroPill('F ${fat.toInt()}g', const Color(0xFFFFB84A)),
                        ],
                      ),
                    ],
                  ),
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
      final g = (_goals['daily_calories'] as num?)?.toDouble() ?? 2000;
      return c >= g * 0.8 && c <= g * 1.1;
    }).length;

    final workoutDays = _weeklyProgress.where((d) => d['workout_done'] == true).length;

    return Row(
      children: [
        Expanded(child: _weeklyStatCard('Avg Calories', '${avgCals.toInt()}', 'kcal/day', AppColors.primaryFixed)),
        const SizedBox(width: 8),
        Expanded(child: _weeklyStatCard('On Track', '$daysOnTrack', 'days', const Color(0xFF66BB6A))),
        const SizedBox(width: 8),
        Expanded(child: _weeklyStatCard(AppLocalizations.of(context)!.workoutsLabel, '$workoutDays', 'this week', const Color(0xFFFFB84A))),
      ],
    );
  }

  Widget _weeklyStatCard(String label, String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(sub, style: TextStyle(fontSize: 9, color: color.withOpacity(0.7), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _historyMacroPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
  );

  // ─── Add Food Bottom Sheet ─────────────────────────────────────────────────
  void _showAddFoodBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFoodSheet(),
    ).then((_) => _loadData());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Macro Pie Indicator (small summary donut)
// ─────────────────────────────────────────────────────────────────────────────
class _MacroPieIndicator extends StatelessWidget {
  final double protein; // calories from protein
  final double carbs;   // calories from carbs
  final double fat;     // calories from fat

  const _MacroPieIndicator({required this.protein, required this.carbs, required this.fat});

  @override
  Widget build(BuildContext context) {
    final total = protein + carbs + fat;
    if (total == 0) return const SizedBox.shrink();

    return SizedBox(
      width: 36, height: 36,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 1.5,
              centerSpaceRadius: 10,
              sections: [
                PieChartSectionData(value: protein, color: const Color(0xFFFF6B6B), radius: 7, title: ''),
                PieChartSectionData(value: carbs, color: const Color(0xFF4A9EFF), radius: 7, title: ''),
                PieChartSectionData(value: fat, color: const Color(0xFFFFB84A), radius: 7, title: ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Macro Row (improved)
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedMacroRow extends StatelessWidget {
  final String label;
  final Color color;
  final double current, goal;
  final Animation<double> animation;
  final String unit;
  final IconData icon;

  const _AnimatedMacroRow({
    required this.label, required this.color, required this.current,
    required this.goal, required this.animation,
    this.unit = 'g', required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final prog = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final isOver = current > goal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
            const Spacer(),
            AnimatedBuilder(
              animation: animation,
              builder: (_, __) => Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${(current * animation.value).toStringAsFixed(1)}',
                    style: TextStyle(fontSize: 14, color: isOver ? const Color(0xFFFFAB40) : color, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    ' / ${goal.toInt()}$unit',
                    style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                  if (isOver) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_upward_rounded, size: 12, color: const Color(0xFFFFAB40)),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: animation,
          builder: (_, __) => Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: (prog * animation.value).clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: Colors.white.withOpacity(0.07),
                  valueColor: AlwaysStoppedAnimation(isOver ? const Color(0xFFFFAB40) : color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        AnimatedBuilder(
          animation: animation,
          builder: (_, __) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(prog * 100 * animation.value).toInt()}% of daily goal', style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant)),
              Text('${(goal - current).abs().toStringAsFixed(0)}$unit ${isOver ? AppLocalizations.of(context)!.caloriesOver : AppLocalizations.of(context)!.caloriesRemaining}',
                style: TextStyle(fontSize: 9, color: isOver ? const Color(0xFFFFAB40) : AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ring Painter
// ─────────────────────────────────────────────────────────────────────────────
class _NutritionRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _NutritionRingPainter({
    required this.progress, required this.color,
    required this.trackColor, required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    // Track
    canvas.drawCircle(center, radius, Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..color = trackColor);

    // Subtle tick marks at 25%, 50%, 75%
    for (final pct in [0.25, 0.5, 0.75]) {
      final angle = -pi / 2 + 2 * pi * pct;
      final innerR = radius - strokeWidth / 2 - 2;
      final outerR = radius + strokeWidth / 2 + 2;
      canvas.drawLine(
        Offset(center.dx + innerR * cos(angle), center.dy + innerR * sin(angle)),
        Offset(center.dx + outerR * cos(angle), center.dy + outerR * sin(angle)),
        Paint()..color = Colors.white.withOpacity(0.1)..strokeWidth = 1.5..strokeCap = StrokeCap.round,
      );
    }

    // Arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NutritionRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fade + Slide-In Wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int delayMs;
  final Animation<double> parent;

  const _FadeSlideIn({required this.child, required this.delayMs, required this.parent});

  @override
  Widget build(BuildContext context) {
    final start = (delayMs / 2000.0).clamp(0.0, 0.85);
    final end = ((delayMs + 600) / 2000.0).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: parent,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(offset: Offset(0, 14 * (1 - anim.value)), child: child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Food Sheet (improved search UX)
// ─────────────────────────────────────────────────────────────────────────────
class _AddFoodSheet extends StatefulWidget {
  const _AddFoodSheet();
  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _nutritionService = NutritionService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _recentFoods = [];
  bool _searching = false;
  bool _hasSearched = false;
  String _selectedCategory = '';

  List<({String label, String db, String emoji})> get _categories => [
    (label: AppLocalizations.of(context)!.allCategories, db: 'all', emoji: '🍽'),
    (label: 'Arabic', db: 'arabic', emoji: '🌍'),
    (label: AppLocalizations.of(context)!.proteinGoal, db: 'protein', emoji: '🍗'),
    (label: AppLocalizations.of(context)!.carbs, db: 'carbs', emoji: '🍚'),
    (label: 'Veggies', db: 'vegetables', emoji: '🥦'),
    (label: 'Fruits', db: 'fruits', emoji: '🍎'),
    (label: 'Dairy', db: 'dairy', emoji: '🧀'),
    (label: 'Fats', db: 'fats', emoji: '🥜'),
    (label: 'Fast Food', db: 'fastfood', emoji: '🍔'),
    (label: 'Drinks', db: 'drinks', emoji: '🥤'),
  ];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    // Simulate loading recent foods — replace with actual service call
    // final recent = await _nutritionService.getRecentFoods();
    // setState(() => _recentFoods = recent);
  }

  Future<void> _search() async {
    if (_searchController.text.trim().isEmpty && _selectedCategory == AppLocalizations.of(context)!.allCategories) return;
    setState(() { _searching = true; _hasSearched = true; });
    final cat = _categories.firstWhere((c) => c.label == _selectedCategory).db;
    final results = await _nutritionService.searchFoods(_searchController.text, category: cat);
    if (mounted) setState(() { _results = results; _searching = false; });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCategory.isEmpty) {
      _selectedCategory = AppLocalizations.of(context)!.allCategories;
    }
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context)!.searchFood, style: AppText.headlineSm.copyWith(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                      Text('Search in English or Arabic', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (v) { if (v.length > 1) _search(); },
              onSubmitted: (_) => _search(),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. Chicken breast, أرز...',
                hintStyle: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
                filled: true,
                fillColor: AppColors.surfaceContainerHigh,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.primaryFixed, width: 1.5),
                ),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.onSurfaceVariant, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18, color: AppColors.onSurfaceVariant),
                        onPressed: () { _searchController.clear(); setState(() { _results = []; _hasSearched = false; }); },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          // Category chips
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final sel = cat.label == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat.label);
                    _search();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primaryFixed : AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: sel ? null : Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text('${cat.emoji} ${cat.label}', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : AppColors.onSurfaceVariant,
                    )),
                  ),
                );
              },
            ),
          ),
          // Results count
          if (_hasSearched && !_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Text(
                    '${_results.length} result${_results.length != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          // Results list
          Expanded(
            child: _searching
                ? Center(child: CircularProgressIndicator(color: AppColors.primaryFixed, strokeWidth: 2.5))
                : !_hasSearched
                ? _buildSearchSuggestions()
                : _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🔍', style: const TextStyle(fontSize: 36)),
                        const SizedBox(height: 12),
                        Text('No results found', style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Try a different name or spelling', style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: _results.length,
                    itemBuilder: (_, i) => _buildFoodResultTile(_results[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    final suggestions = ['Chicken breast', 'Brown rice', 'Egg', 'Banana', 'Milk', 'Almonds'];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QUICK PICKS', style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: suggestions.map((s) => GestureDetector(
              onTap: () {
                _searchController.text = s;
                _search();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Text(s, style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodResultTile(Map<String, dynamic> food) {
    final catEmoji = _categories.firstWhere(
      (c) => c.db == (food['category'] ?? 'other'),
      orElse: () => _categories[0],
    ).emoji;

    return GestureDetector(
      onTap: () => _showLogFoodSheet(food),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: AppColors.primaryFixed.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(catEmoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food['name'] ?? '', style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700)),
                  if (food['name_ar'] != null)
                    Text(food['name_ar'], style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _resultBadge('${food['calories']} kcal', AppColors.primaryFixed),
                      _resultBadge('P ${food['protein_g']}g', const Color(0xFFFF6B6B)),
                      _resultBadge('C ${food['carbs_g']}g', const Color(0xFF4A9EFF)),
                      _resultBadge('F ${food['fat_g']}g', const Color(0xFFFFB84A)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, color: AppColors.primaryFixed, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
  );

  void _showLogFoodSheet(Map<String, dynamic> food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogFoodSheet(
        food: food,
        onLogged: () { Navigator.pop(context); Navigator.pop(context); },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log Food Sheet (improved macro preview)
// ─────────────────────────────────────────────────────────────────────────────
class _LogFoodSheet extends StatefulWidget {
  final Map<String, dynamic> food;
  final VoidCallback onLogged;
  const _LogFoodSheet({required this.food, required this.onLogged});

  @override
  State<_LogFoodSheet> createState() => _LogFoodSheetState();
}

class _LogFoodSheetState extends State<_LogFoodSheet> {
  final _nutritionService = NutritionService();
  late TextEditingController _quantityCtrl;
  String _mealType = 'breakfast';
  late double _quantity;
  late String _unit;
  bool _logging = false;

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
  static const _emojis = ['🍳', '🥗', '🍽', '🥜'];

  @override
  void initState() {
    super.initState();
    // Pick the smartest default unit & quantity for this food
    final units = _servingUnitsFor(widget.food['name'] ?? '');
    _unit = units.first.label;
    // Use 1 unit for named units, 100 for plain grams
    _quantity = _unit == 'g' ? 100.0 : 1.0;
    _quantityCtrl = TextEditingController(text: _quantity.toStringAsFixed(0));
  }

  // ─── Smart per-food serving units ─────────────────────────────────────────
  bool _kw(String name, List<String> keys) => keys.any((k) => name.contains(k));

  List<({String label, double grams, String icon, String hint})> _servingUnitsFor(String rawName) {
    final n = rawName.toLowerCase();

    if (_kw(n, ['egg', 'بيض', 'beyd']))
      return [(label: 'piece (حبة)', grams: 50.0, icon: '🥚', hint: '1 egg ≈ 50g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['bread', 'toast', 'خبز', 'عيش', 'pita', 'aish']))
      return [(label: 'slice (شريحة)', grams: 25.0, icon: '🍞', hint: '1 slice ≈ 25g'), (label: 'loaf (رغيف)', grams: 300.0, icon: '🥖', hint: '1 loaf ≈ 300g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['milk', 'حليب', 'lait']))
      return [(label: 'cup (كوب)', grams: 240.0, icon: '🥛', hint: '1 cup = 240ml'), (label: 'glass (كأس)', grams: 200.0, icon: '🥛', hint: '1 glass ≈ 200ml'), (label: 'ml', grams: 1.0, icon: '💧', hint: 'Milliliters')];

    if (_kw(n, ['yogurt', 'yoghurt', 'زبادي', 'zabadi', 'labneh', 'لبن']))
      return [(label: 'cup (كوب)', grams: 245.0, icon: '🥛', hint: '1 cup ≈ 245g'), (label: 'tbsp', grams: 15.0, icon: '🥄', hint: '1 tbsp ≈ 15g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['cheese', 'جبن', 'جبنة']))
      return [(label: 'slice (شريحة)', grams: 20.0, icon: '🧀', hint: '1 slice ≈ 20g'), (label: 'cup (مبشور)', grams: 113.0, icon: '🧀', hint: '1 cup shredded ≈ 113g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['butter', 'زبدة']))
      return [(label: 'tbsp (ملعقة)', grams: 14.0, icon: '🧈', hint: '1 tbsp ≈ 14g'), (label: 'tsp (صغيرة)', grams: 4.7, icon: '🥄', hint: '1 tsp ≈ 5g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['oil', 'زيت']))
      return [(label: 'tbsp (ملعقة)', grams: 14.0, icon: '🫙', hint: '1 tbsp ≈ 14g'), (label: 'tsp (صغيرة)', grams: 4.7, icon: '🥄', hint: '1 tsp ≈ 5g'), (label: 'ml', grams: 0.9, icon: '💧', hint: 'Milliliters')];

    if (_kw(n, ['rice', 'أرز', 'ارز', 'ruz']))
      return [(label: 'cup cooked (كوب)', grams: 186.0, icon: '🍚', hint: '1 cup cooked ≈ 186g'), (label: 'cup dry (جاف)', grams: 185.0, icon: '🌾', hint: '1 cup dry ≈ 185g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['oat', 'oats', 'oatmeal', 'شوفان']))
      return [(label: 'cup (كوب)', grams: 90.0, icon: '🌾', hint: '1 cup dry oats ≈ 90g'), (label: 'tbsp', grams: 10.0, icon: '🥄', hint: '1 tbsp ≈ 10g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['banana', 'موز']))
      return [(label: 'piece (حبة)', grams: 118.0, icon: '🍌', hint: '1 medium banana ≈ 118g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['apple', 'تفاح']))
      return [(label: 'piece (حبة)', grams: 182.0, icon: '🍎', hint: '1 medium apple ≈ 182g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['orange', 'برتقال']))
      return [(label: 'piece (حبة)', grams: 131.0, icon: '🍊', hint: '1 medium orange ≈ 131g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['chicken', 'دجاج', 'djaj']))
      return [(label: 'piece (قطعة)', grams: 150.0, icon: '🍗', hint: '1 breast ≈ 150g'), (label: '½ piece (نص)', grams: 75.0, icon: '🍗', hint: 'Half breast ≈ 75g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['tuna', 'تونة']))
      return [(label: 'can (علبة)', grams: 140.0, icon: '🐟', hint: '1 can drained ≈ 140g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['almond', 'peanut', 'cashew', 'walnut', 'pistachio', 'لوز', 'فول سوداني', 'كاجو', 'جوز', 'فستق', 'nuts', 'مكسرات']))
      return [(label: 'handful (حفنة)', grams: 28.0, icon: '🥜', hint: '1 handful ≈ 28g'), (label: 'tbsp', grams: 16.0, icon: '🥄', hint: '1 tbsp ≈ 16g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['peanut butter', 'زبدة الفول']))
      return [(label: 'tbsp (ملعقة)', grams: 16.0, icon: '🥜', hint: '1 tbsp ≈ 16g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['potato', 'بطاطس', 'batata']))
      return [(label: 'piece (حبة)', grams: 150.0, icon: '🥔', hint: '1 medium potato ≈ 150g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['pasta', 'spaghetti', 'noodle', 'معكرونة', 'مكرونة']))
      return [(label: 'cup cooked (كوب)', grams: 140.0, icon: '🍝', hint: '1 cup cooked ≈ 140g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['sugar', 'سكر', 'sukkar']))
      return [(label: 'tsp (صغيرة)', grams: 4.0, icon: '🍬', hint: '1 tsp ≈ 4g'), (label: 'tbsp (كبيرة)', grams: 12.0, icon: '🥄', hint: '1 tbsp ≈ 12g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['honey', 'عسل']))
      return [(label: 'tbsp (ملعقة)', grams: 21.0, icon: '🍯', hint: '1 tbsp ≈ 21g'), (label: 'tsp (صغيرة)', grams: 7.0, icon: '🥄', hint: '1 tsp ≈ 7g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    if (_kw(n, ['avocado', 'أفوكادو']))
      return [(label: 'piece (حبة)', grams: 200.0, icon: '🥑', hint: '1 whole ≈ 200g'), (label: '½ piece (نص)', grams: 100.0, icon: '🥑', hint: 'Half ≈ 100g'), (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams')];

    // Default fallback
    return [
      (label: 'g',          grams: 1.0,   icon: '⚖️', hint: 'Grams'),
      (label: 'oz',         grams: 28.35, icon: '🇺🇸', hint: '1 oz ≈ 28g'),
      (label: 'cup (كوب)',  grams: 240.0, icon: '☕',  hint: '1 cup ≈ 240g'),
      (label: 'serving',    grams: 100.0, icon: '🥣',  hint: '1 serving = 100g'),
    ];
  }

  double get _grams {
    final units = _servingUnitsFor(widget.food['name'] ?? '');
    final match = units.firstWhere((u) => u.label == _unit, orElse: () => units.first);
    return _quantity * match.grams;
  }

  double _calc(String key) => ((widget.food[key] as num?)?.toDouble() ?? 0) * _grams / 100;

  String get _unitHint {
    final units = _servingUnitsFor(widget.food['name'] ?? '');
    return units.firstWhere((u) => u.label == _unit, orElse: () => units.first).hint;
  }

  List<({String type, String label, String emoji})> _getMeals(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      (type: 'breakfast', label: l10n.breakfast, emoji: '🍳'),
      (type: 'lunch', label: l10n.lunch, emoji: '🥗'),
      (type: 'dinner', label: l10n.dinner, emoji: '🍽'),
      (type: 'snack', label: l10n.snack, emoji: '🥜'),
    ];
  }

  @override
  void dispose() { _quantityCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.food['name'] ?? '', style: AppText.headlineSm.copyWith(fontWeight: FontWeight.w800)),
                      if (widget.food['name_ar'] != null)
                        Text(widget.food['name_ar'], style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('per 100g', style: TextStyle(fontSize: 10, color: AppColors.primaryFixed, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Live macro grid
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(child: _liveStatCol(_calc('calories').toInt().toString(), AppLocalizations.of(context)!.caloriesLabel, AppLocalizations.of(context)!.kcal, AppColors.primaryFixed)),
                  _divider(),
                  Expanded(child: _liveStatCol('${_calc('protein_g').toStringAsFixed(1)}', AppLocalizations.of(context)!.proteinGoal, 'g', const Color(0xFFFF6B6B))),
                  _divider(),
                  Expanded(child: _liveStatCol('${_calc('carbs_g').toStringAsFixed(1)}', AppLocalizations.of(context)!.carbs, 'g', const Color(0xFF4A9EFF))),
                  _divider(),
                  Expanded(child: _liveStatCol('${_calc('fat_g').toStringAsFixed(1)}', AppLocalizations.of(context)!.fat, 'g', const Color(0xFFFFB84A))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Quantity + unit
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.quantity,
                      labelStyle: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surfaceContainer,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primaryFixed, width: 1.5),
                      ),
                      helperText: _unitHint,
                      helperStyle: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                    ),
                    onChanged: (v) => setState(() => _quantity = double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryFixed.withOpacity(0.35)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: Builder(
                      builder: (context) {
                        final units = _servingUnitsFor(widget.food['name'] ?? '');
                        // If current _unit isn't valid for this food, snap to first
                        if (!units.any((u) => u.label == _unit)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _unit = units.first.label);
                          });
                        }
                        return DropdownButton<String>(
                          value: units.any((u) => u.label == _unit) ? _unit : units.first.label,
                          dropdownColor: AppColors.surfaceContainerHigh,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          icon: Icon(Icons.expand_more_rounded, color: AppColors.primaryFixed, size: 18),
                          items: units.map((u) => DropdownMenuItem(
                            value: u.label,
                            child: Text('${u.icon} ${u.label}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          )).toList(),
                          onChanged: (v) => setState(() => _unit = v ?? units.first.label),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Meal type
            Text('Add to meal', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
            const SizedBox(height: 10),
            Row(
              children: _getMeals(context).map((m) {
                final sel = _mealType == m.type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mealType = m.type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsetsDirectional.only(end: m.type == 'snack' ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primaryFixed : AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: sel ? null : Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        children: [
                          Text(m.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 3),
                          Text(
                            m.label.substring(0, min(3, m.label.length)).toUpperCase(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: sel ? Colors.white : AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryFixed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _logging ? null : () async {
                  HapticFeedback.mediumImpact();
                  setState(() => _logging = true);
                  await _nutritionService.logFood(
                    foodId: widget.food['id'].toString(),
                    foodName: widget.food['name'],
                    mealType: _mealType,
                    quantity: _grams,
                    calories: _calc('calories'),
                    proteinG: _calc('protein_g'),
                    carbsG: _calc('carbs_g'),
                    fatG: _calc('fat_g'),
                  );
                  widget.onLogged();
                },
                child: _logging
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.logFood, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 0.5, height: 36, color: Colors.white.withOpacity(0.08));

  Widget _liveStatCol(String val, String label, String unit, Color color) => Column(
    children: [
      Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      Text(unit, style: TextStyle(fontSize: 9, color: color.withOpacity(0.7))),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant)),
    ],
  );
}