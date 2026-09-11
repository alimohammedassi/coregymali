import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/pixel_art_icons.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// NutritionHistoryPage — extracted from NutritionScreen for easy editing.
/// ─────────────────────────────────────────────────────────────────────────────
/// Owns all `CALORIES — LAST 7 DAYS` chart + Weekly Stats + Daily Breakdown.
/// Parent (NutritionScreen) just does:
///   `NutritionHistoryPage(weeklyProgress: _weeklyProgress, caloriesGoal: _caloriesGoal)`
///
/// v2 — UI/UX + animation pass:
/// • Line chart now eases in with Curves.easeOutCubic instead of linear reveal.
/// • Staggered entrance: stat row → chart card → daily cards fade/slide in in sequence.
/// • Animated count-up numbers on the weekly stat cards.
/// • "Today" marker gets a soft looping pulse/glow instead of a static dot.
/// • Daily cards get a tactile press-scale + haptic tap, and syncing with chart
///   selection is now animated (color/border/elevation cross-fade).
/// • Selected day surfaces a small "You selected" summary strip above the list.
///
/// Edit this file directly to tweak:
/// • date-generation / 7-day normalization
/// • grid interval / target line / colors
/// • markers / fill / padding / labels / animation timings
/// No need to touch `nutrition_screen.dart`.
///
class NutritionHistoryPage extends StatefulWidget {
  /// Raw rows from `stats_service.getWeeklyProgress()` (may be sparse, 0-7 rows).
  final List<Map<String, dynamic>> weeklyProgress;

  /// Daily calorie target (e.g. 2000). Controls target dashed line + Y scale headroom.
  final double caloriesGoal;

  const NutritionHistoryPage({
    super.key,
    required this.weeklyProgress,
    required this.caloriesGoal,
  });

  @override
  State<NutritionHistoryPage> createState() => _NutritionHistoryPageState();
}

class _NutritionHistoryPageState extends State<NutritionHistoryPage>
    with TickerProviderStateMixin {
  late AnimationController _lineChartController;
  late AnimationController _entranceController;
  late AnimationController _pulseController;
  int _selectedHistoryIndex = 6; // today (last) selected by default

  static const _entranceDuration = Duration(milliseconds: 900);
  static const _chartDuration = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    _lineChartController = AnimationController(
      vsync: this,
      duration: _chartDuration,
    )..forward();
    _entranceController = AnimationController(
      vsync: this,
      duration: _entranceDuration,
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant NutritionHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weeklyProgress != widget.weeklyProgress ||
        oldWidget.caloriesGoal != widget.caloriesGoal) {
      _lineChartController.forward(from: 0);
      _entranceController.forward(from: 0);
      // keep selection clamped to 0..6
      if (_selectedHistoryIndex >= _normalized.length)
        _selectedHistoryIndex = _normalized.length - 1;
    }
  }

  @override
  void dispose() {
    _lineChartController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Eased progress used for the line-chart reveal (replaces the old linear value).
  double get _chartProgress =>
      Curves.easeOutCubic.transform(_lineChartController.value.clamp(0.0, 1.0));

  // Staggered fade/slide helper — give each section a slice of the entrance timeline.
  Widget _staggered({
    required double start,
    required double end,
    required Widget child,
    double slideFrom = 18,
  }) {
    final anim = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (context, c) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, slideFrom * (1 - anim.value)),
          child: c,
        ),
      ),
    );
  }

  // ─── 7-day normalization — fixes missing / reversed dates ───────────────────
  List<Map<String, dynamic>> get _normalized {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mapByDate = <String, Map<String, dynamic>>{};
    for (final r in widget.weeklyProgress) {
      final raw = r['summary_date']?.toString() ?? '';
      final key = raw.length >= 10 ? raw.substring(0, 10) : raw;
      if (key.isNotEmpty) mapByDate[key] = Map<String, dynamic>.from(r);
    }
    return List.generate(7, (i) {
      final d = today.subtract(
        Duration(days: 6 - i),
      ); // oldest -> newest, today last
      final key =
          "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      final row = mapByDate[key];
      if (row != null) return row;
      return <String, dynamic>{
        'summary_date': key,
        'calories_consumed': 0,
        'protein_g': 0,
        'carbs_g': 0,
        'fat_g': 0,
        'workout_done': false,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _normalized;

    // Required verification log — date-order bug check
    final verifyPoints = normalized
        .map(
          (e) =>
              "(${e['summary_date']}, ${(e['calories_consumed'] as num?)?.toInt() ?? 0})",
        )
        .toList();
    debugPrint(
      "[CALORIES CHART] Last 7 days (oldest→newest, today last): $verifyPoints — count=${verifyPoints.length}",
    );

    final allZero = normalized.every(
      (d) => ((d['calories_consumed'] as num?)?.toDouble() ?? 0) == 0,
    );
    final showEmptyHint = widget.weeklyProgress.isEmpty && allZero;
    final avgCals =
        normalized.fold<double>(
          0,
          (s, d) => s + ((d['calories_consumed'] as num?)?.toDouble() ?? 0),
        ) /
        normalized.length;
    final bottomPad = MediaQuery.of(context).padding.bottom + 68 + 12 + 16;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _staggered(
            start: 0.0,
            end: 0.55,
            child: _buildWeeklyStatsRowNormalized(normalized, avgCals),
          ),
          const SizedBox(height: 16),
          _staggered(
            start: 0.12,
            end: 0.7,
            child: _buildChartCard(context, normalized, showEmptyHint),
          ),
          const SizedBox(height: 24),
          _staggered(
            start: 0.2,
            end: 0.75,
            child: Text(
              "Daily Breakdown",
              style: AppText.headlineMd.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1,
                child: child,
              ),
            ),
            child: _buildSelectedSummary(normalized),
          ),
          ...normalized.reversed.toList().asMap().entries.map((entry) {
            // Later cards in the list arrive a touch later for a subtle cascade.
            final t = entry.key / max(1, normalized.length - 1);
            final start = (0.25 + t * 0.35).clamp(0.0, 0.9);
            final end = (start + 0.4).clamp(0.0, 1.0);
            return _staggered(
              start: start,
              end: end,
              child: _buildDailyCard(context, entry),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSelectedSummary(List<Map<String, dynamic>> normalized) {
    if (_selectedHistoryIndex < 0 || _selectedHistoryIndex >= normalized.length)
      return const SizedBox.shrink(key: ValueKey('none'));
    final day = normalized[_selectedHistoryIndex];
    final cals = (day['calories_consumed'] as num?)?.toInt() ?? 0;
    final dateStr = day['summary_date']?.toString() ?? '';
    final label = dateStr.length >= 10 ? dateStr.substring(5, 10) : dateStr;
    final isToday = _selectedHistoryIndex == normalized.length - 1;
    return Padding(
      key: ValueKey('summary-$_selectedHistoryIndex'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(Icons.timeline_rounded, size: 15, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              isToday ? "Today" : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              "· $cals kcal logged",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Chart Card — single-color analytics style ──────────────────────────────
  Widget _buildChartCard(
    BuildContext context,
    List<Map<String, dynamic>> normalized,
    bool showEmptyHint,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.last7Days,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.textMuted.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 2,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "TARGET ${widget.caloriesGoal.toInt()}",
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: showEmptyHint
                ? Padding(
                    key: const ValueKey('empty-hint'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      "No meals logged yet — showing 7-day baseline",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-hint')),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _lineChartController,
                _pulseController,
              ]),
              builder: (context, _) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => HapticFeedback.selectionClick(),
                child: _buildLineChart(normalized),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<Map<String, dynamic>> normalized) {
    final rawSpots = normalized
        .asMap()
        .entries
        .map(
          (e) => FlSpot(
            e.key.toDouble(),
            (e.value["calories_consumed"] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();
    final progress = _chartProgress;
    final maxXValRaw = (rawSpots.length - 1).toDouble();
    const padX = 0.28;
    final minX = -padX;
    final maxX = maxXValRaw + padX;
    final cutoffX = maxXValRaw * progress;
    List<FlSpot> spots = rawSpots
        .where((s) => s.x <= cutoffX + 0.0001)
        .toList();
    if (spots.isEmpty) spots = [rawSpots.first];
    if (progress < 0.999 && spots.length < rawSpots.length) {
      final next = rawSpots[spots.length];
      final frac = (cutoffX - (spots.isEmpty ? 0 : spots.last.x)).clamp(
        0.0,
        1.0,
      );
      if (frac > 0.02 && frac < 0.98) {
        final prev = spots.last;
        spots = [
          ...spots,
          FlSpot(
            prev.x + (next.x - prev.x) * frac,
            prev.y + (next.y - prev.y) * frac,
          ),
        ];
      }
    }
    double dataMax = rawSpots.fold<double>(0, (m, s) => s.y > m ? s.y : m);
    dataMax = max(dataMax, widget.caloriesGoal * 1.08);
    double niceMax = ((dataMax / 1000).ceil() * 1000).toDouble();
    if (niceMax < 1000) niceMax = 1000;
    if (niceMax < widget.caloriesGoal * 1.05)
      niceMax = ((widget.caloriesGoal * 1.12 / 1000).ceil() * 1000).toDouble();
    final yInterval = niceMax / 4;
    final maxY = niceMax;
    const minY = 0.0;
    final lineColor = AppColors.primary;
    final targetLineColor = AppColors.textMuted.withValues(
      alpha: 0.52 * progress.clamp(0.0, 1.0),
    );
    final gridLineColor = AppColors.borderLight.withValues(
      alpha: AppColors.isLight ? 0.70 : 0.26,
    );
    final pulse = _pulseController.value; // 0 → 1 → 0 looped
    final lineBar = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.18,
      preventCurveOverShooting: true,
      color: lineColor,
      barWidth: 2.4,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.16),
            lineColor.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
    final dotsBar = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.18,
      color: Colors.transparent,
      barWidth: 0,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, _, __, ___) {
          final rawIdx = spot.x.round().clamp(0, rawSpots.length - 1);
          final isLatest =
              rawIdx == rawSpots.length - 1 &&
              spots.length >= rawSpots.length - 0.5 &&
              progress > 0.985;
          final isSelected = rawIdx == _selectedHistoryIndex;
          return _HistoryDotPainter(
            color: lineColor,
            isLatest: isLatest,
            isSelected: isSelected,
            pulse: isLatest ? pulse : 0,
            borderColor: AppColors.surface,
          );
        },
      ),
    );

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.none(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          checkToShowHorizontalLine: (v) => v > minY + 0.5 && v < maxY - 0.5,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridLineColor, strokeWidth: 0.7),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if (value < minY + 1 || value > maxY - 1)
                  return const SizedBox.shrink();
                if (value == 0) return const SizedBox.shrink();
                if ((value - widget.caloriesGoal).abs() < yInterval * 0.22)
                  return const SizedBox.shrink();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8,
                  child: Text(
                    value.toInt().toString(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted.withValues(alpha: 0.92),
                    ),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= normalized.length)
                  return const SizedBox.shrink();
                final raw = normalized[i]["summary_date"].toString();
                final label = raw.length >= 10 ? raw.substring(5, 10) : raw;
                final isSel = i == _selectedHistoryIndex;
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 6,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: isSel ? 10 : 9,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel
                          ? AppColors.primary
                          : AppColors.textMuted.withValues(alpha: 0.9),
                    ),
                    child: Text(label),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: widget.caloriesGoal,
              color: targetLineColor,
              strokeWidth: 1.2,
              dashArray: [6, 4],
              label: HorizontalLineLabel(show: false),
            ),
          ],
        ),
        lineBarsData: [lineBar, dotsBar],
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchSpotThreshold: 22,
          touchCallback: (e, r) {
            if (r?.lineBarSpots != null && r!.lineBarSpots!.isNotEmpty) {
              final seen = <int>{};
              LineBarSpot? f;
              for (final s in r.lineBarSpots!) {
                if (seen.add(s.x.round())) {
                  f = s;
                  break;
                }
              }
              if (f != null) {
                final idx = f.x.round().clamp(0, normalized.length - 1);
                if (idx != _selectedHistoryIndex) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedHistoryIndex = idx);
                }
              }
            }
          },
          getTouchedSpotIndicator: (b, idxs) => idxs
              .map(
                (_) => TouchedSpotIndicatorData(
                  FlLine(
                    color: AppColors.textMuted.withValues(alpha: 0.38),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => _HistoryDotPainter(
                      color: lineColor,
                      borderColor: AppColors.surface,
                      isTouched: true,
                      isSelected: true,
                    ),
                  ),
                ),
              )
              .toList(),
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 10,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            tooltipBorder: BorderSide(color: AppColors.borderSubtle),
            tooltipMargin: 12,
            getTooltipColor: (_) =>
                AppColors.surfaceContainerHighest.withValues(alpha: 0.98),
            getTooltipItems: (spots) {
              final seen = <int>{};
              final uniq = <LineBarSpot>[];
              for (final s in spots) {
                if (seen.add(s.x.round())) uniq.add(s);
              }
              return uniq.map((spot) {
                final idx = spot.x.round().clamp(0, normalized.length - 1);
                final dateStr =
                    normalized[idx]["summary_date"]?.toString() ?? "";
                final displayDate = dateStr.length >= 10
                    ? dateStr.substring(5, 10)
                    : dateStr;
                final cals = spot.y.toInt();
                final prevY = idx > 0 ? (rawSpots[idx - 1].y.toInt()) : null;
                final diff = prevY != null ? cals - prevY : null;
                final diffLabel = diff == null
                    ? ""
                    : diff >= 0
                    ? "  +$diff"
                    : "  $diff";
                final diffColor = diff == null
                    ? Colors.transparent
                    : diff >= 0
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444);
                return LineTooltipItem(
                  "$displayDate  $cals kcal",
                  GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  children: diff == null
                      ? null
                      : [
                          TextSpan(
                            text: diffLabel,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: diffColor,
                            ),
                          ),
                        ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // ─── Weekly stats + daily cards ────────────────────────────────────────────
  Widget _buildWeeklyStatsRowNormalized(
    List<Map<String, dynamic>> normalized,
    double avgCals,
  ) {
    final daysOnTrack = normalized.where((d) {
      final c = (d["calories_consumed"] as num?)?.toDouble() ?? 0;
      return c >= widget.caloriesGoal * 0.85 && c <= widget.caloriesGoal * 1.15;
    }).length;
    final workoutDays = normalized
        .where((d) => d["workout_done"] == true)
        .length;
    return Row(
      children: [
        Expanded(
          child: _weeklyStatCard(
            "Avg Calories",
            avgCals,
            "kcal / day",
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _weeklyStatCard(
            "On Track",
            daysOnTrack.toDouble(),
            "days in zone",
            AppColors.accentCalories,
            isInt: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _weeklyStatCard(
            "Workouts",
            workoutDays.toDouble(),
            "this week",
            AppColors.accentWorkout,
            isInt: true,
          ),
        ),
      ],
    );
  }

  Widget _weeklyStatCard(
    String label,
    double value,
    String sub,
    Color color, {
    bool isInt = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              isInt ? v.round().toString() : v.round().toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: TextStyle(
              fontSize: 9,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCard(
    BuildContext context,
    MapEntry<int, Map<String, dynamic>> entry,
  ) {
    final day = entry.value;
    final cals = (day["calories_consumed"] as num?)?.toDouble() ?? 0;
    final protein = (day["protein_g"] as num?)?.toDouble() ?? 0;
    final carbs = (day["carbs_g"] as num?)?.toDouble() ?? 0;
    final fat = (day["fat_g"] as num?)?.toDouble() ?? 0;
    final pct = widget.caloriesGoal > 0
        ? (cals / widget.caloriesGoal).clamp(0.0, 1.0)
        : 0.0;
    final isWorkout = day["workout_done"] == true;
    final dateStr = day["summary_date"].toString();
    final isToday = entry.key == 0;
    // normalized index within the oldest→newest list (entry.key counts from the reversed/newest-first list)
    final normalizedIndex = _normalized.length - 1 - entry.key;
    final isSelected = normalizedIndex == _selectedHistoryIndex;

    return _TapScale(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedHistoryIndex = normalizedIndex);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.55)
                : (isToday
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.borderSubtle),
            width: isSelected ? 1.6 : (isToday ? 1.5 : 1.0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.today,
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      dateStr,
                      style: AppText.headlineSm.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isWorkout)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentWorkout.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const PixelArtIcon(
                            type: PixelIconType.dumbbell,
                            size: 12,
                            color: AppColors.accentWorkout,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Workout",
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.accentWorkout,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    "${cals.toInt()} kcal",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: pct >= 1.0
                          ? AppColors.accentCalories
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation(
                      pct >= 1.0 ? AppColors.accentCalories : AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  _historyMacroPill(
                    "P ${protein.toInt()}g",
                    AppColors.accentProtein,
                  ),
                  _historyMacroPill(
                    "C ${carbs.toInt()}g",
                    AppColors.accentCarbs,
                  ),
                  _historyMacroPill("F ${fat.toInt()}g", AppColors.accentFat),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyMacroPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800),
    ),
  );
}

/// Small reusable press-scale wrapper so daily cards feel tactile without
/// pulling in a full ripple/InkWell (keeps custom borders/shadows intact).
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _scale = 0.98),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// Marker with a soft looping glow on the latest point and a distinct ring
// when a point is selected (tapped in the list) or actively touched.
class _HistoryDotPainter extends FlDotPainter {
  final Color color;
  final bool isLatest;
  final bool isSelected;
  final double pulse; // 0..1, only meaningful when isLatest
  final Color borderColor;
  final bool isTouched;
  const _HistoryDotPainter({
    required this.color,
    this.isLatest = false,
    this.isSelected = false,
    this.pulse = 0,
    this.borderColor = Colors.white,
    this.isTouched = false,
  });

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offset) {
    final r = isTouched ? 5.0 : (isLatest ? 5.2 : (isSelected ? 4.6 : 3.8));

    // Looping glow halo for the latest/today point.
    if (isLatest) {
      final glowR = r + 6 + pulse * 5;
      canvas.drawCircle(
        offset,
        glowR,
        Paint()..color = color.withValues(alpha: 0.14 * (1 - pulse)),
      );
    }

    // Selection ring for a tapped-but-not-latest point.
    if (isSelected && !isLatest) {
      canvas.drawCircle(
        offset,
        r + 4.5,
        Paint()..color = color.withValues(alpha: 0.18),
      );
    }

    canvas.drawCircle(
      offset,
      r + (isLatest ? 1.6 : 1.3),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      offset,
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    if (isLatest)
      canvas.drawCircle(
        offset,
        1.3,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.92)
          ..style = PaintingStyle.fill,
      );
  }

  @override
  Size getSize(FlSpot s) => Size(isLatest ? 24 : 14, isLatest ? 24 : 14);

  @override
  Color get mainColor => color;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;

  @override
  List<Object?> get props => [
    color,
    isLatest,
    isSelected,
    pulse,
    borderColor,
    isTouched,
  ];
}
