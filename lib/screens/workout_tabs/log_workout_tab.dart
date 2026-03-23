import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../services/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class LogWorkoutTab extends StatefulWidget {
  const LogWorkoutTab({super.key});

  @override
  State<LogWorkoutTab> createState() => _LogWorkoutTabState();
}

class _LogWorkoutTabState extends State<LogWorkoutTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _exercises = [];
  String _muscleFilter = 'Chest';

  final List<String> _muscleGroups = [
    'Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core', 'Full Body'
  ];

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);
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

  void _showExerciseDetail(Map<String, dynamic> exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ExerciseDetailScreen(exercise: exercise, defaultMuscleGroup: _muscleFilter)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _muscleGroups.length,
            itemBuilder: (context, index) {
              final item = _muscleGroups[index];
              final isSelected = _muscleFilter == item;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(item.toUpperCase(), style: AppText.labelSm.copyWith(
                    color: isSelected ? Colors.black : Colors.white
                  )),
                  selected: isSelected,
                  selectedColor: AppColors.primaryFixed,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  onSelected: (_) {
                    setState(() => _muscleFilter = item);
                    _loadExercises();
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryFixed))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 90),
                  itemCount: _exercises.length,
                  itemBuilder: (context, index) {
                    final ex = _exercises[index];
                    final String? videoId = ex['youtube_video_id'];
                    return Card(
                      color: AppColors.surfaceContainerHigh,
                      margin: const EdgeInsets.only(bottom: 16),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: () => _showExerciseDetail(ex),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (ex['image_url'] != null)
                              CachedNetworkImage(
                                imageUrl: ex['image_url'] ?? '',
                                placeholder: (context, url) => Container(
                                  height: 150, color: Colors.grey[800],
                                  child: const Center(child: Icon(Icons.fitness_center, size: 60, color: Colors.grey)),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 150, color: Colors.grey[800],
                                  child: const Center(child: Icon(Icons.fitness_center, size: 60, color: Colors.grey)),
                                ),
                                fit: BoxFit.cover,
                                height: 150,
                                width: double.infinity,
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(ex['name'] ?? '', style: AppText.titleSm),
                                        if (ex['name_ar'] != null)
                                          Text(ex['name_ar'], style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            _buildBadge(ex['equipment'] ?? 'Bodyweight', Colors.orangeAccent),
                                            const SizedBox(width: 8),
                                            _buildBadge(ex['category'] ?? 'Strength', Colors.blueAccent),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                  if (videoId != null && videoId.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 32),
                                      onPressed: () => _openYouTube(videoId),
                                    )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Text(text.toUpperCase(), style: AppText.labelSm.copyWith(color: color, fontSize: 10)),
    );
  }
}

class LoggedSet {
  final int setNumber;
  final double weight;
  final int reps;
  LoggedSet({required this.setNumber, required this.weight, required this.reps});
}

class _ExerciseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final String defaultMuscleGroup;
  const _ExerciseDetailScreen({required this.exercise, required this.defaultMuscleGroup});

  @override
  State<_ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<_ExerciseDetailScreen> {
  final List<LoggedSet> _sets = [];
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  bool _saving = false;

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
      setState(() {
        _sets.add(LoggedSet(setNumber: _sets.length + 1, weight: w, reps: r));
        _repsController.clear();
      });
    }
  }

  Future<void> _saveWorkout() async {
    if (_sets.isEmpty) return;
    if (currentUserId == null) return;
    setState(() => _saving = true);
    
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final startTime = DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(); // mock start
      
      // 1. Create Session
      final session = await supabase.from('workout_sessions').insert({
        'user_id': currentUserId,
        'muscle_group': widget.defaultMuscleGroup,
        'session_name': '${widget.defaultMuscleGroup} Workout',
        'session_date': today,
        'started_at': startTime,
        'ended_at': DateTime.now().toIso8601String(),
        'duration_min': 30,
      }).select().single();
      
      final sessionId = session['id'];

      // 2. Save Sets
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

      // 3. Save Exercise Progress
      final bestSet = _sets.reduce((a, b) => (a.weight * a.reps) > (b.weight * b.reps) ? a : b);
      final oneRM = bestSet.weight * (1 + bestSet.reps / 30.0);
      final totalVolume = _sets.fold(0.0, (sum, item) => sum + (item.weight * item.reps));

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout Logged!')));

    } on PostgrestException catch (e) {
      debugPrint('DB Error Logging Workout: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final String? videoId = ex['youtube_video_id'];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(ex['name'] ?? 'Exercise', style: AppText.titleMd),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ex['image_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: ex['image_url'],
                  height: 250, width: double.infinity, fit: BoxFit.cover,
                  placeholder: (c, u) => Container(color: Colors.grey[800]),
                  errorWidget: (c, u, e) => Container(color: Colors.grey[800]),
                ),
              ),
            const SizedBox(height: 16),
            if (ex['name_ar'] != null)
               Text(ex['name_ar'], style: AppText.headlineSm),
            const SizedBox(height: 16),
            if (videoId != null && videoId.isNotEmpty) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Watch Tutorial'),
                onPressed: () => _openYouTube(videoId),
              ),
              const SizedBox(height: 16),
            ],
            if (ex['instructions_ar'] != null && ex['instructions_ar'].toString().isNotEmpty) ...[
              Text('Instructions', style: AppText.titleSm.copyWith(color: AppColors.primaryFixed)),
              const SizedBox(height: 8),
              Text(ex['instructions_ar'], style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 24),
            ],
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            Text('Log Sets', style: AppText.titleMd),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Weight (kg)',
                      filled: true, fillColor: AppColors.surfaceContainerHigh,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _repsController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Reps',
                      filled: true, fillColor: AppColors.surfaceContainerHigh,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _addSet,
                  icon: const Icon(Icons.add_circle, size: 40, color: AppColors.primaryFixed),
                )
              ],
            ),
            const SizedBox(height: 24),
            if (_sets.isNotEmpty)
              Container(
                decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _sets.length,
                  separatorBuilder: (c, i) => const Divider(color: Colors.white12),
                  itemBuilder: (context, index) {
                    final s = _sets[index];
                    return ListTile(
                      title: Text('Set ${s.setNumber}', style: AppText.titleSm),
                      trailing: Text('${s.weight} kg x ${s.reps} reps', style: AppText.bodyMd),
                    );
                  },
                ),
              ),
            const SizedBox(height: 32),
            if (_sets.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryFixed,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _saving ? null : _saveWorkout,
                  child: _saving ? const CircularProgressIndicator() : const Text('Save Workout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
          ],
        ),
      ),
    );
  }
}
