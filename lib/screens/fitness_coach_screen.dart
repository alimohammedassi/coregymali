import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../services/exercise_database.dart';
import '../services/fitness_plan_generator.dart';
import 'exercise_detail_sheet.dart';

// Design tokens
const _kSurface = Color(0xFF111113);
const _kCard = Color(0xFF1C1C1E);
const _kCard2 = Color(0xFF2C2C2E);
const _kAccent = Color(0xFFD4FF57);
const _kMuted = Color(0xFF8E8E93);
const _kSubtle = Color(0xFF636366);

class FitnessCoachScreen extends StatefulWidget {
  const FitnessCoachScreen({super.key});

  @override
  State<FitnessCoachScreen> createState() => _FitnessCoachScreenState();
}

class _FitnessCoachScreenState extends State<FitnessCoachScreen>
    with TickerProviderStateMixin {
  WorkoutMood _selectedMood = WorkoutMood.medium;
  final Set<String> _selectedMuscles = {'صدر'};
  int _duration = 45;

  WorkoutPlan? _generatedPlan;
  bool _isGenerating = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<String> _muscleOptions = [
    'صدر',
    'ظهر',
    'أكتاف',
    'بايسبس',
    'ترايسبس',
    'رجل',
    'بطن',
    'كارديو',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _generatePlan() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isGenerating = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      final plan = FitnessPlanGenerator.generatePlan(
        mood: _selectedMood,
        muscles: _selectedMuscles.toList(),
        durationMinutes: _duration,
      );

      setState(() {
        _generatedPlan = plan;
        _isGenerating = false;
      });
    });
  }

  void _openExerciseDetail(PlannedExercise exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExerciseDetailSheet(
        plannedExercise: exercise,
        onLogSet: (setData) {
          debugPrint('Logged set: $setData');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        child: _generatedPlan == null
            ? _buildInputScreen()
            : _buildPlanScreen(),
      ),
    );
  }

  Widget _buildInputScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: _kAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMART TRAINER',
                      style: AppText.headlineSm.copyWith(
                        color: _kAccent,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      'المدرب الذكي',
                      style: AppText.bodySm.copyWith(
                        color: _kMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Mood Selection
          Text(
            'HOW DO YOU FEEL?',
            style: AppText.labelSm.copyWith(color: _kMuted, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            'كيف تشعر اليوم؟',
            style: AppText.titleMd.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: WorkoutMood.values.length,
              itemBuilder: (context, index) {
                final mood = WorkoutMood.values[index];
                final isSelected = _selectedMood == mood;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedMood = mood);
                    },
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final scale = isSelected ? _pulseAnimation.value : 1.0;
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 90,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _getMoodColor(mood).withOpacity(0.2)
                              : _kCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? _getMoodColor(mood)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getMoodIcon(mood),
                              color: isSelected
                                  ? _getMoodColor(mood)
                                  : _kSubtle,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getMoodLabel(mood),
                              style: TextStyle(
                                color: isSelected
                                    ? _getMoodColor(mood)
                                    : _kSubtle,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          // Muscle Selection
          Text(
            'TARGET MUSCLES',
            style: AppText.labelSm.copyWith(color: _kMuted, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            'اختر العضلات المستهدفة',
            style: AppText.titleMd.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _muscleOptions.map((muscle) {
              final isSelected = _selectedMuscles.contains(muscle);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected && _selectedMuscles.length > 1) {
                      _selectedMuscles.remove(muscle);
                    } else if (!isSelected) {
                      _selectedMuscles.add(muscle);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _kAccent.withOpacity(0.2)
                        : _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getMuscleIcon(muscle),
                        color: isSelected ? _kAccent : _kSubtle,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        muscle,
                        style: TextStyle(
                          color: isSelected ? _kAccent : Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Duration Selection
          Text(
            'DURATION',
            style: AppText.labelSm.copyWith(color: _kMuted, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            'مدة التمرين',
            style: AppText.titleMd.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildDurationOption(30),
              const SizedBox(width: 10),
              _buildDurationOption(45),
              const SizedBox(width: 10),
              _buildDurationOption(60),
              const SizedBox(width: 10),
              _buildDurationOption(90),
            ],
          ),
          const SizedBox(height: 48),

          // Generate Button
          GestureDetector(
            onTap: _generatePlan,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4FF57), Color(0xFF9FFF00)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _kAccent.withOpacity(_isGenerating ? 0.5 : 0.3),
                    blurRadius: _isGenerating ? 20 : 10,
                    spreadRadius: _isGenerating ? 2 : 0,
                  ),
                ],
              ),
              child: Center(
                child: _isGenerating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.black,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'GENERATE WORKOUT',
                            style: AppText.titleSm.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 150),
        ],
      ),
    );
  }

  Widget _buildDurationOption(int minutes) {
    final isSelected = _duration == minutes;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _duration = minutes);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? _kAccent.withOpacity(0.2) : _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _kAccent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$minutes',
                style: TextStyle(
                  color: isSelected ? _kAccent : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'MIN',
                style: TextStyle(
                  color: isSelected ? _kAccent : _kSubtle,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanScreen() {
    final plan = _generatedPlan!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _generatedPlan = null),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR WORKOUT',
                      style: AppText.labelSm.copyWith(
                        color: _kAccent,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      plan.targetMuscles,
                      style: AppText.titleMd.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: _kMuted, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${plan.totalDurationMinutes} min',
                      style: const TextStyle(
                        color: _kMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Motivational intro
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _kAccent.withOpacity(0.2),
                  _kAccent.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.format_quote_rounded,
                  color: _kAccent,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    plan.intro,
                    style: AppText.bodySm.copyWith(
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Exercise list
          ...plan.exercises.asMap().entries.map((entry) {
            final index = entry.key;
            final exercise = entry.value;
            return _buildExerciseCard(exercise, index);
          }),
          const SizedBox(height: 150),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(PlannedExercise exercise, int index) {
    final isWarmup = exercise.isWarmup;
    final hasVideo = exercise.exercise.youtubeVideoId.isNotEmpty &&
        exercise.exercise.youtubeVideoId != '是什么';

    return GestureDetector(
      onTap: () => _openExerciseDetail(exercise),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: isWarmup
              ? Border.all(color: Colors.orange.withOpacity(0.5), width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isWarmup
                        ? Colors.orange.withOpacity(0.2)
                        : _kAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isWarmup ? Colors.orange : _kAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.exercise.nameAr,
                        style: AppText.titleSm.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _kCard2,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              exercise.exercise.muscleGroup,
                              style: const TextStyle(
                                color: _kMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isWarmup) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'إحماء',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${exercise.sets} × ${exercise.reps}',
                      style: AppText.titleSm.copyWith(
                        color: _kAccent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (exercise.restSeconds > 0)
                      Text(
                        '${exercise.restSeconds}s rest',
                        style: const TextStyle(
                          color: _kMuted,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                if (hasVideo)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kCard2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: _kMuted,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kCard2.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: _kMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exercise.exercise.formTips,
                      style: const TextStyle(
                        color: _kMuted,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _kSubtle,
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMoodColor(WorkoutMood mood) {
    switch (mood) {
      case WorkoutMood.tired:
        return Colors.blue;
      case WorkoutMood.light:
        return Colors.green;
      case WorkoutMood.medium:
        return Colors.orange;
      case WorkoutMood.energetic:
        return Colors.purple;
      case WorkoutMood.fullPower:
        return Colors.red;
    }
  }

  IconData _getMoodIcon(WorkoutMood mood) {
    switch (mood) {
      case WorkoutMood.tired:
        return Icons.bedtime_rounded;
      case WorkoutMood.light:
        return Icons.spa_rounded;
      case WorkoutMood.medium:
        return Icons.bolt_rounded;
      case WorkoutMood.energetic:
        return Icons.flash_on_rounded;
      case WorkoutMood.fullPower:
        return Icons.local_fire_department_rounded;
    }
  }

  String _getMoodLabel(WorkoutMood mood) {
    switch (mood) {
      case WorkoutMood.tired:
        return 'متعب';
      case WorkoutMood.light:
        return 'خفيف';
      case WorkoutMood.medium:
        return 'متوسط';
      case WorkoutMood.energetic:
        return 'نشيط';
      case WorkoutMood.fullPower:
        return 'طاقة كاملة';
    }
  }

  IconData _getMuscleIcon(String muscle) {
    switch (muscle) {
      case 'صدر':
        return Icons.fitness_center_rounded;
      case 'ظهر':
        return Icons.accessibility_new_rounded;
      case 'أكتاف':
        return Icons.sports_gymnastics_rounded;
      case 'بايسبس':
        return Icons.sports_martial_arts_rounded;
      case 'ترايسبس':
        return Icons.sports_handball_rounded;
      case 'رجل':
        return Icons.directions_walk_rounded;
      case 'بطن':
        return Icons.self_improvement_rounded;
      case 'كارديو':
        return Icons.favorite_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }
}
