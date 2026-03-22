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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
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
      _weeklyProgress =
          List<Map<String, dynamic>>.from(results[3] as List);
      _isLoading = false;
    });
  }

  Future<void> _deleteLog(String id) async {
    await _nutritionService.deleteLog(id);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('NUTRITION', style: AppText.headlineSm),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryFixed,
          labelColor: AppColors.primaryFixed,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          tabs: const [
            Tab(text: 'TODAY'),
            Tab(text: 'HISTORY'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryFixed))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTab(),
                _buildHistoryTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => _showAddFoodBottomSheet(context),
              backgroundColor: AppColors.primaryFixed,
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
    );
  }

  Widget _buildTodayTab() {
    final double caloriesConsumed =
        (_summary['calories_consumed'] as num?)?.toDouble() ?? 0;
    final double caloriesGoal =
        (_goals['daily_calories'] as num?)?.toDouble() ?? 2000;
    final double proteinConsumed =
        (_summary['protein_g'] as num?)?.toDouble() ?? 0;
    final double proteinGoal =
        (_goals['daily_protein_g'] as num?)?.toDouble() ?? 150;
    final double carbsConsumed =
        (_summary['carbs_g'] as num?)?.toDouble() ?? 0;
    final double carbsGoal =
        (_goals['daily_carbs_g'] as num?)?.toDouble() ?? 250;
    final double fatConsumed = (_summary['fat_g'] as num?)?.toDouble() ?? 0;
    final double fatGoal = (_goals['daily_fat_g'] as num?)?.toDouble() ?? 65;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calorie Ring
          Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: caloriesGoal > 0 ? caloriesConsumed / caloriesGoal : 0,
                    strokeWidth: 12,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryFixed),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${caloriesConsumed.toInt()}',
                          style: AppText.headlineLg,
                        ),
                        Text(
                          '/ ${caloriesGoal.toInt()} kcal',
                          style: AppText.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Macros
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroItem('Protein', proteinConsumed, proteinGoal, Colors.redAccent),
              _buildMacroItem('Carbs', carbsConsumed, carbsGoal, Colors.blueAccent),
              _buildMacroItem('Fat', fatConsumed, fatGoal, Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 32),
          // Meals
          _buildMealSection('Breakfast', 'breakfast'),
          const SizedBox(height: 16),
          _buildMealSection('Lunch', 'lunch'),
          const SizedBox(height: 16),
          _buildMealSection('Dinner', 'dinner'),
          const SizedBox(height: 16),
          _buildMealSection('Snack', 'snack'),
          const SizedBox(height: 80), // offset for FAB
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, double consumed, double goal, Color color) {
    double pct = goal > 0 ? consumed / goal : 0;
    if (pct > 1.0) pct = 1.0;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Text(label, style: AppText.labelSm),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '${consumed.toInt()}/${goal.toInt()}g',
              style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMealSection(String title, String mealType) {
    final logs = _todayLogs[mealType] ?? [];
    double totalCals = 0;
    for (var log in logs) {
      totalCals += (log['calories'] as num?)?.toDouble() ?? 0;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: AppText.titleMd),
                Text(
                  '${totalCals.toInt()} kcal',
                  style: AppText.labelMd.copyWith(color: AppColors.primaryFixed),
                ),
              ],
            ),
          ),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('No food logged yet.',
                  style:
                      AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            ),
          ...logs.map((log) {
            return Dismissible(
              key: Key(log['id'].toString()),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: AppColors.error,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) {
                _deleteLog(log['id'].toString());
              },
              child: ListTile(
                title: Text(log['food_name'], style: AppText.bodyMd),
                subtitle: Text(
                  '${log['quantity']}g • Protein: ${((log['protein_g'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}g',
                  style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                ),
                trailing: Text('${((log['calories'] as num?)?.toDouble() ?? 0).toInt()} kcal',
                    style: AppText.bodyMd),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_weeklyProgress.isEmpty) {
      return Center(
          child:
              Text('No data available', style: AppText.bodyMd));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LAST 7 DAYS CALORIES', style: AppText.headlineSm),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 3000,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < _weeklyProgress.length) {
                          final date = _weeklyProgress[value.toInt()]['summary_date'].toString();
                          final shortDate = date.substring(5, 10);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(shortDate,
                                style: AppText.labelSm.copyWith(
                                    color: AppColors.onSurfaceVariant, fontSize: 10)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _weeklyProgress.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final day = entry.value;
                  double cals = (day['calories_consumed'] as num?)?.toDouble() ?? 0;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: cals,
                        color: AppColors.primaryFixed,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      )
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text('DAILY LOGS', style: AppText.headlineSm),
          const SizedBox(height: 16),
          ..._weeklyProgress.reversed.map((day) {
            final cals = (day['calories_consumed'] as num?)?.toDouble() ?? 0;
            final proteing = (day['protein_g'] as num?)?.toDouble() ?? 0;
            final isWorkout = day['workout_done'] == true;
            final dateStr = day['summary_date'].toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateStr, style: AppText.titleSm),
                      const SizedBox(height: 4),
                      Text(
                        '${cals.toInt()} kcal • ${proteing.toInt()}g protein',
                        style: AppText.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant),
                      )
                    ],
                  ),
                  Icon(
                    isWorkout ? Icons.fitness_center : Icons.airline_seat_recline_normal,
                    color: isWorkout ? AppColors.primaryFixed : AppColors.outline,
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showAddFoodBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _AddFoodSheet(),
    ).then((_) => _loadData());
  }
}

class _AddFoodSheet extends StatefulWidget {
  const _AddFoodSheet();
  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _nutritionService = NutritionService();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String _mealType = 'breakfast';
  final _qtyController = TextEditingController(text: '100');

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    setState(() => _searching = true);
    final results = await _nutritionService.searchFoods(query);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  Future<void> _logFood(Map<String, dynamic> food) async {
    final qty = double.tryParse(_qtyController.text) ?? 100;
    await _nutritionService.logFood(
      foodId: food['id'].toString(),
      foodName: food['name'],
      mealType: _mealType,
      quantity: qty,
      calories: (food['calories'] as num).toDouble(),
      proteinG: (food['protein_g'] as num).toDouble(),
      carbsG: (food['carbs_g'] as num).toDouble(),
      fatG: (food['fat_g'] as num).toDouble(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Food', style: AppText.headlineSm),
            const SizedBox(height: 16),
            // Select Meal
            Row(
              children: [
                _buildMealChip('Breakfast', 'breakfast'),
                const SizedBox(width: 8),
                _buildMealChip('Lunch', 'lunch'),
                const SizedBox(width: 8),
                _buildMealChip('Dinner', 'dinner'),
                const SizedBox(width: 8),
                _buildMealChip('Snack', 'snack'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onSubmitted: _search,
                    style: AppText.bodyMd.copyWith(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search food...',
                      hintStyle: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                      filled: true,
                      fillColor: AppColors.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    style: AppText.bodyMd.copyWith(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Qty(g)',
                      labelStyle: AppText.labelSm.copyWith(color: AppColors.primaryFixed),
                      filled: true,
                      fillColor: AppColors.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_searching)
              const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryFixed))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final food = _results[index];
                    return ListTile(
                      title: Text(food['name'], style: AppText.bodyMd),
                      subtitle: Text(
                        '${food['calories']} kcal / 100g',
                        style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.primaryFixed),
                        onPressed: () => _logFood(food),
                      ),
                    );
                  },
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildMealChip(String label, String value) {
    final selected = _mealType == value;
    return GestureDetector(
      onTap: () => setState(() => _mealType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryFixed : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppText.labelSm.copyWith(
            color: selected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}
