import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/stats_service.dart';
import '../services/measurements_service.dart';
import '../services/workout_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  final _statsService = StatsService();
  final _measurementsService = MeasurementsService();
  final _workoutService = WorkoutService();

  Map<String, dynamic> _goals = {};
  List<Map<String, dynamic>> _weeklyProgress = [];
  List<Map<String, dynamic>> _weightHistory = [];
  Map<String, dynamic>? _latestMeasurements;
  List<Map<String, dynamic>> _personalRecords = [];
  bool _isLoading = true;

  // Toggle for weekly chart
  String _selectedMetric = 'calories'; // 'calories', 'steps', 'workouts'

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _statsService.getGoals(),
      _statsService.getWeeklyProgress(),
      _measurementsService.getLatest(),
      _measurementsService.getWeightHistory(),
      _workoutService.getPersonalRecords(),
    ]);

    if (!mounted) return;
    setState(() {
      _goals = results[0] as Map<String, dynamic>;
      _weeklyProgress = List<Map<String, dynamic>>.from(results[1] as List);
      _latestMeasurements = results[2] as Map<String, dynamic>?;
      _weightHistory = List<Map<String, dynamic>>.from(results[3] as List);
      _personalRecords = List<Map<String, dynamic>>.from(results[4] as List);
      _isLoading = false;
    });
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryFixed),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('PROGRESS', style: AppText.headlineSm),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart, color: AppColors.primaryFixed),
            onPressed: () => _showUpdateMeasurementsSheet(context),
          )
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          color: AppColors.primaryFixed,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Body Weight Chart ──
                _buildSectionHeader('BODY WEIGHT', Icons.monitor_weight_outlined),
                const SizedBox(height: 16),
                _buildWeightChart(),
                const SizedBox(height: 8),
                _buildLogWeightButton(),

                const SizedBox(height: 32),

                // ── Body Measurements ──
                _buildSectionHeader('BODY MEASUREMENTS', Icons.straighten),
                const SizedBox(height: 16),
                _buildMeasurementsCard(),

                const SizedBox(height: 32),

                // ── Weekly Activity Chart ──
                _buildSectionHeader('WEEKLY ACTIVITY', Icons.bar_chart),
                const SizedBox(height: 12),
                _buildChartToggle(),
                const SizedBox(height: 16),
                _buildWeeklyActivityChart(),

                const SizedBox(height: 32),

                // ── Personal Records ──
                _buildSectionHeader('PERSONAL RECORDS', Icons.emoji_events_outlined),
                const SizedBox(height: 16),
                _buildPersonalRecords(),

                const SizedBox(height: 32),

                // ── Current Goals ──
                _buildSectionHeader('CURRENT GOALS', Icons.track_changes_outlined),
                const SizedBox(height: 16),
                _buildGoalsList(),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryFixed, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppText.titleSm.copyWith(letterSpacing: 2),
        ),
      ],
    );
  }

  // ── Body Weight Chart ──
  Widget _buildWeightChart() {
    if (_weightHistory.isEmpty) {
      return _buildEmptyState('No weight data yet.\nLog your weight to see progress.');
    }

    // Calculate change
    final firstWeight = (_weightHistory.first['weight_kg'] as num?)?.toDouble() ?? 0;
    final lastWeight = (_weightHistory.last['weight_kg'] as num?)?.toDouble() ?? 0;
    final change = lastWeight - firstWeight;
    final changeStr = change >= 0 ? '+${change.toStringAsFixed(1)}' : change.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${lastWeight.toStringAsFixed(1)} kg', style: AppText.metricMd),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: change >= 0
                      ? AppColors.primaryFixed.withValues(alpha: 0.15)
                      : AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$changeStr kg since start',
                  style: AppText.labelMd.copyWith(
                    color: change >= 0 ? AppColors.primaryFixed : AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: _weightHistory.length <= 7,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < _weightHistory.length) {
                          final dateStr =
                              _weightHistory[idx]['measured_date']?.toString() ?? '';
                          if (dateStr.length >= 10) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                dateStr.substring(5, 10),
                                style: AppText.labelSm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 9),
                              ),
                            );
                          }
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _weightHistory.asMap().entries.map((e) {
                      final w = (e.value['weight_kg'] as num?)?.toDouble() ?? 0;
                      return FlSpot(e.key.toDouble(), w);
                    }).toList(),
                    isCurved: true,
                    color: AppColors.primaryFixed,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: AppColors.primaryFixed,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryFixed.withValues(alpha: 0.2),
                          AppColors.primaryFixed.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
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

  Widget _buildLogWeightButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showLogWeightDialog(),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('LOG TODAY\'S WEIGHT'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryFixed,
          side: const BorderSide(color: AppColors.primaryFixed),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  void _showLogWeightDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title: Text("LOG WEIGHT", style: AppText.headlineSm.copyWith(fontSize: 18)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppText.bodyLg.copyWith(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Weight (kg)',
            labelStyle: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant),
            suffixText: 'kg',
            filled: true,
            fillColor: AppColors.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: AppText.labelMd.copyWith(color: AppColors.outline)),
          ),
          ElevatedButton(
            onPressed: () async {
              final weight = double.tryParse(controller.text);
              if (weight != null && weight > 0) {
                Navigator.pop(ctx);
                await _measurementsService.saveMeasurement(weightKg: weight);
                if (mounted) _loadData();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryFixed),
            child: Text('SAVE', style: AppText.buttonPrimary.copyWith(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // ── Body Measurements Card ──
  Widget _buildMeasurementsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_latestMeasurements == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No measurements logged yet.',
                style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.5,
              children: [
                _buildMeasurementCard('Weight', '${_latestMeasurements!['weight_kg'] ?? '--'} kg'),
                _buildMeasurementCard('Body Fat', '${_latestMeasurements!['body_fat_pct'] ?? '--'}%'),
                _buildMeasurementCard('Chest', '${_latestMeasurements!['chest_cm'] ?? '--'} cm'),
                _buildMeasurementCard('Arms', '${_latestMeasurements!['arms_cm'] ?? '--'} cm'),
                _buildMeasurementCard('Waist', '${_latestMeasurements!['waist_cm'] ?? '--'} cm'),
                _buildMeasurementCard('Thighs', '${_latestMeasurements!['thighs_cm'] ?? '--'} cm'),
              ],
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showUpdateMeasurementsSheet(context),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('UPDATE MEASUREMENTS'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryFixed,
                side: const BorderSide(color: AppColors.primaryFixed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppText.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant, fontSize: 9)),
          const SizedBox(height: 2),
          Text(value, style: AppText.titleSm),
        ],
      ),
    );
  }

  // ── Weekly Activity Chart Toggle ──
  Widget _buildChartToggle() {
    return Row(
      children: [
        _buildToggleChip('Calories', 'calories'),
        const SizedBox(width: 8),
        _buildToggleChip('Steps', 'steps'),
        const SizedBox(width: 8),
        _buildToggleChip('Workouts', 'workouts'),
      ],
    );
  }

  Widget _buildToggleChip(String label, String metric) {
    final isSelected = _selectedMetric == metric;
    return GestureDetector(
      onTap: () => setState(() => _selectedMetric = metric),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryFixed
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryFixed : AppColors.glassBorder,
          ),
        ),
        child: Text(
          label,
          style: AppText.labelMd.copyWith(
            color: isSelected ? Colors.black : AppColors.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyActivityChart() {
    if (_weeklyProgress.isEmpty) {
      return _buildEmptyState('No activity data for this week.');
    }

    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 100,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 6,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${rod.toY.round()}%',
                    AppText.labelMd.copyWith(
                      color: AppColors.surfaceLowest,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx >= 0 && idx < days.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          days[idx],
                          style: AppText.labelSm.copyWith(
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
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: _buildWeeklyBarGroups(),
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildWeeklyBarGroups() {
    final filled = List.generate(7, (i) {
      if (i < _weeklyProgress.length) return _weeklyProgress[i];
      return <String, dynamic>{};
    });

    return List.generate(7, (i) {
      final day = filled[i];
      double value;
      switch (_selectedMetric) {
        case 'steps':
          value = (day['steps_pct'] as num?)?.toDouble() ?? 0;
          break;
        case 'workouts':
          value = (day['workout_done'] == true) ? 100.0 : 0.0;
          break;
        default: // calories
          value = (day['calorie_pct'] as num?)?.toDouble() ?? 0;
      }
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: value,
            gradient: const LinearGradient(
              colors: [Color(0xFFE0C800), Color(0xFFFFF176)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 14,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ],
      );
    });
  }

  // ── Personal Records ──
  Widget _buildPersonalRecords() {
    if (_personalRecords.isEmpty) {
      return _buildEmptyState(
          'No personal records yet.\nComplete workouts to track your bests!');
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: _personalRecords.asMap().entries.map((entry) {
          final rec = entry.value;
          final isLast = entry.key == _personalRecords.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: AppColors.primaryFixed,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        (rec['exercise_name'] ?? '').toString().toUpperCase(),
                        style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${rec['max_weight_kg'] ?? '--'} kg',
                      style: AppText.titleSm.copyWith(color: AppColors.primaryFixed),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: AppColors.outlineVariant.withValues(alpha: 0.2),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Goals List ──
  Widget _buildGoalsList() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGoalRow(Icons.local_fire_department, 'Daily Calories',
              '${_goals['daily_calories'] ?? 2000} kcal'),
          const Divider(color: AppColors.outlineVariant),
          _buildGoalRow(Icons.egg_alt_outlined, 'Daily Protein',
              '${_goals['daily_protein_g'] ?? 150} g'),
          const Divider(color: AppColors.outlineVariant),
          _buildGoalRow(Icons.directions_walk, 'Daily Steps',
              '${_goals['daily_steps'] ?? 10000}'),
          const Divider(color: AppColors.outlineVariant),
          _buildGoalRow(Icons.fitness_center, 'Weekly Workouts',
              '${_goals['weekly_workouts'] ?? 3}x'),
          const Divider(color: AppColors.outlineVariant),
          _buildGoalRow(Icons.monitor_weight_outlined, 'Target Weight',
              '${_goals['target_weight_kg'] ?? '--'} kg'),
        ],
      ),
    );
  }

  Widget _buildGoalRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryFixed, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: AppText.bodyMd),
          ),
          Text(
            value,
            style: AppText.titleSm.copyWith(
              color: AppColors.primaryFixed,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        message,
        style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showUpdateMeasurementsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _UpdateMeasurementsSheet(),
    ).then((_) => _loadData());
  }
}

// ────────────────── Update Measurements Bottom Sheet ──────────────────
class _UpdateMeasurementsSheet extends StatefulWidget {
  const _UpdateMeasurementsSheet();

  @override
  State<_UpdateMeasurementsSheet> createState() =>
      _UpdateMeasurementsSheetState();
}

class _UpdateMeasurementsSheetState extends State<_UpdateMeasurementsSheet> {
  final _service = MeasurementsService();
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _chestController = TextEditingController();
  final _armsController = TextEditingController();
  final _waistController = TextEditingController();
  final _thighsController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _chestController.dispose();
    _armsController.dispose();
    _waistController.dispose();
    _thighsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid weight'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await _service.saveMeasurement(
      weightKg: weight,
      bodyFatPct: double.tryParse(_bodyFatController.text),
      chestCm: double.tryParse(_chestController.text),
      armsCm: double.tryParse(_armsController.text),
      waistCm: double.tryParse(_waistController.text),
      thighsCm: double.tryParse(_thighsController.text),
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
        height: MediaQuery.of(context).size.height * 0.65,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('UPDATE MEASUREMENTS', style: AppText.headlineSm.copyWith(fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                'Log your body stats to track progress',
                style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              _buildInput('Weight (kg) *', _weightController, required: true),
              _buildInput('Body Fat %', _bodyFatController),
              _buildInput('Chest (cm)', _chestController),
              _buildInput('Arms (cm)', _armsController),
              _buildInput('Waist (cm)', _waistController),
              _buildInput('Thighs (cm)', _thighsController),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryFixed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2),
                        )
                      : Text(
                          'SAVE RECORD',
                          style: AppText.buttonPrimary.copyWith(color: Colors.black),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller,
      {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppText.bodyLg.copyWith(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant),
          filled: true,
          fillColor: AppColors.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryFixed, width: 1.5),
          ),
        ),
      ),
    );
  }
}
