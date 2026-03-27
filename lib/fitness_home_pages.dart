import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:coregym2/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import 'profile.dart';
import 'screens/nutrition_screen.dart';
import 'screens/workout_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';
import 'services/supabase_client.dart';
import 'widgets/core_gym_navbar.dart';
import 'widgets/home_header.dart';
import 'widgets/app_background.dart';
import 'widgets/enhanced_charts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Root scaffold
// ─────────────────────────────────────────────────────────────────────────────

class FitnessHomePage extends StatefulWidget {
  const FitnessHomePage({super.key});

  @override
  State<FitnessHomePage> createState() => _FitnessHomePageState();
}

class _FitnessHomePageState extends State<FitnessHomePage> {
  int _currentIndex = 0;

  void _onNavigate(int index) {
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.surface,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeScreenCore(onNavigate: _onNavigate),
          const NutritionScreen(),
          const WorkoutScreen(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: CoreGymNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavigate,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home screen
// ─────────────────────────────────────────────────────────────────────────────

class _HomeScreenCore extends StatefulWidget {
  final Function(int) onNavigate;
  const _HomeScreenCore({required this.onNavigate});

  @override
  State<_HomeScreenCore> createState() => _HomeScreenCoreState();
}

class _HomeScreenCoreState extends State<_HomeScreenCore>
    with TickerProviderStateMixin {
  // ── state ──
  bool _isLoading = true;
  bool _noGoalsSet = false;

  Map<String, dynamic> _profile = {};
  Map<String, dynamic>? _goals;
  List<dynamic> _nutritionLogs = [];
  Map<String, dynamic>? _activeProgram;
  Map<String, dynamic>? _lastWorkout;
  Map<String, dynamic>? _dailySummary;

  double _totalCalories = 0, _goalCalories = 2000;
  double _totalProtein = 0, _goalProtein = 150;
  double _totalCarbs = 0, _goalCarbs = 250;
  double _totalFat = 0, _goalFat = 65;
  int _waterGlasses = 0;
  int _stepsInt = 0;
  int _caloriesBurned = 0;

  // ── animation controllers ──
  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;
  late AnimationController _macroCtrl;
  late Animation<double> _proteinAnim, _carbsAnim, _fatAnim;
  late AnimationController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);

    _macroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _proteinAnim = CurvedAnimation(
      parent: _macroCtrl,
      curve: const Interval(0.0, 0.70, curve: Curves.easeOutCubic),
    );
    _carbsAnim = CurvedAnimation(
      parent: _macroCtrl,
      curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic),
    );
    _fatAnim = CurvedAnimation(
      parent: _macroCtrl,
      curve: const Interval(0.30, 1.00, curve: Curves.easeOutCubic),
    );

    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _loadData();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _macroCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── helpers ──
  double get _calorieProgress => (_goalCalories > 0)
      ? (_totalCalories / _goalCalories).clamp(0.0, 1.0)
      : 0;

  Color get _ringColor {
    if (_calorieProgress >= 1.0) return Colors.redAccent;
    if (_calorieProgress > 0.8) return Colors.orangeAccent;
    return AppColors.primaryFixed;
  }

  // ── data ──
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _ringCtrl.reset();
    _macroCtrl.reset();
    _pageCtrl.reset();

    try {
      if (currentUserId == null) return;
      final today = DateTime.now().toIso8601String().split('T')[0];

      final results = await Future.wait([
        supabase.from('profiles').select().eq('id', currentUserId!).single(),
        supabase
            .from('user_goals')
            .select()
            .eq('user_id', currentUserId!)
            .maybeSingle(),
        supabase
            .from('nutrition_logs')
            .select()
            .eq('user_id', currentUserId!)
            .eq('logged_date', today)
            .order('logged_at'),
        supabase
            .from('workout_sessions')
            .select()
            .eq('user_id', currentUserId!)
            .order('started_at', ascending: false)
            .limit(1),
        supabase
            .from('user_active_program')
            .select(
              '*, training_programs(name, name_ar, level, duration_weeks)',
            )
            .eq('user_id', currentUserId!)
            .maybeSingle(),
        supabase
            .from('daily_summary')
            .select()
            .eq('user_id', currentUserId!)
            .eq('summary_date', today)
            .maybeSingle(),
      ]);

      if (!mounted) return;

      _profile = results[0] as Map<String, dynamic>;
      _goals = results[1] as Map<String, dynamic>?;
      _nutritionLogs = results[2] as List<dynamic>;
      final workouts = results[3] as List<dynamic>;
      _lastWorkout = workouts.isNotEmpty
          ? workouts.first as Map<String, dynamic>
          : null;
      _activeProgram = results[4] as Map<String, dynamic>?;
      _dailySummary = results[5] as Map<String, dynamic>?;
      _noGoalsSet = _goals == null;

      _totalCalories = _nutritionLogs.fold(
        0.0,
        (s, l) => s + ((l['calories'] as num?) ?? 0),
      );
      _totalProtein = _nutritionLogs.fold(
        0.0,
        (s, l) => s + ((l['protein_g'] as num?) ?? 0),
      );
      _totalCarbs = _nutritionLogs.fold(
        0.0,
        (s, l) => s + ((l['carbs_g'] as num?) ?? 0),
      );
      _totalFat = _nutritionLogs.fold(
        0.0,
        (s, l) => s + ((l['fat_g'] as num?) ?? 0),
      );

      if (_goals != null) {
        _goalCalories = (_goals!['daily_calories'] as num?)?.toDouble() ?? 2000;
        _goalProtein = (_goals!['daily_protein_g'] as num?)?.toDouble() ?? 150;
        _goalCarbs = (_goals!['daily_carbs_g'] as num?)?.toDouble() ?? 250;
        _goalFat = (_goals!['daily_fat_g'] as num?)?.toDouble() ?? 65;
      }

      _waterGlasses = _dailySummary?['water_ml'] != null
          ? (_dailySummary!['water_ml'] as num) ~/ 250
          : 0;
      _stepsInt = (_dailySummary?['steps'] as num?)?.toInt() ?? 0;
      _caloriesBurned =
          (_dailySummary?['calories_burned'] as num?)?.toInt() ?? 0;

      setState(() => _isLoading = false);
      _ringCtrl.forward();
      _macroCtrl.forward();
      _pageCtrl.forward();
    } catch (e) {
      debugPrint('Home load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateWater() async {
    if (currentUserId == null) return;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final current = (_dailySummary?['water_ml'] as num?)?.toInt() ?? 0;
    try {
      final res = await supabase
          .from('daily_summary')
          .upsert({
            'user_id': currentUserId,
            'summary_date': today,
            'water_ml': current + 250,
            'steps': _stepsInt,
          }, onConflict: 'user_id,summary_date')
          .select()
          .single();
      setState(() {
        _dailySummary = res;
        _waterGlasses = (res['water_ml'] as num) ~/ 250;
      });
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Water update error: $e');
    }
  }

  Future<void> _editSteps() async {
    final ctrl = TextEditingController(text: _stepsInt.toString());
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context)!.updateSteps,
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            suffixText: 'steps',
            suffixStyle: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(c);
              final today = DateTime.now().toIso8601String().split('T')[0];
              final newSteps = int.tryParse(ctrl.text) ?? _stepsInt;
              final res = await supabase
                  .from('daily_summary')
                  .upsert({
                    'user_id': currentUserId,
                    'summary_date': today,
                    'water_ml': _waterGlasses * 250,
                    'steps': newSteps,
                  }, onConflict: 'user_id,summary_date')
                  .select()
                  .single();
              setState(() {
                _dailySummary = res;
                _stepsInt = newSteps;
              });
            },
            child: Text(
              AppLocalizations.of(context)!.save,
              style: TextStyle(color: AppColors.primaryFixed),
            ),
          ),
        ],
      ),
    );
  }

  // ── shimmer ──
  Widget _buildShimmer() {
    return SafeArea(
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceContainerHigh,
        highlightColor: AppColors.surfaceContainerHighest,
        child: Column(
          children: [
            const SizedBox(height: 20),
            _shimBox(70, radius: 0),
            const SizedBox(height: 20),
            _shimBox(180, radius: 20),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 20),
                Expanded(child: _shimBox(90, radius: 16)),
                const SizedBox(width: 10),
                Expanded(child: _shimBox(90, radius: 16)),
                const SizedBox(width: 10),
                Expanded(child: _shimBox(90, radius: 16)),
                const SizedBox(width: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimBox(double h, {double radius = 12}) => Container(
    width: double.infinity,
    height: h,
    margin: EdgeInsets.fromLTRB(
      radius == 0 ? 20 : 0,
      0,
      radius == 0 ? 20 : 0,
      0,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );

  // ── build ──
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: AppBackground(
          child: _buildShimmer(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AppBackground(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primaryFixed,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 20),
                  child: HomeHeader(
                    userName: _profile['name'] ?? 'User',
                    avatarUrl: _profile['avatar_url'] ?? '',
                  ),
                ),
              ),
            ),

            // ── Goals banner ────────────────────────────────────────────────
            if (_noGoalsSet)
              SliverToBoxAdapter(
                child: _FadeIn(
                  ctrl: _pageCtrl,
                  delay: 0,
                  child: _GoalsBanner(onTap: () => widget.onNavigate(3)),
                ),
              ),

            // ── Calories + Macros card ───────────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeIn(
                ctrl: _pageCtrl,
                delay: 80,
                child: _CaloriesMacrosCard(
                  ringAnim: _ringAnim,
                  proteinAnim: _proteinAnim,
                  carbsAnim: _carbsAnim,
                  fatAnim: _fatAnim,
                  progress: _calorieProgress,
                  ringColor: _ringColor,
                  totalCalories: _totalCalories,
                  goalCalories: _goalCalories,
                  totalProtein: _totalProtein,
                  goalProtein: _goalProtein,
                  totalCarbs: _totalCarbs,
                  goalCarbs: _goalCarbs,
                  totalFat: _totalFat,
                  goalFat: _goalFat,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Activity strip ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeIn(
                ctrl: _pageCtrl,
                delay: 180,
                child: _ActivityStrip(
                  waterGlasses: _waterGlasses,
                  stepsInt: _stepsInt,
                  caloriesBurned: _caloriesBurned,
                  onAddWater: _updateWater,
                  onEditSteps: _editSteps,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Today's meals ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeIn(
                ctrl: _pageCtrl,
                delay: 280,
                child: _SectionHeader(
                  title: 'Today\'s Meals',
                  action: AppLocalizations.of(context)!.addFood,
                  onAction: () => widget.onNavigate(1),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(
              child: _FadeIn(
                ctrl: _pageCtrl,
                delay: 320,
                child: _nutritionLogs.isEmpty
                    ? _EmptyMeals(onTap: () => widget.onNavigate(1))
                    : _MealsScroll(
                        logs: _nutritionLogs,
                        onTap: () => widget.onNavigate(1),
                      ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Active program ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeIn(
                ctrl: _pageCtrl,
                delay: 420,
                child: _SectionHeader(
                  title: AppLocalizations.of(context)!.yourProgram,
                  action: '',
                  onAction: null,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(
              child: _FadeIn(
                ctrl: _pageCtrl,
                delay: 460,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ProgramCard(
                    activeProgram: _activeProgram,
                    onTap: () => widget.onNavigate(2),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Last workout ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeIn(
                ctrl: _pageCtrl,
                delay: 540,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _LastWorkoutCard(
                    lastWorkout: _lastWorkout,
                    onTap: () => widget.onNavigate(2),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    ),
  );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Goals banner
// ─────────────────────────────────────────────────────────────────────────────

class _GoalsBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _GoalsBanner({required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orangeAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.completeProfile,
              style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              AppLocalizations.of(context)!.fix,
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Calories + Macros card  (matches screenshot layout exactly)
// ─────────────────────────────────────────────────────────────────────────────

class _CaloriesMacrosCard extends StatelessWidget {
  final Animation<double> ringAnim, proteinAnim, carbsAnim, fatAnim;
  final double progress, totalCalories, goalCalories;
  final double totalProtein, goalProtein;
  final double totalCarbs, goalCarbs;
  final double totalFat, goalFat;
  final Color ringColor;

  const _CaloriesMacrosCard({
    required this.ringAnim,
    required this.proteinAnim,
    required this.carbsAnim,
    required this.fatAnim,
    required this.progress,
    required this.ringColor,
    required this.totalCalories,
    required this.goalCalories,
    required this.totalProtein,
    required this.goalProtein,
    required this.totalCarbs,
    required this.goalCarbs,
    required this.totalFat,
    required this.goalFat,
  });

  @override
  Widget build(BuildContext context) {
    // Gradient colors based on progress
    final gradientColors = progress >= 1.0
        ? [const Color(0xFFFF5252), const Color(0xFFFF8A65)]
        : progress > 0.85
            ? [const Color(0xFFFFAB40), const Color(0xFFFFD54F)]
            : [AppColors.primaryFixed, const Color(0xFFA8E600)];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.08),
              blurRadius: 30,
              spreadRadius: -10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row
            Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.caloriesToday,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Badge
                AnimatedBuilder(
                  animation: ringAnim,
                  builder: (_, __) => _Badge(
                    label:
                        '${(totalCalories * ringAnim.value).toInt()} / ${goalCalories.toInt()} kcal',
                    color: ringColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Ring + Macros row  (screenshot layout)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ring with glow
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    children: [
                      AnimatedBuilder(
                        animation: ringAnim,
                        builder: (_, __) => TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: ringColor),
                          duration: const Duration(milliseconds: 500),
                          builder: (_, c, __) => CustomPaint(
                            size: const Size(130, 130),
                            painter: _RingPainter(
                              progress: progress * ringAnim.value,
                              color: c ?? AppColors.primaryFixed,
                              showGlow: true,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: ringAnim,
                              builder: (_, __) => Text(
                                (totalCalories * ringAnim.value)
                                    .toInt()
                                    .toString(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ),
                            Text(
                              AppLocalizations.of(context)!.kcal,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 1),
                            AnimatedBuilder(
                              animation: ringAnim,
                              builder: (_, __) => Text(
                                'of ${goalCalories.toInt()}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: ringColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Macros column — matches screenshot
                Expanded(
                  child: Column(
                    children: [
                      _MacroRow(
                        label: AppLocalizations.of(context)!.proteinGoal,
                        color: Colors.redAccent,
                        current: totalProtein,
                        goal: goalProtein,
                        anim: proteinAnim,
                      ),
                      const SizedBox(height: 12),
                      _MacroRow(
                        label: AppLocalizations.of(context)!.carbs,
                        color: Colors.blueAccent,
                        current: totalCarbs,
                        goal: goalCarbs,
                        anim: carbsAnim,
                      ),
                      const SizedBox(height: 12),
                      _MacroRow(
                        label: AppLocalizations.of(context)!.fat,
                        color: Colors.orangeAccent,
                        current: totalFat,
                        goal: goalFat,
                        anim: fatAnim,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3), width: 0.8),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
    ),
  );
}

class _MacroRow extends StatelessWidget {
  final String label;
  final Color color;
  final double current, goal;
  final Animation<double> anim;

  const _MacroRow({
    required this.label,
    required this.color,
    required this.current,
    required this.goal,
    required this.anim,
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
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.white70)),
            const Spacer(),
            AnimatedBuilder(
              animation: anim,
              builder: (_, __) => Text(
                '${(current * anim.value).toInt()}/${goal.toInt()}g',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        AnimatedBuilder(
          animation: anim,
          builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (prog * anim.value).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.08),
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity strip  (Water / Steps / Burned)
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityStrip extends StatelessWidget {
  final int waterGlasses, stepsInt, caloriesBurned;
  final VoidCallback onAddWater, onEditSteps;

  const _ActivityStrip({
    required this.waterGlasses,
    required this.stepsInt,
    required this.caloriesBurned,
    required this.onAddWater,
    required this.onEditSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Water
          Expanded(
            child: _ActivityCard(
              emoji: '💧',
              value: '$waterGlasses',
              unit: AppLocalizations.of(context)!.ofGlasses,
              accentColor: const Color(0xFF4A9EFF),
              actionIcon: Icons.add_rounded,
              onAction: onAddWater,
              bottom: Wrap(
                spacing: 2,
                children: List.generate(
                  8,
                  (i) => Icon(
                    i < waterGlasses
                        ? Icons.water_drop_rounded
                        : Icons.water_drop_outlined,
                    size: 12,
                    color: i < waterGlasses
                        ? const Color(0xFF4A9EFF)
                        : Colors.white.withOpacity(0.12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Steps
          Expanded(
            child: _ActivityCard(
              emoji: '👟',
              value: '$stepsInt',
              unit: AppLocalizations.of(context)!.ofSteps,
              accentColor: const Color(0xFF4DC591),
              actionIcon: Icons.edit_rounded,
              onAction: onEditSteps,
              bottom: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (stepsInt / 10000).clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: Colors.white.withOpacity(0.07),
                  color: const Color(0xFF4DC591),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Burned
          Expanded(
            child: _ActivityCard(
              emoji: '🔥',
              value: '$caloriesBurned',
              unit: AppLocalizations.of(context)!.kcalBurned,
              accentColor: AppColors.primaryFixed,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String emoji, value, unit;
  final Color accentColor;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Widget? bottom;

  const _ActivityCard({
    required this.emoji,
    required this.value,
    required this.unit,
    required this.accentColor,
    this.actionIcon,
    this.onAction,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (bottom != null) ...[const SizedBox(height: 6), bottom!],
          if (onAction != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onAction,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(actionIcon, color: accentColor, size: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title, action;
  final VoidCallback? onAction;
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        Text(
          title,
          style: AppText.titleMd.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        if (action.isNotEmpty && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primaryFixed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Meals scroll  (matches screenshot card style)
// ─────────────────────────────────────────────────────────────────────────────

class _MealsScroll extends StatelessWidget {
  final List<dynamic> logs;
  final VoidCallback onTap;
  const _MealsScroll({required this.logs, required this.onTap});

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
  static const _emojis = ['🍳', '🥗', '🍽', '🥜'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final meals = [
      ('breakfast', l10n.breakfast, '🍳'),
      ('lunch', l10n.lunch, '🥗'),
      ('dinner', l10n.dinner, '🍽'),
      ('snack', l10n.snack, '🥜'),
    ];
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: meals.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (type, label, emoji) = meals[i];
          final mLogs = logs.where((l) => l['meal_type'] == type).toList();
          final kcal = mLogs.fold(
            0.0,
            (s, l) => s + ((l['calories'] as num?) ?? 0),
          );
          final has = mLogs.isNotEmpty;
          return GestureDetector(
            onTap: onTap,
            child: Container(
              width: 130,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: has
                    ? AppColors.primaryFixed.withOpacity(0.07)
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: has
                      ? AppColors.primaryFixed.withOpacity(0.28)
                      : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  const Spacer(),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    has ? '${kcal.toInt()} kcal' : '—',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: has
                          ? AppColors.primaryFixed
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                  Text(
                    has
                        ? '${mLogs.length} item${mLogs.length > 1 ? 's' : ''}'
                        : AppLocalizations.of(context)!.notLogged,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.onSurfaceVariant.withOpacity(0.6),
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
}

class _EmptyMeals extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyMeals({required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primaryFixed.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.restaurant_outlined,
              color: AppColors.primaryFixed.withOpacity(0.5),
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.noMealsYet,
                    style: AppText.titleSm.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to log your first meal today',
                    style: AppText.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.primaryFixed),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Program card  (matches screenshot)
// ─────────────────────────────────────────────────────────────────────────────

class _ProgramCard extends StatelessWidget {
  final Map<String, dynamic>? activeProgram;
  final VoidCallback onTap;
  const _ProgramCard({required this.activeProgram, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (activeProgram == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎯 No active program',
              style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _PrimaryBtn(label: AppLocalizations.of(context)!.browsePrograms, onTap: onTap),
          ],
        ),
      );
    }

    final prog = activeProgram!['training_programs'] as Map<String, dynamic>;
    final name = prog['name'] as String? ?? '';
    final level = (prog['level'] as String? ?? '').toUpperCase();
    final totalWeeks = (prog['duration_weeks'] as num?)?.toInt() ?? 12;
    final currentWeek = (activeProgram!['current_week'] as num?)?.toInt() ?? 1;
    final filled = ((currentWeek - 1) / totalWeeks * 12).round().clamp(0, 12);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryFixed.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.activeProgram2,
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.primaryFixed,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    style: AppText.headlineSm.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryFixed.withOpacity(0.25),
                  ),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primaryFixed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Week dots
          Row(
            children: List.generate(
              12,
              (i) => Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsetsDirectional.only(end: i < 11 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: i < filled
                        ? AppColors.primaryFixed
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Week $currentWeek of $totalWeeks',
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _PrimaryBtn(label: 'Start Today\'s Workout', onTap: onTap),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Last workout card
// ─────────────────────────────────────────────────────────────────────────────

class _LastWorkoutCard extends StatelessWidget {
  final Map<String, dynamic>? lastWorkout;
  final VoidCallback onTap;
  const _LastWorkoutCard({required this.lastWorkout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (lastWorkout == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏋️ No workouts logged yet',
              style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _OutlineBtn(label: AppLocalizations.of(context)!.logFirstWorkout, onTap: onTap),
          ],
        ),
      );
    }

    final name = lastWorkout!['session_name'] as String? ?? AppLocalizations.of(context)!.navWorkout;
    final date = lastWorkout!['session_date'] as String? ?? '';
    final duration = (lastWorkout!['duration_min'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LAST WORKOUT',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$date${duration > 0 ? '  ·  $duration min' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primaryFixed.withOpacity(0.4),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AppLocalizations.of(context)!.history,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryFixed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Buttons
// ─────────────────────────────────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryFixed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        elevation: 0,
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryFixed,
        side: BorderSide(color: AppColors.primaryFixed.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Ring painter (using enhanced version from enhanced_charts.dart)
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool showGlow;

  const _RingPainter({
    required this.progress,
    required this.color,
    this.showGlow = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final strokeWidth = 14.0;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white.withOpacity(0.07),
    );

    // Glow effect
    if (showGlow && progress > 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 8
          ..color = color.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Arc with gradient-like effect
    if (progress > 0) {
      // Create a gradient effect by drawing multiple arcs
      final gradientColors = [
        color,
        color.withOpacity(0.8),
      ];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: gradientColors,
            startAngle: -pi / 2,
            endAngle: -pi / 2 + 2 * pi * progress.clamp(0.0, 1.0),
            transform: GradientRotation(-pi / 2),
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );

      // End cap highlight
      if (progress > 0.02) {
        final endAngle = -pi / 2 + 2 * pi * progress.clamp(0.0, 1.0);
        final endX = center.dx + radius * cos(endAngle);
        final endY = center.dy + radius * sin(endAngle);

        canvas.drawCircle(
          Offset(endX, endY),
          strokeWidth / 3,
          Paint()
            ..color = Colors.white.withOpacity(0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) =>
      o.progress != progress || o.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fade + slide-in animation wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _FadeIn extends StatelessWidget {
  final Widget child;
  final int delay;
  final AnimationController ctrl;

  const _FadeIn({required this.child, required this.delay, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final start = (delay / 1800).clamp(0.0, 1.0);
    final end = ((delay + 600) / 1800).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: ctrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - anim.value)),
          child: child,
        ),
      ),
    );
  }
}
