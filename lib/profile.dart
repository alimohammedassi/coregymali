import 'dart:math';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:coregym2/l10n/app_localizations.dart';
import 'package:coregym2/supabase/auth_service.dart';
import 'package:coregym2/supabase/profile_service.dart';
import 'package:coregym2/supabase/supabase_config.dart';
import 'services/stats_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';
import 'login_sign_up.dart';
import 'widgets/language_toggle.dart';
import 'features/coach/presentation/screens/coach_registration_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS  (single source of truth)
// ─────────────────────────────────────────────────────────────────────────────
abstract class _D {
  // ── 4/8dp spacing grid ──────────────────────────────────────────────────
  static const double sp2 = 2;
  static const double sp4 = 4;
  static const double sp6 = 6;
  static const double sp8 = 8;
  static const double sp10 = 10;
  static const double sp12 = 12;
  static const double sp16 = 16;
  static const double sp20 = 20;
  static const double sp24 = 24;
  static const double sp32 = 32;
  static const double sp48 = 48;

  // ── Radius scale ─────────────────────────────────────────────────────────
  static const double r6 = 6;
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;
  static const double r28 = 28;

  // ── Icon scale (consistent stroke-weight family) ─────────────────────────
  static const double iconXs = 14;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;

  // ── Touch targets ────────────────────────────────────────────────────────
  static const double touch = 44; // Apple HIG / Material minimum

  // ── Semantic brand colours ───────────────────────────────────────────────
  static const Color gold = Color(0xFFC9A84C);
  static const Color red = Color(0xFFFF6B6B);
  static const Color green = Color(0xFF50C878);
  static const Color blue = Color(0xFF6C9BF5);

  // ── Opacity scale ────────────────────────────────────────────────────────
  static const double o03 = 0.03;
  static const double o05 = 0.05;
  static const double o07 = 0.07;
  static const double o10 = 0.10;
  static const double o15 = 0.15;
  static const double o20 = 0.20;
  static const double o25 = 0.25;
  static const double o40 = 0.40;
  static const double o50 = 0.50;
  static const double o55 = 0.55;
  static const double o70 = 0.70;

  // ── Duration scale ───────────────────────────────────────────────────────
  static const Duration t100 = Duration(milliseconds: 100);
  static const Duration t150 = Duration(milliseconds: 150);
  static const Duration t200 = Duration(milliseconds: 200);
  static const Duration t300 = Duration(milliseconds: 300);
  static const Duration t1000 = Duration(milliseconds: 1000);
  static const Duration bgLoop = Duration(seconds: 18);
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  // ── Services ──────────────────────────────────────────────────────────────
  final _profileService = ProfileService();
  final _statsService = StatsService();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isUploadingAvatar = false;

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

    _bgCtrl = AnimationController(vsync: this, duration: _D.bgLoop)
      ..repeat(reverse: true);

    _entryCtrl = AnimationController(vsync: this, duration: _D.t1000);

    _avatarCtrl = AnimationController(vsync: this, duration: _D.t150);
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
        _D.green,
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
              const SizedBox(width: _D.sp12),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.surfaceContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_D.r12),
            side: BorderSide(color: color.withOpacity(.3)),
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
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          _buildAmbientBg(),
          RefreshIndicator(
            color: AppColors.primaryFixed,
            backgroundColor: AppColors.surfaceContainer,
            displacement: 60,
            onRefresh: _loadData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    _D.sp20,
                    _D.sp8,
                    _D.sp20,
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
    backgroundColor: AppColors.surface,
    body: SafeArea(
      child: Column(
        children: [
          const SizedBox(height: _D.sp32),
          Center(child: _Shimmer(width: 86, height: 86, radius: 43)),
          const SizedBox(height: _D.sp16),
          Center(child: _Shimmer(width: 140, height: 14, radius: _D.r8)),
          const SizedBox(height: _D.sp8),
          Center(child: _Shimmer(width: 100, height: 10, radius: _D.r6)),
          const SizedBox(height: _D.sp32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _D.sp20),
            child: Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : _D.sp8),
                    child: _Shimmer(
                      width: double.infinity,
                      height: 80,
                      radius: _D.r16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: _D.sp16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _D.sp20),
            child: _Shimmer(width: double.infinity, height: 72, radius: _D.r16),
          ),
          const SizedBox(height: _D.sp16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _D.sp20),
            child: _Shimmer(
              width: double.infinity,
              height: 160,
              radius: _D.r16,
            ),
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
            child: _Orb(
              size: 280,
              color: AppColors.primaryFixed.withOpacity(.06),
            ),
          ),
          Positioned(
            bottom: -50 + 24 * cos(t * pi * .7),
            left: -60,
            child: _Orb(size: 220, color: AppColors.secondary.withOpacity(.04)),
          ),
          Positioned(
            top:
                MediaQuery.of(context).size.height * .42 +
                18 * sin(t * pi * 1.1),
            right: -30,
            child: _Orb(size: 150, color: _D.gold.withOpacity(.025)),
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
        height: _D.touch,
        child: const LanguageToggle(compact: true),
      ),
      const SizedBox(width: _D.sp4),
      Semantics(
        label: 'Refresh profile',
        button: true,
        child: IconButton(
          icon: Icon(
            Icons.refresh_rounded,
            color: AppColors.outline,
            size: _D.iconMd,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            _loadData();
          },
          tooltip: 'Refresh',
          splashRadius: 20,
        ),
      ),
      const SizedBox(width: _D.sp8),
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
              Colors.white.withOpacity(.06),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ),
  );

  // ── Rank Calculation ──────────────────────────────────────────────────────
  ({String label, Color color}) _getRank() {
    if (_totalWorkoutsAllTime < 5) {
      return (label: 'ROOKIE', color: AppColors.onSurfaceVariant);
    }
    if (_totalWorkoutsAllTime < 20) {
      return (label: 'IRON', color: Colors.blueGrey);
    }
    if (_totalWorkoutsAllTime < 50) {
      return (label: 'BRONZE', color: const Color(0xFFCD7F32));
    }
    if (_totalWorkoutsAllTime < 100) {
      return (label: 'SILVER', color: const Color(0xFFE5E4E2));
    }
    return (label: 'GOLD', color: _D.gold);
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
                Icon(Icons.fullscreen_rounded, color: AppColors.primaryFixed),
                const SizedBox(width: _D.sp16),
                Text(
                  'View Photo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _D.sp12),
        ],
        _PressCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          onTap: () {
            Navigator.pop(ctx);
            _pickAndUpload();
          },
          child: Row(
            children: [
              Icon(Icons.photo_library_rounded, color: AppColors.primaryFixed),
              const SizedBox(width: _D.sp16),
              Text(
                hasAvatar ? 'Change Photo' : 'Upload Photo',
                style: const TextStyle(
                  color: Colors.white,
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
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Hero(
              tag: 'profile_avatar_hero',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_D.r24),
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
          // Gold accent stripe at the top
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
                    AppColors.primaryFixed.withOpacity(.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _D.sp20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: _D.sp20),

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
                                      AppColors.primaryFixed.withOpacity(.18),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              // Gold ring
                              Container(
                                width: 98,
                                height: 98,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primaryFixed.withOpacity(
                                      .5,
                                    ),
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
                                            color: AppColors.primaryFixed,
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
                                    color: Colors.black.withOpacity(.5),
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
                                      color: AppColors.primaryFixed,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.surface,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryFixed
                                              .withOpacity(.45),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: _D.sp16),

                  // ── Name ────────────────────────────────────────────────
                  Text(
                    _userName.toUpperCase(),
                    style: AppText.headlineMd.copyWith(
                      letterSpacing: 2.0,
                      fontSize: 20,
                      height: 1.1,
                    ),
                  ),

                  const SizedBox(height: _D.sp10),

                  // ── Badges Row ──────────────────────────────────────────
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: _D.sp8,
                    runSpacing: _D.sp8,
                    children: [
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

                  const SizedBox(height: _D.sp20),
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
      const SizedBox(height: _D.sp20),

      _A(1, _buildProgramBanner()),
      const SizedBox(height: _D.sp20),

      _A(
        2,
        _SectionHeader(
          title: l10n.operativeData,
          action: _HeaderAction(
            label: 'Edit',
            icon: Icons.edit_rounded,
            onTap: () => _showEditDataSheet(context),
          ),
        ),
      ),
      const SizedBox(height: _D.sp10),
      _A(2, _buildMetricsCard()),
      const SizedBox(height: _D.sp20),

      _A(
        3,
        _SectionHeader(
          title: l10n.dailyTargets,
          action: _HeaderAction(
            label: 'Edit',
            icon: Icons.tune_rounded,
            onTap: () => _showEditGoalsSheet(context),
          ),
        ),
      ),
      const SizedBox(height: _D.sp10),
      _A(3, _buildTargetsRow()),
      const SizedBox(height: _D.sp20),

      _A(4, _SectionHeader(title: l10n.thisMonth)),
      const SizedBox(height: _D.sp10),
      _A(4, _buildMonthCard()),
      const SizedBox(height: _D.sp20),

      if (_exerciseProgress.isNotEmpty) ...[
        _A(5, _SectionHeader(title: l10n.rmProgress)),
        const SizedBox(height: _D.sp10),
        _A(5, _buildProgressChart()),
        const SizedBox(height: _D.sp20),
      ],

      _A(6, _GradientDivider()),
      const SizedBox(height: _D.sp24),

      _A(7, _buildCoachCta()),
      const SizedBox(height: _D.sp10),

      _A(8, _buildSignOutBtn()),
    ];
  }

  // ── Stats row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        _StatChip(
          value: '$_totalWorkoutsAllTime',
          label: l10n.totalWorkouts,
          icon: Icons.fitness_center_rounded,
          color: AppColors.primaryFixed,
        ),
        const SizedBox(width: _D.sp8),
        _StatChip(
          value: '$_totalWorkoutsThisMonth',
          label: l10n.thisMonthWorkouts,
          icon: Icons.calendar_month_rounded,
          color: _D.blue,
        ),
        const SizedBox(width: _D.sp8),
        _StatChip(
          value: '${(_totalCaloriesThisMonth / 1000).toStringAsFixed(1)}k',
          label: l10n.kcalLogged,
          icon: Icons.local_fire_department_rounded,
          color: _D.red,
        ),
      ],
    );
  }

  // ── Program banner ────────────────────────────────────────────────────────
  Widget _buildProgramBanner() => _PressCard(
    semanticLabel: 'Active program: $_activeProgramName. Tap to view.',
    onTap: () => HapticFeedback.lightImpact(),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withOpacity(_D.o15),
            borderRadius: BorderRadius.circular(_D.r12),
          ),
          child: Icon(
            Icons.bolt_rounded,
            color: AppColors.primaryFixed,
            size: _D.iconLg,
          ),
        ),
        const SizedBox(width: _D.sp16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.activeProgram2.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.primaryFixed,
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
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          color: AppColors.primaryFixed.withOpacity(_D.o70),
          size: _D.iconMd,
        ),
      ],
    ),
  );

  // ── Metrics card ──────────────────────────────────────────────────────────
  Widget _buildMetricsCard() {
    final l10n = AppLocalizations.of(context)!;
    final rows = [
      _MetricRow(Icons.cake_outlined, l10n.age, _age, _D.blue),
      _MetricRow(Icons.monitor_weight_outlined, l10n.weight, _weight, _D.red),
      _MetricRow(Icons.height_outlined, l10n.height, _height, _D.green),
      _MetricRow(
        Icons.track_changes_outlined,
        l10n.goal,
        _goal,
        AppColors.primaryFixed,
      ),
    ];
    return _GlassCard(
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final isLast = index == rows.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: row.color.withOpacity(_D.o10),
                        borderRadius: BorderRadius.circular(_D.r8),
                      ),
                      child: Icon(row.icon, color: row.color, size: _D.iconSm),
                    ),
                    const SizedBox(width: _D.sp12),
                    Text(
                      row.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: .3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      row.value,
                      style: AppText.titleSm.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(height: 1, color: Colors.white.withOpacity(.05)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Daily targets ─────────────────────────────────────────────────────────
  Widget _buildTargetsRow() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _TargetTile(
            icon: Icons.local_fire_department_rounded,
            value: '$_dailyCalories',
            unit: l10n.kcal,
            label: l10n.caloriesLabel,
            color: AppColors.primaryFixed,
          ),
        ),
        const SizedBox(width: _D.sp8),
        Expanded(
          child: _TargetTile(
            icon: Icons.egg_alt_outlined,
            value: '$_dailyProtein',
            unit: 'g',
            label: l10n.proteinGoal,
            color: _D.red,
          ),
        ),
        const SizedBox(width: _D.sp8),
        Expanded(
          child: _TargetTile(
            icon: Icons.fitness_center_rounded,
            value: '$_weeklyWorkouts',
            unit: '×/wk',
            label: l10n.workoutsLabel,
            color: _D.green,
          ),
        ),
      ],
    );
  }

  // ── Month card ────────────────────────────────────────────────────────────
  Widget _buildMonthCard() {
    final l10n = AppLocalizations.of(context)!;
    return _GlassCard(
      child: Row(
        children: [
          Expanded(
            child: _MonthCell(
              icon: Icons.fitness_center_rounded,
              value: '$_totalWorkoutsThisMonth',
              label: l10n.workoutsLabel,
              color: AppColors.primaryFixed,
            ),
          ),
          Container(width: 1, height: 60, color: Colors.white.withOpacity(.07)),
          Expanded(
            child: _MonthCell(
              icon: Icons.local_fire_department_rounded,
              value: _totalCaloriesThisMonth > 0
                  ? '${(_totalCaloriesThisMonth / 1000).toStringAsFixed(1)}k'
                  : '0',
              label: l10n.caloriesLabel,
              color: _D.red,
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress chart ────────────────────────────────────────────────────────
  Widget _buildProgressChart() {
    if (_exerciseProgress.isEmpty) {
      return _GlassCard(
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

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: _D.sp8),
              Text(
                AppLocalizations.of(context)!.estimatedOneRM,
                style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _Pill(label: '${spots.length} sessions'),
            ],
          ),
          const SizedBox(height: _D.sp20),
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
                      color: Colors.white.withOpacity(.04),
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
                            color: AppColors.onSurfaceVariant,
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
                                color: AppColors.onSurfaceVariant.withOpacity(
                                  .8,
                                ),
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
                      getTooltipColor: (_) => AppColors.surfaceContainer,
                      getTooltipItems: (touchedSpots) => touchedSpots
                          .map(
                            (spot) => LineTooltipItem(
                              '${spot.y.toInt()} kg',
                              TextStyle(
                                color: AppColors.primaryFixed,
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
                      color: AppColors.primaryFixed,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 3.5,
                          color: AppColors.primaryFixed,
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
                            AppColors.primaryFixed.withOpacity(.18),
                            AppColors.primaryFixed.withOpacity(0),
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

  // ── Coach CTA ─────────────────────────────────────────────────────────────
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
        constraints: const BoxConstraints(minHeight: _D.touch),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_D.r16),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_D.gold.withOpacity(.22), _D.gold.withOpacity(.10)],
          ),
          border: Border.all(color: _D.gold.withOpacity(.45), width: 1),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: _D.sp16,
          horizontal: _D.sp20,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _D.gold.withOpacity(_D.o15),
                borderRadius: BorderRadius.circular(_D.r12),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: _D.gold,
                size: _D.iconLg,
              ),
            ),
            const SizedBox(width: _D.sp16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BECOME A COACH',
                    style: TextStyle(
                      fontSize: 10,
                      color: _D.gold,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Unlock coaching tools & clients',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: _D.gold.withOpacity(.7),
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
          color: _D.blue,
        ),
        const SizedBox(height: _D.sp12),
        _FieldInput(
          label: AppLocalizations.of(context)!.weight,
          unit: AppLocalizations.of(context)!.kg,
          ctrl: weightCtrl,
          icon: Icons.monitor_weight_outlined,
          color: _D.red,
        ),
        const SizedBox(height: _D.sp12),
        _FieldInput(
          label: AppLocalizations.of(context)!.height,
          unit: 'cm',
          ctrl: heightCtrl,
          icon: Icons.height_outlined,
          color: _D.green,
        ),
        const SizedBox(height: _D.sp12),
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
        const SizedBox(height: _D.sp24),
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
          color: AppColors.primaryFixed,
        ),
        const SizedBox(height: _D.sp12),
        _FieldInput(
          label: l10n.dailyProtein,
          unit: 'g',
          ctrl: proCtrl,
          icon: Icons.egg_alt_outlined,
          color: _D.red,
        ),
        const SizedBox(height: _D.sp12),
        _FieldInput(
          label: l10n.weeklyWorkoutsLabel,
          unit: '×',
          ctrl: wkCtrl,
          icon: Icons.fitness_center_rounded,
          color: _D.green,
        ),
        const SizedBox(height: _D.sp24),
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
      barrierColor: Colors.black.withOpacity(_D.o50),
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
      barrierColor: Colors.black.withOpacity(_D.o55),
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_D.r20),
          side: BorderSide(color: AppColors.error.withOpacity(.25)),
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          _D.sp24,
          _D.sp20,
          _D.sp24,
          _D.sp24,
        ),
        titlePadding: const EdgeInsets.fromLTRB(_D.sp24, _D.sp24, _D.sp24, 0),
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
            size: _D.iconLg,
          ),
        ),
        title: Text(
          l10n.signOutTitle,
          style: AppText.headlineSm.copyWith(fontSize: 18),
          textAlign: TextAlign.center,
        ),
        content: Text(
          l10n.signOutConfirm,
          style: AppText.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(_D.sp16, 0, _D.sp16, _D.sp20),
        actions: [
          SizedBox(
            height: _D.touch,
            child: TextButton(
              onPressed: () => Navigator.pop(dCtx),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: _D.sp24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_D.r12),
                  side: BorderSide(color: Colors.white.withOpacity(.1)),
                ),
              ),
              child: Text(
                l10n.cancel,
                style: AppText.labelMd.copyWith(color: AppColors.outline),
              ),
            ),
          ),
          const SizedBox(width: _D.sp12),
          SizedBox(
            height: _D.touch,
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
                padding: const EdgeInsets.symmetric(horizontal: _D.sp24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_D.r12),
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

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────
class _MetricRow {
  final IconData icon;
  final String label, value;
  final Color color;
  const _MetricRow(this.icon, this.label, this.value, this.color);
}

class _HeaderAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Section header with optional trailing text-icon action
class _SectionHeader extends StatelessWidget {
  final String title;
  final _HeaderAction? action;
  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 2),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withOpacity(.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: _D.sp8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        if (action != null) ...[
          const Spacer(),
          SizedBox(
            height: _D.touch,
            child: TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                action!.onTap();
              },
              icon: Icon(action!.icon, size: 13, color: AppColors.primaryFixed),
              label: Text(
                action!.label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryFixed,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .5,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: _D.sp12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Glassmorphism card base
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(_D.r16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        padding: const EdgeInsets.all(_D.sp16),
        decoration: BoxDecoration(
          color: AppColors.glass1,
          borderRadius: BorderRadius.circular(_D.r16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: child,
      ),
    ),
  );
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
    _c = AnimationController(vsync: this, duration: _D.t150);
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
                padding: const EdgeInsets.all(_D.sp16),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.withOpacity(_D.o07),
                  borderRadius: BorderRadius.circular(_D.r16),
                  border: Border.all(
                    color: AppColors.primaryFixed.withOpacity(_D.o20),
                  ),
                ),
                child: widget.child,
              ),
      ),
    ),
  );
}

/// Stat chip (3 across in a row)
class _StatChip extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatChip({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: '$value $label',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(_D.r16),
          border: Border.all(color: Colors.white.withOpacity(.06)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: _D.iconMd),
            const SizedBox(height: _D.sp8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: AppColors.onSurfaceVariant,
                letterSpacing: .4,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Daily target tile
class _TargetTile extends StatelessWidget {
  final IconData icon;
  final String value, unit, label;
  final Color color;
  const _TargetTile({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $unit $label',
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(_D.o07),
        borderRadius: BorderRadius.circular(_D.r16),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: _D.iconMd),
          const SizedBox(height: _D.sp8),
          FittedBox(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: unit,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: .3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

/// Month stat cell
class _MonthCell extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _MonthCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $label',
    child: Column(
      children: [
        Icon(icon, color: color, size: _D.iconLg),
        const SizedBox(height: _D.sp8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
    _c = AnimationController(vsync: this, duration: _D.t150);
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
    final c = widget.isDestructive ? AppColors.error : AppColors.primaryFixed;
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
            constraints: const BoxConstraints(minHeight: _D.touch),
            padding: const EdgeInsets.symmetric(
              vertical: _D.sp16,
              horizontal: _D.sp20,
            ),
            decoration: BoxDecoration(
              color: c.withOpacity(_D.o07),
              borderRadius: BorderRadius.circular(_D.r16),
              border: Border.all(color: c.withOpacity(.22)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: c, size: _D.iconMd),
                const SizedBox(width: _D.sp12),
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
    final baseColor = colorOverride ?? AppColors.primaryFixed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: subtle
            ? Colors.white.withOpacity(.05)
            : baseColor.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: subtle
              ? Colors.white.withOpacity(.09)
              : baseColor.withOpacity(.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 11,
              color: subtle ? AppColors.onSurfaceVariant : baseColor,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: subtle ? 11 : 10,
              color: subtle ? AppColors.onSurfaceVariant : baseColor,
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
      color: AppColors.surfaceContainer,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(_D.r24)),
      border: Border.all(color: Colors.white.withOpacity(.07)),
    ),
    padding: const EdgeInsets.fromLTRB(_D.sp24, 0, _D.sp24, _D.sp32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: _D.sp20),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.15),
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
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: _D.sp12),
            Text(
              title,
              style: AppText.headlineSm.copyWith(
                fontSize: 16,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: _D.sp24),
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
      borderRadius: BorderRadius.circular(_D.r12),
      border: Border.all(color: color.withOpacity(.2)),
    ),
    child: TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _D.sp12),
          child: Icon(icon, color: color, size: _D.iconSm),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: _D.touch,
          minHeight: _D.touch,
        ),
        labelText: label,
        labelStyle: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
        suffixText: unit,
        suffixStyle: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          vertical: _D.sp16,
          horizontal: _D.sp16,
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
    padding: const EdgeInsets.symmetric(horizontal: _D.sp16),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(_D.r12),
      border: Border.all(color: Colors.white.withOpacity(.08)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: AppColors.surfaceContainerHigh,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.onSurfaceVariant,
        ),
        style: const TextStyle(
          color: Colors.white,
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
        backgroundColor: AppColors.primaryFixed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_D.r16),
        ),
        elevation: 0,
      ),
      child: Text(
        label,
        style: AppText.buttonPrimary.copyWith(
          color: Colors.white,
          letterSpacing: 1.5,
        ),
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
          Colors.white.withOpacity(.08),
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
      end: .10,
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
        color: Colors.white.withOpacity(_a.value),
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
    padding: const EdgeInsets.symmetric(vertical: _D.sp32),
    child: Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, -4 + 8 * Curves.easeInOutSine.transform(_c.value)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: AppColors.onSurfaceVariant.withOpacity(.7),
                size: 36,
              ),
              const SizedBox(height: _D.sp12),
              Text(
                widget.label,
                style: TextStyle(
                  color: AppColors.onSurfaceVariant.withOpacity(.8),
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
