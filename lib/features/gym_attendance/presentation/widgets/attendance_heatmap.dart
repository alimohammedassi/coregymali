import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../data/attendance_day.dart';

/// Range switch for the attendance heat views — the single toggle on My Gym
/// flips both this widget and the stats strip above it.
enum AttendanceHeatmapRange { week, month, year }

/// Attendance heat visuals in three ranges:
///  - week  : the rolling last 7 days — one large square per day with its
///            weekday label under it
///  - month : the current calendar month as a Sun–Sat grid of large squares
///  - year  : the full GitHub-contributions grid (the owner's reference
///            image) — weeks as columns, month labels along the bottom
///
/// All three share one single-accent intensity scale (empty = neutral
/// container tone, attended = accent deepening by dwell buckets) and the
/// same long-press tooltip ("Sat, Nov 21 · 47 min at the gym" / "لا زيارة").
/// The grids stay LTR even in Arabic so time flows left→right like the
/// reference image.
class AttendanceHeatmap extends StatelessWidget {
  const AttendanceHeatmap({
    super.key,
    required this.data,
    required this.anchor,
    required this.localeName,
    this.range = AttendanceHeatmapRange.year,
    this.onDayTap,
  });

  /// Date-only keys (local midnight) → that day's longest dwell.
  final Map<DateTime, AttendanceDay> data;

  /// "Today" — the last rendered day in every range; later days are blank.
  final DateTime anchor;

  final String localeName;
  final AttendanceHeatmapRange range;

  /// Heat scale color for a level 0–4 — exposed for the Less/More legend.
  static Color levelColor(int level) => _cellColor(level);

  /// Tap on a day cell — the owner screen shows the selected day's detail
  /// row below the matrix (design's selected-day bar).
  final ValueChanged<DateTime>? onDayTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: switch (range) {
        AttendanceHeatmapRange.week => _WeekStrip(
            data: data,
            anchor: anchor,
            localeName: localeName,
            l10n: l10n,
            onDayTap: onDayTap,
          ),
        AttendanceHeatmapRange.month => _MonthCalendar(
            data: data,
            anchor: anchor,
            localeName: localeName,
            l10n: l10n,
            onDayTap: onDayTap,
          ),
        AttendanceHeatmapRange.year => _YearGrid(
            data: data,
            anchor: anchor,
            localeName: localeName,
            l10n: l10n,
            onDayTap: onDayTap,
          ),
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Shared heat scale + cell
// ────────────────────────────────────────────────────────────────────────────

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Single-hue intensity by dwell length — buckets at 40/60/90 min.
int _levelFor(Map<DateTime, AttendanceDay> data, DateTime day) {
  final minutes = data[day]?.minutes ?? 0;
  if (minutes >= 90) return 4;
  if (minutes >= 60) return 3;
  if (minutes >= 40) return 2;
  if (minutes > 0) return 1;
  return 0;
}

Color _cellColor(int level) {
  if (level == 0) return AppColors.surfaceContainerHighest;
  // GitHub-style SOLID-feeling ramp — low alphas over the graphite canvas
  // read as muddy olive, so every attended level stays clearly lime
  // (owner: "الاخضر خافت اوي مش باين").
  const alphas = [0.0, 0.45, 0.68, 0.85, 1.0];
  return AppColors.accent.withValues(alpha: alphas[level]);
}

String _tooltipFor(
  Map<DateTime, AttendanceDay> data,
  DateTime day,
  String localeName,
  AppLocalizations l10n,
) {
  final attended = data[day];
  if (attended == null) return l10n.gymAttHeatmapNoVisit;
  final date = DateFormat('EEE, d MMM', localeName).format(day);
  return l10n.gymAttHeatmapVisited(date, '${attended.minutes}');
}

/// One heat square with its long-press tooltip and optional tap handler.
class _HeatCell extends StatelessWidget {
  final Map<DateTime, AttendanceDay> data;
  final DateTime day;
  final double size;
  final double radius;
  final String localeName;
  final AppLocalizations l10n;
  final ValueChanged<DateTime>? onDayTap;

  const _HeatCell({
    required this.data,
    required this.day,
    required this.size,
    required this.radius,
    required this.localeName,
    required this.l10n,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final cell = Tooltip(
      message: _tooltipFor(data, day, localeName, l10n),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: AppText.bodySm.copyWith(color: AppColors.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.all(8),
      preferBelow: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _cellColor(_levelFor(data, day)),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
    if (onDayTap == null) return cell;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onDayTap!(day),
      child: cell,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Week — rolling last 7 days as one row of large squares
// ────────────────────────────────────────────────────────────────────────────

class _WeekStrip extends StatelessWidget {
  final Map<DateTime, AttendanceDay> data;
  final DateTime anchor;
  final String localeName;
  final AppLocalizations l10n;
  final ValueChanged<DateTime>? onDayTap;

  const _WeekStrip({
    required this.data,
    required this.anchor,
    required this.localeName,
    required this.l10n,
    this.onDayTap,
  });

  static const double _cell = 38;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(anchor);
    final days = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    // Expanded slots — the row fits any card width (a fixed 7×38 row
    // overflowed narrow 360dp screens).
    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Column(
              children: [
                Center(
                  child: _HeatCell(
                    data: data,
                    day: day,
                    size: _cell,
                    radius: 8,
                    localeName: localeName,
                    l10n: l10n,
                    onDayTap: onDayTap,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('E', localeName).format(day),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Month — current calendar month as a Sun–Sat grid of large squares
// ────────────────────────────────────────────────────────────────────────────

class _MonthCalendar extends StatelessWidget {
  final Map<DateTime, AttendanceDay> data;
  final DateTime anchor;
  final String localeName;
  final AppLocalizations l10n;
  final ValueChanged<DateTime>? onDayTap;

  const _MonthCalendar({
    required this.data,
    required this.anchor,
    required this.localeName,
    required this.l10n,
    this.onDayTap,
  });

  static const double _cell = 38;
  static const double _gap = 5;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(anchor);
    final first = DateTime(today.year, today.month, 1);
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    // Sunday-start columns, matching the year grid's anatomy.
    final lead = first.weekday % 7;
    final rows = (lead + daysInMonth + 6) ~/ 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            DateFormat('MMMM yyyy', localeName).format(first),
            style: AppText.titleSm.copyWith(color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(height: 12),
        for (var r = 0; r < rows; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : _gap),
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  _slot(
                    row: r,
                    column: c,
                    today: today,
                    first: first,
                    lead: lead,
                    daysInMonth: daysInMonth,
                    onDayTap: onDayTap,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Expanded slot — the grid flexes to the card's width instead of
  /// overflowing it (7 fixed 43px slots broke on 360dp screens).
  Widget _slot({
    required int row,
    required int column,
    required DateTime today,
    required DateTime first,
    required int lead,
    required int daysInMonth,
    ValueChanged<DateTime>? onDayTap,
  }) {
    final dayNumber = row * 7 + column - lead + 1;
    final inMonth = dayNumber >= 1 && dayNumber <= daysInMonth;
    final day = inMonth ? DateTime(first.year, first.month, dayNumber) : null;
    final Widget cell = (day == null || day.isAfter(today))
        ? const SizedBox.square(dimension: _cell)
        : _HeatCell(
            data: data,
            day: day,
            size: _cell,
            radius: 8,
            localeName: localeName,
            l10n: l10n,
            onDayTap: onDayTap,
          );
    return Expanded(
      child: SizedBox(height: _cell, child: Center(child: cell)),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Year — the full GitHub-contributions grid (the owner's reference image)
// ────────────────────────────────────────────────────────────────────────────

class _YearGrid extends StatefulWidget {
  final Map<DateTime, AttendanceDay> data;
  final DateTime anchor;
  final String localeName;
  final AppLocalizations l10n;
  final ValueChanged<DateTime>? onDayTap;

  const _YearGrid({
    required this.data,
    required this.anchor,
    required this.localeName,
    required this.l10n,
    this.onDayTap,
  });

  @override
  State<_YearGrid> createState() => _YearGridState();
}

class _YearGridState extends State<_YearGrid> {
  static const double _cellSize = 11;
  static const double _cellGap = 3;
  static const double _pitch = _cellSize + _cellGap;
  static const int _weeks = 53;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Open on the most recent weeks, like the reference image.
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(widget.anchor);
    // Sunday-start columns; Dart's `weekday` runs 1=Mon…7=Sun, so Sunday
    // shifts by 0 and Monday by 1.
    final lastSunday = _dateOnly(
      widget.anchor,
    ).subtract(Duration(days: today.weekday % 7));

    // Sunday of each week column, oldest → newest.
    final columns = <DateTime>[
      for (var w = _weeks - 1; w >= 0; w--)
        lastSunday.subtract(Duration(days: 7 * w)),
    ];
    final gridWidth = columns.length * _pitch;

    // Month labels along the bottom, pinned under the column where a new
    // month starts (skipping any that would collide, and the right edge).
    final monthLabels = <Widget>[];
    var lastLabelColumn = -99;
    for (var i = 0; i < columns.length; i++) {
      final sunday = columns[i];
      final prevSunday = i > 0 ? columns[i - 1] : null;
      final isNewMonth = prevSunday == null || sunday.month != prevSunday.month;
      if (isNewMonth && i - lastLabelColumn >= 3 && i <= columns.length - 3) {
        lastLabelColumn = i;
        monthLabels.add(
          Positioned(
            left: i * _pitch,
            top: 0,
            child: Text(
              DateFormat('MMM', widget.localeName).format(sunday),
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                color: AppColors.textMuted,
              ),
            ),
          ),
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final sunday in columns)
                _weekColumn(sunday, today, widget.l10n),
            ],
          ),          const SizedBox(height: 6),
          SizedBox(
            width: gridWidth,
            height: 14,
            child: Stack(children: monthLabels),
          ),
        ],
      ),
    );
  }

  Widget _weekColumn(DateTime sunday, DateTime today, AppLocalizations l10n) {
    return Column(
      children: [
        for (var d = 0; d < 7; d++)
          _cell(sunday.add(Duration(days: d)), today, l10n),
      ],
    );
  }

  Widget _cell(DateTime day, DateTime today, AppLocalizations l10n) {
    return SizedBox(
      width: _pitch,
      height: _pitch,
      child: Center(
        // Days after the anchor keep the grid shape but paint nothing.
        child: day.isAfter(today)
            ? const SizedBox.square(dimension: _cellSize)
            : _HeatCell(
                data: widget.data,
                day: day,
                size: _cellSize,
                radius: 3.2,
                localeName: widget.localeName,
                l10n: l10n,
                onDayTap: widget.onDayTap,
              ),
      ),
    );
  }
}
