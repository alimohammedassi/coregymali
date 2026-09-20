import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../domain/day_activity.dart';

/// Horizontal Fri..Thu week strip for the Home dashboard.
///
/// Each cell shows the weekday abbreviation, the day-of-month number and a
/// small activity dot (lit = something was logged that day). The selected
/// day gets a high-contrast pill ([AppColors.onSurface] fill — white-on-dark
/// in dark mode, ink-on-light in light mode). Future days render dimmed and
/// are not tappable.
///
/// Owner brief 2026-09-18: the strip is week-navigable — chevron arrows on
/// both ends page to the previous/next week (next is disabled once the
/// current week is shown), so past days and their logged data are reachable.
class WeekDaySelector extends StatelessWidget {
  final List<DayActivity> week;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback? onPreviousWeek;
  final VoidCallback? onNextWeek;

  /// False once the strip is showing the current week — the next-week
  /// arrow grays out (there is never data in the future).
  final bool canGoNext;

  const WeekDaySelector({
    super.key,
    required this.week,
    required this.selectedDate,
    required this.onSelectDate,
    this.onPreviousWeek,
    this.onNextWeek,
    this.canGoNext = false,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    // RTL flips the reading direction, so "previous week" points right.
    final prevIcon = isArabic
        ? Icons.chevron_right_rounded
        : Icons.chevron_left_rounded;
    final nextIcon = isArabic
        ? Icons.chevron_left_rounded
        : Icons.chevron_right_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _WeekArrow(icon: prevIcon, onTap: onPreviousWeek),
          Expanded(
            child: Row(
              children: [
                for (final day in week)
                  _DayCell(
                    day: day,
                    selectedDate: selectedDate,
                    onSelectDate: onSelectDate,
                  ),
              ],
            ),
          ),
          _WeekArrow(
            icon: nextIcon,
            onTap: canGoNext ? onNextWeek : null,
          ),
        ],
      ),
    );
  }
}

/// One chevron paging button at either end of the strip. A null [onTap]
/// renders the disabled (muted) state.
class _WeekArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _WeekArrow({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: 30,
      height: 44,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 20,
          color: enabled
              ? AppColors.textSecondary
              : AppColors.textMuted.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DayActivity day;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  const _DayCell({
    required this.day,
    required this.selectedDate,
    required this.onSelectDate,
  });

  /// Locale-aware 3-letter weekday ("FRI" / "جمعة"). Falls back to the
  /// default-locale symbols if the Arabic data set fails to load.
  static String _weekdayLabel(DateTime date, bool isArabic) {
    try {
      return DateFormat.E(isArabic ? 'ar' : 'en').format(date).toUpperCase();
    } catch (_) {
      return DateFormat.E().format(date).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(day.date.year, day.date.month, day.date.day);
    final isFuture = date.isAfter(today);
    final isSelected = day.isSameDay(selectedDate);
    final isToday = date.isAtSameMomentAs(today);

    final label = _weekdayLabel(date, isArabic);
    final dimmed = isFuture
        ? 0.55
        : 1.0;
    final labelColor = isSelected
        ? AppColors.background
        : AppColors.textSecondary.withValues(alpha: dimmed);
    final numberColor = isSelected
        ? AppColors.background
        : AppColors.textPrimary.withValues(alpha: dimmed);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isFuture
            ? null
            : () {
                HapticFeedback.selectionClick();
                onSelectDate(date);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            // Selected pill: inverted ink-on-surface so it flips correctly
            // between dark (white pill) and light (ink pill) modes.
            color: isSelected ? AppColors.onSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: labelColor,
                  fontFamily: AppText.fontFamily(isArabic: isArabic),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: isToday && !isSelected ? 15.5 : 14.5,
                  fontWeight: FontWeight.w800,
                  color: numberColor,
                  fontFamily: AppText.fontFamily(isArabic: isArabic),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Lit dot = the volt accent (the design system's
                  // active-state color); empty = a faint outline dot.
                  color: day.hasActivity && !isFuture
                      ? AppColors.accent
                      : Colors.transparent,
                  border: day.hasActivity && !isFuture
                      ? null
                      : Border.all(
                          color: AppColors.textMuted.withValues(
                            alpha: isFuture ? 0.35 : 0.6,
                          ),
                          width: 1,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
