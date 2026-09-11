import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../services/rank_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Read-only public profile of another client: commitment heatmap +
/// trend charts (calories / water / steps adherence), leaderboard style.
///
/// Life added in this version:
/// - Staggered fade+slide entrance for header → heatmap → trend card
/// - Animated count-up on the stat numbers instead of popping in
/// - Tier badge "pops" in with an elastic bounce
/// - Heatmap cells fill in one-by-one like a commit graph loading
/// - Chart crossfades when switching daily/weekly/cumulative or 7d/30d,
///   plus fl_chart's own point-draw animation
/// - Shimmering skeleton instead of a bare spinner while loading
class ClientProfileScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String? avatarUrl;
  final int score;
  final RankTier tier;

  const ClientProfileScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.score,
    required this.tier,
  });

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

enum _TrendMode { daily, weekly, cumulative }

class _ClientProfileScreenState extends State<ClientProfileScreen>
    with SingleTickerProviderStateMixin {
  final RankService _service = RankService();

  // One 35-day fetch feeds the heatmap AND both chart ranges (no refetch
  // when flipping 7/30 — the range is just a window over the same data).
  List<ActivityDay> _days = const [];
  bool _loading = true;
  String? _error;
  int _range = 30;
  _TrendMode _mode = _TrendMode.daily;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _headerFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
  );
  late final Animation<double> _heatmapFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.25, 0.8, curve: Curves.easeOut),
  );
  late final Animation<double> _trendFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
  );

  static const _calColor = Color(0xFFB2D742); // lime — calories
  static const _waterColor = Color(0xFF4DA8DC); // blue — water
  static const _stepsColor = Color(0xFFE8894D); // orange — steps

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final days = await _service.getUserActivity(widget.userId, days: 35);
      if (!mounted) return;
      setState(() {
        _days = days;
        _loading = false;
      });
      _entrance.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<ActivityDay> get _window =>
      _days.length > _range ? _days.sublist(_days.length - _range) : _days;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tierColors = _tierColorsOf(widget.tier);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: BackButton(color: AppColors.textPrimary),
      ),
      body: _loading
          ? const _ProfileSkeleton()
          : _error != null
          ? _errorView(l10n)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                _rise(_headerFade, _header(l10n, tierColors)),
                const SizedBox(height: 16),
                _rise(_heatmapFade, _heatmapCard(l10n)),
                const SizedBox(height: 16),
                _rise(_trendFade, _trendCard(l10n)),
              ],
            ),
    );
  }

  /// Wraps a section in a fade + gentle upward slide, driven by [anim].
  Widget _rise(Animation<double> anim, Widget child) {
    return FadeTransition(
      opacity: anim,
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, c) => Transform.translate(
          offset: Offset(0, (1 - anim.value) * 18),
          child: c,
        ),
        child: child,
      ),
    );
  }

  Widget _errorView(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: AppColors.textSecondary,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: Text(l10n.retry)),
        ],
      ),
    );
  }

  Widget _header(AppLocalizations l10n, (Color, String) tierColors) {
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
    final logged = _days.where((d) => d.calories > 0 || d.waterMl > 0).length;
    final avgScore = logged > 0
        ? (_days.fold<int>(0, (a, d) => a + d.score) / _days.length).round()
        : 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.primaryFixed.withValues(
                    alpha: 0.15,
                  ),
                  backgroundImage: (widget.avatarUrl?.isNotEmpty ?? false)
                      ? CachedNetworkImageProvider(widget.avatarUrl!)
                      : null,
                  child: (widget.avatarUrl?.isNotEmpty ?? false)
                      ? null
                      : Text(
                          initial,
                          style: AppText.displaySm.copyWith(
                            color: AppColors.primaryFixed,
                            fontSize: 28,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headlineMd.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.4, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: tierColors.$1.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${tierColors.$2} ${widget.score}',
                              style: AppText.labelSm.copyWith(
                                color: tierColors.$1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat(logged, l10n.cpDaysLoggedN(logged)),
              _stat(avgScore, l10n.cpAvgScore),
              _stat(_days.where((d) => d.workoutDone).length, l10n.cpWorkouts),
            ],
          ),
        ],
      ),
    );
  }

  /// A stat number that counts up from 0 instead of appearing instantly.
  Widget _stat(int value, String label) {
    return Expanded(
      child: Column(
        children: [
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) => Text(
              '$v',
              style: AppText.headlineMd.copyWith(
                color: AppColors.primaryFixed,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppText.labelSm.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// GitHub-style commitment grid: columns = weeks, rows = weekdays,
  /// cell intensity = day commitment score.
  Widget _heatmapCard(AppLocalizations l10n) {
    return _card(
      title: l10n.cpCommitment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeatmapGrid(days: _days),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.cpLess,
                style: AppText.labelSm.copyWith(color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  for (final intensity in [0.0, 0.33, 0.66, 1.0])
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: intensity == 0
                            ? AppColors.surfaceContainerHigh
                            : AppColors.primaryFixed.withValues(
                                alpha: intensity,
                              ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
              Text(
                l10n.cpMore,
                style: AppText.labelSm.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trendCard(AppLocalizations l10n) {
    return _card(
      title: l10n.cpTrend,
      trailing: _modeSwitch(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _rangeChip(l10n, 7, l10n.rankLast7),
              const SizedBox(width: 8),
              _rangeChip(l10n, 30, l10n.rankLast30),
            ],
          ),
          const SizedBox(height: 12),
          _legend(),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              // Key changes on mode/range flip → triggers the crossfade.
              child: KeyedSubtree(
                key: ValueKey('${_mode}_$_range'),
                child: _buildChart(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeSwitch() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in _TrendMode.values)
            GestureDetector(
              onTap: () => setState(() => _mode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _mode == mode
                      ? AppColors.primaryFixed
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  switch (mode) {
                    _TrendMode.daily => l10n.cpDaily,
                    _TrendMode.weekly => l10n.cpWeekly,
                    _TrendMode.cumulative => l10n.cpCumulative,
                  },
                  style: AppText.labelSm.copyWith(
                    color: _mode == mode
                        ? AppColors.onPrimary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rangeChip(AppLocalizations l10n, int days, String label) {
    final active = _range == days;
    return GestureDetector(
      onTap: () => setState(() => _range = days),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryFixed
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppText.labelSm.copyWith(
            color: active ? AppColors.onPrimary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (_calColor, l10n.cpCalories),
      (_waterColor, l10n.cpWater),
      (_stepsColor, l10n.cpSteps),
    ];
    return Wrap(
      spacing: 14,
      children: [
        for (final (color, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppText.labelSm.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildChart() {
    final window = _window;
    if (window.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.cpNoData,
          style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    final series = _seriesFor(window, _mode);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 120,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 40,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: AppColors.borderSubtle, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 40,
              reservedSize: 30,
              getTitlesWidget: (v, meta) => Text(
                '${v.toInt()}%',
                style: AppText.labelSm.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: _bottomInterval(window.length),
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= window.length) return const SizedBox.shrink();
                final d = window[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${d.day}/${d.month}',
                    style: AppText.labelSm.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${s.y.round()}%',
                  AppText.labelSm.copyWith(color: Colors.white),
                ),
            ],
          ),
        ),
        lineBarsData: [
          _line(series.cal, _calColor),
          _line(series.water, _waterColor),
          _line(series.steps, _stepsColor),
        ],
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  double _bottomInterval(int length) =>
      length <= 8 ? 1 : (length / 6).ceilToDouble();

  LineChartBarData _line(List<double> values, Color color) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ],
      isCurved: true,
      color: color,
      barWidth: 2.2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  ({List<double> cal, List<double> water, List<double> steps}) _seriesFor(
    List<ActivityDay> days,
    _TrendMode mode,
  ) {
    List<double> pct(double Function(ActivityDay) pick) {
      switch (mode) {
        case _TrendMode.daily:
          return [for (final d in days) pick(d) * 100];
        case _TrendMode.weekly:
          // One averaged point per 7-day bucket.
          final out = <double>[];
          for (var i = 0; i < days.length; i += 7) {
            final bucket = days.sublist(i, (i + 7).clamp(0, days.length));
            out.add(
              bucket.isEmpty
                  ? 0.0
                  : bucket.map(pick).reduce((a, b) => a + b) /
                        bucket.length *
                        100,
            );
          }
          return out;
        case _TrendMode.cumulative:
          // Running average to date — shows the commitment trend settling.
          final out = <double>[];
          var sum = 0.0;
          for (var i = 0; i < days.length; i++) {
            sum += pick(days[i]) * 100;
            out.add(sum / (i + 1));
          }
          return out;
      }
    }

    return (
      cal: pct((d) => d.calorieAdherence),
      water: pct((d) => d.waterAdherence),
      steps: pct((d) => d.stepsAdherence),
    );
  }

  Widget _card({
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppText.headlineSm.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

(Color, String) _tierColorsOf(RankTier tier) => switch (tier) {
  RankTier.diamond => (const Color(0xFF4DC591), '💎'),
  RankTier.gold => (const Color(0xFFE8B93E), '🥇'),
  RankTier.silver => (const Color(0xFF9AA3AF), '🥈'),
  RankTier.bronze => (const Color(0xFFCE8A5B), '🥉'),
  RankTier.unranked => (AppColors.textSecondary, '—'),
};

/// Renders the commitment heatmap. 7 rows (weekdays) × N columns (weeks),
/// aligned so each column is a real calendar week (Monday-first).
/// Cells fill in with a staggered scale+fade, left to right, so the grid
/// feels like it's being drawn rather than dumped on screen.
class _HeatmapGrid extends StatelessWidget {
  final List<ActivityDay> days;
  const _HeatmapGrid({required this.days});

  Color _cellColor(int score) {
    if (score <= 0) return AppColors.surfaceContainerHigh;
    final intensity = (score / 100).clamp(0.25, 1.0);
    return AppColors.primaryFixed.withValues(alpha: intensity);
  }

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Text(
        AppLocalizations.of(context)!.cpNoData,
        style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
      );
    }
    // Monday-first weekday index (Flutter: Monday=1..Sunday=7)
    final firstWeekday = (days.first.date.weekday) - 1;
    final cells = <int?>[for (var i = 0; i < firstWeekday; i++) null]
      ..addAll([for (final d in days) d.score]);
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final weeks = (cells.length / 7).ceil();

    return SizedBox(
      height: 7 * 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          for (var w = 0; w < weeks; w++)
            Expanded(
              child: Column(
                children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: _AnimatedHeatCell(
                          color: cells[w * 7 + d] == null
                              ? Colors.transparent
                              : _cellColor(cells[w * 7 + d]!),
                          // Column-major stagger: whole weeks sweep left→right.
                          delayMs: w * 22,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A single heatmap cell that scales+fades in after [delayMs], giving the
/// commit-graph its "drawing itself" feel.
class _AnimatedHeatCell extends StatefulWidget {
  final Color color;
  final int delayMs;
  const _AnimatedHeatCell({required this.color, required this.delayMs});

  @override
  State<_AnimatedHeatCell> createState() => _AnimatedHeatCellState();
}

class _AnimatedHeatCellState extends State<_AnimatedHeatCell> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _shown ? 1 : 0.3,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Shimmering placeholder shaped like the real layout (header, heatmap,
/// chart) so the page never shows a bare, lifeless spinner.
class _ProfileSkeleton extends StatefulWidget {
  const _ProfileSkeleton();

  @override
  State<_ProfileSkeleton> createState() => _ProfileSkeletonState();
}

class _ProfileSkeletonState extends State<_ProfileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final opacity = 0.35 + 0.25 * (0.5 - (t - 0.5).abs()) * 2;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            _box(height: 130, opacity: opacity),
            const SizedBox(height: 16),
            _box(height: 190, opacity: opacity),
            const SizedBox(height: 16),
            _box(height: 260, opacity: opacity),
          ],
        );
      },
    );
  }

  Widget _box({required double height, required double opacity}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}
