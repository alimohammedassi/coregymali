import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/nutrition_service.dart';
import '../services/stats_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

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
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _ringAnim = CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOutCubic,
    );
    _proteinAnim = CurvedAnimation(
      parent: _macroController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );
    _carbsAnim = CurvedAnimation(
      parent: _macroController,
      curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic),
    );
    _fatAnim = CurvedAnimation(
      parent: _macroController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    );

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

  // ─── helpers ───────────────────────────────────────────────────────────────
  double get _caloriesConsumed =>
      (_summary['calories_consumed'] as num?)?.toDouble() ?? 0;
  double get _caloriesGoal =>
      (_goals['daily_calories'] as num?)?.toDouble() ?? 2000;
  double get _proteinConsumed =>
      (_summary['protein_g'] as num?)?.toDouble() ?? 0;
  double get _proteinGoal =>
      (_goals['daily_protein_g'] as num?)?.toDouble() ?? 150;
  double get _carbsConsumed => (_summary['carbs_g'] as num?)?.toDouble() ?? 0;
  double get _carbsGoal => (_goals['daily_carbs_g'] as num?)?.toDouble() ?? 250;
  double get _fatConsumed => (_summary['fat_g'] as num?)?.toDouble() ?? 0;
  double get _fatGoal => (_goals['daily_fat_g'] as num?)?.toDouble() ?? 65;

  double get _calorieProgress => _caloriesGoal > 0
      ? (_caloriesConsumed / _caloriesGoal).clamp(0.0, 1.0)
      : 0;

  Color get _ringColor {
    if (_calorieProgress >= 1.0) return Colors.redAccent;
    if (_calorieProgress > 0.8) return Colors.orangeAccent;
    return AppColors.primaryFixed;
  }

  // ─── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildShimmer()
          : TabBarView(
              controller: _tabController,
              children: [_buildTodayTab(), _buildHistoryTab()],
            ),
      floatingActionButton: _tabController.index == 0 ? _buildFAB() : null,
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'NUTRITION',
        style: AppText.headlineSm.copyWith(letterSpacing: 2),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1,
            ),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'TODAY'),
              Tab(text: 'HISTORY'),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FAB ───────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () => _showAddFoodBottomSheet(context),
      backgroundColor: AppColors.primaryFixed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
    );
  }

  // ─── Shimmer ───────────────────────────────────────────────────────────────
  Widget _buildShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _shimmerBox(220, radius: 120),
          const SizedBox(height: 16),
          _shimmerBox(60, radius: 12),
          const SizedBox(height: 12),
          _shimmerBox(110, radius: 14),
          const SizedBox(height: 10),
          _shimmerBox(110, radius: 14),
        ],
      ),
    );
  }

  Widget _shimmerBox(double h, {double radius = 12}) => Container(
    width: double.infinity,
    height: h,
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(radius),
    ),
  );

  // ─── TODAY TAB ─────────────────────────────────────────────────────────────
  Widget _buildTodayTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryFixed,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FadeSlideIn(
              parent: _pageController,
              delayMs: 0,
              child: _buildCaloriesCard(),
            ),
            const SizedBox(height: 16),
            _FadeSlideIn(
              parent: _pageController,
              delayMs: 150,
              child: _buildMacrosCard(),
            ),
            const SizedBox(height: 24),
            _FadeSlideIn(
              parent: _pageController,
              delayMs: 250,
              child: Text(
                'Meals',
                style: AppText.titleMd.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            _FadeSlideIn(
              parent: _pageController,
              delayMs: 300,
              child: _buildMealSection('Breakfast', 'breakfast', '🍳'),
            ),
            const SizedBox(height: 10),
            _FadeSlideIn(
              parent: _pageController,
              delayMs: 380,
              child: _buildMealSection('Lunch', 'lunch', '🥗'),
            ),
            const SizedBox(height: 10),
            _FadeSlideIn(
              parent: _pageController,
              delayMs: 460,
              child: _buildMealSection('Dinner', 'dinner', '🍽'),
            ),
            const SizedBox(height: 10),
            _FadeSlideIn(
              parent: _pageController,
              delayMs: 540,
              child: _buildMealSection('Snack', 'snack', '🥜'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Calories Card ─────────────────────────────────────────────────────────
  Widget _buildCaloriesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'CALORIES TODAY',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _ringAnim,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _ringColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(_caloriesConsumed * _ringAnim.value).toInt()} / ${_caloriesGoal.toInt()} kcal',
                    style: TextStyle(
                      fontSize: 11,
                      color: _ringColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Ring
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _ringAnim,
                  builder: (_, __) => CustomPaint(
                    size: const Size(160, 160),
                    painter: _NutritionRingPainter(
                      progress: _calorieProgress * _ringAnim.value,
                      color: _ringColor,
                      trackColor: Colors.white.withOpacity(0.07),
                      strokeWidth: 14,
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
                          (_caloriesConsumed * _ringAnim.value)
                              .toInt()
                              .toString(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                      Text(
                        'kcal consumed',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_caloriesGoal - _caloriesConsumed).abs().toInt()} kcal ${_caloriesConsumed > _caloriesGoal ? 'over' : 'remaining'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _caloriesConsumed > _caloriesGoal
                              ? Colors.redAccent
                              : AppColors.primaryFixed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Macros Card ───────────────────────────────────────────────────────────
  Widget _buildMacrosCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          _AnimatedMacroRow(
            label: 'Protein',
            color: const Color(0xFFFF6B6B),
            current: _proteinConsumed,
            goal: _proteinGoal,
            animation: _proteinAnim,
          ),
          const SizedBox(height: 14),
          _AnimatedMacroRow(
            label: 'Carbs',
            color: const Color(0xFF4A9EFF),
            current: _carbsConsumed,
            goal: _carbsGoal,
            animation: _carbsAnim,
          ),
          const SizedBox(height: 14),
          _AnimatedMacroRow(
            label: 'Fat',
            color: const Color(0xFFFFB84A),
            current: _fatConsumed,
            goal: _fatGoal,
            animation: _fatAnim,
          ),
        ],
      ),
    );
  }

  // ─── Meal section ──────────────────────────────────────────────────────────
  Widget _buildMealSection(String title, String mealType, String emoji) {
    final logs = _todayLogs[mealType] ?? [];
    final totalCals = logs.fold(
      0.0,
      (s, l) => s + ((l['calories'] as num?) ?? 0),
    );
    final hasLogs = logs.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasLogs
              ? AppColors.primaryFixed.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (hasLogs)
                  Text(
                    '${totalCals.toInt()} kcal',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryFixed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showAddFoodBottomSheet(context),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: AppColors.primaryFixed,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Logs
          if (!hasLogs)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'No food logged yet.',
                style: AppText.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant.withOpacity(0.6),
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
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
              ),
              onDismissed: (_) => _deleteLog(log['id'].toString()),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.04)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log['food_name'] ?? '',
                            style: AppText.bodyMd.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${log['quantity']}g  ·  P: ${((log['protein_g'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}g  ·  C: ${((log['carbs_g'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}g  ·  F: ${((log['fat_g'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}g',
                            style: AppText.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${((log['calories'] as num?)?.toDouble() ?? 0).toInt()}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryFixed,
                              ),
                            ),
                            Text(
                              ' kcal',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _deleteLog(log['id'].toString()),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Colors.redAccent.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (hasLogs) const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ─── HISTORY TAB ───────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    if (_weeklyProgress.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 48,
              color: AppColors.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text('No history yet', style: AppText.titleSm),
            const SizedBox(height: 4),
            Text(
              'Start logging meals to see your progress',
              style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final maxY =
        _weeklyProgress.fold(0.0, (m, d) {
          final c = (d['calories_consumed'] as num?)?.toDouble() ?? 0;
          return c > m ? c : m;
        }) *
        1.3;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart card
          _FadeSlideIn(
            parent: _pageController,
            delayMs: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CALORIES — LAST 7 DAYS',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY > 0 ? maxY : 3000,
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i >= 0 && i < _weeklyProgress.length) {
                                  final d = _weeklyProgress[i]['summary_date']
                                      .toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      d.substring(5, 10),
                                      style: TextStyle(
                                        color: AppColors.onSurfaceVariant,
                                        fontSize: 9,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          horizontalInterval: maxY / 3,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.white.withOpacity(0.04),
                            strokeWidth: 1,
                          ),
                          drawVerticalLine: false,
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _weeklyProgress.asMap().entries.map((e) {
                          final cals =
                              (e.value['calories_consumed'] as num?)
                                  ?.toDouble() ??
                              0;
                          final isGoalMet =
                              cals >=
                              (_goals['daily_calories'] as num? ?? 2000);
                          return BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: cals,
                                width: 18,
                                borderRadius: BorderRadius.circular(6),
                                color: isGoalMet
                                    ? AppColors.primaryFixed
                                    : AppColors.primaryFixed.withOpacity(0.35),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendDot(AppColors.primaryFixed),
                      const SizedBox(width: 4),
                      Text(
                        'Goal met',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 16),
                      _legendDot(AppColors.primaryFixed.withOpacity(0.35)),
                      const SizedBox(width: 4),
                      Text(
                        'Under goal',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _FadeSlideIn(
            parent: _pageController,
            delayMs: 200,
            child: Text(
              'Daily Logs',
              style: AppText.titleMd.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          ..._weeklyProgress.reversed.toList().asMap().entries.map((entry) {
            final delay = 280 + entry.key * 60;
            final day = entry.value;
            final cals = (day['calories_consumed'] as num?)?.toDouble() ?? 0;
            final protein = (day['protein_g'] as num?)?.toDouble() ?? 0;
            final carbs = (day['carbs_g'] as num?)?.toDouble() ?? 0;
            final goalCal =
                (_goals['daily_calories'] as num?)?.toDouble() ?? 2000;
            final pct = goalCal > 0 ? (cals / goalCal).clamp(0.0, 1.0) : 0.0;
            final isWorkout = day['workout_done'] == true;
            final dateStr = day['summary_date'].toString();

            return _FadeSlideIn(
              parent: _pageController,
              delayMs: delay,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dateStr,
                          style: AppText.titleSm.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (isWorkout)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryFixed.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.fitness_center,
                                  color: AppColors.primaryFixed,
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Workout',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primaryFixed,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct.toDouble(),
                        minHeight: 4,
                        backgroundColor: Colors.white.withOpacity(0.07),
                        color: pct >= 1.0
                            ? Colors.greenAccent
                            : AppColors.primaryFixed,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _historyPill(
                          '${cals.toInt()} kcal',
                          AppColors.primaryFixed,
                        ),
                        const SizedBox(width: 6),
                        _historyPill(
                          'P: ${protein.toInt()}g',
                          const Color(0xFFFF6B6B),
                        ),
                        const SizedBox(width: 6),
                        _historyPill(
                          'C: ${carbs.toInt()}g',
                          const Color(0xFF4A9EFF),
                        ),
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

  Widget _legendDot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _historyPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
    ),
  );

  // ─── Bottom Sheet ──────────────────────────────────────────────────────────
  void _showAddFoodBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFoodSheet(),
    ).then((_) => _loadData());
  }
}

// ─── Animated macro row ────────────────────────────────────────────────────
class _AnimatedMacroRow extends StatelessWidget {
  final String label;
  final Color color;
  final double current, goal;
  final Animation<double> animation;

  const _AnimatedMacroRow({
    required this.label,
    required this.color,
    required this.current,
    required this.goal,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final prog = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: animation,
              builder: (_, __) => Text(
                '${(current * animation.value).toInt()} / ${goal.toInt()}g',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: animation,
          builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (prog * animation.value).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.07),
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Ring painter ─────────────────────────────────────────────────────────
class _NutritionRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _NutritionRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    // Glow when near goal
    if (progress > 0.85) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..color = color.withOpacity(0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center, radius, glowPaint);
    }

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    // Arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NutritionRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Fade + slide-in wrapper ───────────────────────────────────────────────
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
    final start = delayMs / 1800.0;
    final end = (delayMs + 600) / 1800.0;
    final anim = CurvedAnimation(
      parent: parent,
      curve: Interval(
        start.clamp(0.0, 1.0),
        end.clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - anim.value)),
          child: child,
        ),
      ),
    );
  }
}

// ─── Add Food Sheet ────────────────────────────────────────────────────────
class _AddFoodSheet extends StatefulWidget {
  const _AddFoodSheet();
  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _nutritionService = NutritionService();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<({String label, String db, String emoji})> _categories = const [
    (label: 'All', db: 'all', emoji: '🍽'),
    (label: 'Arabic', db: 'arabic', emoji: '🌍'),
    (label: 'Protein', db: 'protein', emoji: '🍗'),
    (label: 'Carbs', db: 'carbs', emoji: '🍚'),
    (label: 'Vegetables', db: 'vegetables', emoji: '🥦'),
    (label: 'Fruits', db: 'fruits', emoji: '🍎'),
    (label: 'Dairy', db: 'dairy', emoji: '🧀'),
    (label: 'Fats', db: 'fats', emoji: '🥜'),
    (label: 'Fast Food', db: 'fastfood', emoji: '🍔'),
    (label: 'Drinks', db: 'drinks', emoji: '🥤'),
  ];

  Future<void> _search() async {
    setState(() => _searching = true);
    final cat = _categories.firstWhere((c) => c.label == _selectedCategory).db;
    final results = await _nutritionService.searchFoods(
      _searchQuery,
      category: cat,
    );
    if (mounted)
      setState(() {
        _results = results;
        _searching = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Text('Search Food', style: AppText.headlineSm),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: TextField(
              autofocus: false,
              onChanged: (v) {
                _searchQuery = v;
                if (v.length > 1) _search();
              },
              onSubmitted: (_) => _search(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search in English or Arabic...',
                hintStyle: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.onSurfaceVariant,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          // Category chips
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
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
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.primaryFixed
                          : AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${cat.emoji} ${cat.label}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Results
          Expanded(
            child: _searching
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryFixed,
                    ),
                  )
                : _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: AppColors.onSurfaceVariant.withOpacity(0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Search for a food',
                          style: AppText.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final food = _results[i];
                      return GestureDetector(
                        onTap: () => _showLogFoodSheet(food),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryFixed.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _categories
                                      .firstWhere(
                                        (c) =>
                                            c.db ==
                                            (food['category'] ?? 'other'),
                                        orElse: () => _categories[0],
                                      )
                                      .emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      food['name'] ?? '',
                                      style: AppText.titleSm.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (food['name_ar'] != null)
                                      Text(
                                        food['name_ar'],
                                        style: AppText.bodySm.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        _macroBadge(
                                          '${food['calories']} kcal',
                                          AppColors.primaryFixed,
                                        ),
                                        const SizedBox(width: 4),
                                        _macroBadge(
                                          'P ${food['protein_g']}g',
                                          const Color(0xFFFF6B6B),
                                        ),
                                        const SizedBox(width: 4),
                                        _macroBadge(
                                          'C ${food['carbs_g']}g',
                                          const Color(0xFF4A9EFF),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.onSurfaceVariant,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _macroBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
    ),
  );

  void _showLogFoodSheet(Map<String, dynamic> food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogFoodSheet(
        food: food,
        onLogged: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ─── Log Food Sheet ────────────────────────────────────────────────────────
class _LogFoodSheet extends StatefulWidget {
  final Map<String, dynamic> food;
  final VoidCallback onLogged;
  const _LogFoodSheet({required this.food, required this.onLogged});

  @override
  State<_LogFoodSheet> createState() => _LogFoodSheetState();
}

class _LogFoodSheetState extends State<_LogFoodSheet> {
  final _nutritionService = NutritionService();
  final _quantityCtrl = TextEditingController(text: '100');
  String _mealType = 'breakfast';
  double _quantity = 100;
  String _unit = 'g';
  bool _logging = false;

  static const _meals = [
    (type: 'breakfast', label: 'Breakfast', emoji: '🍳'),
    (type: 'lunch',     label: 'Lunch',     emoji: '🥗'),
    (type: 'dinner',    label: 'Dinner',    emoji: '🍽'),
    (type: 'snack',     label: 'Snack',     emoji: '🥜'),
  ];

  // Each unit maps to how many GRAMS it equals for this food
  static const _unitConversions = {
    'g':       1.0,
    'oz':      28.3495,
    'cup':     240.0,
    'piece':   1.0,
    'serving': 100.0,
  };

  static const _units = [
    (label: 'g',       icon: '⚖️'),
    (label: 'oz',      icon: '🇺🇸'),
    (label: 'cup',     icon: '☕'),
    (label: 'piece',   icon: '🍴'),
    (label: 'serving', icon: '🥣'),
  ];

  /// Convert entered quantity → grams so macros stay accurate
  double get _grams => _quantity * (_unitConversions[_unit] ?? 1.0);

  double _calc(String key) {
    final base = (widget.food[key] as num?)?.toDouble() ?? 0;
    return base * _grams / 100;
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.food['name'] ?? '',
              style: AppText.headlineSm.copyWith(fontWeight: FontWeight.w800),
            ),
            if (widget.food['name_ar'] != null)
              Text(
                widget.food['name_ar'],
                style: AppText.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 20),
            // Live macros
            AnimatedBuilder(
              animation: const AlwaysStoppedAnimation(1),
              builder: (_, __) => Row(
                children: [
                  _liveStat(
                    _calc('calories').toInt().toString(),
                    'kcal',
                    AppColors.primaryFixed,
                  ),
                  _liveStat(
                    '${_calc('protein_g').toStringAsFixed(1)}g',
                    'Protein',
                    const Color(0xFFFF6B6B),
                  ),
                  _liveStat(
                    '${_calc('carbs_g').toStringAsFixed(1)}g',
                    'Carbs',
                    const Color(0xFF4A9EFF),
                  ),
                  _liveStat(
                    '${_calc('fat_g').toStringAsFixed(1)}g',
                    'Fat',
                    const Color(0xFFFFB84A),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Quantity + unit row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      labelStyle: TextStyle(color: AppColors.onSurfaceVariant),
                      filled: true,
                      fillColor: AppColors.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primaryFixed, width: 1.5),
                      ),
                    ),
                    onChanged: (v) => setState(() => _quantity = double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 10),
                // Unit selector dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryFixed.withOpacity(0.4), width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _unit,
                      dropdownColor: AppColors.surfaceContainerHigh,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      icon: Icon(Icons.expand_more_rounded, color: AppColors.primaryFixed, size: 18),
                      items: _units.map((u) =>
                        DropdownMenuItem(
                          value: u.label,
                          child: Text('${u.icon} ${u.label}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        )
                      ).toList(),
                      onChanged: (v) => setState(() => _unit = v ?? 'g'),
                    ),
                  ),
                ),
              ],
            ),
            // Unit description hint
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                _unit == 'g'       ? 'Per 100g values from database'
                : _unit == 'oz'    ? '1 oz = 28.35g'
                : _unit == 'cup'   ? '1 cup ≈ 240g'
                : _unit == 'piece' ? '1 piece = 1g equivalent (adjust as needed)'
                                   : '1 serving = 100g equivalent',
                style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),
            // Meal type
            Text(
              'Meal',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: _meals.map((m) {
                final sel = _mealType == m.type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mealType = m.type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: m.type == 'snack' ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.primaryFixed
                            : AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(m.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 3),
                          Text(
                            m.label.substring(0, 3).toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? Colors.white
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryFixed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _logging
                    ? null
                    : () async {
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
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Log Food',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveStat(String val, String label, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant),
        ),
      ],
    ),
  );
}
