import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:coregym2/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'profile.dart';
import 'screens/nutrition_screen.dart';
import 'screens/workout_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';
import 'services/supabase_client.dart';
import 'widgets/home_header.dart';
import 'widgets/app_background.dart';
import 'features/coach/presentation/screens/coach_marketplace_screen.dart';
import 'features/coach/presentation/screens/coach_dashboard_screen.dart';
import 'features/coach/presentation/providers/coach_providers.dart';
import 'features/coach/presentation/providers/subscription_providers.dart';
import 'features/coach/presentation/providers/coach_dashboard_providers.dart';
import 'providers/profile_provider.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
// Inspired by: Nike Training Club, Whoop, Strava premium dark aesthetic
const _kGold = Color(0xFFC9A84C);
const _kGoldDim = Color(0xFF8A6B2E);
const _kSurface1 = Color(0xFF0E0E12);
const _kSurface2 = Color(0xFF16161D);
const _kSurface3 = Color(0xFF1E1E28);
const _kBorderSubtle = Color(0xFF2A2A35);
const _kTextPrimary = Colors.white;
const _kTextSecondary = Color(0xFF8B8B9A);
const _kTextTertiary = Color(0xFF55555F);
const _kBlue = Color(0xFF4A9EFF);
const _kGreen = Color(0xFF34D399);
const _kOrange = Color(0xFFF97316);
const _kRed = Color(0xFFEF4444);

// ─────────────────────────────────────────────────────────────────────────────
// Root scaffold — role-aware (unchanged logic)
// ─────────────────────────────────────────────────────────────────────────────

class FitnessHomePage extends StatefulWidget {
  const FitnessHomePage({super.key});

  @override
  State<FitnessHomePage> createState() => _FitnessHomePageState();
}

class _FitnessHomePageState extends State<FitnessHomePage> {
  int _currentIndex = 0;

  final _clientTabs = const [
    TabInfo(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    TabInfo(
      icon: Icons.restaurant_outlined,
      activeIcon: Icons.restaurant_rounded,
      label: 'Nutrition',
    ),
    TabInfo(
      icon: Icons.fitness_center_outlined,
      activeIcon: Icons.fitness_center,
      label: 'Workout',
    ),
    TabInfo(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Coaches',
    ),
    TabInfo(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  final _coachTabs = const [
    TabInfo(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    TabInfo(
      icon: Icons.restaurant_outlined,
      activeIcon: Icons.restaurant_rounded,
      label: 'Nutrition',
    ),
    TabInfo(
      icon: Icons.fitness_center_outlined,
      activeIcon: Icons.fitness_center,
      label: 'Workout',
    ),
    TabInfo(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Dashboard',
      isGold: true,
    ),
    TabInfo(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  void _onNavigate(int index) {
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  List<Widget> _buildChildren(bool isCoach) {
    return [
      _HomeScreenCore(onNavigate: _onNavigate),
      const NutritionScreen(),
      const WorkoutScreen(),
      if (isCoach)
        CoachDashboardProviders.provideAll(child: const CoachDashboardScreen())
      else
        _buildCoachMarketplace(),
      const ProfilePage(),
    ];
  }

  Widget _buildCoachMarketplace() {
    return ChangeNotifierProvider(
      create: (_) => CoachRepositoryProvider(),
      child: Builder(
        builder: (ctx) => MultiProvider(
          providers: [
            ChangeNotifierProxyProvider<
              CoachRepositoryProvider,
              CoachListNotifier
            >(
              create: (c) => CoachListNotifier(
                c.read<CoachRepositoryProvider>().repository,
              ),
              update: (_, repo, prev) =>
                  prev ?? CoachListNotifier(repo.repository),
            ),
            ChangeNotifierProvider(
              create: (_) => SubscriptionRepositoryProvider(),
            ),
            ChangeNotifierProxyProvider<
              SubscriptionRepositoryProvider,
              ActiveSubscriptionNotifier
            >(
              create: (c) {
                final n = ActiveSubscriptionNotifier(
                  c.read<SubscriptionRepositoryProvider>().repository,
                );
                n.fetchActiveSubscription();
                return n;
              },
              update: (_, repo, prev) =>
                  prev ?? ActiveSubscriptionNotifier(repo.repository),
            ),
            ChangeNotifierProxyProvider<
              SubscriptionRepositoryProvider,
              SubscriptionNotifier
            >(
              create: (c) => SubscriptionNotifier(
                c.read<SubscriptionRepositoryProvider>().repository,
              ),
              update: (_, repo, prev) =>
                  prev ?? SubscriptionNotifier(repo.repository),
            ),
          ],
          child: const CoachMarketplaceScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final isCoach = profileProvider.isCoach;
    final tabs = isCoach ? _coachTabs : _clientTabs;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: _buildChildren(isCoach),
        ),
      ),
      bottomNavigationBar: _PremiumNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavigate,
        tabs: tabs,
      ),
    );
  }
}

class TabInfo {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isGold;
  const TabInfo({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isGold = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Nav Bar — pill indicator style (Strava/Nike aesthetic)
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<TabInfo> tabs;

  const _PremiumNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: _kSurface2.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _kBorderSubtle, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(tabs.length, (i) {
                  final tab = tabs[i];
                  final isActive = currentIndex == i;
                  final accentColor = tab.isGold
                      ? _kGold
                      : AppColors.primaryFixed;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onTap(i);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              width: isActive ? 48 : 36,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? accentColor.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isActive ? tab.activeIcon : tab.icon,
                                size: 22,
                                color: isActive ? accentColor : _kTextTertiary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isActive ? accentColor : _kTextTertiary,
                                letterSpacing: 0.2,
                              ),
                              child: Text(tab.label),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen Core
// ─────────────────────────────────────────────────────────────────────────────

class _HomeScreenCore extends StatefulWidget {
  final Function(int) onNavigate;
  const _HomeScreenCore({required this.onNavigate});

  @override
  State<_HomeScreenCore> createState() => _HomeScreenCoreState();
}

class _HomeScreenCoreState extends State<_HomeScreenCore>
    with TickerProviderStateMixin {
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

  late AnimationController _heroCtrl;
  late AnimationController _staggerCtrl;
  late Animation<double> _heroAnim;
  late Animation<double> _ringAnim;
  late Animation<double> _macroAnim;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _heroAnim = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic);
    _ringAnim = CurvedAnimation(
      parent: _heroCtrl,
      curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
    );
    _macroAnim = CurvedAnimation(
      parent: _heroCtrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    );
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadData();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  double get _calorieProgress =>
      _goalCalories > 0 ? (_totalCalories / _goalCalories).clamp(0.0, 1.0) : 0;

  Color get _ringColor {
    if (_calorieProgress >= 1.0) return _kRed;
    if (_calorieProgress > 0.8) return _kOrange;
    return AppColors.primaryFixed;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _heroCtrl.reset();
    _staggerCtrl.reset();
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
      _heroCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      _staggerCtrl.forward();
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
      builder: (c) => _StepsDialog(
        controller: ctrl,
        onSave: () async {
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
        onCancel: () => Navigator.pop(c),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: _kSurface3,
      highlightColor: const Color(0xFF2E2E3A),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _shim(48, width: 48, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shim(10, width: 80, radius: 5),
                      const SizedBox(height: 6),
                      _shim(16, width: 160, radius: 5),
                    ],
                  ),
                ),
                _shim(36, width: 36, radius: 12),
              ],
            ),
            const SizedBox(height: 28),
            _shim(280, radius: 24),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _shim(100, radius: 18)),
                const SizedBox(width: 10),
                Expanded(child: _shim(100, radius: 18)),
                const SizedBox(width: 10),
                Expanded(child: _shim(100, radius: 18)),
              ],
            ),
            const SizedBox(height: 28),
            _shim(14, width: 110, radius: 5),
            const SizedBox(height: 12),
            SizedBox(
              height: 88,
              child: Row(
                children: List.generate(
                  4,
                  (i) => Padding(
                    padding: EdgeInsets.only(right: i < 3 ? 12 : 0),
                    child: _shim(88, width: 88, radius: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shim(double h, {double? width, double radius = 12}) => Container(
    width: width ?? double.infinity,
    height: h,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: _buildShimmer()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryFixed,
        backgroundColor: _kSurface2,
        displacement: 60,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: _PremiumHeader(
                  profile: _profile,
                  totalCalories: _totalCalories,
                  goalCalories: _goalCalories,
                ),
              ),
            ),

            // ── Goals banner ──
            if (_noGoalsSet)
              SliverToBoxAdapter(
                child: _Stagger(
                  ctrl: _staggerCtrl,
                  index: 0,
                  child: _GoalsBanner(onTap: () => widget.onNavigate(3)),
                ),
              ),

            // ── Hero Calorie Ring Card ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 1,
                child: _HeroCalorieCard(
                  ringAnim: _ringAnim,
                  macroAnim: _macroAnim,
                  progress: _calorieProgress,
                  ringColor: _ringColor,
                  totalCalories: _totalCalories,
                  goalCalories: _goalCalories,
                  caloriesBurned: _caloriesBurned,
                  totalProtein: _totalProtein,
                  goalProtein: _goalProtein,
                  totalCarbs: _totalCarbs,
                  goalCarbs: _goalCarbs,
                  totalFat: _totalFat,
                  goalFat: _goalFat,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // ── Activity Ring Strip (Whoop-inspired) ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 2,
                child: _ActivityRingStrip(
                  waterGlasses: _waterGlasses,
                  stepsInt: _stepsInt,
                  caloriesBurned: _caloriesBurned,
                  onAddWater: _updateWater,
                  onEditSteps: _editSteps,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── Today's Meals ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 3,
                child: _SectionHeader(
                  title: "Today's Meals",
                  action: AppLocalizations.of(context)!.addFood,
                  onAction: () => widget.onNavigate(1),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 4,
                child: _nutritionLogs.isEmpty
                    ? _EmptyMeals(onTap: () => widget.onNavigate(1))
                    : _MealsRow(
                        logs: _nutritionLogs,
                        onTap: () => widget.onNavigate(1),
                      ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── Training ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 5,
                child: _SectionHeader(
                  title: AppLocalizations.of(context)!.yourProgram,
                  action: '',
                  onAction: null,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 6,
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
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 7,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _LastWorkoutCard(
                    lastWorkout: _lastWorkout,
                    onTap: () => widget.onNavigate(2),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── Coach Banner ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const _CoachBanner(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Header — greeting + streak + notification bell
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumHeader extends StatelessWidget {
  final Map<String, dynamic> profile;
  final double totalCalories, goalCalories;

  const _PremiumHeader({
    required this.profile,
    required this.totalCalories,
    required this.goalCalories,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = profile['name'] as String? ?? 'Athlete';
    final firstName = name.split(' ').first;
    final avatarUrl = profile['avatar_url'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          // Avatar with online ring
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_kGold, Color(0xFF7B5A1E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? Image.network(avatarUrl, fit: BoxFit.cover)
                      : Container(
                          color: _kSurface3,
                          child: Center(
                            child: Text(
                              firstName.isNotEmpty
                                  ? firstName[0].toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                color: _kGold,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _kGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: _kSurface1, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kTextSecondary,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  firstName,
                  style: const TextStyle(
                    fontSize: 20,
                    color: _kTextPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          // Notification button
          _HeaderBtn(icon: Icons.notifications_outlined, onTap: () {}),
        ],
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _kSurface3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderSubtle),
      ),
      child: Icon(icon, color: _kTextSecondary, size: 20),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Goals banner — compact inline nudge
// ─────────────────────────────────────────────────────────────────────────────

class _GoalsBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _GoalsBanner({required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _kOrange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kOrange.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Set your goals to unlock personalized tracking',
                style: TextStyle(
                  fontSize: 12,
                  color: _kOrange.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _kOrange.withValues(alpha: 0.6),
              size: 18,
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Calorie Card — Arc + 3 macro pills (Nike-inspired)
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCalorieCard extends StatelessWidget {
  final Animation<double> ringAnim, macroAnim;
  final double progress, totalCalories, goalCalories;
  final double totalProtein,
      goalProtein,
      totalCarbs,
      goalCarbs,
      totalFat,
      goalFat;
  final int caloriesBurned;
  final Color ringColor;

  const _HeroCalorieCard({
    required this.ringAnim,
    required this.macroAnim,
    required this.progress,
    required this.ringColor,
    required this.totalCalories,
    required this.goalCalories,
    required this.caloriesBurned,
    required this.totalProtein,
    required this.goalProtein,
    required this.totalCarbs,
    required this.goalCarbs,
    required this.totalFat,
    required this.goalFat,
  });

  bool get _isOver => totalCalories > goalCalories;
  double get _remaining =>
      (_isOver ? totalCalories - goalCalories : goalCalories - totalCalories)
          .abs();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _kSurface2,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _isOver ? _kRed.withValues(alpha: 0.3) : _kBorderSubtle,
          ),
          boxShadow: [
            BoxShadow(
              color: ringColor.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: -8,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top: ring + stats ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  // Ring
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: ringAnim,
                          builder: (_, __) => TweenAnimationBuilder<Color?>(
                            tween: ColorTween(end: ringColor),
                            duration: const Duration(milliseconds: 600),
                            builder: (_, c, __) => CustomPaint(
                              size: const Size(140, 140),
                              painter: _FullRingPainter(
                                progress: progress * ringAnim.value,
                                color: c ?? AppColors.primaryFixed,
                              ),
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: ringAnim,
                          builder: (_, __) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TweenAnimationBuilder<Color?>(
                                tween: ColorTween(end: ringColor),
                                duration: const Duration(milliseconds: 500),
                                builder: (_, c, __) => Text(
                                  '${(_remaining * ringAnim.value).toInt()}',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: _isOver
                                        ? (c ?? _kRed)
                                        : _kTextPrimary,
                                    height: 1,
                                    letterSpacing: -1.5,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isOver ? 'OVER' : 'KCAL LEFT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _isOver
                                      ? _kRed.withValues(alpha: 0.7)
                                      : _kTextSecondary,
                                  letterSpacing: 1.5,
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
                        _StatRow(
                          label: 'Goal',
                          value: '${goalCalories.toInt()}',
                          unit: 'kcal',
                          color: _kTextSecondary,
                          icon: Icons.flag_outlined,
                        ),
                        const SizedBox(height: 12),
                        _StatRow(
                          label: 'Eaten',
                          value: '${totalCalories.toInt()}',
                          unit: 'kcal',
                          color: AppColors.primaryFixed,
                          icon: Icons.restaurant_outlined,
                        ),
                        const SizedBox(height: 12),
                        _StatRow(
                          label: 'Burned',
                          value: '$caloriesBurned',
                          unit: 'kcal',
                          color: _kOrange,
                          icon: Icons.local_fire_department_outlined,
                        ),
                        const SizedBox(height: 12),
                        // Mini progress bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${(progress * 100).toInt()}% of daily goal',
                              style: const TextStyle(
                                fontSize: 10,
                                color: _kTextTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 5),
                            AnimatedBuilder(
                              animation: ringAnim,
                              builder: (_, __) => ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (progress * ringAnim.value).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  minHeight: 4,
                                  backgroundColor: _kSurface3,
                                  valueColor: AlwaysStoppedAnimation(ringColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Divider ──
            Container(height: 1, color: _kBorderSubtle),

            // ── Macro pills row ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: AnimatedBuilder(
                animation: macroAnim,
                builder: (_, __) => Row(
                  children: [
                    Expanded(
                      child: _MacroPill(
                        label: 'Carbs',
                        emoji: '🌾',
                        current: totalCarbs * macroAnim.value,
                        goal: goalCarbs,
                        color: _kBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MacroPill(
                        label: 'Protein',
                        emoji: '🥩',
                        current: totalProtein * macroAnim.value,
                        goal: goalProtein,
                        color: const Color(0xFFFF6B6B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MacroPill(
                        label: 'Fat',
                        emoji: '🫙',
                        current: totalFat * macroAnim.value,
                        goal: goalFat,
                        color: const Color(0xFFFFD166),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  final IconData icon;
  const _StatRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 14),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: _kTextTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: _kTextPrimary,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _kTextSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

class _MacroPill extends StatelessWidget {
  final String label, emoji;
  final double current, goal;
  final Color color;
  const _MacroPill({
    required this.label,
    required this.emoji,
    required this.current,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final prog = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final isOver = current > goal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: isOver ? 0.4 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: _kTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: prog,
              minHeight: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(isOver ? _kRed : color),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${current.toInt()}/${goal.toInt()}g',
            style: TextStyle(
              fontSize: 11,
              color: isOver ? _kRed : _kTextPrimary,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Ring Strip — Apple Watch ring-inspired compact cards
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityRingStrip extends StatelessWidget {
  final int waterGlasses, stepsInt, caloriesBurned;
  final VoidCallback onAddWater, onEditSteps;

  const _ActivityRingStrip({
    required this.waterGlasses,
    required this.stepsInt,
    required this.caloriesBurned,
    required this.onAddWater,
    required this.onEditSteps,
  });

  String _formatSteps(int steps) =>
      steps >= 1000 ? '${(steps / 1000).toStringAsFixed(1)}k' : '$steps';

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        Expanded(
          child: _ActivityTile(
            icon: '💧',
            value: '$waterGlasses',
            unit: 'glasses',
            subtitle: 'of 8 goal',
            color: _kBlue,
            progress: waterGlasses / 8,
            onAction: onAddWater,
            actionIcon: Icons.add_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActivityTile(
            icon: '👟',
            value: _formatSteps(stepsInt),
            unit: 'steps',
            subtitle: '${((stepsInt / 10000) * 100).toInt()}% of 10k',
            color: _kGreen,
            progress: stepsInt / 10000,
            onAction: onEditSteps,
            actionIcon: Icons.edit_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActivityTile(
            icon: '🔥',
            value: '$caloriesBurned',
            unit: 'kcal',
            subtitle: 'burned today',
            color: _kOrange,
            progress: (caloriesBurned / 500).clamp(0.0, 1.0),
          ),
        ),
      ],
    ),
  );
}

class _ActivityTile extends StatelessWidget {
  final String icon, value, unit, subtitle;
  final Color color;
  final double progress;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  const _ActivityTile({
    required this.icon,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.color,
    required this.progress,
    this.onAction,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kSurface2,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _kBorderSubtle),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            if (onAction != null)
              GestureDetector(
                onTap: onAction,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(actionIcon, color: color, size: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // Mini ring + value side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CustomPaint(
                painter: _MiniRingPainter(
                  progress: progress.clamp(0.0, 1.0),
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _kTextPrimary,
                      height: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 9,
                      color: color,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 9,
            color: _kTextTertiary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _kTextPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const Spacer(),
        if (action.isNotEmpty && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryFixed,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: AppColors.primaryFixed,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Meals Row — horizontal compact tiles (Cronometer-inspired)
// ─────────────────────────────────────────────────────────────────────────────

class _MealsRow extends StatelessWidget {
  final List<dynamic> logs;
  final VoidCallback onTap;
  const _MealsRow({required this.logs, required this.onTap});

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
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: meals.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (type, label, emoji, targetKcal) = meals[i];
          final mLogs = logs.where((l) => l['meal_type'] == type).toList();
          final kcal = mLogs.fold(
            0.0,
            (s, l) => s + ((l['calories'] as num?) ?? 0),
          );
          final has = mLogs.isNotEmpty;
          final prog = (kcal / targetKcal).clamp(0.0, 1.0);

          return GestureDetector(
            onTap: onTap,
            child: Container(
              width: 84,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: has
                    ? AppColors.primaryFixed.withValues(alpha: 0.08)
                    : _kSurface2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: has
                      ? AppColors.primaryFixed.withValues(alpha: 0.25)
                      : _kBorderSubtle,
                  width: has ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 18)),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: has ? AppColors.primaryFixed : _kSurface3,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          has ? Icons.check_rounded : Icons.add_rounded,
                          size: 9,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: prog,
                      minHeight: 2,
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      color: has ? AppColors.primaryFixed : _kTextTertiary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: has ? _kTextPrimary : _kTextSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    has ? '${kcal.toInt()} cal' : '—',
                    style: TextStyle(
                      fontSize: 9,
                      color: has
                          ? AppColors.primaryFixed.withValues(alpha: 0.8)
                          : _kTextTertiary,
                      fontWeight: FontWeight.w500,
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _kSurface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primaryFixed.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.restaurant_outlined,
                color: AppColors.primaryFixed.withValues(alpha: 0.7),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.noMealsYet,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to log your first meal today',
                    style: TextStyle(fontSize: 12, color: _kTextSecondary),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: AppColors.primaryFixed,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Program Card — Strava activity card style
// ─────────────────────────────────────────────────────────────────────────────

class _ProgramCard extends StatelessWidget {
  final Map<String, dynamic>? activeProgram;
  final VoidCallback onTap;
  const _ProgramCard({required this.activeProgram, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (activeProgram == null) {
      return _EmptyProgramCard(onTap: onTap);
    }
    final prog = activeProgram!['training_programs'] as Map<String, dynamic>;
    final name = prog['name'] as String? ?? '';
    final level = (prog['level'] as String? ?? '').toUpperCase();
    final totalWeeks = (prog['duration_weeks'] as num?)?.toInt() ?? 12;
    final currentWeek = (activeProgram!['current_week'] as num?)?.toInt() ?? 1;
    final pct = ((currentWeek - 1) / totalWeeks).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryFixed.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE PROGRAM',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.8,
                        color: AppColors.primaryFixed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _kTextPrimary,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryFixed.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryFixed,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress segmented bar
          _SegmentedProgress(
            current: currentWeek - 1,
            total: totalWeeks,
            color: AppColors.primaryFixed,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Week $currentWeek of $totalWeeks',
                style: const TextStyle(
                  fontSize: 12,
                  color: _kTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(pct * 100).toInt()}% complete',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryFixed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryFixed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                "Start Today's Workout",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedProgress extends StatelessWidget {
  final int current, total;
  final Color color;
  const _SegmentedProgress({
    required this.current,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final segW = (constraints.maxWidth - (total - 1) * 3) / total;
      return Row(
        children: List.generate(total, (i) {
          final filled = i < current;
          final partial = i == current;
          return Padding(
            padding: EdgeInsets.only(right: i < total - 1 ? 3 : 0),
            child: Container(
              width: segW,
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: filled
                    ? color
                    : partial
                    ? color.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
          );
        }),
      );
    },
  );
}

class _EmptyProgramCard extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyProgramCard({required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _kSurface2,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _kBorderSubtle),
    ),
    child: Row(
      children: [
        const Text('🎯', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No active program',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Pick a training plan to track your progress',
                style: TextStyle(fontSize: 12, color: _kTextSecondary),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryFixed.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)!.browsePrograms,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryFixed,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Last Workout Card
// ─────────────────────────────────────────────────────────────────────────────

class _LastWorkoutCard extends StatelessWidget {
  final Map<String, dynamic>? lastWorkout;
  final VoidCallback onTap;
  const _LastWorkoutCard({required this.lastWorkout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (lastWorkout == null) return _EmptyWorkoutCard(onTap: onTap);
    final name =
        lastWorkout!['session_name'] as String? ??
        AppLocalizations.of(context)!.navWorkout;
    final date = lastWorkout!['session_date'] as String? ?? '';
    final duration = (lastWorkout!['duration_min'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _kSurface3,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('💪', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LAST WORKOUT',
                  style: TextStyle(
                    fontSize: 9,
                    color: _kTextTertiary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (date.isNotEmpty) ...[
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 10,
                        color: _kTextTertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _kTextTertiary,
                        ),
                      ),
                    ],
                    if (duration > 0) ...[
                      const Text(
                        ' · ',
                        style: TextStyle(color: _kTextTertiary),
                      ),
                      const Icon(
                        Icons.timer_outlined,
                        size: 10,
                        color: _kTextTertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$duration min',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _kTextTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _kSurface3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorderSubtle),
              ),
              child: Text(
                AppLocalizations.of(context)!.history,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWorkoutCard extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyWorkoutCard({required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kSurface2,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _kBorderSubtle),
    ),
    child: Row(
      children: [
        const Text('🏋️', style: TextStyle(fontSize: 26)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No workouts logged yet',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Start your first session',
                style: TextStyle(fontSize: 12, color: _kTextSecondary),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryFixed.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)!.logFirstWorkout,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryFixed,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Coach Banner — elevated gold premium
// ─────────────────────────────────────────────────────────────────────────────

class _CoachBanner extends StatelessWidget {
  const _CoachBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CoachProviders.provideRepository(
              child: SubscriptionProviders.provideRepository(
                child: CoachProviders.provideCoachList(
                  child: SubscriptionProviders.provideActiveSubscription(
                    child: SubscriptionProviders.provideSubscriptionActions(
                      child: const CoachMarketplaceScreen(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0, 0.6, 1],
            colors: [Color(0xFF2C2010), Color(0xFF1A1508), _kSurface1],
          ),
          border: Border.all(color: _kGold.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _kGold.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _kGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kGold.withValues(alpha: 0.25)),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: _kGold,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Level up with a Pro Coach',
                    style: TextStyle(
                      color: _kTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Certified coaches available · Plans from \$29/mo',
                    style: TextStyle(
                      color: _kGold.withValues(alpha: 0.7),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: _kGold.withValues(alpha: 0.8),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Steps Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _StepsDialog extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSave, onCancel;
  const _StepsDialog({
    required this.controller,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _kSurface2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: Text(
      AppLocalizations.of(context)!.updateSteps,
      style: const TextStyle(
        color: _kTextPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    content: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      autofocus: true,
      style: const TextStyle(color: _kTextPrimary, fontSize: 16),
      decoration: InputDecoration(
        filled: true,
        fillColor: _kSurface3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
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
        suffixStyle: const TextStyle(color: _kTextSecondary, fontSize: 13),
      ),
    ),
    actions: [
      TextButton(
        onPressed: onCancel,
        child: Text(
          AppLocalizations.of(context)!.cancel,
          style: const TextStyle(color: _kTextSecondary),
        ),
      ),
      FilledButton(
        onPressed: onSave,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryFixed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(AppLocalizations.of(context)!.save),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────

/// Full 360° progress ring (activity ring style)
class _FullRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _FullRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeW = 10.0;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..color = Colors.white.withValues(alpha: 0.07),
    );

    if (progress <= 0) return;

    // Outer glow
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW + 12
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Main arc with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [color.withValues(alpha: 0.5), color],
          startAngle: -pi / 2,
          endAngle: -pi / 2 + 2 * pi,
          transform: const GradientRotation(-pi / 2),
        ).createShader(rect),
    );

    // Tip dot
    final tipAngle = -pi / 2 + 2 * pi * progress.clamp(0, 1);
    final tipX = center.dx + radius * cos(tipAngle);
    final tipY = center.dy + radius * sin(tipAngle);
    canvas.drawCircle(Offset(tipX, tipY), 5, Paint()..color = color);
    canvas.drawCircle(
      Offset(tipX, tipY),
      8,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _FullRingPainter o) =>
      o.progress != progress || o.color != color;
}

/// Mini activity tile ring
class _MiniRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _MiniRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    const strokeW = 3.5;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..color = Colors.white.withValues(alpha: 0.07),
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
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniRingPainter o) =>
      o.progress != progress || o.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Stagger animation — cleaner implementation
// ─────────────────────────────────────────────────────────────────────────────

class _Stagger extends StatefulWidget {
  final Widget child;
  final int index;
  final AnimationController ctrl;

  const _Stagger({
    required this.child,
    required this.index,
    required this.ctrl,
  });

  @override
  State<_Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<_Stagger> {
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final start = (widget.index * 0.08).clamp(0.0, 0.7);
    final end = (start + 0.35).clamp(0.0, 1.0);
    _anim = CurvedAnimation(
      parent: widget.ctrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, child) => Opacity(
      opacity: _anim.value,
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - _anim.value)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}
