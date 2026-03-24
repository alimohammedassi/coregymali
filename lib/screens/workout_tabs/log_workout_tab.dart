import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../services/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
const _kSurface = Color(0xFF111113);
const _kCard = Color(0xFF1C1C1E);
const _kCard2 = Color(0xFF2C2C2E);
const _kAccent = Color(0xFFD4FF57);
const _kMuted = Color(0xFF8E8E93);
const _kSubtle = Color(0xFF636366);

const Map<String, Color> _muscleColors = {
  'Chest': Color(0xFFF87171),
  'Back': Color(0xFF7C3AED),
  'Shoulders': Color(0xFF06B6D4),
  'Arms': Color(0xFFFBBF24),
  'Legs': Color(0xFF34D399),
  'Core': Color(0xFFFF6B35),
  'Full Body': Color(0xFFD4FF57),
};

// ─────────────────────────────────────────────────────────────────────────────
//  LogWorkoutTab
// ─────────────────────────────────────────────────────────────────────────────
class LogWorkoutTab extends StatefulWidget {
  const LogWorkoutTab({super.key});

  @override
  State<LogWorkoutTab> createState() => _LogWorkoutTabState();
}

class _LogWorkoutTabState extends State<LogWorkoutTab>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _exercises = [];
  String _muscleFilter = 'Chest';

  late AnimationController _listController;
  late Animation<double> _listFade;

  final List<String> _muscleGroups = [
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Legs',
    'Core',
    'Full Body',
  ];

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _listFade = CurvedAnimation(parent: _listController, curve: Curves.easeOut);
    _loadExercises();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);
    _listController.reset();
    try {
      final data = await supabase
          .from('exercises')
          .select()
          .ilike('muscle_group', '%$_muscleFilter%')
          .order('name');

      if (mounted) {
        setState(() {
          _exercises = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        _listController.forward();
      }
    } on PostgrestException catch (e) {
      debugPrint('DB Error [${e.code}]: ${e.message}');
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading exercises: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openYouTube(String videoId) async {
    final url = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _muscleColors[_muscleFilter] ?? const Color(0xFFD4FF57);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // ── Muscle Group Tab Bar ──
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _muscleGroups.length,
            itemBuilder: (context, index) {
              final item = _muscleGroups[index];
              final isSelected = _muscleFilter == item;
              final color = _muscleColors[item] ?? _kAccent;

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _muscleFilter = item);
                    _loadExercises();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.15) : _kCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? color.withOpacity(0.5)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _muscleIcon(item),
                          color: isSelected ? color : _kSubtle,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? color : _kSubtle,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // ── Results count ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _isLoading
                  ? ''
                  : '${_exercises.length} EXERCISES IN ${_muscleFilter.toUpperCase()}',
              key: ValueKey('$_muscleFilter-${_exercises.length}'),
              style: const TextStyle(
                color: _kMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── List ──
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: accentColor,
                    strokeWidth: 2,
                  ),
                )
              : FadeTransition(
                  opacity: _listFade,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: _exercises.length,
                    itemBuilder: (context, index) {
                      return _ExerciseCard(
                        exercise: _exercises[index],
                        accentColor: accentColor,
                        muscleGroup: _muscleFilter,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _ExerciseDetailScreen(
                              exercise: _exercises[index],
                              defaultMuscleGroup: _muscleFilter,
                            ),
                          ),
                        ),
                        onYouTubeTap:
                            _exercises[index]['youtube_video_id'] != null
                            ? () => _openYouTube(
                                _exercises[index]['youtube_video_id'],
                              )
                            : null,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  IconData _muscleIcon(String group) {
    switch (group) {
      case 'Chest':
        return Icons.fitness_center_rounded;
      case 'Back':
        return Icons.airline_seat_flat_angled_rounded;
      case 'Shoulders':
        return Icons.accessibility_rounded;
      case 'Arms':
        return Icons.sports_gymnastics_rounded;
      case 'Legs':
        return Icons.directions_run_rounded;
      case 'Core':
        return Icons.self_improvement_rounded;
      case 'Full Body':
        return Icons.accessibility_new_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Exercise Card
// ─────────────────────────────────────────────────────────────────────────────
class _ExerciseCard extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final Color accentColor;
  final String muscleGroup;
  final VoidCallback onTap;
  final VoidCallback? onYouTubeTap;

  const _ExerciseCard({
    required this.exercise,
    required this.accentColor,
    required this.muscleGroup,
    required this.onTap,
    this.onYouTubeTap,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final String? videoId = ex['youtube_video_id'];
    final String? imageUrl = ex['image_url'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTapDown: (_) => _press.reverse(),
        onTapUp: (_) {
          _press.forward();
          widget.onTap();
        },
        onTapCancel: () => _press.forward(),
        child: ScaleTransition(
          scale: _press,
          child: Container(
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image / placeholder
                if (imageUrl != null)
                  Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => _imagePlaceholder(),
                        errorWidget: (c, u, e) => _imagePlaceholder(),
                      ),
                      // Gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                _kCard.withOpacity(0.8),
                              ],
                              stops: const [0.4, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // YouTube button
                      if (videoId != null && videoId.isNotEmpty)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: widget.onYouTubeTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.redAccent,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'VIDEO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  _imagePlaceholder(),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex['name'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (ex['name_ar'] != null)
                        Text(
                          ex['name_ar'],
                          style: const TextStyle(color: _kMuted, fontSize: 12),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _badge(
                            ex['equipment'] ?? 'Bodyweight',
                            const Color(0xFFFF6B35),
                          ),
                          const SizedBox(width: 6),
                          _badge(
                            ex['category'] ?? 'Strength',
                            const Color(0xFF06B6D4),
                          ),
                          const Spacer(),
                          if (imageUrl == null &&
                              videoId != null &&
                              videoId.isNotEmpty)
                            GestureDetector(
                              onTap: widget.onYouTubeTap,
                              child: const Icon(
                                Icons.play_circle_filled_rounded,
                                color: Colors.redAccent,
                                size: 28,
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
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 100,
      width: double.infinity,
      color: _kCard2,
      child: Icon(
        Icons.fitness_center_rounded,
        size: 40,
        color: widget.accentColor.withOpacity(0.3),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LoggedSet model
// ─────────────────────────────────────────────────────────────────────────────
class LoggedSet {
  final int setNumber;
  final double weight;
  final int reps;
  LoggedSet({
    required this.setNumber,
    required this.weight,
    required this.reps,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Exercise Detail Screen
// ─────────────────────────────────────────────────────────────────────────────
class _ExerciseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final String defaultMuscleGroup;
  const _ExerciseDetailScreen({
    required this.exercise,
    required this.defaultMuscleGroup,
  });

  @override
  State<_ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<_ExerciseDetailScreen>
    with TickerProviderStateMixin {
  final List<LoggedSet> _sets = [];
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  bool _saving = false;

  late AnimationController _addSetController;
  late Animation<double> _addSetScale;

  Color get _accentColor =>
      _muscleColors[widget.defaultMuscleGroup] ?? _kAccent;

  @override
  void initState() {
    super.initState();
    _addSetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
    _addSetScale = _addSetController;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _addSetController.dispose();
    super.dispose();
  }

  Future<void> _openYouTube(String videoId) async {
    final url = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _addSet() {
    final w = double.tryParse(_weightController.text) ?? 0.0;
    final r = int.tryParse(_repsController.text) ?? 0;
    if (r > 0) {
      HapticFeedback.lightImpact();
      _addSetController.reverse().then((_) => _addSetController.forward());
      setState(() {
        _sets.add(LoggedSet(setNumber: _sets.length + 1, weight: w, reps: r));
        _repsController.clear();
      });
    }
  }

  void _removeSet(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _sets.removeAt(index);
      // Renumber
      for (int i = 0; i < _sets.length; i++) {
        _sets[i] = LoggedSet(
          setNumber: i + 1,
          weight: _sets[i].weight,
          reps: _sets[i].reps,
        );
      }
    });
  }

  Future<void> _saveWorkout() async {
    if (_sets.isEmpty) return;
    if (currentUserId == null) return;
    setState(() => _saving = true);

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final startTime = DateTime.now()
          .subtract(const Duration(minutes: 30))
          .toIso8601String();

      final session = await supabase
          .from('workout_sessions')
          .insert({
            'user_id': currentUserId,
            'muscle_group': widget.defaultMuscleGroup,
            'session_name': '${widget.defaultMuscleGroup} Workout',
            'session_date': today,
            'started_at': startTime,
            'ended_at': DateTime.now().toIso8601String(),
            'duration_min': 30,
          })
          .select()
          .single();

      final sessionId = session['id'];

      for (final s in _sets) {
        await supabase.from('workout_sets').insert({
          'session_id': sessionId,
          'user_id': currentUserId,
          'exercise_name': widget.exercise['name'],
          'set_number': s.setNumber,
          'reps': s.reps,
          'weight_kg': s.weight,
        });
      }

      final bestSet = _sets.reduce(
        (a, b) => (a.weight * a.reps) > (b.weight * b.reps) ? a : b,
      );
      final oneRM = bestSet.weight * (1 + bestSet.reps / 30.0);
      final totalVolume = _sets.fold(
        0.0,
        (sum, item) => sum + (item.weight * item.reps),
      );

      await supabase.from('exercise_progress').insert({
        'user_id': currentUserId,
        'exercise_id': widget.exercise['id'],
        'session_date': today,
        'best_set_weight': bestSet.weight,
        'best_set_reps': bestSet.reps,
        'total_volume': totalVolume,
        'one_rm_estimate': oneRM,
        'session_id': sessionId,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: _accentColor, size: 20),
              const SizedBox(width: 12),
              const Text(
                'Workout logged!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: _kCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } on PostgrestException catch (e) {
      debugPrint('DB Error Logging Workout: ${e.message}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final String? videoId = ex['youtube_video_id'];
    final String? imageUrl = ex['image_url'];

    final totalVolume = _sets.fold(0.0, (sum, s) => sum + (s.weight * s.reps));

    return Scaffold(
      backgroundColor: _kSurface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── SliverAppBar with image ──
          SliverAppBar(
            expandedHeight: imageUrl != null ? 280 : 0,
            pinned: true,
            backgroundColor: _kSurface,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            actions: [
              if (videoId != null && videoId.isNotEmpty)
                GestureDetector(
                  onTap: () => _openYouTube(videoId),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'TUTORIAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            flexibleSpace: imageUrl != null
                ? FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Container(color: _kCard2),
                          errorWidget: (c, u, e) => Container(color: _kCard2),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, _kSurface],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    ex['name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  if (ex['name_ar'] != null)
                    Text(
                      ex['name_ar'],
                      style: const TextStyle(color: _kMuted, fontSize: 15),
                    ),

                  const SizedBox(height: 16),

                  // Badges row
                  Row(
                    children: [
                      _infoPill(
                        ex['equipment'] ?? 'Bodyweight',
                        const Color(0xFFFF6B35),
                      ),
                      const SizedBox(width: 8),
                      _infoPill(
                        ex['category'] ?? 'Strength',
                        const Color(0xFF06B6D4),
                      ),
                      const SizedBox(width: 8),
                      _infoPill(widget.defaultMuscleGroup, _accentColor),
                    ],
                  ),

                  if (ex['instructions_ar'] != null &&
                      ex['instructions_ar'].toString().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'INSTRUCTIONS',
                      style: TextStyle(
                        color: _kMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                      child: Text(
                        ex['instructions_ar'],
                        style: const TextStyle(
                          color: Color(0xFFE5E5EA),
                          fontSize: 14,
                          height: 1.7,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  Container(height: 1, color: Colors.white.withOpacity(0.07)),
                  const SizedBox(height: 28),

                  // ── Log Sets Header ──
                  Row(
                    children: [
                      const Text(
                        'LOG SETS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (_sets.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_sets.length} SETS',
                            style: TextStyle(
                              color: _accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Input Row ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _inputField(
                            controller: _weightController,
                            label: 'WEIGHT',
                            unit: 'kg',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _inputField(
                            controller: _repsController,
                            label: 'REPS',
                            unit: 'reps',
                          ),
                        ),
                        const SizedBox(width: 12),
                        ScaleTransition(
                          scale: _addSetScale,
                          child: GestureDetector(
                            onTap: _addSet,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _accentColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.black,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Set List ──
                  if (_sets.isNotEmpty)
                    Column(
                      children: [
                        ..._sets.asMap().entries.map((entry) {
                          final i = entry.key;
                          final s = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SetRow(
                              set: s,
                              accentColor: _accentColor,
                              onDelete: () => _removeSet(i),
                            ),
                          );
                        }),

                        // Volume summary
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _accentColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _accentColor.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _volumeStat(
                                '${_sets.length}',
                                'Sets',
                                _accentColor,
                              ),
                              _volumeDiv(),
                              _volumeStat(
                                '${_sets.fold(0, (s, e) => s + e.reps)}',
                                'Total Reps',
                                _accentColor,
                              ),
                              _volumeDiv(),
                              _volumeStat(
                                '${totalVolume.toStringAsFixed(0)} kg',
                                'Volume',
                                _accentColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Floating Save Button ──
      bottomNavigationBar: _sets.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: GestureDetector(
                  onTap: _saving ? null : _saveWorkout,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 58,
                    decoration: BoxDecoration(
                      color: _saving
                          ? _accentColor.withOpacity(0.5)
                          : _accentColor,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.save_alt_rounded,
                                  color: Colors.black,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'SAVE WORKOUT',
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
                ),
              ),
            )
          : null,
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _kMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: unit,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: _kCard2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _volumeStat(String val, String label, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _kMuted, fontSize: 11)),
      ],
    );
  }

  Widget _volumeDiv() => Container(width: 1, height: 32, color: Colors.white10);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Set Row Widget
// ─────────────────────────────────────────────────────────────────────────────
class _SetRow extends StatelessWidget {
  final LoggedSet set;
  final Color accentColor;
  final VoidCallback onDelete;

  const _SetRow({
    required this.set,
    required this.accentColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${set.setNumber}',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                _setDetail('${set.weight}', 'kg'),
                const SizedBox(width: 20),
                const Text(
                  '×',
                  style: TextStyle(color: _kSubtle, fontSize: 16),
                ),
                const SizedBox(width: 20),
                _setDetail('${set.reps}', 'reps'),
                const Spacer(),
                Text(
                  '${(set.weight * set.reps).toStringAsFixed(0)} kg vol',
                  style: const TextStyle(color: _kSubtle, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.redAccent,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setDetail(String val, String unit) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 3),
        Text(unit, style: const TextStyle(color: _kMuted, fontSize: 11)),
      ],
    );
  }
}
