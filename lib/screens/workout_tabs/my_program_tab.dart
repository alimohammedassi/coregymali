import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
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
          color: Color(0xFFD4FF57),
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

    final Map<String, Color> levelColors = {
      'beginner': const Color(0xFF34D399),
      'intermediate': const Color(0xFFFBBF24),
      'advanced': const Color(0xFFF87171),
    };
    final levelColor = levelColors[level] ?? const Color(0xFFD4FF57);

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

              const SizedBox(height: 28),

              // ── Weekly snapshot ────────────────────────────
              Row(
                children: [
                  _statCard('${progData['days_per_week'] ?? 4}', 'Days/Week',
                      Icons.calendar_month_rounded, const Color(0xFF7C3AED)),
                  const SizedBox(width: 12),
                  _statCard('$totalWeeks', 'Total Weeks',
                      Icons.timelapse_rounded, const Color(0xFF06B6D4)),
                  const SizedBox(width: 12),
                  _statCard('${(progress * 100).round()}%', 'Complete',
                      Icons.pie_chart_rounded, const Color(0xFFD4FF57)),
                ],
              ),

              const SizedBox(height: 28),

              // ── Today's Workout ────────────────────────────
              const Text(
                'TODAY\'S WORKOUT',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildWorkoutCard(),

              const SizedBox(height: 28),

              // ── Weekly Schedule ────────────────────────────
              const Text(
                'THIS WEEK',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildWeekRow(currentWeek),

              const SizedBox(height: 32),

              // ── CTA ────────────────────────────────────────
              GestureDetector(
                onTap: () => _showMuscleSelection(context),
                child: Container(
                  width: double.infinity,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4FF57),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4FF57).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: Colors.black, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'START TODAY\'S WORKOUT',
                        style: TextStyle(
                          color: Colors.black,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
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
                  color: levelColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: levelColor.withOpacity(0.4)),
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
                  const Text(
                    'WEEK',
                    style: TextStyle(
                        color: Color(0xFF636366),
                        fontSize: 11,
                        letterSpacing: 1),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$currentWeek/$totalWeeks',
                    style: const TextStyle(
                      color: Colors.white,
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
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
                style:
                    const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
              ),
            ),

          if (progData['description'] != null) ...[
            const SizedBox(height: 12),
            Text(
              progData['description'],
              style: const TextStyle(
                color: Color(0xFF636366),
                fontSize: 13,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 24),

          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PROGRESS',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
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
                  backgroundColor: Colors.white10,
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
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF636366),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            splashColor: Colors.white.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4FF57).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: Color(0xFFD4FF57),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Day 1 — Full Body',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '5 exercises  •  ~45 min',
                          style:
                              TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chevron_right,
                        color: Colors.white54, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekRow(int currentDay) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final workoutDays = [0, 2, 4]; // Mon, Wed, Fri

    return Row(
      children: List.generate(7, (i) {
        final isWorkout = workoutDays.contains(i);
        final isToday = i == 0;
        final isDone = i < currentDay - 1;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFFD4FF57)
                        : isDone
                            ? const Color(0xFF2C2C2E)
                            : isWorkout
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isWorkout && !isToday && !isDone
                          ? Colors.white.withOpacity(0.15)
                          : Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFF34D399), size: 16)
                        : isWorkout
                            ? Icon(
                                Icons.fitness_center_rounded,
                                size: 14,
                                color: isToday
                                    ? Colors.black
                                    : Colors.white38,
                              )
                            : const Text('—',
                                style: TextStyle(
                                    color: Color(0xFF3A3A3C), fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  days[i],
                  style: TextStyle(
                    color: isToday
                        ? const Color(0xFFD4FF57)
                        : const Color(0xFF636366),
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
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 40,
                color: Color(0xFF636366),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Active Program',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Head to the Library tab to pick a program and start your journey.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8E8E93),
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
          'color': const Color(0xFFF87171)
        },
        {
          'label': 'Pull Day',
          'id': 'pull',
          'icon': Icons.fitness_center,
          'color': const Color(0xFF7C3AED)
        },
        {
          'label': 'Legs Day',
          'id': 'legs',
          'icon': Icons.directions_run,
          'color': const Color(0xFF34D399)
        },
        {
          'label': 'Core / Abs',
          'id': 'core',
          'icon': Icons.self_improvement,
          'color': const Color(0xFFFBBF24)
        },
      ];
    } else if (progName.contains('upper') || progName.contains('lower')) {
      options = [
        {
          'label': 'Upper Body',
          'id': 'upper',
          'icon': Icons.fitness_center,
          'color': const Color(0xFF7C3AED)
        },
        {
          'label': 'Lower Body',
          'id': 'lower',
          'icon': Icons.directions_run,
          'color': const Color(0xFF34D399)
        },
        {
          'label': 'Core / Abs',
          'id': 'core',
          'icon': Icons.self_improvement,
          'color': const Color(0xFFFBBF24)
        },
      ];
    } else if (progName.contains('full')) {
      options = [
        {
          'label': 'Full Body',
          'id': 'full_body',
          'icon': Icons.accessibility_new,
          'color': const Color(0xFFD4FF57)
        },
        {
          'label': 'Core / Abs',
          'id': 'core',
          'icon': Icons.self_improvement,
          'color': const Color(0xFFFBBF24)
        },
      ];
    } else {
      options = [
        {
          'label': 'Chest',
          'id': 'chest',
          'icon': Icons.fitness_center,
          'color': const Color(0xFFF87171)
        },
        {
          'label': 'Back',
          'id': 'back',
          'icon': Icons.airline_seat_flat_angled,
          'color': const Color(0xFF7C3AED)
        },
        {
          'label': 'Shoulders',
          'id': 'shoulders',
          'icon': Icons.accessibility,
          'color': const Color(0xFF06B6D4)
        },
        {
          'label': 'Arms',
          'id': 'arms',
          'icon': Icons.sports_gymnastics,
          'color': const Color(0xFFFBBF24)
        },
        {
          'label': 'Legs',
          'id': 'legs',
          'icon': Icons.directions_run,
          'color': const Color(0xFF34D399)
        },
        {
          'label': 'Core',
          'id': 'core',
          'icon': Icons.self_improvement,
          'color': const Color(0xFFFF6B35)
        },
      ];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'SELECT TARGET',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'What are you training today?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
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
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(opt['icon'] as IconData,
                                color: color, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              opt['label'] as String,
                              style: TextStyle(
                                color: color,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
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