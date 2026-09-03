import 'dart:math';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
import 'supabase/auth_service.dart';
import 'supabase/profile_service.dart';
import 'supabase/supabase_config.dart';
import 'services/stats_service.dart';
import 'services/streak_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';
import 'login_sign_up.dart';
import 'widgets/language_toggle.dart';
import 'widgets/theme_mode_toggle.dart';
import 'features/coach/presentation/screens/coach_registration_screen.dart';
import 'screens/workout_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────
class ProfilePage extends StatefulWidget {
  /// When the profile lives inside the main tab scaffold, this jumps to the
  /// Workouts tab; when profile is shown standalone it can stay null and the
  /// banner pushes the WorkoutScreen instead.
  final VoidCallback? onOpenWorkout;
  const ProfilePage({super.key, this.onOpenWorkout});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  // ── Services ──────────────────────────────────────────────────────────────
  final _profileService = ProfileService();
  final _statsService = StatsService();
  final _streakService = StreakService();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  int _streakCount = 0;
  bool _streakLoggedToday = false;

  // Profile
  String _userName = 'User';
  String _userEmail = '';
  String _avatarUrl = '';
  String _age = '--';
  String _weight = '--';
  String _height = '--';
  String _goal = '--';

  // Goals
  int _dailyCalories = 2000;
  int _dailyProtein = 150;
  int _weeklyWorkouts = 3;

  // Stats
  int _totalWorkoutsThisMonth = 0;
  int _totalCaloriesThisMonth = 0;
  String _activeProgramName = 'None';
  int _totalWorkoutsAllTime = 0;
  List<Map<String, dynamic>> _exerciseProgress = [];

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _bgCtrl; // ambient orbs
  late AnimationController _entryCtrl; // staggered list reveal
  late AnimationController _avatarCtrl; // avatar press pulse
  late Animation<double> _avatarScale;

  late List<Animation<double>> _fades;
  late List<Animation<Offset>> _slides;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 18))
      ..repeat(reverse: true);

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

    _avatarCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _avatarScale = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(CurvedAnimation(parent: _avatarCtrl, curve: Curves.easeOut));

    const n = 10; // item count
    _fades = List.generate(
      n,
      (i) => CurvedAnimation(
        parent: _entryCtrl,
        curve: Interval(
          (i * .07).clamp(0.0, 0.9),
          (i * .07 + .5).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      ),
    );
    _slides = List.generate(
      n,
      (i) =>
          Tween<Offset>(begin: const Offset(0, .035), end: Offset.zero).animate(
            CurvedAnimation(
              parent: _entryCtrl,
              curve: Interval(
                (i * .07).clamp(0.0, 0.9),
                (i * .07 + .5).clamp(0.0, 1.0),
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
    );

    _loadData();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  // Shorthand animator wrapper
  Widget _A(int i, Widget w) => FadeTransition(
    opacity: _fades[i],
    child: SlideTransition(position: _slides[i], child: w),
  );

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _entryCtrl.reset();
    // Streak — fire-and-forget; badge updates when it lands.
    _streakService.getStatus().then((s) {
      if (mounted) {
        setState(() {
          _streakCount = s.currentStreak;
          _streakLoggedToday = s.loggedToday;
        });
      }
    });
    try {
      final results = await Future.wait([
        _profileService.getProfile(),
        _statsService.getGoals(),
        _loadExtendedStats(),
      ]);
      final profile = results[0] as Map<String, dynamic>?;
      final goals = results[1] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        if (profile != null) {
          _userName = profile['name'] ?? profile['full_name'] ?? 'User';
          _userEmail = profile['email'] ?? '';
          _avatarUrl = profile['avatar_url'] ?? '';
          _age = '${profile['age'] ?? '--'}';
          _weight = profile['weight_kg'] != null
              ? '${profile['weight_kg']} kg'
              : '--';
          _height = profile['height_cm'] != null
              ? '${profile['height_cm']} cm'
              : '--';
          _goal = _fmtGoal((profile['fitness_goal'] ?? '').toString());
        }
        _dailyCalories = (goals['daily_calories'] as num?)?.toInt() ?? 2000;
        _dailyProtein = (goals['daily_protein_g'] as num?)?.toInt() ?? 150;
        _weeklyWorkouts = (goals['weekly_workouts'] as num?)?.toInt() ?? 3;
        _isLoading = false;
      });
      _entryCtrl.forward();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExtendedStats() async {
    try {
      final db = SupabaseConfig.client;
      final userId = db.auth.currentUser?.id;
      if (userId == null) return;

      final monthStart = DateTime.now()
          .copyWith(day: 1)
          .toIso8601String()
          .substring(0, 10);

      final results = await Future.wait<dynamic>([
        db
            .from('workout_sessions')
            .select('id')
            .eq('user_id', userId)
            .gte('session_date', monthStart),
        db
            .from('daily_summary')
            .select('calories_consumed')
            .eq('user_id', userId)
            .gte('summary_date', monthStart),
        db
            .from('user_active_program')
            .select('*, training_programs(name)')
            .eq('user_id', userId)
            .maybeSingle(),
        db.from('workout_sessions').select('id').eq('user_id', userId),
        db
            .from('exercise_progress')
            .select()
            .eq('user_id', userId)
            .order('session_date'),
      ]);

      if (!mounted) return;

      setState(() {
        _totalWorkoutsThisMonth = (results[0] as List).length;
        _totalCaloriesThisMonth = (results[1] as List).fold<int>(
          0,
          (sum, e) => sum + ((e['calories_consumed'] as num?)?.toInt() ?? 0),
        );

        final active = results[2] as Map<String, dynamic>?;
        if (active?['training_programs'] != null) {
          _activeProgramName =
              active!['training_programs']['name'] as String? ?? 'None';
        }

        _totalWorkoutsAllTime = (results[3] as List).length;
        _exerciseProgress = List<Map<String, dynamic>>.from(results[4] as List);
      });
    } catch (_) {}
  }

  String _fmtGoal(String raw) {
    final l10n = AppLocalizations.of(context)!;
    return {
          'weight_loss': l10n.weightLoss,
          'muscle_gain': l10n.muscleGain,
          'endurance': l10n.endurance,
          'flexibility': l10n.flexibility,
          'general_fitness': l10n.generalFitness,
        }[raw] ??
        (raw.isEmpty ? '--' : raw);
  }

  String _rawGoal(String fmt) {
    final l10n = AppLocalizations.of(context)!;
    return {
          l10n.weightLoss: 'weight_loss',
          l10n.muscleGain: 'muscle_gain',
          l10n.endurance: 'endurance',
          l10n.flexibility: 'flexibility',
          l10n.generalFitness: 'general_fitness',
        }[fmt] ??
        'general_fitness';
  }

  // ── Avatar upload ──────────────────────────────────────────────────────────
  Future<void> _pickAndUpload() async {
    HapticFeedback.lightImpact();
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final db = SupabaseConfig.client;
      final userId = db.auth.currentUser?.id;
      if (userId == null) throw Exception('Not signed in');

      final bytes = await File(picked.path).readAsBytes();
      final path = '$userId/avatar.jpg';

      await db.storage
          .from('coach-media')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final url =
          '${db.storage.from('coach-media').getPublicUrl(path)}'
          '?t=${DateTime.now().millisecondsSinceEpoch}';

      await _profileService.updateProfile({'avatar_url': url});

      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _isUploadingAvatar = false;
      });
      HapticFeedback.mediumImpact();
      _toast(
        'Profile photo updated',
        Icons.check_circle_outline_rounded,
        AppColors.greenAccent,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      _toast(
        'Upload failed. Try again.',
        Icons.error_outline_rounded,
        AppColors.error,
      );
    }
  }

  void _toast(String msg, IconData icon, Color color) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  msg,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.surfaceContainerHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withValues(alpha: .3)),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildAmbientBg(),
          RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            displacement: 60,
            onRefresh: _loadData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    120,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(_items()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading skeleton ──────────────────────────────────────────────────────
  Widget _buildSkeleton() => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Center(child: _Shimmer(width: 86, height: 86, radius: 43)),
          const SizedBox(height: 16),
          const Center(child: _Shimmer(width: 140, height: 14, radius: 8)),
          const SizedBox(height: 8),
          const Center(child: _Shimmer(width: 100, height: 10, radius: 6)),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                    child: const _Shimmer(
                      width: double.infinity,
                      height: 80,
                      radius: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Shimmer(width: double.infinity, height: 72, radius: 16),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Shimmer(width: double.infinity, height: 160, radius: 16),
          ),
        ],
      ),
    ),
  );

  // ── Ambient background ────────────────────────────────────────────────────
  Widget _buildAmbientBg() => AnimatedBuilder(
    animation: _bgCtrl,
    builder: (_, __) {
      final t = _bgCtrl.value;
      return Stack(
        children: [
          Positioned(
            top: -80 + 30 * sin(t * pi),
            right: -60 + 18 * cos(t * pi * 1.3),
            child: _Orb(size: 280, color: AppColors.primary.withValues(alpha: .07)),
          ),
          Positioned(
            bottom: -50 + 24 * cos(t * pi * .7),
            left: -60,
            child: _Orb(size: 220, color: AppColors.secondary.withValues(alpha: .05)),
          ),
          Positioned(
            top:
                MediaQuery.of(context).size.height * .42 +
                18 * sin(t * pi * 1.1),
            right: -30,
            child: _Orb(size: 150, color: AppColors.tertiary.withValues(alpha: .04)),
          ),
        ],
      );
    },
  );

  // ── SliverAppBar ──────────────────────────────────────────────────────────
  Widget _buildAppBar() => SliverAppBar(
    pinned: true,
    expandedHeight: 290,
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    actions: [
      SizedBox(
        height: 44,
        child: const LanguageToggle(compact: true),
      ),
      const SizedBox(width: 4),
      Semantics(
        label: 'Refresh profile',
        button: true,
        child: IconButton(
          icon: Icon(
            Icons.refresh_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            _loadData();
          },
          tooltip: 'Refresh',
          splashRadius: 20,
        ),
      ),
      const SizedBox(width: 8),
    ],
    flexibleSpace: FlexibleSpaceBar(
      collapseMode: CollapseMode.pin,
      background: _buildHeroHeader(),
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              AppColors.borderSubtle,
              Colors.transparent,
            ],
          ),
        ),
      ),
    ),
  );

  // ── Rank Calculation ──────────────────────────────────────────────────────
  // Tiered brand colors — the top tier wears the primary accent (the app's
  // "volt"), lower tiers step down through cyan / amber / silver / muted.
  // All values are readable on light pill backgrounds.
  ({String label, Color color}) _getRank() {
    if (_totalWorkoutsAllTime < 5) {
      return (label: 'ROOKIE', color: AppColors.textMuted);
    }
    if (_totalWorkoutsAllTime < 20) {
      return (label: 'IRON', color: AppColors.secondaryDim);
    }
    if (_totalWorkoutsAllTime < 50) {
      return (label: 'BRONZE', color: AppColors.tertiaryDim);
    }
    if (_totalWorkoutsAllTime < 100) {
      return (label: 'SILVER', color: AppColors.textSecondary);
    }
    return (label: 'GOLD', color: AppColors.primaryGreen);
  }

  // ── Date Formatter ────────────────────────────────────────────────────────
  String _formatDate(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return '';
    }
  }

  // ── Avatar Options ────────────────────────────────────────────────────────
  void _showAvatarOptions() {
    final hasAvatar = _avatarUrl.isNotEmpty;
    _openSheet(
      context,
      title: 'PROFILE PHOTO',
      builder: (ctx, _) => [
        if (hasAvatar) ...[
          _PressCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            onTap: () {
              Navigator.pop(ctx);
              _showFullScreenAvatar();
            },
            child: Row(
              children: [
                Icon(Icons.fullscreen_rounded, color: AppColors.primary),
                const SizedBox(width: 16),
                Text(
                  'View Photo',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _PressCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          onTap: () {
            Navigator.pop(ctx);
            _pickAndUpload();
          },
          child: Row(
            children: [
              Icon(Icons.photo_library_rounded, color: AppColors.primary),
              const SizedBox(width: 16),
              Text(
                hasAvatar ? 'Change Photo' : 'Upload Photo',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFullScreenAvatar() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Hero(
              tag: 'profile_avatar_hero',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  _avatarUrl,
                  width: MediaQuery.of(ctx).size.width * 0.85,
                  height: MediaQuery.of(ctx).size.width * 0.85,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero header ───────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U';
    final hasAvatar = _avatarUrl.isNotEmpty;
    final rank = _getRank();

    return Container(
      color: AppColors.surface,
      child: Stack(
        children: [
          // Primary accent stripe at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withValues(alpha: .75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // ── Avatar ──────────────────────────────────────────────
                  Semantics(
                    label: 'Profile photo. Tap for options.',
                    button: true,
                    child: GestureDetector(
                      onTapDown: (_) => _avatarCtrl.forward(),
                      onTapUp: (_) {
                        _avatarCtrl.reverse();
                        _showAvatarOptions();
                      },
                      onTapCancel: () => _avatarCtrl.reverse(),
                      child: ScaleTransition(
                        scale: _avatarScale,
                        child: SizedBox(
                          width: 112,
                          height: 112,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow halo
                              Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: .16),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              // Primary ring
                              Container(
                                width: 98,
                                height: 98,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: .45),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              // Avatar image or initials
                              Hero(
                                tag: 'profile_avatar_hero',
                                child: CircleAvatar(
                                  radius: 43,
                                  backgroundColor:
                                      AppColors.surfaceContainerHigh,
                                  backgroundImage: hasAvatar
                                      ? NetworkImage(_avatarUrl)
                                      : null,
                                  onBackgroundImageError: hasAvatar
                                      ? (_, __) {}
                                      : null,
                                  child: !hasAvatar
                                      ? Text(
                                          initial,
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 30,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              // Upload spinner overlay
                              if (_isUploadingAvatar)
                                Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: .5),
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              // Camera/Edit badge
                              if (!_isUploadingAvatar)
                                Positioned(
                                  bottom: 3,
                                  right: 3,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.surface,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: .35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child:  Icon(
                                      Icons.edit_rounded,
                                      size: 14,
                                      color: AppColors.onPrimary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Name ────────────────────────────────────────────────
                  Text(
                    _userName.toUpperCase(),
                    style: AppText.headlineMd.copyWith(
                      letterSpacing: 2.0,
                      fontSize: 20,
                      height: 1.1,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Badges Row ──────────────────────────────────────────
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pill(
                        icon: Icons.local_fire_department_rounded,
                        label: '$_streakCount',
                        colorOverride:
                            _streakLoggedToday ? AppColors.primary : null,
                      ),
                      _Pill(
                        icon: Icons.military_tech_rounded,
                        label: rank.label,
                        colorOverride: rank.color,
                        subtle: false,
                      ),
                      if (_userEmail.isNotEmpty)
                        _Pill(
                          icon: Icons.alternate_email_rounded,
                          label: _userEmail,
                          subtle: true,
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Content list ──────────────────────────────────────────────────────────
  List<Widget> _items() {
    final l10n = AppLocalizations.of(context)!;
    return [
      _A(0, _buildStatsRow()),
      if (_totalWorkoutsAllTime == 0) ...[
        const SizedBox(height: 10),
        _A(0, _buildFirstRunNudge()),
      ],
      const SizedBox(height: 20),

      _A(1, _buildProgramBanner()),
      const SizedBox(height: 20),

      _A(2, _SectionHeader(title: l10n.operativeData)),
      const SizedBox(height: 10),
      _A(
        2,
        _ProfileCard(
          onTap: () => _showEditDataSheet(context),
          semanticLabel: 'Edit body data',
          showEditBadge: true,
          child: _buildMetricsRows(),
        ),
      ),
      const SizedBox(height: 20),

      _A(3, _SectionHeader(title: l10n.dailyTargets)),
      const SizedBox(height: 10),
      _A(
        3,
        _ProfileCard(
          onTap: () => _showEditGoalsSheet(context),
          semanticLabel: 'Edit daily targets',
          showEditBadge: true,
          child: _buildTargetRows(),
        ),
      ),
      const SizedBox(height: 20),

      _A(4, _SectionHeader(title: l10n.thisMonth)),
      const SizedBox(height: 10),
      _A(4, _ProfileCard(child: _buildMonthRows())),
      const SizedBox(height: 20),

      if (_exerciseProgress.isNotEmpty) ...[
        _A(5, _SectionHeader(title: l10n.rmProgress)),
        const SizedBox(height: 10),
        _A(5, _buildProgressChart()),
        const SizedBox(height: 20),
      ],

      _A(6, _GradientDivider()),
      const SizedBox(height: 24),

      _A(7, _buildCoachCta()),
      const SizedBox(height: 10),

      _A(8, _SectionHeader(title: l10n.appearance)),
      const SizedBox(height: 10),
      _A(8, _ProfileCard(child: ThemeModeToggle())),
      const SizedBox(height: 20),

      _A(9, _buildSignOutBtn()),
    ];
  }

  // ── First-run nudge ───────────────────────────────────────────────────────
  Widget _buildFirstRunNudge() {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.profileFirstRunNudge,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.tertiary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.tertiary.withValues(alpha: .3)),
        ),
        child: Row(
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 18, color: AppColors.tertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.profileFirstRunNudge,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats row — deliberately quiet: one compact borderless strip so the
  // program banner and daily targets read as the primary content.
  Widget _buildStatsRow() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          _InlineStat(
            value: '$_totalWorkoutsAllTime',
            label: l10n.totalWorkouts,
            icon: Icons.fitness_center_rounded,
            color: AppColors.primary,
          ),
          _statDivider(),
          _InlineStat(
            value: '$_totalWorkoutsThisMonth',
            label: l10n.thisMonthWorkouts,
            icon: Icons.calendar_month_rounded,
            color: AppColors.secondary,
          ),
          _statDivider(),
          _InlineStat(
            value: '${(_totalCaloriesThisMonth / 1000).toStringAsFixed(1)}k',
            label: l10n.kcalLogged,
            icon: Icons.local_fire_department_rounded,
            color: AppColors.accentCalories,
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: AppColors.borderSubtle,
      );

  // ── Program banner ────────────────────────────────────────────────────────
  Widget _buildProgramBanner() => _PressCard(
    semanticLabel: 'Active program: $_activeProgramName. Tap to view.',
    // The banner promises "tap to view" — open the active program in the
    // Workouts tab (in-app) or push the workout screen when standalone.
    onTap: () {
      HapticFeedback.lightImpact();
      if (widget.onOpenWorkout != null) {
        widget.onOpenWorkout!();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WorkoutScreen()),
        );
      }
    },
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.bolt_rounded,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.activeProgram2.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _activeProgramName,
                style: AppText.titleSm.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textSecondary.withValues(alpha: .7),
          size: 20,
        ),
      ],
    ),
  );

  // ── Unified metric-row list pattern ───────────────────────────────────────
  // One consistent card language for all "a few numbers" sections
  // (body data, daily targets, this month): icon chip · label · value.
  Widget _metricListRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    String? unit,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppText.bodySm.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: AppText.metricMd.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (unit != null && unit.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: AppText.bodySm.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: AppColors.borderLight),
      ],
    );
  }

  Widget _buildMetricsRows() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _metricListRow(
          icon: Icons.cake_outlined,
          color: AppColors.secondary,
          label: l10n.age,
          value: _age == '--' ? '--' : _age,
          unit: _age == '--' ? null : 'yrs',
        ),
        _metricListRow(
          icon: Icons.monitor_weight_outlined,
          color: AppColors.purpleAccent,
          label: l10n.weight,
          value: _weight == '--' ? '--' : _weight.replaceAll(' kg', ''),
          unit: _weight == '--' ? null : 'kg',
        ),
        _metricListRow(
          icon: Icons.height_outlined,
          color: AppColors.tertiary,
          label: l10n.height,
          value: _height == '--' ? '--' : _height.replaceAll(' cm', ''),
          unit: _height == '--' ? null : 'cm',
        ),
        _metricListRow(
          icon: Icons.track_changes_outlined,
          color: AppColors.primary,
          label: l10n.goal,
          value: _goal,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTargetRows() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _metricListRow(
          icon: Icons.local_fire_department_rounded,
          color: AppColors.accentCalories,
          label: l10n.caloriesLabel,
          value: '$_dailyCalories',
          unit: l10n.kcal,
        ),
        _metricListRow(
          icon: Icons.egg_alt_outlined,
          color: AppColors.accentProtein,
          label: l10n.proteinGoal,
          value: '$_dailyProtein',
          unit: 'g',
        ),
        _metricListRow(
          icon: Icons.fitness_center_rounded,
          color: AppColors.primary,
          label: l10n.workoutsLabel,
          value: '$_weeklyWorkouts',
          unit: '×/wk',
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildMonthRows() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _metricListRow(
          icon: Icons.fitness_center_rounded,
          color: AppColors.primary,
          label: l10n.workoutsLabel,
          value: '$_totalWorkoutsThisMonth',
        ),
        _metricListRow(
          icon: Icons.local_fire_department_rounded,
          color: AppColors.accentCalories,
          label: l10n.caloriesLabel,
          value: _totalCaloriesThisMonth > 0
              ? '${(_totalCaloriesThisMonth / 1000).toStringAsFixed(1)}k'
              : '0',
          unit: _totalCaloriesThisMonth > 0 ? 'kcal' : null,
          isLast: true,
        ),
      ],
    );
  }

  // ── Progress chart ────────────────────────────────────────────────────────
  Widget _buildProgressChart() {
    if (_exerciseProgress.isEmpty) {
      return _ProfileCard(
        child: _EmptyState(
          icon: Icons.show_chart_rounded,
          label: 'No progress data yet',
        ),
      );
    }

    final spots = <FlSpot>[];
    double minY = double.infinity, maxY = 0;
    for (int i = 0; i < _exerciseProgress.length; i++) {
      final v =
          (_exerciseProgress[i]['one_rm_estimate'] as num?)?.toDouble() ?? 0;
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
      spots.add(FlSpot(i.toDouble(), v));
    }
    if (minY == double.infinity) minY = 0;
    minY = (minY - 10).clamp(0.0, double.infinity);
    maxY += 10;

    return _ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.estimatedOneRM,
                style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _Pill(label: '${spots.length} sessions'),
            ],
          ),
          const SizedBox(height: 20),
          Semantics(
            label:
                '1RM progress line chart — ${spots.length} sessions recorded.',
            child: SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.borderLight,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: 1,
                        getTitlesWidget: (v, meta) {
                          final index = v.toInt();
                          if (index < 0 || index >= _exerciseProgress.length) {
                            return const SizedBox();
                          }
                          // Only show every Nth label if there are too many spots
                          if (spots.length > 5 &&
                              index % ((spots.length / 5).ceil()) != 0 &&
                              index != spots.length - 1) {
                            return const SizedBox();
                          }
                          final rawDate =
                              _exerciseProgress[index]['session_date']
                                  ?.toString();
                          if (rawDate == null) return const SizedBox();

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _formatDate(rawDate),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      // Compatible with fl_chart ≥ 0.67 — uses getTooltipColor
                      // instead of the deprecated tooltipBgColor field.
                      getTooltipColor: (_) => AppColors.surfaceContainerHigh,
                      getTooltipItems: (touchedSpots) => touchedSpots
                          .map(
                            (spot) => LineTooltipItem(
                              '${spot.y.toInt()} kg',
                              TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: .35,
                      color: AppColors.primary,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 3.5,
                          color: AppColors.primary,
                          strokeWidth: 2,
                          strokeColor: AppColors.surface,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: .16),
                            AppColors.primary.withValues(alpha: 0),
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

  // ── Coach CTA — premium in-brand moment using the shared action gradient ──
  Widget _buildCoachCta() => Semantics(
    button: true,
    label: 'Become a Coach',
    child: _PressCard(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CoachRegistrationScreen()),
        );
      },
      padding: EdgeInsets.zero,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppColors.primaryActionGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .30),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BECOME A COACH',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Unlock coaching tools & clients',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: .85),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: .9),
              size: 14,
            ),
          ],
        ),
      ),
    ),
  );

  // ── Sign out ──────────────────────────────────────────────────────────────
  Widget _buildSignOutBtn() => _FlatActionBtn(
    label: AppLocalizations.of(context)!.signOut,
    icon: Icons.logout_rounded,
    isDestructive: true,
    onTap: () => _showLogoutDialog(context),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // SHEETS
  // ─────────────────────────────────────────────────────────────────────────
  void _showEditDataSheet(BuildContext context) {
    final ageCtrl = TextEditingController(text: _age == '--' ? '' : _age);
    final weightCtrl = TextEditingController(
      text: _weight == '--' ? '' : _weight.replaceAll(' kg', ''),
    );
    final heightCtrl = TextEditingController(
      text: _height == '--' ? '' : _height.replaceAll(' cm', ''),
    );
    String goal = _goal == '--' ? 'general_fitness' : _rawGoal(_goal);

    _openSheet(
      context,
      title: 'EDIT DATA',
      builder: (ctx, setState) => [
        _FieldInput(
          label: AppLocalizations.of(context)!.age,
          unit: 'yrs',
          ctrl: ageCtrl,
          icon: Icons.cake_outlined,
          color: AppColors.secondary,
        ),
        const SizedBox(height: 12),
        _FieldInput(
          label: AppLocalizations.of(context)!.weight,
          unit: AppLocalizations.of(context)!.kg,
          ctrl: weightCtrl,
          icon: Icons.monitor_weight_outlined,
          color: AppColors.accentProtein,
        ),
        const SizedBox(height: 12),
        _FieldInput(
          label: AppLocalizations.of(context)!.height,
          unit: 'cm',
          ctrl: heightCtrl,
          icon: Icons.height_outlined,
          color: AppColors.primary,
        ),
        const SizedBox(height: 12),
        _FieldDropdown(
          value: goal,
          items: {
            'weight_loss': AppLocalizations.of(context)!.weightLoss,
            'muscle_gain': AppLocalizations.of(context)!.muscleGain,
            'endurance': AppLocalizations.of(context)!.endurance,
            'flexibility': AppLocalizations.of(context)!.flexibility,
            'general_fitness': AppLocalizations.of(context)!.generalFitness,
          },
          onChanged: (v) {
            if (v != null) setState(() => goal = v);
          },
        ),
        const SizedBox(height: 24),
        _SaveBtn(
          label: 'SAVE DATA',
          onPressed: () async {
            HapticFeedback.mediumImpact();
            try {
              final db = SupabaseConfig.client;
              final uid = db.auth.currentUser?.id;
              if (uid != null) {
                await db
                    .from('profiles')
                    .update({
                      'age': int.tryParse(ageCtrl.text),
                      'weight_kg': double.tryParse(weightCtrl.text),
                      'height_cm': double.tryParse(heightCtrl.text),
                      'fitness_goal': goal,
                    })
                    .eq('id', uid);
              }
            } catch (_) {}
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) _loadData();
          },
        ),
      ],
    );
  }

  void _showEditGoalsSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final calCtrl = TextEditingController(text: '$_dailyCalories');
    final proCtrl = TextEditingController(text: '$_dailyProtein');
    final wkCtrl = TextEditingController(text: '$_weeklyWorkouts');

    _openSheet(
      context,
      title: l10n.editGoalsTitle,
      builder: (ctx, _) => [
        _FieldInput(
          label: l10n.dailyCalories,
          unit: l10n.kcal,
          ctrl: calCtrl,
          icon: Icons.local_fire_department_rounded,
          color: AppColors.accentCalories,
        ),
        const SizedBox(height: 12),
        _FieldInput(
          label: l10n.dailyProtein,
          unit: 'g',
          ctrl: proCtrl,
          icon: Icons.egg_alt_outlined,
          color: AppColors.accentProtein,
        ),
        const SizedBox(height: 12),
        _FieldInput(
          label: l10n.weeklyWorkoutsLabel,
          unit: '×',
          ctrl: wkCtrl,
          icon: Icons.fitness_center_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(height: 24),
        _SaveBtn(
          label: 'SAVE GOALS',
          onPressed: () async {
            HapticFeedback.mediumImpact();
            try {
              final db = SupabaseConfig.client;
              final uid = db.auth.currentUser?.id;
              if (uid != null) {
                await db.from('user_goals').upsert({
                  'user_id': uid,
                  'daily_calories':
                      int.tryParse(calCtrl.text) ?? _dailyCalories,
                  'daily_protein_g':
                      int.tryParse(proCtrl.text) ?? _dailyProtein,
                  'weekly_workouts':
                      int.tryParse(wkCtrl.text) ?? _weeklyWorkouts,
                  'updated_at': DateTime.now().toIso8601String(),
                }, onConflict: 'user_id');
              }
            } catch (_) {}
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) _loadData();
          },
        ),
      ],
    );
  }

  /// Generic bottom-sheet launcher — eliminates duplicated scaffold code.
  void _openSheet(
    BuildContext context, {
    required String title,
    required List<Widget> Function(BuildContext, StateSetter) builder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      enableDrag: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _Sheet(title: title, children: builder(ctx, ss)),
        ),
      ),
    );
  }

  // ── Logout dialog ─────────────────────────────────────────────────────────
  void _showLogoutDialog(BuildContext ctx) {
    final l10n = AppLocalizations.of(ctx)!;
    showDialog(
      context: ctx,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.error.withValues(alpha: .25)),
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24,
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.logout_rounded,
            color: AppColors.error,
            size: 24,
          ),
        ),
        title: Text(
          l10n.signOutTitle,
          style: AppText.headlineSm.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          l10n.signOutConfirm,
          style: AppText.bodyMd.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        actions: [
          SizedBox(
            height: 44,
            child: TextButton(
              onPressed: () => Navigator.pop(dCtx),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              child: Text(
                l10n.cancel,
                style: AppText.labelMd.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                Navigator.pop(dCtx);
                await AuthService().signOut();
                if (ctx.mounted) {
                  Navigator.of(ctx).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (_, a, __) => const AuthWrapper(),
                      transitionsBuilder: (_, a, __, child) => FadeTransition(
                        opacity: CurvedAnimation(
                          parent: a,
                          curve: Curves.easeOut,
                        ),
                        child: child,
                      ),
                      transitionDuration: const Duration(milliseconds: 400),
                    ),
                    (_) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                l10n.signOutTitle,
                style: AppText.labelMd.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Section header — quiet eyebrow label
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 2),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style:  TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    ),
  );
}

/// Flat card base — the shared CoreGym card language (white surface,
/// subtle border, soft shadow). Optionally tappable with an inline edit
/// badge so editability is discoverable on the data itself.
class _ProfileCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool showEditBadge;
  const _ProfileCard({
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.showEditBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            // Floating edit badge straddles the card border so it can
            // never overlap the data rows inside.
            if (showEditBadge)
              Positioned(
                top: -9,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: .3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pressable card with scale micro-interaction
class _PressCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry? padding;
  const _PressCard({
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.padding,
  });
  @override
  State<_PressCard> createState() => _PressCardState();
}

class _PressCardState extends State<_PressCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _s = Tween<double>(
      begin: 1.0,
      end: .98,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.semanticLabel,
    child: ScaleTransition(
      scale: _s,
      child: GestureDetector(
        onTapDown: (_) => _c.forward(),
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: widget.padding != null
            ? Padding(padding: widget.padding!, child: widget.child)
            : Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: widget.child,
              ),
      ),
    ),
  );
}

/// Compact inline stat for the de-emphasized stats strip
class _InlineStat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _InlineStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: '$value $label',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textMuted,
              letterSpacing: .3,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

/// Flat outline action button (sign-out)
class _FlatActionBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isDestructive;
  final VoidCallback onTap;
  const _FlatActionBtn({
    required this.label,
    required this.icon,
    this.isDestructive = false,
    required this.onTap,
  });
  @override
  State<_FlatActionBtn> createState() => _FlatActionBtnState();
}

class _FlatActionBtnState extends State<_FlatActionBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _s = Tween<double>(
      begin: 1.0,
      end: .97,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.isDestructive ? AppColors.error : AppColors.primary;
    return Semantics(
      button: true,
      label: widget.label,
      child: ScaleTransition(
        scale: _s,
        child: GestureDetector(
          onTapDown: (_) => _c.forward(),
          onTapUp: (_) {
            _c.reverse();
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          onTapCancel: () => _c.reverse(),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 20,
            ),
            decoration: BoxDecoration(
              color: c.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.withOpacity(.22)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: c, size: 20),
                const SizedBox(width: 12),
                Text(
                  widget.label.toUpperCase(),
                  style: AppText.labelMd.copyWith(
                    color: c,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill tag (email, badge labels, session count)
class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool subtle;
  final Color? colorOverride;
  const _Pill({
    required this.label,
    this.icon,
    this.subtle = false,
    this.colorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = colorOverride ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: subtle
            ? AppColors.surfaceContainerHigh
            : baseColor.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: subtle
              ? AppColors.borderSubtle
              : baseColor.withValues(alpha: .25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 11,
              color: subtle ? AppColors.textSecondary : baseColor,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: subtle ? 11 : 10,
              color: subtle ? AppColors.textSecondary : baseColor,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet container
class _Sheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Sheet({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border.all(color: AppColors.borderSubtle),
    ),
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: AppText.headlineSm.copyWith(
                fontSize: 16,
                letterSpacing: 1.8,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...children,
      ],
    ),
  );
}

/// Labelled numeric text field for sheets
class _FieldInput extends StatelessWidget {
  final String label, unit;
  final TextEditingController ctrl;
  final IconData icon;
  final Color color;
  const _FieldInput({
    required this.label,
    required this.unit,
    required this.ctrl,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(.2)),
    ),
    child: TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(icon, color: color, size: 16),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
        suffixText: unit,
        suffixStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
    ),
  );
}

/// Goal dropdown for the edit-data sheet
class _FieldDropdown extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  const _FieldDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.borderSubtle),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: AppColors.surfaceContainerHigh,
        icon:  Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary,
        ),
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        items: items.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

/// Full-width primary save button for sheets
class _SaveBtn extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _SaveBtn({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
      ),
      child: Text(
        label,
        style: AppText.buttonPrimary.copyWith(letterSpacing: 1.5),
      ),
    ),
  );
}

/// Horizontal gradient divider
class _GradientDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          AppColors.borderSubtle,
          Colors.transparent,
        ],
      ),
    ),
  );
}

/// Animated shimmer placeholder used in the skeleton screen
class _Shimmer extends StatefulWidget {
  final double width, height, radius;
  const _Shimmer({
    required this.width,
    required this.height,
    required this.radius,
  });
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _a = Tween<double>(
      begin: .04,
      end: .09,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: _a.value),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

/// Empty state placeholder (icon + label)
class _EmptyState extends StatefulWidget {
  final IconData icon;
  final String label;
  const _EmptyState({required this.icon, required this.label});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, -4 + 8 * Curves.easeInOutSine.transform(_c.value)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.icon,
                  color: AppColors.textMuted,
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: .3,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Ambient radial-gradient orb (non-interactive)
class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    ),
  );
}
