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
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _HomeScreenCore(onNavigate: _onNavigate),
            const NutritionScreen(),
            const WorkoutScreen(),
            const ProfilePage(),
          ],
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.of(context)!.updateSteps,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.primaryFixed.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixText: 'steps',
            suffixStyle: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          FilledButton(
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryFixed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }

  // ── shimmer — mirrors actual layout skeleton ──
  Widget _buildShimmer() {
    return SafeArea(
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceContainerHigh,
        highlightColor: AppColors.surfaceContainerHighest,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header skeleton
              Row(
                children: [
                  _shimBox(48, width: 48, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimBox(12, width: 100, radius: 6),
                        const SizedBox(height: 6),
                        _shimBox(18, width: 160, radius: 6),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // main card skeleton
              _shimBox(260, radius: 22),
              const SizedBox(height: 12),
              // activity strip skeleton
              Row(
                children: [
                  Expanded(child: _shimBox(130, radius: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: _shimBox(130, radius: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: _shimBox(130, radius: 18)),
                ],
              ),
              const SizedBox(height: 24),
              // section header skeleton
              _shimBox(16, width: 120, radius: 6),
              const SizedBox(height: 12),
              // meals scroll skeleton
              SizedBox(
                height: 140,
                child: Row(
                  children: List.generate(
                    4,
                    (i) => Padding(
                      padding: EdgeInsets.only(right: i < 3 ? 14 : 0),
                      child: _shimBox(140, width: 88, radius: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _shimBox(16, width: 140, radius: 6),
              const SizedBox(height: 12),
              _shimBox(140, radius: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimBox(double h, {double? width, double radius = 12}) => Container(
    width: width ?? double.infinity,
    height: h,
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
        backgroundColor: Colors.transparent,
        body: _buildShimmer(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryFixed,
        displacement: 60,
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
                child: _FadeSlide(
                  ctrl: _pageCtrl,
                  delay: 0,
                  child: _GoalsBanner(onTap: () => widget.onNavigate(3)),
                ),
              ),

            // ── Calories + Macros card ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeSlide(
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
                  caloriesBurned: _caloriesBurned,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // ── Activity strip ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeSlide(
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

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── Today's meals ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeSlide(
                ctrl: _pageCtrl,
                delay: 280,
                child: _SectionHeader(
                  title: 'Today\'s Meals',
                  action: AppLocalizations.of(context)!.addFood,
                  onAction: () => widget.onNavigate(1),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: _FadeSlide(
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

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── Active program ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeSlide(
                ctrl: _pageCtrl,
                delay: 420,
                child: _SectionHeader(
                  title: AppLocalizations.of(context)!.yourProgram,
                  action: '',
                  onAction: null,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: _FadeSlide(
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

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // ── Last workout ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _FadeSlide(
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Goals banner  — warmer, punchier, dismissible feel
// ─────────────────────────────────────────────────────────────────────────────

class _GoalsBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _GoalsBanner({required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.withValues(alpha: 0.14),
                Colors.deepOrange.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.orangeAccent.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.orangeAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set your goals',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      AppLocalizations.of(context)!.completeProfile,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orangeAccent.withValues(alpha: 0.70),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.orangeAccent.withValues(alpha: 0.70),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Calories + Macros card  — cleaner arc section, better label hierarchy
// ─────────────────────────────────────────────────────────────────────────────

class _CaloriesMacrosCard extends StatelessWidget {
  final Animation<double> ringAnim, proteinAnim, carbsAnim, fatAnim;
  final double progress, totalCalories, goalCalories;
  final double totalProtein, goalProtein;
  final double totalCarbs, goalCarbs;
  final double totalFat, goalFat;
  final int caloriesBurned;
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
    required this.caloriesBurned,
  });

  @override
  Widget build(BuildContext context) {
    final caloriesLeft = (goalCalories - totalCalories).clamp(0, goalCalories);
    final isOverGoal = totalCalories > goalCalories;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF11111A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: ringColor.withValues(alpha: isOverGoal ? 0.35 : 0.10),
            width: isOverGoal ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: ringColor.withValues(alpha: 0.10),
              blurRadius: 36,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: Column(
              children: [
                // ── Header row ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: ringColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'TODAY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.35),
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        'Goal: ${goalCalories.toInt()} kcal',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.50),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Arc row ──
                SizedBox(
                  height: 196,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // radial glow
                      Positioned.fill(
                        child: TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: ringColor),
                          duration: const Duration(milliseconds: 600),
                          builder: (_, c, __) => DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0, 0.2),
                                radius: 0.85,
                                colors: [
                                  (c ?? AppColors.primaryFixed).withValues(
                                    alpha: 0.10,
                                  ),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // arc
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: ringAnim,
                          builder: (_, __) => TweenAnimationBuilder<Color?>(
                            tween: ColorTween(end: ringColor),
                            duration: const Duration(milliseconds: 500),
                            builder: (_, c, __) => CustomPaint(
                              painter: _SemiArcPainter(
                                progress: progress * ringAnim.value,
                                color: c ?? AppColors.primaryFixed,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // EATEN — left
                      Positioned(
                        left: 4,
                        bottom: 10,
                        child: AnimatedBuilder(
                          animation: ringAnim,
                          builder: (_, __) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(totalCalories * ringAnim.value).toInt()}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'EATEN',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.35),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // CENTER — calories left / over
                      Positioned(
                        bottom: 8,
                        child: AnimatedBuilder(
                          animation: ringAnim,
                          builder: (_, __) {
                            final displayVal = isOverGoal
                                ? (totalCalories - goalCalories).abs()
                                : caloriesLeft.toDouble();
                            return Column(
                              children: [
                                TweenAnimationBuilder<Color?>(
                                  tween: ColorTween(end: ringColor),
                                  duration: const Duration(milliseconds: 600),
                                  builder: (_, c, __) => Text(
                                    '${(displayVal * ringAnim.value).toInt()}',
                                    style: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                      color: isOverGoal
                                          ? (c ?? Colors.redAccent)
                                          : Colors.white,
                                      height: 1,
                                      letterSpacing: -2,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  isOverGoal ? 'OVER GOAL' : 'KCAL LEFT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isOverGoal
                                        ? ringColor.withValues(alpha: 0.80)
                                        : Colors.white.withValues(alpha: 0.35),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      // BURNED — right
                      Positioned(
                        right: 4,
                        bottom: 10,
                        child: AnimatedBuilder(
                          animation: ringAnim,
                          builder: (_, __) => Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${(caloriesBurned * ringAnim.value).toInt()}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'BURNED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.35),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Divider ──
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),

                const SizedBox(height: 20),

                // ── Macro row ──
                Row(
                  children: [
                    Expanded(
                      child: _MacroCol(
                        emoji: '🌾',
                        label: AppLocalizations.of(context)!.carbs,
                        color: const Color(0xFF5B8DEE),
                        current: totalCarbs,
                        goal: goalCarbs,
                        anim: carbsAnim,
                      ),
                    ),
                    _vertDivider(),
                    Expanded(
                      child: _MacroCol(
                        emoji: '🥩',
                        label: AppLocalizations.of(context)!.proteinGoal,
                        color: const Color(0xFFFF6B6B),
                        current: totalProtein,
                        goal: goalProtein,
                        anim: proteinAnim,
                      ),
                    ),
                    _vertDivider(),
                    Expanded(
                      child: _MacroCol(
                        emoji: '🫙',
                        label: AppLocalizations.of(context)!.fat,
                        color: const Color(0xFFFFD166),
                        current: totalFat,
                        goal: goalFat,
                        anim: fatAnim,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vertDivider() => Container(
    width: 1,
    height: 68,
    color: Colors.white.withValues(alpha: 0.06),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Macro column  — cleaner bars, over-goal indicator
// ─────────────────────────────────────────────────────────────────────────────

class _MacroCol extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final double current, goal;
  final Animation<double> anim;

  const _MacroCol({
    required this.emoji,
    required this.label,
    required this.color,
    required this.current,
    required this.goal,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    final prog = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final isOver = current > goal;
    final effectiveColor = isOver ? Colors.redAccent.shade100 : color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          AnimatedBuilder(
            animation: anim,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (prog * anim.value).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                color: effectiveColor,
              ),
            ),
          ),
          const SizedBox(height: 5),
          AnimatedBuilder(
            animation: anim,
            builder: (_, __) => RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${(current * anim.value).toInt()}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOver ? Colors.redAccent.shade100 : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: '/${goal.toInt()}g',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity strip — uniform height, better layout, clearer tap targets
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
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ActivityCard(
                emoji: '💧',
                value: '$waterGlasses',
                unit: AppLocalizations.of(context)!.ofGlasses,
                accentColor: const Color(0xFF4A9EFF),
                actionIcon: Icons.add_rounded,
                actionTooltip: 'Add water',
                onAction: onAddWater,
                bottom: _WaterDots(glasses: waterGlasses),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActivityCard(
                emoji: '👟',
                value: _formatSteps(stepsInt),
                unit: AppLocalizations.of(context)!.ofSteps,
                accentColor: const Color(0xFF4DC591),
                actionIcon: Icons.edit_rounded,
                actionTooltip: AppLocalizations.of(context)!.updateSteps,
                onAction: onEditSteps,
                bottom: _StepsBar(steps: stepsInt),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActivityCard(
                emoji: '🔥',
                value: '$caloriesBurned',
                unit: AppLocalizations.of(context)!.kcalBurned,
                accentColor: AppColors.primaryFixed,
                bottom: _BurnedGlow(color: AppColors.primaryFixed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) return '${(steps / 1000).toStringAsFixed(1)}k';
    return '$steps';
  }
}

/// Dots indicator for water glasses (8 total)
class _WaterDots extends StatelessWidget {
  final int glasses;
  const _WaterDots({required this.glasses});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 3,
    runSpacing: 3,
    children: List.generate(
      8,
      (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i < glasses
              ? const Color(0xFF4A9EFF)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
    ),
  );
}

/// Segmented bar for step progress toward 10k
class _StepsBar extends StatelessWidget {
  final int steps;
  const _StepsBar({required this.steps});

  @override
  Widget build(BuildContext context) {
    final prog = (steps / 10000).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: prog,
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.07),
            color: const Color(0xFF4DC591),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(prog * 100).toInt()}% of 10k',
          style: TextStyle(
            fontSize: 9,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Subtle ambient glow indicator for calories burned
class _BurnedGlow extends StatelessWidget {
  final Color color;
  const _BurnedGlow({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    height: 3,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(3),
      gradient: LinearGradient(
        colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.0)],
      ),
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  final String emoji, value, unit;
  final Color accentColor;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;
  final Widget? bottom;

  const _ActivityCard({
    required this.emoji,
    required this.value,
    required this.unit,
    required this.accentColor,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              if (onAction != null)
                _MiniIconBtn(
                  icon: actionIcon!,
                  color: accentColor,
                  tooltip: actionTooltip ?? '',
                  onTap: onAction!,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.onSurfaceVariant,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (bottom != null) ...[const SizedBox(height: 10), bottom!],
        ],
      ),
    );
  }
}

/// Compact icon button used in activity cards
class _MiniIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniIconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    tooltip: tooltip,
    child: Material(
      color: color.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, color: color, size: 14),
        ),
      ),
    ),
  );
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: AppText.titleMd.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            fontSize: 17,
          ),
        ),
        const Spacer(),
        if (action.isNotEmpty && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryFixed,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(44, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.add_rounded, size: 15),
              ],
            ),
          ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Meals scroll  — larger rings, clearer meal names, better empty slot feel
// ─────────────────────────────────────────────────────────────────────────────

class _MealsScroll extends StatelessWidget {
  final List<dynamic> logs;
  final VoidCallback onTap;
  const _MealsScroll({required this.logs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final meals = [
      ('breakfast', l10n.breakfast, '🍳', 600.0),
      ('lunch', l10n.lunch, '🥗', 700.0),
      ('dinner', l10n.dinner, '🍽', 700.0),
      ('snack', l10n.snack, '🥜', 300.0),
    ];

    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: meals.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final (type, label, emoji, targetKcal) = meals[i];
          final mLogs = logs.where((l) => l['meal_type'] == type).toList();
          final kcal = mLogs.fold(
            0.0,
            (s, l) => s + ((l['calories'] as num?) ?? 0),
          );
          final has = mLogs.isNotEmpty;
          final ringProg = (kcal / targetKcal).clamp(0.0, 1.0);

          return Semantics(
            button: true,
            label: '$label, ${kcal.toInt()} calories',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: SizedBox(
                  width: 92,
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // progress ring
                          SizedBox(
                            width: 84,
                            height: 84,
                            child: CustomPaint(
                              painter: _MealRingPainter(
                                progress: has ? ringProg : 0,
                                trackColor: Colors.white.withValues(
                                  alpha: 0.07,
                                ),
                                arcColor: has
                                    ? AppColors.primaryFixed
                                    : Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                          // emoji bg
                          Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: has
                                  ? AppColors.primaryFixed.withValues(
                                      alpha: 0.08,
                                    )
                                  : Colors.white.withValues(alpha: 0.04),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                          // add badge
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: has
                                    ? AppColors.primaryFixed
                                    : AppColors.surfaceContainerHighest,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                has ? Icons.check_rounded : Icons.add_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: has
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        has ? '${kcal.toInt()} cal' : '—',
                        style: TextStyle(
                          fontSize: 10,
                          color: has
                              ? AppColors.primaryFixed.withValues(alpha: 0.80)
                              : AppColors.onSurfaceVariant,
                          fontWeight: has ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
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
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primaryFixed.withValues(alpha: 0.18),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryFixed.withValues(alpha: 0.10),
                ),
                child: Icon(
                  Icons.restaurant_outlined,
                  color: AppColors.primaryFixed.withValues(alpha: 0.7),
                  size: 22,
                ),
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
                    const SizedBox(height: 3),
                    Text(
                      'Tap to log your first meal today',
                      style: AppText.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: AppColors.primaryFixed,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Program card  — week dots replaced with labeled chips, clearer progress
// ─────────────────────────────────────────────────────────────────────────────

class _ProgramCard extends StatelessWidget {
  final Map<String, dynamic>? activeProgram;
  final VoidCallback onTap;
  const _ProgramCard({required this.activeProgram, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (activeProgram == null) {
      return _EmptyCard(
        icon: '🎯',
        title: 'No active program',
        subtitle: 'Pick a training program to get started',
        child: _PrimaryBtn(
          label: AppLocalizations.of(context)!.browsePrograms,
          onTap: onTap,
        ),
      );
    }

    final prog = activeProgram!['training_programs'] as Map<String, dynamic>;
    final name = prog['name'] as String? ?? '';
    final level = (prog['level'] as String? ?? '').toUpperCase();
    final totalWeeks = (prog['duration_weeks'] as num?)?.toInt() ?? 12;
    final currentWeek = (activeProgram!['current_week'] as num?)?.toInt() ?? 1;
    final progressFraction = (currentWeek - 1) / totalWeeks;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryFixed.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // top row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.activeProgram2,
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.primaryFixed,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headlineSm.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryFixed.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primaryFixed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // progress bar + label
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressFraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: AppColors.primaryFixed,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Week $currentWeek of $totalWeeks',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(progressFraction * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryFixed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
      return _EmptyCard(
        icon: '🏋️',
        title: 'No workouts logged yet',
        subtitle: 'Log your first session to track progress',
        child: _OutlineBtn(
          label: AppLocalizations.of(context)!.logFirstWorkout,
          onTap: onTap,
        ),
      );
    }

    final name =
        lastWorkout!['session_name'] as String? ??
        AppLocalizations.of(context)!.navWorkout;
    final date = lastWorkout!['session_date'] as String? ?? '';
    final duration = (lastWorkout!['duration_min'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('💪', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
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
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: AppText.titleSm.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (date.isNotEmpty) ...[
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (duration > 0) ...[
                      Text(
                        '  ·  ',
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      ),
                      Icon(
                        Icons.timer_outlined,
                        size: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$duration min',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryFixed,
              side: BorderSide(
                color: AppColors.primaryFixed.withValues(alpha: 0.35),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(44, 36),
            ),
            child: Text(
              AppLocalizations.of(context)!.history,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared empty state card
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String icon, title, subtitle;
  final Widget child;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.titleSm.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
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
        minimumSize: const Size.fromHeight(46),
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
        side: BorderSide(color: AppColors.primaryFixed.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        minimumSize: const Size.fromHeight(46),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Semi-arc painter  (unchanged logic, small glow tweak)
// ─────────────────────────────────────────────────────────────────────────────

class _SemiArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _SemiArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const arcAngle = 3.9;
    const startAngle = (pi / 2) + (2 * pi - arcAngle) / 2;

    final center = Offset(size.width / 2, size.height * 0.84);
    final radius = size.height * 0.72;
    const strokeW = 14.0;

    // track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      arcAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.07),
    );

    if (progress > 0) {
      // soft outer glow
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcAngle * progress.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW + 14
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );

      // main arc with sweep gradient
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcAngle * progress.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [color.withValues(alpha: 0.55), color],
            startAngle: startAngle,
            endAngle: startAngle + arcAngle,
            transform: GradientRotation(startAngle),
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );

      // tip dot for emphasis
      final tipAngle = startAngle + arcAngle * progress.clamp(0, 1);
      final tipX = center.dx + radius * cos(tipAngle);
      final tipY = center.dy + radius * sin(tipAngle);
      canvas.drawCircle(Offset(tipX, tipY), 5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SemiArcPainter o) =>
      o.progress != progress || o.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Meal ring painter  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _MealRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color arcColor;
  const _MealRingPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const strokeW = 4.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..color = trackColor,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round
          ..color = arcColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MealRingPainter o) =>
      o.progress != progress || o.arcColor != arcColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// FadeSlide  — fixed: no CurvedAnimation leak on every rebuild
// ─────────────────────────────────────────────────────────────────────────────

class _FadeSlide extends StatefulWidget {
  final Widget child;
  final int delay;
  final AnimationController ctrl;

  const _FadeSlide({
    required this.child,
    required this.delay,
    required this.ctrl,
  });

  @override
  State<_FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<_FadeSlide> {
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final start = (widget.delay / 1800).clamp(0.0, 1.0);
    final end = ((widget.delay + 600) / 1800).clamp(0.0, 1.0);
    _anim = CurvedAnimation(
      parent: widget.ctrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(
        opacity: _anim.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - _anim.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
