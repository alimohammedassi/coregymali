import 'package:flutter/material.dart';
import 'package:coregym2/l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'workout_tabs/my_program_tab.dart';
import 'workout_tabs/programs_library_tab.dart';
import 'workout_tabs/log_workout_tab.dart';
import 'fitness_coach_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.workoutTitle, style: AppText.headlineSm),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryFixed,
          labelColor: AppColors.primaryFixed,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          tabs: const [
            Tab(text: 'My Program\n(برنامجي)'),
            Tab(text: 'Library\n(مكتبة)'),
            Tab(text: 'Log Workout\n(سجّل)'),
            Tab(text: 'Coach AI\n(مدرب)'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                MyProgramTab(),
                ProgramsLibraryTab(),
                LogWorkoutTab(),
                FitnessCoachScreen(),
              ],
            ),
          ),
          const SizedBox(height: 110),
        ],
      ),
    );
  }
}
