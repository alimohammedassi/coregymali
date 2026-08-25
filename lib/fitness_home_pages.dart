import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'chat/presentation/screens/chat_list_screen.dart';
import 'features/coach/data/repositories/coach_repository_impl.dart';
import 'features/coach/data/repositories/subscription_repository_impl.dart';
import 'features/coach/presentation/providers/coach_dashboard_providers.dart';
import 'features/coach/presentation/providers/coach_providers.dart';
import 'features/coach/presentation/providers/subscription_providers.dart';
import 'features/coach/presentation/screens/coach_dashboard_screen.dart';
import 'features/coach/presentation/screens/coach_marketplace_screen.dart';
import 'l10n/app_localizations.dart';
import 'profile.dart';
import 'providers/profile_provider.dart';
import 'screens/food_scan_screen.dart';
import 'screens/barcode_scan_screen.dart';
import 'screens/nutrition_screen.dart';
import 'screens/voice_food_log_screen.dart';
import 'screens/workout_screen.dart';
import 'services/stats_service.dart';
import 'services/streak_service.dart';
import 'services/supabase_client.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';
import 'widgets/add_food_sheet.dart';
import 'widgets/app_background.dart';
import 'widgets/food_logging_modal.dart';
import 'widgets/pixel_art_icons.dart';
import 'features/health/presentation/widgets/today_activity_card.dart';

// ─── Interactive Micro-Widgets ────────────────────────────────────────────────

class _InteractiveScaleDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  const _InteractiveScaleDetector({
    required this.child,
    this.onTap,
    this.scaleFactor = 0.96,
  });

  @override
  State<_InteractiveScaleDetector> createState() =>
      _InteractiveScaleDetectorState();
}

class _InteractiveScaleDetectorState extends State<_InteractiveScaleDetector>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor)
        .animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null) _controller.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      _controller.reverse();
      HapticFeedback.lightImpact();
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// Clean soft-rounded white card with subtle outline and soft shadow
class _ModernPlayfulCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;

  const _ModernPlayfulCard({
    required this.child,
    this.padding,
    this.borderRadius = 22,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.borderSubtle,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Root Scaffold ───────────────────────────────────────────────────────────

class FitnessHomePage extends StatefulWidget {
  const FitnessHomePage({super.key});

  @override
  State<FitnessHomePage> createState() => _FitnessHomePageState();
}

/// Semantic identity of every bottom-navigation destination. Tabs and their
/// screens are both derived from this single enum, so the visible tab list and
/// the IndexedStack children can never drift out of sync again.
enum _TabId { home, nutrition, dashboard, workout, coaches, profile }

class _FitnessHomePageState extends State<FitnessHomePage> {
  int _currentIndex = 0;

  final GlobalKey<NutritionScreenState> _nutritionScreenKey =
      GlobalKey<NutritionScreenState>();

  void _onNutritionChanged() {
    _nutritionScreenKey.currentState?.refreshAfterExternalSave();
  }

  /// Single source of truth for the bottom bar. Both roles share Home /
  /// Nutrition / Workout / Coaches / Profile; coaches additionally get the
  /// gold Dashboard tab. A coach is also a CoreGym user who tracks their own
  /// food, so Nutrition stays a first-class tab for them too.
  List<_TabInfo> _tabsFor(bool isCoach, AppLocalizations l10n) => [
    _TabInfo(
      id: _TabId.home,
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: l10n.navHome,
    ),
    _TabInfo(
      id: _TabId.nutrition,
      icon: Icons.restaurant_outlined,
      activeIcon: Icons.restaurant_rounded,
      label: l10n.navNutrition,
    ),
    if (isCoach)
      _TabInfo(
        id: _TabId.dashboard,
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: l10n.navDashboard,
        isGold: true,
      ),
    _TabInfo(
      id: _TabId.workout,
      icon: Icons.fitness_center_outlined,
      activeIcon: Icons.fitness_center,
      label: l10n.navWorkout,
    ),
    _TabInfo(
      id: _TabId.coaches,
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: l10n.navCoaches,
    ),
    _TabInfo(
      id: _TabId.profile,
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: l10n.navProfile,
    ),
  ];

  int _indexOf(List<_TabInfo> tabs, _TabId id) =>
      tabs.indexWhere((t) => t.id == id);

  Widget _screenFor(_TabInfo tab, List<_TabInfo> tabs) {
    return switch (tab.id) {
      _TabId.home => _HomeScreenCore(
        onNavigate: _onNavigate,
        onNutritionChanged: _onNutritionChanged,
        workoutTabIndex: _indexOf(tabs, _TabId.workout),
        profileTabIndex: _indexOf(tabs, _TabId.profile),
      ),
      _TabId.nutrition => NutritionScreen(key: _nutritionScreenKey),
      _TabId.dashboard => CoachDashboardProviders.provideAll(
        child: const CoachDashboardScreen(),
      ),
      _TabId.workout => const WorkoutScreen(),
      _TabId.coaches => _buildCoachesScreen(),
      _TabId.profile => const ProfilePage(),
    };
  }

  Widget _buildCoachesScreen() {
    final subRepo = SubscriptionRepositoryImpl();
    final activeSubNotifier = ActiveSubscriptionNotifier(subRepo);
    final subNotifier = SubscriptionNotifier(subRepo);

    // Defer the fetch out of the build phase — it calls notifyListeners()
    // synchronously, which would mark provider scopes dirty mid-build and
    // throw "setState() called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      activeSubNotifier.fetchActiveSubscription();
    });

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final n = CoachListNotifier(CoachRepositoryImpl());
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => n.fetchCoaches(),
            );
            return n;
          },
        ),
        ChangeNotifierProvider.value(value: activeSubNotifier),
        ChangeNotifierProvider.value(value: subNotifier),
      ],
      child: const CoachMarketplaceScreen(),
    );
  }

  void _onNavigate(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileProvider = context.watch<ProfileProvider>();
    final isCoach = profileProvider.isCoach;
    final tabs = _tabsFor(isCoach, l10n);
    final children = tabs.map((t) => _screenFor(t, tabs)).toList();

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: AppBackground(
        child: IndexedStack(index: _currentIndex, children: children),
      ),
      bottomNavigationBar: _PlayfulNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavigate,
        tabs: tabs,
      ),
    );
  }
}

class _TabInfo {
  final _TabId id;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isGold;
  const _TabInfo({
    required this.id,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isGold = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Playful Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────

class _PlayfulNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_TabInfo> tabs;

  const _PlayfulNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.borderSubtle, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.06),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final isActive = currentIndex == i;
              final accentColor = tab.isGold
                  ? AppColors.tertiaryFixed
                  : AppColors.primaryGreen;

              return Expanded(
                child: _InteractiveScaleDetector(
                  scaleFactor: 0.88,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? accentColor.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: isActive ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            isActive ? tab.activeIcon : tab.icon,
                            size: 21,
                            color: isActive
                                ? accentColor
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: isActive
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isActive
                                  ? accentColor
                                  : AppColors.textSecondary,
                            ),
                          ),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen Core
// ─────────────────────────────────────────────────────────────────────────────

class _HomeScreenCore extends StatefulWidget {
  final Function(int) onNavigate;
  final VoidCallback? onNutritionChanged;
  /// Resolved by the parent from the active tab list so home-screen shortcuts
  /// land on the right destination for both client and coach layouts.
  final int workoutTabIndex;
  final int profileTabIndex;
  const _HomeScreenCore({
    required this.onNavigate,
    this.onNutritionChanged,
    required this.workoutTabIndex,
    required this.profileTabIndex,
  });

  @override
  State<_HomeScreenCore> createState() => _HomeScreenCoreState();
}

class _HomeScreenCoreState extends State<_HomeScreenCore>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static bool _nudgeShownThisSession = false;

  final StreakService _streakService = StreakService();
  StreakStatus _streakStatus = StreakStatus.empty;

  bool _isLoading = true;
  bool _noGoalsSet = false;
  DateTime _selectedDate = DateTime.now();

  Map<String, dynamic> _profile = {};
  Map<String, dynamic>? _goals;
  List<dynamic> _nutritionLogs = [];

  double _totalCalories = 0, _goalCalories = 2400;
  double _totalProtein = 0, _goalProtein = 140;
  double _totalCarbs = 0, _goalCarbs = 250;
  double _totalFat = 0, _goalFat = 80;
  int _waterGlasses = 0;
  int _stepsInt = 0;
  int _caloriesBurned = 0;

  late AnimationController _heroCtrl;
  late AnimationController _staggerCtrl;
  late Animation<double> _ringAnim;
  late Animation<double> _macroAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      value: 1.0,
    );
    _ringAnim = CurvedAnimation(
      parent: _heroCtrl,
      curve: const Interval(0.1, 0.85, curve: Curves.easeOutCubic),
    );
    _macroAnim = CurvedAnimation(
      parent: _heroCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    );
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1.0,
    );
    StreakService.milestoneReached.addListener(_showMilestoneDialog);
    _loadAll();
  }

  void _showMilestoneDialog() {
    final days = StreakService.milestoneReached.value;
    if (days == null || !mounted) return;
    StreakService.milestoneReached.value = null;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 14),
            Text(
              '$days-day streak!',
              textAlign: TextAlign.center,
              style: AppText.headlineMd.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Consistency is the real workout. Keep the flame alive!',
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: AppColors.primaryActionGradient,
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Keep going!'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    StreakService.milestoneReached.removeListener(_showMilestoneDialog);
    _heroCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll([DateTime? date]) async {
    final targetDate = date ?? _selectedDate;
    final dateStr = targetDate.toIso8601String().substring(0, 10);

    // Streak status — fire-and-forget refresh for the header badge.
    _streakService.getStatus().then((s) {
      if (mounted) setState(() => _streakStatus = s);
    });

    if (currentUserId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        _heroCtrl.forward(from: 0.0);
        _staggerCtrl.forward(from: 0.0);
      }
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        supabase
            .from('profiles')
            .select()
            .eq('id', currentUserId!)
            .maybeSingle(),
        supabase
            .from('user_goals')
            .select()
            .eq('user_id', currentUserId!)
            .maybeSingle(),
        supabase
            .from('nutrition_logs')
            .select()
            .eq('user_id', currentUserId!)
            .eq('logged_date', dateStr),
        supabase
            .from('daily_summary')
            .select()
            .eq('user_id', currentUserId!)
            .eq('summary_date', dateStr)
            .maybeSingle(),
      ]);

      if (!mounted) return;
      _profile = (results[0] as Map<String, dynamic>?) ?? {'name': 'Athlete'};
      _goals = results[1] as Map<String, dynamic>?;
      _nutritionLogs = (results[2] as List<dynamic>?) ?? [];
      final summary = results[3] as Map<String, dynamic>?;

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
        _goalCalories = (_goals!['daily_calories'] as num?)?.toDouble() ?? 2400;
        _goalProtein = (_goals!['daily_protein_g'] as num?)?.toDouble() ?? 140;
        _goalCarbs = (_goals!['daily_carbs_g'] as num?)?.toDouble() ?? 250;
        _goalFat = (_goals!['daily_fat_g'] as num?)?.toDouble() ?? 80;
      }

      if (summary != null) {
        _waterGlasses = summary['water_ml'] != null
            ? ((summary['water_ml'] as num) ~/ 250)
            : 0;
        _stepsInt = (summary['steps'] as num?)?.toInt() ?? 0;
        _caloriesBurned = (summary['calories_burned'] as num?)?.toInt() ?? 0;
      } else {
        _waterGlasses = 0;
        _stepsInt = 0;
        _caloriesBurned = 0;
      }
    } catch (e) {
      debugPrint('Home load error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _heroCtrl.forward(from: 0.0);
        _staggerCtrl.forward(from: 0.0);
      }
    }
  }

  Future<void> _openFoodLogger({
    String mealType = 'breakfast',
    String? mode,
  }) async {
    final result = await FoodLoggingModal.show(
      context,
      initialMealType: mealType,
      initialMode: mode,
    );
    if (result == true) {
      await _loadAll();
    }
  }

  // Barcode scanner entry point — same refresh flow as the AI scan.
  Future<void> _openBarcodeScan() async {
    HapticFeedback.lightImpact();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (saved == true && mounted) {
      await _refreshNutritionTotals();
      widget.onNutritionChanged?.call();
    }
  }

  // Add Meal entry point — opens the Supabase `foods` table browser
  // (search + categories + smart serving). Same refresh flow as AI scan.
  Future<void> _openFoodDatabase() async {
    HapticFeedback.lightImpact();
    final h = DateTime.now().hour;
    final defaultMeal = h < 11
        ? 'breakfast'
        : h < 16
        ? 'lunch'
        : h < 22
        ? 'dinner'
        : 'snack';
    await AddFoodSheet.show(
      context,
      preselectedMeal: defaultMeal,
      onFoodLogged: () async {
        await _refreshNutritionTotals();
        widget.onNutritionChanged?.call();
      },
    );
  }

  // AI Food Scan entry point. On success, refresh only the daily nutrition
  // totals (today's logs + summary) instead of re-fetching everything.
  Future<void> _openFoodScan() async {
    HapticFeedback.lightImpact();
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const FoodScanScreen()));
    if (saved == true && mounted) {
      await _refreshNutritionTotals();
      widget.onNutritionChanged?.call();
    }
  }

  // Voice Food Log entry point — same refresh flow as the AI scan.
  Future<void> _openVoiceLog() async {
    HapticFeedback.lightImpact();
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const VoiceFoodLogScreen()));
    if (saved == true && mounted) {
      await _refreshNutritionTotals();
      widget.onNutritionChanged?.call();
    }
  }

  Future<void> _refreshNutritionTotals() async {
    if (currentUserId == null) return;
    final dateStr = _selectedDate.toIso8601String().substring(0, 10);
    try {
      final results = await Future.wait<dynamic>([
        supabase
            .from('nutrition_logs')
            .select()
            .eq('user_id', currentUserId!)
            .eq('logged_date', dateStr),
        supabase
            .from('daily_summary')
            .select()
            .eq('user_id', currentUserId!)
            .eq('summary_date', dateStr)
            .maybeSingle(),
      ]);

      if (!mounted) return;
      _nutritionLogs = (results[0] as List<dynamic>?) ?? [];
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
      setState(() {});
      _heroCtrl.forward(from: 0.0);
      _staggerCtrl.forward(from: 0.0);
    } catch (e) {
      debugPrint('Home nutrition refresh error: $e');
    }
  }

  Future<void> _addWater() async {
    HapticFeedback.lightImpact();
    final newGlasses = (_waterGlasses + 1).clamp(0, 20);
    setState(() => _waterGlasses = newGlasses);
    try {
      await StatsService().updateTodaySummary({'water_ml': newGlasses * 250});
    } catch (e) {
      debugPrint('Error updating water: $e');
    }
  }

  Future<void> _promptUpdateSteps() async {
    final ctrl = TextEditingController(text: '$_stepsInt');
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const PixelArtIcon(type: PixelIconType.sneaker, size: 22),
            const SizedBox(width: 10),
            Text(
              isArabic ? 'تسجيل خطوات اليوم' : 'Log Today\'s Steps',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '6000',
            suffixText: isArabic ? 'خطوة' : 'steps',
            filled: true,
            fillColor: const Color(0xFFF7F9F8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final steps = int.tryParse(ctrl.text);
              Navigator.pop(ctx, steps);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _stepsInt = result);
      await StatsService().updateTodaySummary({'steps': result});
    }
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8ECE9),
      highlightColor: const Color(0xFFF7F9F8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final bottomInset = MediaQuery.of(context).padding.bottom;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _buildShimmer(),
      );
    }

    final double calorieProgress = _goalCalories > 0
        ? (_totalCalories / _goalCalories).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          _heroCtrl.reset();
          _staggerCtrl.reset();
          await _loadAll();
        },
        color: AppColors.primaryGreen,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
            ),

            // ── 1. Top Greeting, Gamified Badges & Avatar ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 0,
                child: _KaleeHeader(
                  profile: _profile,
                  isArabic: isArabic,
                  streakCount: _streakStatus.currentStreak,
                  streakLoggedToday: _streakStatus.loggedToday,
                  onOpenProfile: () =>
                      widget.onNavigate(widget.profileTabIndex),
                  onOpenChat: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ChatListScreen()),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // ── 1b. Streak-at-risk nudge (once per app open) ──
            if (_streakStatus.atRisk && !_nudgeShownThisSession)
              SliverToBoxAdapter(
                child: _StreakAtRiskBanner(
                  streak: _streakStatus.currentStreak,
                  isArabic: isArabic,
                  onDismiss: () =>
                      setState(() => _nudgeShownThisSession = true),
                ),
              ),

            // ── 2. Compact Interactive Date Selector Strip ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 1,
                child: _CompactDateStrip(
                  selectedDate: _selectedDate,
                  isArabic: isArabic,
                  onSelectDate: (d) {
                    setState(() => _selectedDate = d);
                    _loadAll(d);
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 3. Goals Alert if not set ──
            if (_noGoalsSet)
              SliverToBoxAdapter(
                child: _Stagger(
                  ctrl: _staggerCtrl,
                  index: 2,
                  child: _GoalsOnboardingBanner(
                    isArabic: isArabic,
                    onTap: () => widget.onNavigate(widget.profileTabIndex),
                  ),
                ),
              ),

            // ── 4. Hero Today's Calories Card ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 2,
                child: _HeroCalorieCard(
                  ringAnim: _ringAnim,
                  calorieProgress: calorieProgress,
                  totalCalories: _totalCalories,
                  goalCalories: _goalCalories,
                  isArabic: isArabic,
                  onOpenNutrition: () => _openFoodLogger(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // ── 5. Macro Breakdown 3-Pack ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 3,
                child: _MacroCardsPack(
                  macroAnim: _macroAnim,
                  totalProtein: _totalProtein,
                  goalProtein: _goalProtein,
                  totalCarbs: _totalCarbs,
                  goalCarbs: _goalCarbs,
                  totalFat: _totalFat,
                  goalFat: _goalFat,
                  isArabic: isArabic,
                  onTap: () => _openFoodLogger(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 18)),

            // ── 6. 5-Second Daily Snapshot (Water, Steps, Burned) ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 4,
                child: _DailySnapshotRow(
                  waterGlasses: _waterGlasses,
                  steps: _stepsInt,
                  caloriesBurned: _caloriesBurned,
                  isArabic: isArabic,
                  onAddWater: _addWater,
                  onStepsTap: _promptUpdateSteps,
                  onWorkoutTap: () =>
                      widget.onNavigate(widget.workoutTabIndex),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── 6.5 Today's Smartwatch & Health Activity Card ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TodayActivityCard(
                    stepGoal: 10000,
                    onSynced: () => _loadAll(),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── 7. Quick Food Logging Hub (+ Add Meal & AI Scanner) ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 5,
                child: _QuickFoodLogHub(
                  isArabic: isArabic,
                  onAddMeal: _openFoodDatabase,
                  onAiScan: _openFoodScan,
                  onVoice: _openVoiceLog,
                  onText: () => _openFoodLogger(mode: 'quick'),
                  onBarcode: _openBarcodeScan,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 22)),

            // ── 8. Today's Fueling / Meals Feed ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 6,
                child: _SectionHeader(
                  title: l10n.todaysFueling,
                  actionText: l10n.addFood,
                  isArabic: isArabic,
                  onAction: () => _openFoodLogger(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 7,
                child: _MealsFeed(
                  logs: _nutritionLogs,
                  isArabic: isArabic,
                  onTapMeal: (mealType) => _openFoodLogger(mealType: mealType),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 22)),

            // ── 9. Gamified Daily Quests & Challenges ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 8,
                child: _DailyQuestsCard(
                  waterGlasses: _waterGlasses,
                  totalProtein: _totalProtein,
                  goalProtein: _goalProtein,
                  isArabic: isArabic,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 22)),

            // ── 10. Pro Coach Mentorship Banner ──
            SliverToBoxAdapter(
              child: _Stagger(
                ctrl: _staggerCtrl,
                index: 9,
                child: _ProCoachBanner(isArabic: isArabic),
              ),
            ),

            // Bottom buffer to prevent navbar overlap
            SliverToBoxAdapter(child: SizedBox(height: 90 + bottomInset)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Top Header with Greeting, Level/XP, Streak & Avatar
// ─────────────────────────────────────────────────────────────────────────────

class _KaleeHeader extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool isArabic;
  final int streakCount;
  final bool streakLoggedToday;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenChat;

  const _KaleeHeader({
    required this.profile,
    required this.isArabic,
    this.streakCount = 0,
    this.streakLoggedToday = false,
    required this.onOpenProfile,
    required this.onOpenChat,
  });

  String _getGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = profile['name'] as String? ?? 'Athlete';
    final firstName = name.split(' ').first;
    final avatarUrl = profile['avatar_url'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Avatar with green border ring
          _InteractiveScaleDetector(
            onTap: onOpenProfile,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryGreen, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: avatarUrl.isNotEmpty
                    ? Image.network(avatarUrl, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.lightGreen,
                        child: Center(
                          child: Text(
                            firstName.isNotEmpty
                                ? firstName[0].toUpperCase()
                                : 'A',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              fontFamily: AppText.fontFamily(
                                isArabic: isArabic,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Greeting & Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _getGreeting(l10n),
                      style: AppText.styledBodySm(
                        isArabic: isArabic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('👋', style: TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  firstName,
                  style: AppText.styledHeadlineMd(
                    isArabic: isArabic,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          const SizedBox(width: 8),

          // Streak Pill — server-computed (green when logged today, muted
          // when the streak is at risk of breaking).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: streakLoggedToday || streakCount == 0
                  ? AppColors.lightGreen
                  : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: streakLoggedToday
                    ? AppColors.primaryGreen.withValues(alpha: 0.4)
                    : AppColors.borderSubtle,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 15,
                  color: streakCount == 0
                      ? AppColors.textMuted
                      : (streakLoggedToday
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary),
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.daysStreak(streakCount),
                  style: TextStyle(
                    color: streakCount == 0
                        ? AppColors.textMuted
                        : (streakLoggedToday
                            ? AppColors.primaryGreen
                            : AppColors.textSecondary),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: AppText.fontFamily(isArabic: isArabic),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Chat Button
          _InteractiveScaleDetector(
            onTap: onOpenChat,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1b. Streak-at-risk nudge banner
// ─────────────────────────────────────────────────────────────────────────────

class _StreakAtRiskBanner extends StatelessWidget {
  final int streak;
  final bool isArabic;
  final VoidCallback onDismiss;

  const _StreakAtRiskBanner({
    required this.streak,
    required this.isArabic,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isArabic
                  ? 'سجّل أي حاجة النهاردة قبل ما الستريك بتاعك يولّع ($streak أيام)!'
                  : 'Log something today to keep your $streak-day streak alive!',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: AppColors.textPrimary,
                fontFamily: AppText.fontFamily(isArabic: isArabic),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded,
                size: 16, color: AppColors.textSecondary),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Compact Daily Date Selector Strip
// ─────────────────────────────────────────────────────────────────────────────

class _CompactDateStrip extends StatelessWidget {
  final DateTime selectedDate;
  final bool isArabic;
  final ValueChanged<DateTime> onSelectDate;

  const _CompactDateStrip({
    required this.selectedDate,
    required this.isArabic,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    final enDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final arDays = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
    final weekdays = isArabic ? arDays : enDays;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: List.generate(7, (i) {
            final dayDate = startOfWeek.add(Duration(days: i));
            final isSelected =
                dayDate.day == selectedDate.day &&
                dayDate.month == selectedDate.month &&
                dayDate.year == selectedDate.year;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelectDate(dayDate);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.28,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        weekdays[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontFamily: AppText.fontFamily(isArabic: isArabic),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${dayDate.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontFamily: AppText.fontFamily(isArabic: isArabic),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Goals Alert Banner
// ─────────────────────────────────────────────────────────────────────────────

class _GoalsOnboardingBanner extends StatelessWidget {
  final bool isArabic;
  final VoidCallback onTap;

  const _GoalsOnboardingBanner({required this.isArabic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: _InteractiveScaleDetector(
        onTap: onTap,
        child: _ModernPlayfulCard(
          backgroundColor: const Color(0xFFFFF8E1),
          borderColor: const Color(0xFFFFD54F),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const PixelArtIcon(type: PixelIconType.star, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.setGoalsTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFE65100),
                        fontFamily: AppText.fontFamily(isArabic: isArabic),
                      ),
                    ),
                    Text(
                      l10n.setGoalsSubtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFFF57C00),
                        fontFamily: AppText.fontFamily(isArabic: isArabic),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFFE65100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Hero Today's Calories Card
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCalorieCard extends StatelessWidget {
  final Animation<double> ringAnim;
  final double calorieProgress;
  final double totalCalories, goalCalories;
  final bool isArabic;
  final VoidCallback onOpenNutrition;

  const _HeroCalorieCard({
    required this.ringAnim,
    required this.calorieProgress,
    required this.totalCalories,
    required this.goalCalories,
    required this.isArabic,
    required this.onOpenNutrition,
  });

  bool get _isOver => totalCalories > goalCalories;
  double get _remaining =>
      (_isOver ? totalCalories - goalCalories : goalCalories - totalCalories)
          .abs();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _InteractiveScaleDetector(
        onTap: onOpenNutrition,
        child: _ModernPlayfulCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header title + Pixel Fire Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const PixelArtIcon(
                          type: PixelIconType.fire,
                          size: 16,
                          animate: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.todayCalories.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                          fontFamily: AppText.fontFamily(isArabic: isArabic),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Gauge & Main Counter
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circular Progress Gauge
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: ringAnim,
                          builder: (_, __) => CustomPaint(
                            size: const Size(96, 96),
                            painter: _CalorieGaugePainter(
                              progress: (calorieProgress * ringAnim.value)
                                  .clamp(0.0, 1.0),
                              isOver: _isOver,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PixelArtIcon(
                              type: PixelIconType.fire,
                              size: 18,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${((calorieProgress * 100).toInt())}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _isOver
                                    ? AppColors.accentProtein
                                    : AppColors.accentCalories,
                                fontFamily: AppText.fontFamily(
                                  isArabic: isArabic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Numbers & Target Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedBuilder(
                          animation: ringAnim,
                          builder: (_, __) => Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${(totalCalories * ringAnim.value).toInt()}',
                                style: AppText.styledDisplayMd(
                                  isArabic: isArabic,
                                  color: _isOver
                                      ? AppColors.accentProtein
                                      : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                ' / ${goalCalories.toInt()} ${l10n.kcal}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  fontFamily: AppText.fontFamily(
                                    isArabic: isArabic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Remaining Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _isOver
                                ? const Color(0xFFFEE2E2)
                                : AppColors.lightGreen,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _isOver
                                ? l10n.caloriesOverMsg(_remaining.toInt())
                                : l10n.caloriesRemainingMsg(_remaining.toInt()),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _isOver
                                  ? const Color(0xFFB91C1C)
                                  : AppColors.onPrimaryContainer,
                              fontFamily: AppText.fontFamily(
                                isArabic: isArabic,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalorieGaugePainter extends CustomPainter {
  final double progress;
  final bool isOver;

  const _CalorieGaugePainter({required this.progress, required this.isOver});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.5;

    // Track Background
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFF0F3F1);
    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    // Active Track with Rounded Cap
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = isOver ? AppColors.accentProtein : AppColors.accentCalories;

    final sweep = 2 * pi * progress.clamp(0.0, 1.0);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -pi / 2, sweep, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _CalorieGaugePainter old) =>
      old.progress != progress || old.isOver != isOver;
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Macro Breakdown 3-Pack (Protein, Carbs, Fat)
// ─────────────────────────────────────────────────────────────────────────────

class _MacroCardsPack extends StatelessWidget {
  final Animation<double> macroAnim;
  final double totalProtein, goalProtein;
  final double totalCarbs, goalCarbs;
  final double totalFat, goalFat;
  final bool isArabic;
  final VoidCallback onTap;

  const _MacroCardsPack({
    required this.macroAnim,
    required this.totalProtein,
    required this.goalProtein,
    required this.totalCarbs,
    required this.goalCarbs,
    required this.totalFat,
    required this.goalFat,
    required this.isArabic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: macroAnim,
        builder: (_, __) => Row(
          children: [
            // Protein Card (Chicken)
            Expanded(
              child: _MacroCard(
                title: l10n.protein,
                iconType: PixelIconType.chicken,
                current: (totalProtein * macroAnim.value).toInt(),
                goal: goalProtein.toInt(),
                accentColor: AppColors.accentProtein,
                lightBgColor: const Color(0xFFFEE2E2),
                isArabic: isArabic,
                onTap: onTap,
              ),
            ),
            const SizedBox(width: 10),
            // Carbs Card (Grain)
            Expanded(
              child: _MacroCard(
                title: l10n.carbs,
                iconType: PixelIconType.grain,
                current: (totalCarbs * macroAnim.value).toInt(),
                goal: goalCarbs.toInt(),
                accentColor: AppColors.accentCarbs,
                lightBgColor: const Color(0xFFDBEAFE),
                isArabic: isArabic,
                onTap: onTap,
              ),
            ),
            const SizedBox(width: 10),
            // Fat Card (Avocado)
            Expanded(
              child: _MacroCard(
                title: l10n.fat,
                iconType: PixelIconType.avocado,
                current: (totalFat * macroAnim.value).toInt(),
                goal: goalFat.toInt(),
                accentColor: AppColors.accentFat,
                lightBgColor: const Color(0xFFDCFCE7),
                isArabic: isArabic,
                onTap: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String title;
  final PixelIconType iconType;
  final int current, goal;
  final Color accentColor;
  final Color lightBgColor;
  final bool isArabic;
  final VoidCallback onTap;

  const _MacroCard({
    required this.title,
    required this.iconType,
    required this.current,
    required this.goal,
    required this.accentColor,
    required this.lightBgColor,
    required this.isArabic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double pct = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;

    return _InteractiveScaleDetector(
      onTap: onTap,
      scaleFactor: 0.94,
      child: _ModernPlayfulCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: lightBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: PixelArtIcon(type: iconType, size: 16),
                ),
                Text(
                  '${(pct * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    fontFamily: AppText.fontFamily(isArabic: isArabic),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontFamily: AppText.fontFamily(isArabic: isArabic),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${current}g',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: AppText.fontFamily(isArabic: isArabic),
                    ),
                  ),
                  TextSpan(
                    text: ' / ${goal}g',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                      fontFamily: AppText.fontFamily(isArabic: isArabic),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: const Color(0xFFF1F5F3),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. 5-Second Daily Snapshot (Water, Steps, Burned)
// ─────────────────────────────────────────────────────────────────────────────

class _DailySnapshotRow extends StatelessWidget {
  final int waterGlasses;
  final int steps;
  final int caloriesBurned;
  final bool isArabic;
  final VoidCallback onAddWater;
  final VoidCallback onStepsTap;
  final VoidCallback onWorkoutTap;

  const _DailySnapshotRow({
    required this.waterGlasses,
    required this.steps,
    required this.caloriesBurned,
    required this.isArabic,
    required this.onAddWater,
    required this.onStepsTap,
    required this.onWorkoutTap,
  });

  String _formatSteps(int steps) =>
      steps >= 1000 ? '${(steps / 1000).toStringAsFixed(1)}k' : '$steps';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Water Card (Interactive Tap)
          Expanded(
            child: _InteractiveScaleDetector(
              onTap: onAddWater,
              child: _ModernPlayfulCard(
                padding: const EdgeInsets.all(12),
                borderRadius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const PixelArtIcon(
                          type: PixelIconType.waterDrop,
                          size: 16,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '+250ml',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.water,
                      style: AppText.styledBodySm(
                        isArabic: isArabic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$waterGlasses / 8',
                      style: AppText.styledTitleMd(
                        isArabic: isArabic,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Steps Card (Interactive Tap)
          Expanded(
            child: _InteractiveScaleDetector(
              onTap: onStepsTap,
              child: _ModernPlayfulCard(
                padding: const EdgeInsets.all(12),
                borderRadius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const PixelArtIcon(
                          type: PixelIconType.sneaker,
                          size: 16,
                        ),
                        const Icon(
                          Icons.edit_outlined,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.steps,
                      style: AppText.styledBodySm(
                        isArabic: isArabic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _formatSteps(steps),
                      style: AppText.styledTitleMd(
                        isArabic: isArabic,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Workout / Burned Card
          Expanded(
            child: _InteractiveScaleDetector(
              onTap: onWorkoutTap,
              child: _ModernPlayfulCard(
                padding: const EdgeInsets.all(12),
                borderRadius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PixelArtIcon(type: PixelIconType.dumbbell, size: 16),
                    const SizedBox(height: 8),
                    Text(
                      l10n.burned,
                      style: AppText.styledBodySm(
                        isArabic: isArabic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$caloriesBurned kcal',
                      style: AppText.styledTitleMd(
                        isArabic: isArabic,
                        color: AppColors.textPrimary,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. Quick Food Logging Hub (+ Add Meal & AI Scan)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickFoodLogHub extends StatelessWidget {
  final bool isArabic;
  final VoidCallback onAddMeal;
  final VoidCallback onAiScan;
  final VoidCallback onVoice;
  final VoidCallback onText;
  final VoidCallback onBarcode;

  const _QuickFoodLogHub({
    required this.isArabic,
    required this.onAddMeal,
    required this.onAiScan,
    required this.onVoice,
    required this.onText,
    required this.onBarcode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Primary Green CTA Button
          _InteractiveScaleDetector(
            onTap: onAddMeal,
            scaleFactor: 0.97,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryActionGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const PixelArtIcon(
                    type: PixelIconType.robot,
                    size: 20,
                    animate: true,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.addMeal,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: AppText.fontFamily(isArabic: isArabic),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 4 Quick Options (AI Scan, Voice, Text, Barcode)
          Row(
            children: [
              _buildQuickOption(
                icon: Icons.camera_alt_rounded,
                label: l10n.scanAi,
                onTap: onAiScan,
              ),
              const SizedBox(width: 8),
              _buildQuickOption(
                icon: Icons.mic_rounded,
                label: l10n.voiceLog,
                onTap: onVoice,
              ),
              const SizedBox(width: 8),
              _buildQuickOption(
                icon: Icons.edit_note_rounded,
                label: l10n.quickText,
                onTap: onText,
              ),
              const SizedBox(width: 8),
              _buildQuickOption(
                icon: Icons.qr_code_scanner_rounded,
                label: l10n.barcodeScan,
                onTap: onBarcode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: _InteractiveScaleDetector(
        onTap: onTap,
        scaleFactor: 0.90,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryGreen),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. Today's Fueling / Meals Feed
// ─────────────────────────────────────────────────────────────────────────────

class _MealsFeed extends StatelessWidget {
  final List<dynamic> logs;
  final bool isArabic;
  final Function(String mealType) onTapMeal;

  const _MealsFeed({
    required this.logs,
    required this.isArabic,
    required this.onTapMeal,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mealSlots = [
      ('breakfast', l10n.breakfast, PixelIconType.egg, 550.0),
      ('lunch', l10n.lunch, PixelIconType.plate, 750.0),
      ('dinner', l10n.dinner, PixelIconType.apple, 650.0),
      ('snack', l10n.snack, PixelIconType.avocado, 300.0),
    ];

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: mealSlots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (type, label, iconType, targetKcal) = mealSlots[i];
          final mLogs = logs.where((l) => l['meal_type'] == type).toList();
          final kcal = mLogs.fold(
            0.0,
            (s, l) => s + ((l['calories'] as num?) ?? 0),
          );
          final hasLogs = mLogs.isNotEmpty;

          return _InteractiveScaleDetector(
            onTap: () => onTapMeal(type),
            child: _ModernPlayfulCard(
              padding: const EdgeInsets.all(12),
              borderRadius: 18,
              borderColor: hasLogs
                  ? AppColors.primaryGreen.withValues(alpha: 0.4)
                  : AppColors.borderSubtle,
              child: SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PixelArtIcon(type: iconType, size: 18),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: hasLogs
                                ? AppColors.primaryGreen
                                : const Color(0xFFF1F5F3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasLogs ? Icons.check_rounded : Icons.add_rounded,
                            size: 11,
                            color: hasLogs
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      label,
                      style: AppText.styledLabelLg(
                        isArabic: isArabic,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      hasLogs
                          ? '${kcal.toInt()} ${l10n.kcal}'
                          : '${targetKcal.toInt()} ${l10n.kcal}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: hasLogs
                            ? AppColors.primaryGreen
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. Gamified Daily Quests & Challenges
// ─────────────────────────────────────────────────────────────────────────────

class _DailyQuestsCard extends StatelessWidget {
  final int waterGlasses;
  final double totalProtein, goalProtein;
  final bool isArabic;

  const _DailyQuestsCard({
    required this.waterGlasses,
    required this.totalProtein,
    required this.goalProtein,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWaterDone = waterGlasses >= 8;
    final isProteinDone = goalProtein > 0 && totalProtein >= goalProtein;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _ModernPlayfulCard(
        backgroundColor: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const PixelArtIcon(type: PixelIconType.trophy, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      l10n.dailyQuests,
                      style: AppText.styledTitleSm(
                        isArabic: isArabic,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const PixelArtIcon(type: PixelIconType.star, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        l10n.xpEarned(120),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildQuestTile(
              title: l10n.hydrationHero,
              progressText: '$waterGlasses / 8',
              isCompleted: isWaterDone,
              iconType: PixelIconType.waterDrop,
            ),
            const SizedBox(height: 8),
            _buildQuestTile(
              title: l10n.proteinChampion,
              progressText: '${totalProtein.toInt()} / ${goalProtein.toInt()}g',
              isCompleted: isProteinDone,
              iconType: PixelIconType.chicken,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestTile({
    required String title,
    required String progressText,
    required bool isCompleted,
    required PixelIconType iconType,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          PixelArtIcon(type: iconType, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: AppText.fontFamily(isArabic: isArabic),
              ),
            ),
          ),
          Text(
            progressText,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isCompleted
                  ? AppColors.primaryGreen
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            isCompleted
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isCompleted ? AppColors.primaryGreen : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 10. Pro Coach Mentorship Banner
// ─────────────────────────────────────────────────────────────────────────────

class _ProCoachBanner extends StatelessWidget {
  final bool isArabic;

  const _ProCoachBanner({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _InteractiveScaleDetector(
        onTap: () {
          final subRepo = SubscriptionRepositoryImpl();
          final activeSubNotifier = ActiveSubscriptionNotifier(subRepo)
            ..fetchActiveSubscription();
          final subNotifier = SubscriptionNotifier(subRepo);

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MultiProvider(
                providers: [
                  ChangeNotifierProvider(
                    create: (_) {
                      final n =
                          CoachListNotifier(CoachRepositoryImpl());
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => n.fetchCoaches(),
                      );
                      return n;
                    },
                  ),
                  ChangeNotifierProvider.value(value: activeSubNotifier),
                  ChangeNotifierProvider.value(value: subNotifier),
                ],
                child: const CoachMarketplaceScreen(),
              ),
            ),
          );
        },
        child: _ModernPlayfulCard(
          backgroundColor: AppColors.lightGreen,
          borderColor: AppColors.primaryGreen.withValues(alpha: 0.3),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Center(
                  child: PixelArtIcon(type: PixelIconType.trophy, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.coachBannerTitle,
                      style: TextStyle(
                        color: AppColors.onPrimaryContainer,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: AppText.fontFamily(isArabic: isArabic),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.coachBannerSubtitle,
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 11,
                        fontFamily: AppText.fontFamily(isArabic: isArabic),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final bool isArabic;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.actionText,
    required this.isArabic,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppText.styledHeadlineSm(
              isArabic: isArabic,
              color: AppColors.textPrimary,
            ),
          ),
          if (actionText.isNotEmpty && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                  fontFamily: AppText.fontFamily(isArabic: isArabic),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stagger Animation Component
// ─────────────────────────────────────────────────────────────────────────────

class _Stagger extends StatelessWidget {
  final Widget child;
  final int index;
  final AnimationController ctrl;

  const _Stagger({
    required this.child,
    required this.index,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, c) {
        final start = (index * 0.04).clamp(0.0, 0.6);
        final end = (start + 0.35).clamp(0.0, 1.0);
        final curved = CurvedAnimation(
          parent: ctrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        );
        final val = curved.value;
        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - val)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}
