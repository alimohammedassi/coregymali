import 'dart:ui';
import 'package:coregym2/profile.dart';
import 'package:coregym2/progrems.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'services/stats_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';

void main() {
  runApp(const FitnessApp());
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness App',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Inter'),
      home: const FitnessHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// **FitnessHomePage - Main Fitness Home Page**
class FitnessHomePage extends StatefulWidget {
  const FitnessHomePage({super.key});

  @override
  State<FitnessHomePage> createState() => _FitnessHomePageState();
}

class _FitnessHomePageState extends State<FitnessHomePage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _selectedNavIndex = 0;

  final _statsService = StatsService();
  Map<String,dynamic> _summary = {};
  Map<String,dynamic> _goals = {};
  List<Map<String,dynamic>> _weeklyProgress = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _statsService.getTodaySummary(),
      _statsService.getGoals(),
      _statsService.getWeeklyProgress(),
    ]);
    if (mounted) {
      setState(() {
        _summary = results[0] as Map<String,dynamic>;
        _goals   = results[1] as Map<String,dynamic>;
        _weeklyProgress = List<Map<String,dynamic>>.from(results[2] as List);
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _navigateToMuscleTraining(String muscleGroup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MuscleTrainingPage(muscleGroup: muscleGroup),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Background glow orb top-right
          Positioned(
            top: -120,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryFixed.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Background glow orb bottom-left
          Positioned(
            bottom: -60,
            left: -60,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _loading 
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 32),
                          _buildStatsOverview(),
                          const SizedBox(height: 32),
                          _buildCaloriesCard(),
                          const SizedBox(height: 32),
                          _buildFeaturedPlans(),
                          const SizedBox(height: 32),
                          _buildWorkoutPrograms(),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // ────────────────── Header ──────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FRIDAY, MAY 20',
                style: AppText.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Good Morning', style: AppText.headlineLg),
                  const SizedBox(width: 12),
                  const Text('🔥', style: TextStyle(fontSize: 28)),
                ],
              ),
            ],
          ),
          // Notification bell — glass circle
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.glass1,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.notifications_outlined,
                        color: AppColors.onSurface,
                        size: 24,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 14,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryFixed.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────── Stats Overview ──────────────────
  Widget _buildStatsOverview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.glass1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DAILY OVERVIEW',
                    style: AppText.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 3,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+18%',
                      style: AppText.labelMd.copyWith(
                        color: AppColors.primaryFixed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _buildStatItem('${_summary['calories_consumed'] ?? 0}', 'CALORIES', Icons.local_fire_department),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: AppColors.outlineVariant.withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: _buildStatItem('${((_summary['steps'] ?? 0) / 1000).toStringAsFixed(1)}k', 'STEPS', Icons.directions_walk),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: AppColors.outlineVariant.withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: _buildStatItem('${_summary['active_minutes'] ?? 0}m', 'ACTIVE', Icons.timer),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.primaryFixed, size: 22),
        const SizedBox(height: 8),
        Text(value, style: AppText.metricMd.copyWith(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppText.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ────────────────── Calories Card ──────────────────
  Widget _buildCaloriesCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.glass1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryFixed.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('WEEKLY ACTIVITY', style: AppText.titleSm.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                  )),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+12%',
                      style: AppText.labelMd.copyWith(
                        color: AppColors.primaryFixed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(height: 220, child: _buildCaloriesChart()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaloriesChart() {
    return BarChart(
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
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
                if (value.toInt() < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      days[value.toInt()],
                      style: AppText.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 1,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: _generateBarGroups(),
        backgroundColor: Colors.transparent,
      ),
    );
  }

  List<BarChartGroupData> _generateBarGroups() {
    final days = List.generate(7, (i) {
      if (i < _weeklyProgress.length) {
        return _weeklyProgress[i];
      }
      return {'calorie_pct': 0, 'steps_pct': 0};
    });

    return List.generate(7, (index) {
      final day = days[index];
      return BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: (day['calorie_pct'] as num? ?? 0).toDouble(),
            gradient: const LinearGradient(
              colors: [Color(0xFF00D4AA), Color(0xFF00B894)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 12,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          BarChartRodData(
            toY: (day['steps_pct'] as num? ?? 0).toDouble(),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                const Color(0xFFA29BFE).withValues(alpha: 0.3),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 12,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ],
      );
    });
  }

  // ────────────────── Featured Plans ──────────────────
  Widget _buildFeaturedPlans() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('FEATURED PLANS', style: AppText.headlineSm),
            TextButton(
              onPressed: () => debugPrint('View all plans tapped'),
              child: Text(
                'VIEW ALL',
                style: AppText.labelMd.copyWith(
                  color: AppColors.primaryFixed,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 220,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _buildFeaturedPlanCard(
                'Lower Body Workout',
                '15 exercises',
                'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
                AppColors.chestGradient,
                'legs',
              ),
              const SizedBox(width: 16),
              _buildFeaturedPlanCard(
                'Upper Body Strength',
                '12 exercises',
                'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400',
                AppColors.armsGradient,
                'chest',
              ),
              const SizedBox(width: 16),
              _buildFeaturedPlanCard(
                'Core Power',
                '10 exercises',
                'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
                AppColors.legsGradient,
                'core',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedPlanCard(
    String title,
    String subtitle,
    String imageUrl,
    Gradient gradient,
    String muscleGroup,
  ) {
    return GestureDetector(
      onTap: () => _navigateToMuscleTraining(muscleGroup),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                imageUrl,
                width: 280,
                height: 220,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  return progress == null
                      ? child
                      : Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryFixed,
                            strokeWidth: 2,
                          ),
                        );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 280,
                    height: 220,
                    color: AppColors.surfaceContainerHigh,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: AppColors.outline,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
              // Dark overlay gradient
              Container(
                width: 280,
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
              // Top label
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.glass2,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    subtitle.toUpperCase(),
                    style: AppText.labelSm.copyWith(
                      color: AppColors.onSurface,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: AppText.headlineSm.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryFixed.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        'START NOW',
                        style: AppText.buttonPrimary.copyWith(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────── Workout Programs Grid ──────────────────
  Widget _buildWorkoutPrograms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WORKOUT PROGRAMS', style: AppText.headlineSm),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildWorkoutProgramCard(
              'Chest',
              'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400',
              AppColors.chestGradient,
              Icons.fitness_center,
            ),
            _buildWorkoutProgramCard(
              'Arms',
              'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400',
              AppColors.armsGradient,
              Icons.sports_gymnastics,
            ),
            _buildWorkoutProgramCard(
              'Legs',
              'https://images.unsplash.com/photo-1434682772747-f16d3ea162c3?w=400',
              AppColors.legsGradient,
              Icons.directions_run,
            ),
            _buildWorkoutProgramCard(
              'Core',
              'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
              AppColors.coreGradient,
              Icons.self_improvement,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkoutProgramCard(
    String title,
    String imageUrl,
    Gradient gradient,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () => _navigateToMuscleTraining(title.toLowerCase()),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  return progress == null
                      ? child
                      : Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryFixed,
                            strokeWidth: 2,
                          ),
                        );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.surfaceContainerHigh,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: AppColors.outline,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              // Dark overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              // Icon badge top-right
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.glass2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Icon(icon, color: AppColors.onSurface, size: 18),
                ),
              ),
              // Title bottom-left
              Positioned(
                bottom: 14,
                left: 14,
                child: Text(
                  title.toUpperCase(),
                  style: AppText.headlineSm.copyWith(
                    fontSize: 18,
                  ),
                ),
              ),
              // Ink overlay
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    splashColor: AppColors.primaryFixed.withValues(alpha: 0.1),
                    highlightColor: AppColors.primaryFixed.withValues(alpha: 0.05),
                    onTap: () => _navigateToMuscleTraining(title.toLowerCase()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────── Bottom Navigation ──────────────────
  Widget _buildBottomNavigation() {
    return Container(
      height: 80,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.glass2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(Icons.analytics_outlined, 'STATS', 0, onTap: () {}),
                _buildNavItem(Icons.home_rounded, 'HOME', 1, onTap: () {}),
                _buildNavItem(
                  Icons.person_rounded,
                  'PROFILE',
                  2,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfilePage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index, {
    required VoidCallback onTap,
  }) {
    final bool isSelected = _selectedNavIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedNavIndex = index;
            });
            onTap();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected
                      ? AppColors.primaryFixed.withValues(alpha: 0.1)
                      : Colors.transparent,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppColors.primaryFixed : AppColors.outline,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppText.labelSm.copyWith(
                  color: isSelected ? AppColors.primaryFixed : AppColors.outline,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 1,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
