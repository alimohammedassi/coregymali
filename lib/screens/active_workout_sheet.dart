import 'dart:async';
import 'package:flutter/material.dart';
import '../services/workout_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class ActiveWorkoutSheet extends StatefulWidget {
  final String muscleGroup;
  final String exerciseName;
  final String sessionId;
  final VoidCallback onFinish;

  const ActiveWorkoutSheet({
    super.key,
    required this.muscleGroup,
    required this.exerciseName,
    required this.sessionId,
    required this.onFinish,
  });

  @override
  State<ActiveWorkoutSheet> createState() => _ActiveWorkoutSheetState();
}

class _ActiveWorkoutSheetState extends State<ActiveWorkoutSheet> {
  final _workoutService = WorkoutService();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();

  List<Map<String, dynamic>> _sets = [];
  bool _isLoading = true;
  int _restTimer = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadSets();
  }

  Future<void> _loadSets() async {
    final sets = await _workoutService.getSessionSets(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _sets = sets.where((s) => s['exercise_name'] == widget.exerciseName).toList();
      _isLoading = false;
    });
  }

  void _startRestTimer() {
    setState(() => _restTimer = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restTimer > 0) {
        setState(() => _restTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _logSet() async {
    if (_repsController.text.isEmpty || _weightController.text.isEmpty) return;
    final reps = int.tryParse(_repsController.text);
    final weight = double.tryParse(_weightController.text);

    setState(() => _isLoading = true);
    await _workoutService.logSet(
      sessionId: widget.sessionId,
      exerciseName: widget.exerciseName,
      setNumber: _sets.length + 1,
      reps: reps,
      weightKg: weight,
    );
    _startRestTimer();
    _repsController.clear();
    await _loadSets();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.exerciseName.toUpperCase(),
                  style: AppText.headlineSm,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          if (_restTimer > 0)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryFixed),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: AppColors.primaryFixed),
                  const SizedBox(width: 8),
                  Text(
                    'REST: 00:${_restTimer.toString().padLeft(2, '0')}',
                    style: AppText.titleMd.copyWith(color: AppColors.primaryFixed),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  style: AppText.bodyLg.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Weight (kg)',
                    labelStyle: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  style: AppText.bodyLg.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Reps',
                    labelStyle: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _logSet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryFixed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text('LOG SET', style: AppText.buttonPrimary.copyWith(color: Colors.black)),
            ),
          ),
          const SizedBox(height: 24),
          Text('PREVIOUS SETS', style: AppText.labelLg.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _sets.length,
                    itemBuilder: (context, index) {
                      final set = _sets[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Set ${set['set_number']}', style: AppText.titleSm),
                            Text('${set['weight_kg']} kg  ×  ${set['reps']} reps', style: AppText.bodyLg),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: widget.onFinish,
              child: Text(
                'FINISH ENTIRE WORKOUT',
                style: AppText.buttonPrimary.copyWith(color: AppColors.error),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
