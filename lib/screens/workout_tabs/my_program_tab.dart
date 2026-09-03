import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_semantic_colors.dart';
import '../../theme/app_text.dart';
import '../../services/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../progrems.dart';

class MyProgramTab extends StatefulWidget {
  const MyProgramTab({super.key});

  @override
  State<MyProgramTab> createState() => _MyProgramTabState();
}

class _MyProgramTabState extends State<MyProgramTab>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _activeProgram;

  late AnimationController _heroController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;

  // Consistent level accent mapping — single source of truth app-wide
  static const Map<String, Color> _levelColors = AppSemanticColors.level;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heroFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOut));

    _loadActiveProgram();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveProgram() async {
    try {
      if (currentUserId == null) return;
      final data = await supabase
          .from('user_active_program')
          .select('*, training_programs(*)')
          .eq('user_id', currentUserId!)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _activeProgram = data;
          _isLoading = false;
        });
        if (data != null) _heroController.forward();
      }
    } on PostgrestException catch (e) {
      debugPrint('DB Error [${e.code}]: ${e.message}');
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading active program: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (_activeProgram == null) {
      return _buildEmptyState();
    }

    final progData = _activeProgram!['training_programs'] ?? {};
    final String progName = progData['name'] ?? 'Unknown';
    final String progNameAr = progData['name_ar'] ?? '';
    final String level = progData['level'] ?? '';
    final int currentWeek = _activeProgram!['current_week'] ?? 1;
    final int totalWeeks = progData['duration_weeks'] ?? 1;
    final double progress = (currentWeek / totalWeeks).clamp(0.0, 1.0);

    final levelColor = _levelColors[level] ?? AppColors.primary;

    return FadeTransition(
      opacity: _heroFade,
      child: SlideTransition(
        position: _heroSlide,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero Program Card ──────────────────────────
              _buildHeroCard(
                progName: progName,
                progNameAr: progNameAr,
                level: level,
                levelColor: levelColor,
                currentWeek: currentWeek,
                totalWeeks: totalWeeks,
                progress: progress,
                progData: progData,
              ),

              const SizedBox(height: 24),

              // ── Weekly snapshot ────────────────────────────
              Row(
                children: [
                  _statCard('${progData['days_per_week'] ?? 4}', 'Days/Week',
                      Icons.calendar_month_rounded, AppColors.purpleAccent),
                  const SizedBox(width: 12),
                  _statCard('$totalWeeks', 'Total Weeks',
                      Icons.timelapse_rounded, AppColors.secondary),
                  const SizedBox(width: 12),
                  _statCard('${(progress * 100).round()}%', 'Complete',
                      Icons.pie_chart_rounded, AppColors.primary),
                ],
              ),

              const SizedBox(height: 28),

              // ── Today's Workout ────────────────────────────
              _sectionLabel('TODAY\'S WORKOUT'),
              const SizedBox(height: 12),
              _buildWorkoutCard(
                progName: progName,
                currentWeek: currentWeek,
                totalWeeks: totalWeeks,
                currentDay: (_activeProgram!['current_day'] ?? 1) as int,
                daysPerWeek: (progData['days_per_week'] ?? 4) as int,
              ),

              const SizedBox(height: 28),

              // ── Weekly Schedule ────────────────────────────
              _sectionLabel('THIS WEEK'),
              const SizedBox(height: 12),
              _buildWeekRow(
                currentDay: (_activeProgram!['current_day'] ?? 1) as int,
                daysPerWeek: (progData['days_per_week'] ?? 4) as int,
              ),

              const SizedBox(height: 32),

              // ── CTA ────────────────────────────────────────
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _showMuscleSelection(context);
                },
                child: Container(
                  width: double.infinity,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryActionGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'START TODAY\'S WORKOUT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      );

  Widget _buildHeroCard({
    required String progName,
    required String progNameAr,
    required String level,
    required Color levelColor,
    required int currentWeek,
    required int totalWeeks,
    required double progress,
    required Map<String, dynamic> progData,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Level badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: levelColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  level.toUpperCase(),
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              // Week counter
              Row(
                children: [
                  Text(
                    'WEEK',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        letterSpacing: 1),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$currentWeek/$totalWeeks',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            progName,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          if (progNameAr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                progNameAr,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),

          if (progData['description'] != null) ...[
            const SizedBox(height: 12),
            Text(
              progData['description'],
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 22),

          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PROGRESS',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      color: levelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.borderSubtle,
                  valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      String value, String label, IconData icon, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard({
    required String progName,
    required int currentWeek,
    required int totalWeeks,
    required int currentDay,
    required int daysPerWeek,
  }) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // Opens the same training flow as the START CTA below — the
            // muscle-picker sheet is the app's real session entry point.
            onTap: () {
              HapticFeedback.mediumImpact();
              _showMuscleSelection(context);
            },
            splashColor: AppColors.primary.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Day $currentDay — $progName',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$daysPerWeek sessions/week  •  Week $currentWeek of $totalWeeks',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekRow({required int currentDay, required int daysPerWeek}) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    // Derive the training days from the program's days_per_week instead of
    // hardcoding Mon/Wed/Fri: distribute the sessions evenly across the week.
    final workoutDays = <int>{
      for (var i = 0; i < daysPerWeek.clamp(1, 7); i++)
        (i * 7 / daysPerWeek).floor()
    };

    return Row(
      children: List.generate(7, (i) {
        final isWorkout = workoutDays.contains(i);
        // Monday-first index of today (DateTime.weekday: Mon=1..Sun=7)
        final isToday = i == DateTime.now().weekday - 1;
        final isDone = i < currentDay - 1 && !isToday;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.primary
                        : isDone
                            ? AppColors.primary.withValues(alpha: .12)
                            : isWorkout
                                ? AppColors.surfaceContainerHigh
                                : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isWorkout && !isToday && !isDone
                          ? AppColors.borderSubtle
                          : Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.greenAccent, size: 16)
                        : isWorkout
                            ? Icon(
                                Icons.fitness_center_rounded,
                                size: 14,
                                color: isToday
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              )
                            : Text('—',
                                style: TextStyle(
                                    color: AppColors.outlineVariant,
                                    fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  days[i],
                  style: TextStyle(
                    color: isToday
                        ? AppColors.primary
                        : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight:
                        isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 38,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Program',
              style: AppText.headlineMd.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Head to the Library tab to pick a program and start your journey.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMuscleSelection(BuildContext context) {
    if (_activeProgram == null) return;

    final progData = _activeProgram!['training_programs'] ?? {};
    final String progName =
        progData['name']?.toString().toLowerCase() ?? '';

    List<Map<String, dynamic>> options = [];

    if (progName.contains('push') || progName.contains('ppl')) {
      options = [
        {
          'label': 'Push Day',
          'id': 'push',
          'icon': Icons.pan_tool,
          'color': AppSemanticColors.forMuscle('Chest')
        },
        {
          'label': 'Pull Day',
          'id': 'pull',
          'icon': Icons.fitness_center,
          'color': AppSemanticColors.forMuscle('Back')
        },
        {
          'label': 'Legs Day',
          'id': 'legs',
          'icon': Icons.directions_run,
          'color': AppSemanticColors.forMuscle('Legs')
        },
        {
          'label': 'Core / Abs',
          'id': 'core',
          'icon': Icons.self_improvement,
          'color': AppSemanticColors.forMuscle('Core')
        },
      ];
    } else if (progName.contains('upper') || progName.contains('lower')) {
      options = [
        {
          'label': 'Upper Body',
          'id': 'upper',
          'icon': Icons.fitness_center,
          'color': AppSemanticColors.forMuscle('Back')
        },
        {
          'label': 'Lower Body',
          'id': 'lower',
          'icon': Icons.directions_run,
          'color': AppSemanticColors.forMuscle('Legs')
        },
        {
          'label': 'Core / Abs',
          'id': 'core',
          'icon': Icons.self_improvement,
          'color': AppSemanticColors.forMuscle('Core')
        },
      ];
    } else if (progName.contains('full')) {
      options = [
        {
          'label': 'Full Body',
          'id': 'full_body',
          'icon': Icons.accessibility_new,
          'color': AppColors.primary
        },
        {
          'label': 'Core / Abs',
          'id': 'core',
          'icon': Icons.self_improvement,
          'color': AppSemanticColors.forMuscle('Core')
        },
      ];
    } else {
      options = [
        {
          'label': 'Chest',
          'id': 'chest',
          'icon': Icons.fitness_center,
          'color': AppSemanticColors.forMuscle('Chest')
        },
        {
          'label': 'Back',
          'id': 'back',
          'icon': Icons.airline_seat_flat_angled,
          'color': AppSemanticColors.forMuscle('Back')
        },
        {
          'label': 'Shoulders',
          'id': 'shoulders',
          'icon': Icons.accessibility,
          'color': AppSemanticColors.forMuscle('Shoulders')
        },
        {
          'label': 'Arms',
          'id': 'arms',
          'icon': Icons.sports_gymnastics,
          'color': AppSemanticColors.forMuscle('Arms')
        },
        {
          'label': 'Legs',
          'id': 'legs',
          'icon': Icons.directions_run,
          'color': AppSemanticColors.forMuscle('Legs')
        },
        {
          'label': 'Core',
          'id': 'core',
          'icon': Icons.self_improvement,
          'color': AppSemanticColors.forMuscle('Core')
        },
      ];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'SELECT TARGET',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'What are you training today?',
                  style: AppText.headlineMd.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.4,
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final opt = options[index];
                    final color = opt['color'] as Color;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MuscleTrainingPage(
                                muscleGroup: opt['id'] as String),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(opt['icon'] as IconData,
                                color: color, size: 20),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                opt['label'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
