import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../services/exercise_database.dart';
import '../services/fitness_plan_generator.dart';
import '../services/workout_service.dart';

class ExerciseDetailSheet extends StatefulWidget {
  final PlannedExercise plannedExercise;
  final Function(Map<String, dynamic>)? onLogSet;

  const ExerciseDetailSheet({
    super.key,
    required this.plannedExercise,
    this.onLogSet,
  });

  @override
  State<ExerciseDetailSheet> createState() => _ExerciseDetailSheetState();
}

class _ExerciseDetailSheetState extends State<ExerciseDetailSheet>
    with SingleTickerProviderStateMixin {
  YoutubePlayerController? _youtubeController;
  late TabController _tabController;

  // Set tracking
  final List<SetData> _completedSets = [];
  int _currentSet = 1;
  bool _isResting = false;
  int _restSecondsRemaining = 0;

  // Input controllers
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  bool _isWarmup = false;
  bool _isDropset = false;
  bool _isFailure = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeYouTube();
  }

  void _initializeYouTube() {
    final videoId = widget.plannedExercise.exercise.youtubeVideoId;
    if (videoId.isNotEmpty && videoId != '是什么') {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: true,
          hideControls: false,
          forceHD: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _tabController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _startRestTimer(int seconds) {
    setState(() {
      _isResting = true;
      _restSecondsRemaining = seconds;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _restSecondsRemaining--;
        if (_restSecondsRemaining <= 0) {
          _isResting = false;
        }
      });
      return _restSecondsRemaining > 0;
    });
  }

  void _logCurrentSet() {
    final weight = double.tryParse(_weightController.text) ?? 0;
    final reps = int.tryParse(_repsController.text) ?? 0;

    if (reps == 0 && !_isWarmup) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال عدد التكرار'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final setData = SetData(
      setNumber: _currentSet,
      reps: _isWarmup ? null : reps,
      weight: weight,
      isWarmup: _isWarmup,
      isDropset: _isDropset,
      isFailure: _isFailure,
      timestamp: DateTime.now(),
    );

    setState(() {
      _completedSets.add(setData);
      _currentSet++;
      _weightController.clear();
      _repsController.clear();
      _isWarmup = false;
      _isDropset = false;
      _isFailure = false;
    });

    HapticFeedback.mediumImpact();

    // Start rest timer
    if (!_isResting) {
      _startRestTimer(widget.plannedExercise.restSeconds);
    }

    // Callback if provided
    if (widget.onLogSet != null) {
      widget.onLogSet!(setData.toJson());
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.plannedExercise.exercise;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Video & Info Tab
                _buildVideoTab(exercise),
                // Log Sets Tab
                _buildLogTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTab(Exercise exercise) {
    final hasVideo = exercise.youtubeVideoId.isNotEmpty &&
        exercise.youtubeVideoId != '是什么';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.nameAr,
                      style: AppText.titleLg.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.nameEn,
                      style: AppText.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getDifficultyColor(exercise.difficulty).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  exercise.difficulty,
                  style: TextStyle(
                    color: _getDifficultyColor(exercise.difficulty),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // YouTube Video
          if (hasVideo) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: YoutubePlayer(
                controller: _youtubeController!,
                showVideoProgressIndicator: true,
                progressIndicatorColor: AppColors.primaryFixed,
                progressColors: const ProgressBarColors(
                  playedColor: AppColors.primaryFixed,
                  handleColor: AppColors.primaryFixed,
                ),
                aspectRatio: 16 / 9,
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      color: AppColors.onSurfaceVariant,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'لا يتوفر فيديو لهذا التمرين',
                      style: AppText.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Tab Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _tabController.animateTo(1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'تسجيل المجموعات',
                          style: AppText.labelSm.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Exercise Info Cards
          _buildInfoCard(
            icon: Icons.fitness_center_rounded,
            title: 'العضلة المستهدفة',
            value: exercise.muscleGroup,
            color: AppColors.primaryFixed,
          ),
          const SizedBox(height: 12),

          if (exercise.secondaryMuscles.isNotEmpty) ...[
            _buildInfoCard(
              icon: Icons.group_work_rounded,
              title: 'العضلات الثانوية',
              value: exercise.secondaryMuscles,
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
          ],

          _buildInfoCard(
            icon: Icons.sports_gymnastics_rounded,
            title: 'المعدة',
            value: exercise.equipment,
            color: Colors.blue,
          ),
          const SizedBox(height: 20),

          // Description
          Text(
            'الوصف',
            style: AppText.titleSm.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            exercise.description,
            style: AppText.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),

          // Form Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryFixed.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.tips_and_updates_rounded,
                      color: AppColors.primaryFixed,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'نصيحة للتشكيل',
                      style: AppText.labelSm.copyWith(
                        color: AppColors.primaryFixed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  exercise.formTips,
                  style: AppText.bodySm.copyWith(
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Target Sets for this exercise
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildTargetChip(
                  '${widget.plannedExercise.sets} مجموعات',
                  Icons.repeat_rounded,
                ),
                const SizedBox(width: 12),
                _buildTargetChip(
                  widget.plannedExercise.reps,
                  Icons.fitness_center_rounded,
                ),
                const SizedBox(width: 12),
                _buildTargetChip(
                  '${widget.plannedExercise.restSeconds}s راحة',
                  Icons.timer_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  Widget _buildLogTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with video tab
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.plannedExercise.exercise.nameAr,
                  style: AppText.titleLg.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('الفيديو'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryFixed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Rest Timer (if resting)
          if (_isResting) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.2),
                    Colors.orange.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.timer_rounded,
                    color: Colors.orange,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_restSecondsRemaining',
                    style: AppText.headlineLg.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w900,
                      fontSize: 48,
                    ),
                  ),
                  Text(
                    'ثانية راحة متبقية',
                    style: AppText.bodySm.copyWith(color: Colors.orange),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _isResting = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('تخطي الراحة'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Completed Sets
          if (_completedSets.isNotEmpty) ...[
            Text(
              'المجاميع المسجلة',
              style: AppText.titleSm.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            ..._completedSets.asMap().entries.map((entry) {
              final index = entry.key;
              final set = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: set.isWarmup
                            ? Colors.orange.withOpacity(0.2)
                            : AppColors.primaryFixed.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: set.isWarmup ? Colors.orange : AppColors.primaryFixed,
                            fontWeight: FontWeight.w900,
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
                            set.isWarmup
                                ? 'إحماء'
                                : '${set.weight > 0 ? '${set.weight} كجم × ' : ''}${set.reps} تكرار',
                            style: AppText.bodySm.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (set.isDropset || set.isFailure)
                            Row(
                              children: [
                                if (set.isDropset)
                                  _buildSetBadge('Dropset', Colors.purple),
                                if (set.isFailure)
                                  _buildSetBadge('Failure', Colors.red),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (set.isWarmup)
                      const Icon(
                        Icons.whatshot_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
          ],

          // Current Set Input
          Text(
            'المجموعة $_currentSet',
            style: AppText.titleSm.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),

          // Weight & Reps Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'الوزن (كجم)',
                    labelStyle: TextStyle(color: AppColors.onSurfaceVariant),
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryFixed),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'التكرار',
                    labelStyle: TextStyle(color: AppColors.onSurfaceVariant),
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryFixed),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Set Options
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildOptionChip(
                label: 'إحماء',
                icon: Icons.whatshot_rounded,
                isSelected: _isWarmup,
                color: Colors.orange,
                onTap: () => setState(() => _isWarmup = !_isWarmup),
              ),
              _buildOptionChip(
                label: 'Dropset',
                icon: Icons.arrow_downward_rounded,
                isSelected: _isDropset,
                color: Colors.purple,
                onTap: () => setState(() => _isDropset = !_isDropset),
              ),
              _buildOptionChip(
                label: 'للفشل',
                icon: Icons.flag_rounded,
                isSelected: _isFailure,
                color: Colors.red,
                onTap: () => setState(() => _isFailure = !_isFailure),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Log Set Button
          GestureDetector(
            onTap: _logCurrentSet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4FF57), Color(0xFF9FFF00)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'تسجيل المجموعة',
                  style: AppText.titleSm.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Target info
          Center(
            child: Text(
              'الهدف: ${widget.plannedExercise.sets} × ${widget.plannedExercise.reps}',
              style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: AppText.bodySm.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetChip(String text, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryFixed, size: 16),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : AppColors.onSurfaceVariant, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'سهل':
        return Colors.green;
      case 'متوسط':
        return Colors.orange;
      case 'متقدم':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}

class SetData {
  final int setNumber;
  final int? reps;
  final double weight;
  final bool isWarmup;
  final bool isDropset;
  final bool isFailure;
  final DateTime timestamp;

  SetData({
    required this.setNumber,
    this.reps,
    required this.weight,
    this.isWarmup = false,
    this.isDropset = false,
    this.isFailure = false,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'setNumber': setNumber,
    'reps': reps,
    'weightKg': weight,
    'isWarmup': isWarmup,
    'isDropset': isDropset,
    'isFailure': isFailure,
    'timestamp': timestamp.toIso8601String(),
  };
}
