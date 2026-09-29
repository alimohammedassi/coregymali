import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Inline "you're not on today" notice — shown by every day-aware nutrition
/// surface (Home under the week strip, the Nutrition tab) while the selected
/// log date isn't today. Every entry the user adds from any logging path
/// lands on the day being viewed, so the page says so. Not dismissible — it
/// disappears the moment today is selected again.
///
/// Same tinted inline-alert anatomy as the goals banner (the app's
/// inline-banner pattern), tinted gold — the calorie identity this app
/// already uses for the suggest-meal entry — since this is about where a
/// calorie entry will land.
class LoggingNotTodayBanner extends StatelessWidget {
  final DateTime date;
  final bool isArabic;

  const LoggingNotTodayBanner({
    super.key,
    required this.date,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateLabel = DateFormat(
      'EEEE, d MMM',
      Localizations.localeOf(context).languageCode,
    ).format(date);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentCalories.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentCalories.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_repeat_rounded,
            size: 16,
            color: AppColors.accentCalories,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.loggingNotToday(dateLabel),
              style: AppText.styledScaleBodySm(
                isArabic: isArabic,
                color: AppColors.accentCalories,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
