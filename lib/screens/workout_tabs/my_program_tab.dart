import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../services/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyProgramTab extends StatefulWidget {
  const MyProgramTab({super.key});

  @override
  State<MyProgramTab> createState() => _MyProgramTabState();
}

class _MyProgramTabState extends State<MyProgramTab> {
  bool _isLoading = true;
  Map<String, dynamic>? _activeProgram;

  @override
  void initState() {
    super.initState();
    _loadActiveProgram();
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
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryFixed));
    }

    if (_activeProgram == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_late, size: 64, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No Active Program', style: AppText.headlineSm),
            const SizedBox(height: 8),
            Text('Go to the Library tab to select a program.', style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
      );
    }

    final progData = _activeProgram!['training_programs'] ?? {};
    final String progName = progData['name'] ?? 'Unknown';
    final String progNameAr = progData['name_ar'] ?? '';
    final String level = progData['level'] ?? 'All';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(level.toUpperCase(), style: AppText.labelSm.copyWith(color: AppColors.primaryFixed)),
                    ),
                    Text('Week ${_activeProgram!['current_week']}', style: AppText.titleSm),
                  ],
                ),
                const SizedBox(height: 16),
                Text(progName, style: AppText.headlineSm),
                if (progNameAr.isNotEmpty)
                  Text(progNameAr, style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 24),
                // Progress
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  child: LinearProgressIndicator(
                    value: 0.5,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryFixed),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text('50% Complete', style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Today\'s Workout', style: AppText.titleMd),
          const SizedBox(height: 16),
          // Placeholder for Today's workout (needs program_day_exercises join ideally)
          Card(
            color: AppColors.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const ListTile(
              leading: Icon(Icons.fitness_center, color: AppColors.primaryFixed),
              title: Text('Day 1 - Full Body'),
              subtitle: Text('5 Exercises'),
              trailing: Icon(Icons.chevron_right, color: Colors.white),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryFixed,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                // TODO: start workout
              },
              child: const Text('Start Today\'s Workout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }
}
