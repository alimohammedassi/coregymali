import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../theme/app_text.dart';
import '../../domain/entities/client_full_data_entity.dart';
import '../providers/coach_dashboard_providers.dart';
import '../widgets/coach_shared.dart';

class ClientDataScreen extends StatefulWidget {
  final String clientId;
  const ClientDataScreen({super.key, required this.clientId});

  @override
  State<ClientDataScreen> createState() => _ClientDataScreenState();
}

class _ClientDataScreenState extends State<ClientDataScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final range = context.read<SelectedDateRangeNotifier>().range;
      context.read<ClientDataNotifier>().fetch(
            widget.clientId,
            from: range.start,
            to: range.end,
          );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final currentRange = context.read<SelectedDateRangeNotifier>().range;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: currentRange,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: kCoachGold,
            onPrimary: Colors.black,
            surface: Color(0xFF1A1919),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      context.read<SelectedDateRangeNotifier>().update(picked);
      context
          .read<ClientDataNotifier>()
          .refetch(from: picked.start, to: picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCoachBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildDateRangeBar(),
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Consumer<ClientDataNotifier>(
      builder: (ctx, notifier, _) {
        final profile = notifier.data?.profile;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kCoachCard2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kCoachBorder),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              CoachAvatar(url: profile?.avatarUrl, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?.name ?? 'Client',
                        style:
                            AppText.titleMd.copyWith(color: Colors.white)),
                    Text('Client Data', style: AppText.bodySm),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  final range =
                      context.read<SelectedDateRangeNotifier>().range;
                  context.read<ClientDataNotifier>().refetch(
                        from: range.start,
                        to: range.end,
                      );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kCoachCard2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kCoachBorder),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Date range bar ───────────────────────────────────────────────────────

  Widget _buildDateRangeBar() {
    return Consumer<SelectedDateRangeNotifier>(
      builder: (ctx, rangeN, _) {
        final r = rangeN.range;
        String fmt(DateTime d) =>
            '${d.day}/${d.month}/${d.year}';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: kCoachCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kCoachGold.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range_rounded,
                      color: kCoachGold, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    '${fmt(r.start)} → ${fmt(r.end)}',
                    style: AppText.titleSm.copyWith(color: kCoachGold),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit_calendar_rounded,
                      color: kCoachMuted, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Tab bar ──────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: TabBar(
        controller: _tabController,
        indicatorColor: kCoachGold,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2,
        labelColor: kCoachGold,
        unselectedLabelColor: kCoachSubtle,
        labelStyle:
            AppText.labelMd.copyWith(color: kCoachGold, letterSpacing: 1),
        unselectedLabelStyle:
            AppText.labelMd.copyWith(color: kCoachSubtle, letterSpacing: 1),
        tabs: const [
          Tab(text: 'NUTRITION'),
          Tab(text: 'WORKOUTS'),
          Tab(text: 'BODY'),
          Tab(text: 'SUMMARY'),
        ],
      ),
    );
  }

  // ── Tab content ──────────────────────────────────────────────────────────

  Widget _buildTabContent() {
    return Consumer<ClientDataNotifier>(
      builder: (ctx, notifier, _) {
        if (notifier.isLoading) {
          return const Center(
              child: CircularProgressIndicator(
                  color: kCoachGold, strokeWidth: 2));
        }

        if (notifier.error != null) {
          return CoachErrorState(
            message: notifier.error!,
            onRetry: () {
              final range =
                  context.read<SelectedDateRangeNotifier>().range;
              notifier.refetch(from: range.start, to: range.end);
            },
          );
        }

        final data = notifier.data;
        if (data == null) {
          return const Center(
              child: Text('No data',
                  style: TextStyle(color: Colors.white54)));
        }

        return TabBarView(
          controller: _tabController,
          children: [
            _NutritionTab(logs: data.nutritionLogs),
            _WorkoutsTab(sessions: data.workoutSessions),
            _MeasurementsTab(measurements: data.bodyMeasurements),
            _SummaryTab(summaries: data.dailySummaries),
          ],
        );
      },
    );
  }
}

// ── Nutrition tab ─────────────────────────────────────────────────────────────

class _NutritionTab extends StatelessWidget {
  final List<NutritionLog> logs;
  const _NutritionTab({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const CoachEmptyState(
          message: 'No nutrition logs',
          icon: Icons.restaurant_outlined);
    }

    final Map<String, List<NutritionLog>> grouped = {};
    for (final l in logs) {
      final key =
          '${l.loggedDate.day}/${l.loggedDate.month}/${l.loggedDate.year}';
      grouped.putIfAbsent(key, () => []).add(l);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
      children: grouped.entries.map((e) {
        final total = e.value.fold(0.0, (s, l) => s + l.calories);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: e.key,
              badge: '${total.toStringAsFixed(0)} kcal',
              badgeColor: kCoachGold,
            ),
            ...e.value.map((l) => _NutritionCard(log: l)),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final NutritionLog log;
  const _NutritionCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCoachCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCoachBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kCoachGold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.restaurant_rounded,
                color: kCoachGold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.foodName,
                    style:
                        AppText.titleSm.copyWith(color: Colors.white)),
                Text(log.mealType.toUpperCase(),
                    style: AppText.labelMd.copyWith(color: kCoachMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${log.calories.toStringAsFixed(0)} kcal',
                  style: AppText.titleSm.copyWith(color: kCoachGold)),
              Text(
                'P${log.proteinG.toStringAsFixed(0)}  C${log.carbsG.toStringAsFixed(0)}  F${log.fatG.toStringAsFixed(0)}',
                style: AppText.bodySm.copyWith(color: kCoachMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Workouts tab ──────────────────────────────────────────────────────────────

class _WorkoutsTab extends StatelessWidget {
  final List<WorkoutSession> sessions;
  const _WorkoutsTab({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const CoachEmptyState(
          message: 'No workout sessions',
          icon: Icons.fitness_center_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
      itemCount: sessions.length,
      itemBuilder: (ctx, i) => _WorkoutCard(session: sessions[i]),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final WorkoutSession session;
  const _WorkoutCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCoachCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCoachBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.fitness_center_rounded,
                color: Color(0xFF7C3AED), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.sessionName,
                    style:
                        AppText.titleSm.copyWith(color: Colors.white)),
                Text(session.muscleGroup,
                    style: AppText.bodySm.copyWith(color: kCoachMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${session.durationMin} min',
                  style: AppText.titleSm
                      .copyWith(color: const Color(0xFF7C3AED))),
              Text(
                '${session.sessionDate.day}/${session.sessionDate.month}',
                style: AppText.bodySm.copyWith(color: kCoachSubtle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Measurements tab ──────────────────────────────────────────────────────────

class _MeasurementsTab extends StatelessWidget {
  final List<BodyMeasurement> measurements;
  const _MeasurementsTab({required this.measurements});

  @override
  Widget build(BuildContext context) {
    if (measurements.isEmpty) {
      return const CoachEmptyState(
          message: 'No measurements yet',
          icon: Icons.monitor_weight_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
      itemCount: measurements.length,
      itemBuilder: (ctx, i) => _MeasurementCard(m: measurements[i]),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  final BodyMeasurement m;
  const _MeasurementCard({required this.m});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCoachCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCoachBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${m.measuredDate.day}/${m.measuredDate.month}/${m.measuredDate.year}',
            style: AppText.labelMd
                .copyWith(color: kCoachMuted, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (m.weightKg != null)
                _MeasurePill(
                    label: 'Weight',
                    value: '${m.weightKg!.toStringAsFixed(1)} kg',
                    color: kCoachGold),
              if (m.bodyFatPct != null)
                _MeasurePill(
                    label: 'Body Fat',
                    value: '${m.bodyFatPct!.toStringAsFixed(1)}%',
                    color: const Color(0xFFF87171)),
              if (m.muscleMass != null)
                _MeasurePill(
                    label: 'Muscle',
                    value: '${m.muscleMass!.toStringAsFixed(1)} kg',
                    color: const Color(0xFF34D399)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeasurePill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MeasurePill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(value, style: AppText.titleSm.copyWith(color: color)),
          Text(label, style: AppText.labelMd.copyWith(color: kCoachMuted)),
        ],
      ),
    );
  }
}

// ── Summary tab ───────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  final List<DailySummary> summaries;
  const _SummaryTab({required this.summaries});

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const CoachEmptyState(
          message: 'No daily summaries',
          icon: Icons.bar_chart_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
      itemCount: summaries.length,
      itemBuilder: (ctx, i) => _SummaryCard(s: summaries[i]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DailySummary s;
  const _SummaryCard({required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCoachCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: s.workoutDone
              ? const Color(0xFF34D399).withOpacity(0.3)
              : kCoachBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${s.summaryDate.day}/${s.summaryDate.month}/${s.summaryDate.year}',
                style: AppText.titleSm.copyWith(color: Colors.white),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: s.workoutDone
                      ? const Color(0xFF34D399).withOpacity(0.12)
                      : kCoachCard2,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s.workoutDone ? '✓ Trained' : 'Rest',
                  style: AppText.labelMd.copyWith(
                    color: s.workoutDone
                        ? const Color(0xFF34D399)
                        : kCoachSubtle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SumMetric(
                icon: Icons.local_fire_department_rounded,
                label: 'Calories in',
                value: s.caloriesConsumed.toStringAsFixed(0),
                color: kCoachGold,
              ),
              const SizedBox(width: 10),
              _SumMetric(
                icon: Icons.bolt_rounded,
                label: 'Burned',
                value: s.caloriesBurned.toStringAsFixed(0),
                color: const Color(0xFF60A5FA),
              ),
              const SizedBox(width: 10),
              _SumMetric(
                icon: Icons.directions_walk_rounded,
                label: 'Steps',
                value: '${s.steps}',
                color: const Color(0xFF34D399),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SumMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SumMetric(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: AppText.titleSm.copyWith(color: Colors.white)),
            Text(label,
                style: AppText.bodySm
                    .copyWith(color: kCoachMuted, height: 1.2),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String badge;
  final Color badgeColor;
  const _SectionHeader(
      {required this.title, required this.badge, required this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(title,
              style: AppText.labelSm
                  .copyWith(color: kCoachMuted, letterSpacing: 2)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(badge,
                style: AppText.labelMd.copyWith(color: badgeColor)),
          ),
        ],
      ),
    );
  }
}

