import 'dart:io';
import 'dart:math';
// Prefixed: package:intl also exports a TextDirection that would shadow
// dart:ui's enum.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
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
/// `user_goals.daily_steps` goal, the goal percentage in the header and a
/// 7-day smooth sparkline fed by the same week data as the selector.
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

    final percent = goal > 0 ? ((steps / goal) * 100).round() : 0;

    return ActivityCardShell(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Always opens the watch sheet — before linking it's the connect
        // prompt, after linking it's the details + weekly chart. (It used to
        // be tap-dead once connected, leaving the details unreachable.)
        onTap: onConnectWatch,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_walk_rounded,
                  size: 14,
                  color: AppColors.accentSteps,
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.steps,
                  style: AppText.styledScaleBodySm(
                    isArabic: isArabic,
                    color: AppColors.accentSteps,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '$percent%',
                  style: AppText.styledScaleCaption(
                    isArabic: isArabic,
                    color: AppColors.accentSteps,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 6),
                if (!connected)
                  Icon(
                    Icons.watch_outlined,
                    size: 14,
                    color: AppColors.textMuted,
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _countFormat.format(steps),
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

/// 7-day steps sparkline — a smooth filled area over the same real week
/// data the old bar preview used (zero-filled for days without logs).
/// Mirrors in RTL so the week still reads first-day-first, matching the
/// flipped Row layout it replaces.
class _MiniWeekChart extends StatelessWidget {
  final List<int> weekSteps;

  const _MiniWeekChart({required this.weekSteps});

  @override
  Widget build(BuildContext context) {
    final values = weekSteps.take(7).toList();
    while (values.length < 7) {
      values.add(0);
    }
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: CustomPaint(
        painter: _WeekSparkline(
          values: values,
          rtl: Directionality.of(context) == ui.TextDirection.rtl,
        ),
      ),
    );
  }
}

class _WeekSparkline extends CustomPainter {
  final List<int> values;
  final bool rtl;

  _WeekSparkline({required this.values, required this.rtl});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.fold<int>(1, (m, v) => max(m, v));
    final n = values.length;
    final dx = n > 1 ? size.width / (n - 1) : 0.0;

    Offset pointAt(int i) {
      final baseX = dx * i;
      final x = rtl ? size.width - baseX : baseX;
      final y = size.height - 3 - (size.height - 9) * (values[i] / maxVal);
      return Offset(x, y);
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < n; i++) {
      final p0 = pointAt(i - 1);
      final p1 = pointAt(i);
      // Control points at the horizontal midpoint give a smooth S-curve
      // between neighbors without overshooting the data range.
      final midX = (p0.dx + p1.dx) / 2;
      line.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fill = Path.from(line)
      ..lineTo(pointAt(n - 1).dx, size.height)
      ..lineTo(pointAt(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accentSteps.withValues(alpha: 0.30),
            AppColors.accentSteps.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.accentSteps
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      pointAt(n - 1),
      2.5,
      Paint()..color = AppColors.accentSteps,
    );
  }

  @override
  bool shouldRepaint(covariant _WeekSparkline oldDelegate) =>
      oldDelegate.rtl != rtl || !listEquals(oldDelegate.values, values);
}
