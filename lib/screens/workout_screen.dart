import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'workout_tabs/my_program_tab.dart';
import 'workout_tabs/programs_library_tab.dart';
import 'workout_tabs/log_workout_tab.dart';

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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('WORKOUT', style: AppText.headlineSm),
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MyProgramTab(),
          ProgramsLibraryTab(),
          LogWorkoutTab(),
        ],
      ),
    );
  }
}
