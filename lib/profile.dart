import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:coregym2/supabase/auth_service.dart';
import 'package:coregym2/supabase/profile_service.dart';
import 'package:coregym2/supabase/supabase_config.dart';
import 'services/stats_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';
import 'login_sign_up.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  final _profileService = ProfileService();
  final _statsService   = StatsService();

  bool _isLoading = true;

  // Profile
  String _userName  = 'User';
  String _userEmail = '';
  String _avatarUrl = 'https://images.unsplash.com/photo-1535713875002-d1d0cfd492da?q=80&w=400&auto=format&fit=crop';
  String _age    = '--';
  String _weight = '--';
  String _height = '--';
  String _goal   = '--';

  // Goals
  int _dailyCalories  = 2000;
  int _dailyProtein   = 150;
  int _weeklyWorkouts = 3;

  // Stats
  int    _totalWorkoutsThisMonth  = 0;
  int    _totalCaloriesThisMonth  = 0;
  String _activeProgramName       = 'None';
  int    _totalWorkoutsAllTime    = 0;

  List<Map<String, dynamic>> _exerciseProgress = [];

  // Animations
  late AnimationController _entryCtrl;
  late AnimationController _bgCtrl;
  late List<Animation<double>> _itemFades;
  late List<Animation<Offset>> _itemSlides;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 14))
      ..repeat(reverse: true);

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _itemFades = List.generate(8, (i) => CurvedAnimation(
      parent: _entryCtrl,
      curve: Interval(i * 0.07, i * 0.07 + 0.5, curve: Curves.easeOut),
    ));
    _itemSlides = List.generate(8, (i) =>
      Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: Interval(i * 0.07, i * 0.07 + 0.5, curve: Curves.easeOutCubic),
        ),
      ),
    );

    _loadData();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Widget _a(int i, Widget w) => FadeTransition(
    opacity: _itemFades[i],
    child: SlideTransition(position: _itemSlides[i], child: w),
  );

  // ─── Data ──────────────────────────────────────────────────────────────────

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
      final goals   = results[1] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        if (profile != null) {
          _userName  = profile['name'] ?? profile['full_name'] ?? 'User';
          _userEmail = profile['email'] ?? '';
          _avatarUrl = profile['avatar_url'] ?? _avatarUrl;
          _age    = '${profile['age'] ?? '--'}';
          _weight = profile['weight_kg'] != null ? '${profile['weight_kg']} kg' : '--';
          _height = profile['height_cm'] != null ? '${profile['height_cm']} cm' : '--';
          _goal   = _formatGoal((profile['fitness_goal'] ?? '').toString());
        }
        _dailyCalories  = (goals['daily_calories']  as num?)?.toInt() ?? 2000;
        _dailyProtein   = (goals['daily_protein_g'] as num?)?.toInt() ?? 150;
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
      final db     = SupabaseConfig.client;
      final userId = db.auth.currentUser?.id;
      if (userId == null) return;

      final monthStart = DateTime.now().copyWith(day: 1)
          .toIso8601String().substring(0, 10);

      final results = await Future.wait(<Future<dynamic>>[
        db.from('workout_sessions').select('id').eq('user_id', userId).gte('session_date', monthStart),
        db.from('daily_summary').select('calories_consumed').eq('user_id', userId).gte('summary_date', monthStart),
        db.from('user_active_program').select('*, training_programs(name)').eq('user_id', userId).maybeSingle(),
        db.from('workout_sessions').select('id').eq('user_id', userId),
        db.from('exercise_progress').select().eq('user_id', userId).order('session_date'),
      ]);

      _totalWorkoutsThisMonth = (results[0] as List).length;
      _totalCaloriesThisMonth = (results[1] as List)
          .fold<int>(0, (s, r) => s + ((r['calories_consumed'] as num?)?.toInt() ?? 0));

      final active = results[2] as Map<String, dynamic>?;
      if (active?['training_programs'] != null)
        _activeProgramName = active!['training_programs']['name'] ?? 'None';

      _totalWorkoutsAllTime = (results[3] as List).length;
      _exerciseProgress = List<Map<String, dynamic>>.from(results[4] as List);
    } catch (_) {}
  }

  String _formatGoal(String raw) {
    const map = {
      'weight_loss': 'Weight Loss',
      'muscle_gain': 'Muscle Gain',
      'endurance':   'Endurance',
      'flexibility': 'Flexibility',
      'general_fitness': 'General Fitness',
    };
    return map[raw] ?? (raw.isEmpty ? '--' : raw);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryFixed)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Animated bg orbs
          AnimatedBuilder(animation: _bgCtrl, builder: (_, __) {
            final t = _bgCtrl.value;
            return Stack(children: [
              Positioned(
                top: -80 + 30 * sin(t * pi),
                right: -60 + 20 * cos(t * pi * 1.2),
                child: _Orb(size: 280, color: AppColors.primaryFixed.withOpacity(0.07)),
              ),
              Positioned(
                bottom: -50 + 25 * cos(t * pi * 0.8),
                left: -60,
                child: _Orb(size: 220, color: AppColors.secondary.withOpacity(0.04)),
              ),
            ]);
          }),

          // Body
          RefreshIndicator(
            color: AppColors.primaryFixed,
            onRefresh: _loadData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── SliverAppBar ──
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 260,
                  backgroundColor: AppColors.surface,
                  elevation: 0,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: AppColors.outline, size: 20),
                      onPressed: _loadData,
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: _buildHeroHeader(),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(0),
                    child: Container(
                      height: 0.5,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),

                // ── Content ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Stats strip
                      _a(0, _buildStatsStrip()),
                      const SizedBox(height: 20),

                      // Active program banner
                      _a(1, _buildProgramBanner()),
                      const SizedBox(height: 16),

                      // Operative data
                      _a(2, _SectionLabel('OPERATIVE DATA')),
                      const SizedBox(height: 10),
                      _a(2, _buildInfoCard([
                        _InfoRow(Icons.cake_outlined,          'Age',    _age),
                        _InfoRow(Icons.monitor_weight_outlined, 'Weight', _weight),
                        _InfoRow(Icons.height_outlined,         'Height', _height),
                        _InfoRow(Icons.track_changes_outlined,  'Goal',   _goal),
                      ])),
                      const SizedBox(height: 16),

                      // Daily targets
                      _a(3, _SectionLabel('DAILY TARGETS')),
                      const SizedBox(height: 10),
                      _a(3, _buildTargetsRow()),
                      const SizedBox(height: 16),

                      // This month
                      _a(4, _SectionLabel('THIS MONTH')),
                      const SizedBox(height: 10),
                      _a(4, _buildMonthCard()),
                      const SizedBox(height: 16),

                      // Progress chart
                      if (_exerciseProgress.isNotEmpty) ...[
                        _a(5, _SectionLabel('1RM PROGRESS')),
                        const SizedBox(height: 10),
                        _a(5, _buildProgressChart()),
                        const SizedBox(height: 16),
                      ],

                      // Actions
                      _a(6, _buildEditGoalsBtn()),
                      const SizedBox(height: 10),
                      _a(7, _buildSignOutBtn()),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero header ───────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U';
    return Container(
      decoration: BoxDecoration(color: AppColors.surface),
      child: Stack(
        children: [
          // Top accent line
          Positioned(top: 0, left: 0, right: 0,
            child: Container(height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent, AppColors.primaryFixed, Colors.transparent,
                ]),
              ),
            ),
          ),
          // Content
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                // Avatar
                Stack(alignment: Alignment.center, children: [
                  // Outer glow ring
                  Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppColors.primaryFixed.withOpacity(0.15),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                  // Ring
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryFixed.withOpacity(0.4), width: 1.5),
                    ),
                  ),
                  // Avatar
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    backgroundImage: NetworkImage(_avatarUrl),
                    onBackgroundImageError: (_, __) {},
                    child: Text(initial,
                      style: TextStyle(color: AppColors.primaryFixed,
                        fontWeight: FontWeight.w800, fontSize: 28)),
                  ),
                  // Camera button
                  Positioned(bottom: 2, right: 2,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                // Name
                Text(
                  _userName.toUpperCase(),
                  style: AppText.headlineMd.copyWith(letterSpacing: 1.5, fontSize: 20),
                ),
                const SizedBox(height: 4),
                // Email pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Text(
                    _userEmail,
                    style: AppText.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant, fontSize: 11, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats strip ───────────────────────────────────────────────────────────

  Widget _buildStatsStrip() {
    return Row(children: [
      _StatChip(value: '$_totalWorkoutsAllTime', label: 'Total\nWorkouts',
        icon: Icons.fitness_center_rounded),
      const SizedBox(width: 10),
      _StatChip(value: '$_totalWorkoutsThisMonth', label: 'This\nMonth',
        icon: Icons.calendar_month_rounded),
      const SizedBox(width: 10),
      _StatChip(value: '${(_totalCaloriesThisMonth / 1000).toStringAsFixed(1)}k',
        label: 'kcal\nLogged', icon: Icons.local_fire_department_rounded),
    ]);
  }

  // ─── Program banner ────────────────────────────────────────────────────────

  Widget _buildProgramBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryFixed.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.bolt_rounded, color: AppColors.primaryFixed, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ACTIVE PROGRAM',
            style: TextStyle(fontSize: 9, color: AppColors.primaryFixed,
              fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 2),
          Text(_activeProgramName,
            style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700)),
        ])),
        Icon(Icons.chevron_right_rounded, color: AppColors.primaryFixed, size: 20),
      ]),
    );
  }

  // ─── Info card ─────────────────────────────────────────────────────────────

  Widget _buildInfoCard(List<_InfoRow> rows) {
    return _GlassCard(
      child: Column(
        children: rows.asMap().entries.map((e) {
          final row = e.value;
          final isLast = e.key == rows.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(row.icon, color: AppColors.primaryFixed, size: 16),
                ),
                const SizedBox(width: 12),
                Text(row.label,
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.5)),
                const Spacer(),
                Text(row.value,
                  style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700)),
              ]),
            ),
            if (!isLast)
              Divider(height: 1, color: Colors.white.withOpacity(0.05)),
          ]);
        }).toList(),
      ),
    );
  }

  // ─── Targets row ───────────────────────────────────────────────────────────

  Widget _buildTargetsRow() {
    return Row(children: [
      Expanded(child: _TargetCard(
        icon: Icons.local_fire_department_rounded,
        value: '$_dailyCalories',
        unit: 'kcal',
        label: 'Calories',
        color: AppColors.primaryFixed,
      )),
      const SizedBox(width: 10),
      Expanded(child: _TargetCard(
        icon: Icons.egg_alt_outlined,
        value: '$_dailyProtein',
        unit: 'g',
        label: 'Protein',
        color: const Color(0xFFFF6B6B),
      )),
      const SizedBox(width: 10),
      Expanded(child: _TargetCard(
        icon: Icons.fitness_center_rounded,
        value: '$_weeklyWorkouts×',
        unit: '/wk',
        label: 'Workouts',
        color: const Color(0xFF4DC591),
      )),
    ]);
  }

  // ─── Month card ────────────────────────────────────────────────────────────

  Widget _buildMonthCard() {
    return _GlassCard(
      child: Row(children: [
        Expanded(child: _MonthStat(
          icon: Icons.fitness_center_rounded,
          value: '$_totalWorkoutsThisMonth',
          label: 'Workouts',
          color: AppColors.primaryFixed,
        )),
        Container(width: 1, height: 56,
          color: Colors.white.withOpacity(0.07)),
        Expanded(child: _MonthStat(
          icon: Icons.local_fire_department_rounded,
          value: _totalCaloriesThisMonth > 0
              ? '${(_totalCaloriesThisMonth / 1000).toStringAsFixed(1)}k'
              : '0',
          label: 'Calories',
          color: AppColors.primaryFixed,
        )),
      ]),
    );
  }

  // ─── Progress chart ────────────────────────────────────────────────────────

  Widget _buildProgressChart() {
    if (_exerciseProgress.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    double minY = double.infinity, maxY = 0;
    for (int i = 0; i < _exerciseProgress.length; i++) {
      final v = (_exerciseProgress[i]['one_rm_estimate'] as num?)?.toDouble() ?? 0;
      if (v < minY) minY = v;
      if (v > maxY) maxY = v;
      spots.add(FlSpot(i.toDouble(), v));
    }
    if (minY == double.infinity) minY = 0;
    minY = (minY - 10).clamp(0, double.infinity);
    maxY += 10;

    return _GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 14,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(2),
            )),
          const SizedBox(width: 8),
          Text('Estimated 1RM over time',
            style: AppText.titleSm.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 160,
          child: LineChart(LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.white.withOpacity(0.04), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles:   AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                  style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant)),
              )),
              rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minX: 0, maxX: (spots.length - 1).toDouble(),
            minY: minY, maxY: maxY,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                  '${s.y.toInt()} kg',
                  TextStyle(color: AppColors.primaryFixed, fontWeight: FontWeight.w700, fontSize: 11),
                )).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: AppColors.primaryFixed,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3, color: AppColors.primaryFixed,
                    strokeWidth: 1.5, strokeColor: AppColors.surface,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primaryFixed.withOpacity(0.15),
                      AppColors.primaryFixed.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ],
          )),
        ),
      ]),
    );
  }

  // ─── Action buttons ────────────────────────────────────────────────────────

  Widget _buildEditGoalsBtn() {
    return _ActionButton(
      label: 'EDIT GOALS',
      icon: Icons.tune_rounded,
      onTap: () => _showEditGoalsSheet(context),
    );
  }

  Widget _buildSignOutBtn() {
    return _ActionButton(
      label: 'SIGN OUT',
      icon: Icons.logout_rounded,
      isDestructive: true,
      onTap: () => _showLogoutDialog(context),
    );
  }

  // ─── Edit goals sheet ──────────────────────────────────────────────────────

  void _showEditGoalsSheet(BuildContext context) {
    final calCtrl  = TextEditingController(text: _dailyCalories.toString());
    final protCtrl = TextEditingController(text: _dailyProtein.toString());
    final wkCtrl   = TextEditingController(text: _weeklyWorkouts.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(children: [
              Container(width: 3, height: 18,
                decoration: BoxDecoration(color: AppColors.primaryFixed, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text('EDIT GOALS', style: AppText.headlineSm.copyWith(fontSize: 18, letterSpacing: 1.5)),
            ]),
            const SizedBox(height: 24),
            _GoalInput(label: 'Daily Calories', unit: 'kcal', controller: calCtrl,
              icon: Icons.local_fire_department_rounded, color: AppColors.primaryFixed),
            const SizedBox(height: 12),
            _GoalInput(label: 'Daily Protein', unit: 'g', controller: protCtrl,
              icon: Icons.egg_alt_outlined, color: const Color(0xFFFF6B6B)),
            const SizedBox(height: 12),
            _GoalInput(label: 'Weekly Workouts', unit: '×', controller: wkCtrl,
              icon: Icons.fitness_center_rounded, color: const Color(0xFF4DC591)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    final db = SupabaseConfig.client;
                    final uid = db.auth.currentUser?.id;
                    if (uid != null) {
                      await db.from('user_goals').upsert({
                        'user_id': uid,
                        'daily_calories':  int.tryParse(calCtrl.text)  ?? _dailyCalories,
                        'daily_protein_g': int.tryParse(protCtrl.text) ?? _dailyProtein,
                        'weekly_workouts': int.tryParse(wkCtrl.text)   ?? _weeklyWorkouts,
                        'updated_at': DateTime.now().toIso8601String(),
                      }, onConflict: 'user_id');
                    }
                  } catch (_) {}
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) _loadData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryFixed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('SAVE GOALS',
                  style: AppText.buttonPrimary.copyWith(color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── Logout dialog ─────────────────────────────────────────────────────────

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.error.withOpacity(0.3)),
        ),
        icon: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
        ),
        title: Text('Sign Out',
          style: AppText.headlineSm.copyWith(fontSize: 18), textAlign: TextAlign.center),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancel', style: AppText.labelMd.copyWith(color: AppColors.outline)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder: (_, a, __) => const AuthWrapper(),
                    transitionsBuilder: (_, a, __, child) => FadeTransition(
                      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
                      child: child,
                    ),
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Sign Out',
              style: AppText.labelMd.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-components
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Row(children: [
      Container(width: 3, height: 12,
        decoration: BoxDecoration(
          color: AppColors.primaryFixed.withOpacity(0.6),
          borderRadius: BorderRadius.circular(2),
        )),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(
        fontSize: 10, color: AppColors.onSurfaceVariant,
        fontWeight: FontWeight.w700, letterSpacing: 2,
      )),
    ]),
  );
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.glass1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: child,
      ),
    ),
  );
}

class _StatChip extends StatelessWidget {
  final String value, label;
  final IconData icon;
  const _StatChip({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: [
        Icon(icon, color: AppColors.primaryFixed, size: 18),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
          fontSize: 9, color: AppColors.onSurfaceVariant,
          letterSpacing: 0.5, height: 1.4), textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _TargetCard extends StatelessWidget {
  final IconData icon;
  final String value, unit, label;
  final Color color;
  const _TargetCard({required this.icon, required this.value,
    required this.unit, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 6),
      RichText(text: TextSpan(children: [
        TextSpan(text: value, style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        TextSpan(text: unit, style: TextStyle(
          fontSize: 10, color: AppColors.onSurfaceVariant)),
      ])),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _MonthStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _MonthStat({required this.icon, required this.value,
    required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: 20),
    const SizedBox(height: 8),
    Text(value, style: TextStyle(
      fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant,
      letterSpacing: 1)),
  ]);
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isDestructive;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon,
    this.isDestructive = false, required this.onTap});
  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(_ctrl);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive ? AppColors.error : AppColors.primaryFixed;
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
        onTapCancel: () => _ctrl.reverse(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(widget.icon, color: color, size: 18),
                const SizedBox(width: 10),
                Text(widget.label, style: AppText.labelMd.copyWith(
                  color: widget.isDestructive ? color : AppColors.onSurface,
                  letterSpacing: 2, fontWeight: FontWeight.w800,
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalInput extends StatelessWidget {
  final String label, unit;
  final TextEditingController controller;
  final IconData icon;
  final Color color;
  const _GoalInput({required this.label, required this.unit,
    required this.controller, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: color, size: 18),
        labelText: label,
        labelStyle: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
        suffixText: unit,
        suffixStyle: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  );
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    ),
  );
}