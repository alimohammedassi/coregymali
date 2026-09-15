import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../../health/data/health_service.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../providers/activity_providers.dart';
import 'activity_card_shell.dart';

/// Steps card for the Home Activity section: big step count vs the
/// `user_goals.daily_steps` goal and a 7-day mini bar chart fed by the same
/// week data as the selector.
///
/// When the smartwatch source (Apple Health / Health Connect) isn't linked
/// yet, the card shows the connect prompt and is tappable — the actual
/// permission flow lives in the existing watch sheet, this card only opens
/// it.
class StepsCard extends ConsumerWidget {
  final int steps;
  final int goal;
  final List<int> weekSteps;
  final VoidCallback? onConnectWatch;

  const StepsCard({
    super.key,
    required this.steps,
    required this.goal,
    required this.weekSteps,
    this.onConnectWatch,
  });

  static final NumberFormat _countFormat = NumberFormat('#,###');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final weekAsync = ref.watch(activityWeekProvider);
    final hasSyncedData = weekAsync.value?.any((d) => d.steps > 0) ?? false;

    // "Connected" = the health source reports data or permission is granted;
    // otherwise show the connect prompt. Past days render whatever the
    // daily_summary stored regardless.
    final permAsync = ref.watch(healthPermissionStatusProvider);
    final connected =
        hasSyncedData || permAsync.value == HealthPermissionStatus.granted;

    return ActivityCardShell(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: connected ? null : onConnectWatch,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.steps,
                  style: AppText.styledScaleBodySm(
                    isArabic: isArabic,
                    color: AppColors.accentSteps,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (!connected)
                  Icon(
                    Icons.watch_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$steps',
                  style: AppText.styledScaleTitleSm(
                    isArabic: isArabic,
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.ofStepsTotal(_countFormat.format(goal)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.styledScaleCaption(
                      isArabic: isArabic,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (!connected) ...[
              const SizedBox(height: 2),
              Text(
                l10n.connectHealthToSync(_healthSourceName()),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.styledScaleCaption(
                  isArabic: isArabic,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
            ],
            _MiniWeekChart(weekSteps: weekSteps),
          ],
        ),
      ),
    );
  }

  String _healthSourceName() {
    if (Platform.isIOS) return 'Apple Health';
    if (Platform.isAndroid) return 'Health Connect';
    return 'Apple Health';
  }
}

/// Tiny 7-bar steps preview — real week data, zero-filled for days without
/// logs. Heights normalize against the week max; the tallest bar uses the
/// steps accent, other logged bars a dimmed accent, empty days stay in the
/// muted container tone.
class _MiniWeekChart extends StatelessWidget {
  final List<int> weekSteps;

  const _MiniWeekChart({required this.weekSteps});

  @override
  Widget build(BuildContext context) {
    final values = weekSteps.take(7).toList();
    while (values.length < 7) {
      values.add(0);
    }
    final maxVal = max(1, values.fold(0, (m, v) => max(m, v)));

    return SizedBox(
      height: 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  height: v <= 0
                      ? 4.0
                      : (8 + (26 * (v / maxVal)).round().clamp(0, 26))
                          .toDouble(),
                  decoration: BoxDecoration(
                    color: v <= 0
                        ? AppColors.surfaceContainerHighest
                        : v == maxVal
                            ? AppColors.accentSteps
                            : AppColors.accentSteps.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
