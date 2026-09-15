import 'package:flutter/material.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

import '../l10n/app_localizations.dart';
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

class _WorkoutScreenState extends State<WorkoutScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Three tabs — the old "Coach AI / Smart Trainer" tab was removed
    // (owner call: redundant, no real use).
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          l10n.workoutTitle,
          style: AppText.styledHeadlineSm(
            isArabic: Localizations.localeOf(context).languageCode == 'ar',
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryFixed,
          labelColor: AppColors.primaryFixed,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          // Smaller, tighter labels so the three tabs sit comfortably in
          // one row on narrow screens.
          labelStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          // Localized single-line labels — the old hardcoded
          // "English\n(Arabic)" stack showed both languages in every locale.
          tabs: [
            Tab(text: l10n.myProgram),
            Tab(text: l10n.workoutLibrary),
            Tab(text: l10n.logWorkout),
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
              ],
            ),
          ),
          // Reserve exactly the floating bar's footprint (same rule as
          // Home) so tab content can scroll clear of it.
          SizedBox(height: LiquidTabBar.reservedHeight(context) + 8),
        ],
      ),
    );
  }
}
