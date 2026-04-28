import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../theme/app_text.dart';
import '../../domain/entities/client_full_data_entity.dart';
import '../providers/coach_dashboard_providers.dart';
import '../widgets/coach_shared.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kGold = Color(0xFFC9A84C);
const _kGoldDim = Color(0xFFA07832);
const _kGoldGlow = Color(0x33C9A84C);
const _kGoldSubtle = Color(0x1AC9A84C);
const _kSuccess = Color(0xFF34D399);
const _kBlue = Color(0xFF60A5FA);
const _kPurple = Color(0xFF7C3AED);
const _kRed = Color(0xFFF87171);
const _kAmber = Color(0xFFFBBF24);

const _kCardR = BorderRadius.all(Radius.circular(20));
const _kPillR = BorderRadius.all(Radius.circular(12));
const _kBadgeR = BorderRadius.all(Radius.circular(8));

// ── Screen ────────────────────────────────────────────────────────────────────

class ClientDataScreen extends StatefulWidget {
  final String clientId;
  const ClientDataScreen({super.key, required this.clientId});

  @override
  State<ClientDataScreen> createState() => _ClientDataScreenState();
}

class _ClientDataScreenState extends State<ClientDataScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _refreshing = false;

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
            primary: _kGold,
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
      context.read<ClientDataNotifier>().refetch(
        from: picked.start,
        to: picked.end,
      );
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final range = context.read<SelectedDateRangeNotifier>().range;
    await context.read<ClientDataNotifier>().refetch(
      from: range.start,
      to: range.end,
    );
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCoachBg,
      body: Column(
        children: [
          _Header(
            clientId: widget.clientId,
            refreshing: _refreshing,
            onRefresh: _refresh,
          ),
          _DateRangeBar(onTap: _pickDateRange),
          const SizedBox(height: 14),
          _TabBar(controller: _tabController),
          const SizedBox(height: 4),
          Expanded(
            child: _TabContent(
              controller: _tabController,
              clientId: widget.clientId,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String clientId;
  final bool refreshing;
  final VoidCallback onRefresh;

  const _Header({
    required this.clientId,
    required this.refreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Consumer<ClientDataNotifier>(
      builder: (ctx, notifier, _) {
        final profile = notifier.data?.profile;
        return Container(
          padding: EdgeInsets.fromLTRB(16, top + 14, 16, 16),
          child: Row(
            children: [
              // Back button
              _IconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 18,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 14),

              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _kGold, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: _kGoldGlow,
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CoachAvatar(url: profile?.avatarUrl, size: 50),
                ),
              ),
              const SizedBox(width: 12),

              // Name + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.name ?? 'Client',
                      style: AppText.titleMd.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _kGoldSubtle,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(6),
                        ),
                        border: Border.all(color: _kGold.withOpacity(0.35)),
                      ),
                      child: Text(
                        'CLIENT DATA',
                        style: AppText.labelSm.copyWith(
                          color: _kGold,
                          fontSize: 9,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Refresh button
              _IconBtn(
                icon: Icons.sync_rounded,
                size: 20,
                spinning: refreshing,
                onTap: onRefresh,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Reusable icon button ──────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final bool spinning;

  const _IconBtn({
    required this.icon,
    required this.size,
    required this.onTap,
    this.spinning = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, color: Colors.white, size: size);
    if (spinning) {
      iconWidget = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        builder: (_, v, child) =>
            Transform.rotate(angle: v * 6.28, child: child),
        child: iconWidget,
      );
    }
    return Material(
      color: kCoachCard2,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        splashColor: _kGoldSubtle,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: iconWidget,
        ),
      ),
    );
  }
}

// ── Date range bar ────────────────────────────────────────────────────────────

class _DateRangeBar extends StatelessWidget {
  final VoidCallback onTap;
  const _DateRangeBar({required this.onTap});

  String _fmt(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SelectedDateRangeNotifier>(
      builder: (ctx, rangeN, _) {
        final r = rangeN.range;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              splashColor: _kGoldSubtle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: kCoachCard,
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  border: Border.all(color: _kGold.withOpacity(0.25)),
                  boxShadow: const [
                    BoxShadow(
                      color: _kGoldGlow,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: _kGoldSubtle,
                        borderRadius: _kBadgeR,
                      ),
                      child: const Icon(
                        Icons.date_range_rounded,
                        color: _kGold,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DATE RANGE',
                          style: AppText.labelSm.copyWith(
                            color: kCoachMuted,
                            fontSize: 9,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_fmt(r.start)}  →  ${_fmt(r.end)}',
                          style: AppText.titleSm.copyWith(color: _kGold),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _kGold.withOpacity(0.12),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8),
                        ),
                        border: Border.all(color: _kGold.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            color: _kGold,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Filter',
                            style: AppText.labelSm.copyWith(
                              color: _kGold,
                              fontSize: 11,
                            ),
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
      },
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: kCoachCard2,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: kCoachBorder),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kGold, _kGoldDim],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(11)),
            boxShadow: const [
              BoxShadow(color: _kGoldGlow, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(3),
          dividerColor: Colors.transparent,
          labelColor: Colors.black,
          unselectedLabelColor: kCoachSubtle,
          labelStyle: AppText.labelMd.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            fontSize: 12,
          ),
          unselectedLabelStyle: AppText.labelMd.copyWith(
            letterSpacing: 0.5,
            fontSize: 12,
          ),
          tabs: const [
            Tab(text: 'Nutrition'),
            Tab(text: 'Workouts'),
            Tab(text: 'Body'),
            Tab(text: 'Summary'),
          ],
        ),
      ),
    );
  }
}

// ── Tab content ───────────────────────────────────────────────────────────────

class _TabContent extends StatelessWidget {
  final TabController controller;
  final String clientId;
  const _TabContent({required this.controller, required this.clientId});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClientDataNotifier>(
      builder: (ctx, notifier, _) {
        if (notifier.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: _kGold,
              strokeWidth: 2,
              backgroundColor: _kGoldSubtle,
            ),
          );
        }
        if (notifier.error != null) {
          return CoachErrorState(
            message: notifier.error!,
            onRetry: () {
              final range = context.read<SelectedDateRangeNotifier>().range;
              notifier.refetch(from: range.start, to: range.end);
            },
          );
        }
        final data = notifier.data;
        if (data == null) {
          return const CoachEmptyState(
            message: 'No data available',
            icon: Icons.inbox_outlined,
          );
        }
        return TabBarView(
          controller: controller,
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

// ═══════════════════════════════════════════════════════════════════════════════
// NUTRITION TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _NutritionTab extends StatelessWidget {
  final List<NutritionLog> logs;
  const _NutritionTab({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const CoachEmptyState(
        message: 'No nutrition logs in this period',
        icon: Icons.restaurant_outlined,
      );
    }

    // Group by date
    final Map<String, List<NutritionLog>> grouped = {};
    for (final l in logs) {
      final key =
          '${l.loggedDate.year}-${l.loggedDate.month.toString().padLeft(2, '0')}-${l.loggedDate.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(l);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    // Compute daily totals for the summary bar
    double totalCals = 0, totalP = 0, totalC = 0, totalF = 0;
    for (final l in logs) {
      totalCals += l.calories;
      totalP += l.proteinG;
      totalC += l.carbsG;
      totalF += l.fatG;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
      children: [
        // Period summary card
        _NutritionSummaryCard(
          calories: totalCals,
          protein: totalP,
          carbs: totalC,
          fat: totalF,
          days: grouped.length,
        ),
        const SizedBox(height: 20),
        ...sortedKeys.map((key) {
          final dayLogs = grouped[key]!;
          final dayTotal = dayLogs.fold(0.0, (s, l) => s + l.calories);
          final date = DateTime.parse(key);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DaySectionHeader(date: date, totalKcal: dayTotal),
              const SizedBox(height: 8),
              ...dayLogs.map((l) => _NutritionCard(log: l)),
              const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }
}

class _NutritionSummaryCard extends StatelessWidget {
  final double calories, protein, carbs, fat;
  final int days;
  const _NutritionSummaryCard({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kGold.withOpacity(0.12), _kGold.withOpacity(0.04)],
        ),
        borderRadius: _kCardR,
        border: Border.all(color: _kGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: _kGold, size: 16),
              const SizedBox(width: 8),
              Text(
                'PERIOD SUMMARY  ·  $days days',
                style: AppText.labelSm.copyWith(
                  color: _kGold,
                  letterSpacing: 1.5,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryMetric(
                label: 'Total Calories',
                value: '${calories.toStringAsFixed(0)}',
                unit: 'kcal',
                color: _kGold,
              ),
              const SizedBox(width: 8),
              _SummaryMetric(
                label: 'Avg / Day',
                value: '${(calories / days.clamp(1, 999)).toStringAsFixed(0)}',
                unit: 'kcal',
                color: _kAmber,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MacroBar(label: 'Protein', value: protein, color: _kBlue),
              const SizedBox(width: 8),
              _MacroBar(label: 'Carbs', value: carbs, color: _kSuccess),
              const SizedBox(width: 8),
              _MacroBar(label: 'Fat', value: fat, color: _kRed),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: _kPillR,
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppText.labelSm.copyWith(color: kCoachMuted, fontSize: 10),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: AppText.titleMd.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: AppText.bodySm.copyWith(color: kCoachMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MacroBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: _kPillR,
        ),
        child: Column(
          children: [
            Text(
              '${value.toStringAsFixed(0)}g',
              style: AppText.titleSm.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppText.labelSm.copyWith(color: kCoachMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySectionHeader extends StatelessWidget {
  final DateTime date;
  final double totalKcal;
  const _DaySectionHeader({required this.date, required this.totalKcal});

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[date.weekday - 1];
    final dateStr = '${months[date.month - 1]} ${date.day}';

    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: _kGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$dayName, $dateStr',
          style: AppText.labelSm.copyWith(
            color: Colors.white70,
            letterSpacing: 1.2,
            fontSize: 11,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _kGold.withOpacity(0.1),
            borderRadius: _kBadgeR,
            border: Border.all(color: _kGold.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: _kGold,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                '${totalKcal.toStringAsFixed(0)} kcal',
                style: AppText.labelSm.copyWith(color: _kGold, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final NutritionLog log;
  const _NutritionCard({required this.log});

  Color get _mealColor {
    switch (log.mealType.toLowerCase()) {
      case 'breakfast':
        return _kAmber;
      case 'lunch':
        return _kSuccess;
      case 'dinner':
        return _kBlue;
      default:
        return _kGold;
    }
  }

  IconData get _mealIcon {
    switch (log.mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_sunny_rounded;
      case 'lunch':
        return Icons.light_mode_rounded;
      case 'dinner':
        return Icons.nights_stay_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCoachCard,
        borderRadius: _kCardR,
        border: Border.all(color: kCoachBorder),
      ),
      child: Row(
        children: [
          // Meal icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _mealColor.withOpacity(0.1),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(color: _mealColor.withOpacity(0.25)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_mealIcon, color: _mealColor, size: 17),
                const SizedBox(height: 1),
                Text(
                  log.mealType.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: _mealColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Name + macros
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.foodName,
                  style: AppText.titleSm.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _MacroChip(label: 'P', value: log.proteinG, color: _kBlue),
                    const SizedBox(width: 5),
                    _MacroChip(label: 'C', value: log.carbsG, color: _kSuccess),
                    const SizedBox(width: 5),
                    _MacroChip(label: 'F', value: log.fatG, color: _kRed),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Calories
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                log.calories.toStringAsFixed(0),
                style: AppText.titleMd.copyWith(
                  color: _kGold,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text('kcal', style: AppText.bodySm.copyWith(color: kCoachMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(0)}g',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WORKOUTS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _WorkoutsTab extends StatelessWidget {
  final List<WorkoutSession> sessions;
  const _WorkoutsTab({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const CoachEmptyState(
        message: 'No workout sessions in this period',
        icon: Icons.fitness_center_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
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
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCoachCard,
        borderRadius: _kCardR,
        border: Border.all(color: kCoachBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Purple accent top bar
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_kPurple, Color(0xFF9F67FA)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _kPurple.withOpacity(0.12),
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    border: Border.all(color: _kPurple.withOpacity(0.25)),
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: _kPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),

                // Name + muscle group
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.sessionName,
                        style: AppText.titleSm.copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _kPurple.withOpacity(0.1),
                          borderRadius: _kBadgeR,
                        ),
                        child: Text(
                          session.muscleGroup.toUpperCase(),
                          style: AppText.labelSm.copyWith(
                            color: _kPurple,
                            fontSize: 9,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Duration + date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _kPurple.withOpacity(0.12),
                        borderRadius: _kBadgeR,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: _kPurple,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${session.durationMin}m',
                            style: AppText.labelSm.copyWith(
                              color: _kPurple,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${months[session.sessionDate.month - 1]} ${session.sessionDate.day}',
                      style: AppText.bodySm.copyWith(color: kCoachSubtle),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BODY / MEASUREMENTS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _MeasurementsTab extends StatelessWidget {
  final List<BodyMeasurement> measurements;
  const _MeasurementsTab({required this.measurements});

  @override
  Widget build(BuildContext context) {
    if (measurements.isEmpty) {
      return const CoachEmptyState(
        message: 'No measurements recorded',
        icon: Icons.monitor_weight_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
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
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCoachCard,
        borderRadius: _kCardR,
        border: Border.all(color: kCoachBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: _kBadgeR,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  '${days[m.measuredDate.weekday - 1]}, '
                  '${months[m.measuredDate.month - 1]} ${m.measuredDate.day}',
                  style: AppText.labelSm.copyWith(
                    color: Colors.white70,
                    letterSpacing: 1,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (m.weightKg != null)
                _MeasurePill(
                  icon: Icons.monitor_weight_rounded,
                  label: 'Weight',
                  value: '${m.weightKg!.toStringAsFixed(1)} kg',
                  color: _kGold,
                ),
              if (m.bodyFatPct != null)
                _MeasurePill(
                  icon: Icons.water_drop_rounded,
                  label: 'Body Fat',
                  value: '${m.bodyFatPct!.toStringAsFixed(1)}%',
                  color: _kRed,
                ),
              if (m.muscleMass != null)
                _MeasurePill(
                  icon: Icons.fitness_center_rounded,
                  label: 'Muscle',
                  value: '${m.muscleMass!.toStringAsFixed(1)} kg',
                  color: _kSuccess,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeasurePill extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _MeasurePill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: _kPillR,
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppText.titleSm.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: AppText.labelSm.copyWith(
                  color: kCoachMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUMMARY TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _SummaryTab extends StatelessWidget {
  final List<DailySummary> summaries;
  const _SummaryTab({required this.summaries});

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const CoachEmptyState(
        message: 'No daily summaries yet',
        icon: Icons.bar_chart_outlined,
      );
    }

    // Compute overall summary
    final trainedDays = summaries.where((s) => s.workoutDone).length;
    final avgCals = summaries.isEmpty
        ? 0.0
        : summaries.fold(0.0, (s, d) => s + d.caloriesConsumed) /
              summaries.length;
    final totalSteps = summaries.fold(0, (s, d) => s + d.steps);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
      children: [
        _WeeklyOverviewCard(
          totalDays: summaries.length,
          trainedDays: trainedDays,
          avgCals: avgCals,
          totalSteps: totalSteps,
        ),
        const SizedBox(height: 20),
        ...summaries.reversed.map((s) => _SummaryCard(s: s)),
      ],
    );
  }
}

class _WeeklyOverviewCard extends StatelessWidget {
  final int totalDays, trainedDays, totalSteps;
  final double avgCals;
  const _WeeklyOverviewCard({
    required this.totalDays,
    required this.trainedDays,
    required this.avgCals,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final consistency = totalDays == 0 ? 0.0 : trainedDays / totalDays;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kSuccess.withOpacity(0.1), _kBlue.withOpacity(0.05)],
        ),
        borderRadius: _kCardR,
        border: Border.all(color: _kSuccess.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: _kSuccess, size: 16),
              const SizedBox(width: 8),
              Text(
                'PERIOD OVERVIEW',
                style: AppText.labelSm.copyWith(
                  color: _kSuccess,
                  letterSpacing: 1.5,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _OverviewMetric(
                label: 'Consistency',
                value: '${(consistency * 100).toStringAsFixed(0)}%',
                color: _kSuccess,
              ),
              const SizedBox(width: 8),
              _OverviewMetric(
                label: 'Trained Days',
                value: '$trainedDays / $totalDays',
                color: _kBlue,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Consistency bar
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            child: LinearProgressIndicator(
              value: consistency,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation(_kSuccess),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _OverviewMetric(
                label: 'Avg Calories',
                value: avgCals.toStringAsFixed(0),
                color: _kGold,
              ),
              const SizedBox(width: 8),
              _OverviewMetric(
                label: 'Total Steps',
                value: totalSteps > 1000
                    ? '${(totalSteps / 1000).toStringAsFixed(1)}k'
                    : '$totalSteps',
                color: _kAmber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: _kPillR,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppText.labelSm.copyWith(color: kCoachMuted, fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppText.titleSm.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DailySummary s;
  const _SummaryCard({required this.s});

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCoachCard,
        borderRadius: _kCardR,
        border: Border.all(
          color: s.workoutDone ? _kSuccess.withOpacity(0.3) : kCoachBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date row + workout badge
          Row(
            children: [
              Text(
                '${days[s.summaryDate.weekday - 1]}, '
                '${months[s.summaryDate.month - 1]} ${s.summaryDate.day}',
                style: AppText.titleSm.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: s.workoutDone
                      ? _kSuccess.withOpacity(0.12)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  border: Border.all(
                    color: s.workoutDone
                        ? _kSuccess.withOpacity(0.3)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      s.workoutDone
                          ? Icons.check_circle_rounded
                          : Icons.bedtime_rounded,
                      color: s.workoutDone ? _kSuccess : kCoachSubtle,
                      size: 12,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      s.workoutDone ? 'Trained' : 'Rest Day',
                      style: AppText.labelSm.copyWith(
                        color: s.workoutDone ? _kSuccess : kCoachSubtle,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metrics row
          Row(
            children: [
              _SumMetric(
                icon: Icons.local_fire_department_rounded,
                label: 'Calories In',
                value: s.caloriesConsumed.toStringAsFixed(0),
                color: _kGold,
              ),
              const SizedBox(width: 8),
              _SumMetric(
                icon: Icons.bolt_rounded,
                label: 'Burned',
                value: s.caloriesBurned.toStringAsFixed(0),
                color: _kBlue,
              ),
              const SizedBox(width: 8),
              _SumMetric(
                icon: Icons.directions_walk_rounded,
                label: 'Steps',
                value: s.steps > 1000
                    ? '${(s.steps / 1000).toStringAsFixed(1)}k'
                    : '${s.steps}',
                color: _kSuccess,
              ),
            ],
          ),

          // Net calories bar
          if (s.caloriesConsumed > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net',
                  style: AppText.labelSm.copyWith(
                    color: kCoachMuted,
                    fontSize: 10,
                  ),
                ),
                Text(
                  '${(s.caloriesConsumed - s.caloriesBurned).toStringAsFixed(0)} kcal',
                  style: AppText.labelSm.copyWith(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(
                value: (s.caloriesBurned / s.caloriesConsumed.clamp(1, 9999))
                    .clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: _kGold.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation(_kBlue),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SumMetric extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _SumMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 5),
            Text(
              value,
              style: AppText.titleSm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppText.bodySm.copyWith(
                color: kCoachMuted,
                height: 1.2,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
