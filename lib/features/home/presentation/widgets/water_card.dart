import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../providers/activity_providers.dart';
import 'activity_card_shell.dart';
import 'water_log_sheet.dart';

/// Water card for the Home Activity section: ml total vs goal as the hero
/// number, the goal percentage in the header, the glass count underneath
/// ("X of N glasses"), a glass-icon progress grid and a +250ml quick-add.
/// The goal comes from `user_goals.daily_water_ml` — never hardcoded.
/// Editing is today-only, matching the vitals bar's canEditDaily rule
/// (past days are read-only).
class WaterCard extends ConsumerWidget {
  final int waterMl;
  final int goalMl;
  final bool canEdit;
  final VoidCallback? onChanged;

  const WaterCard({
    super.key,
    required this.waterMl,
    required this.goalMl,
    required this.canEdit,
    this.onChanged,
  });

  static final NumberFormat _countFormat = NumberFormat('#,###');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final glasses = waterMl ~/ 250;
    final goalGlasses = (goalMl / 250).round().clamp(1, 20);
    final percent =
        goalMl > 0 ? ((waterMl / goalMl) * 100).round() : 0;

    return ActivityCardShell(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Card tap (outside the +250ml button) opens the water control sheet
        // — goal editing + quick-amount logging. Today-only, since logging
        // writes today regardless of the selected day.
        onTap: canEdit ? () => showWaterControlSheet(context) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.water_drop_rounded,
                  size: 14,
                  color: AppColors.accentWater,
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.water,
                  style: AppText.styledScaleBodySm(
                    isArabic: isArabic,
                    color: AppColors.accentWater,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '$percent%',
                  style: AppText.styledScaleCaption(
                    isArabic: isArabic,
                    color: AppColors.accentWater,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                if (canEdit) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.tune_rounded,
                    size: 12,
                    color: AppColors.textMuted,
                  ),
                ],
              ],
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _countFormat.format(waterMl),
                style: AppText.styledScaleTitleSm(
                  isArabic: isArabic,
                  color: AppColors.textPrimary,
                ).copyWith(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '/ ${_countFormat.format(goalMl)} ml',
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
          const SizedBox(height: 4),
          Text(
            '$glasses ${l10n.ofGlassesCount('$goalGlasses')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.styledScaleCaption(
              isArabic: isArabic,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          _GlassDots(glasses: glasses, goalGlasses: goalGlasses),
          const Spacer(),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: TextButton(
              onPressed: canEdit
                  ? () async {
                      // Optimistic tick lands inside the notifier; the write
                      // goes through StatsService like every other water
                      // entry point. Double-taps are debounced there.
                      // NOTE: no onChanged/_loadAll after this — water changes
                      // nothing the hero or meals feed show, and a full reload
                      // (with its 3s health-sync window + entrance replay)
                      // made the card visibly "re-refresh" on every tap
                      // (owner 2026-09-25). Riverpod repaints the dots inline.
                      await ref
                          .read(activityWeekProvider.notifier)
                          .addWaterGlass();
                    }
                  : null,
              style: TextButton.styleFrom(
                // 12% teal wash + teal ink — the water accent's soft
                // container, mirroring AppColors.lightGreen's pattern.
                backgroundColor:
                    AppColors.accentWater.withValues(alpha: 0.12),
                foregroundColor: AppColors.accentWater,
                disabledForegroundColor:
                    AppColors.accentWater.withValues(alpha: 0.45),
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppColors.accentWater.withValues(alpha: 0.18),
                  ),
                ),
              ),
              child: Text(
                l10n.addWaterPortion,
                style: AppText.styledScaleCaption(
                  isArabic: isArabic,
                  color: AppColors.accentWater,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// Glass-icon progress grid — one small cup per 250ml goal glass; logged
/// glasses fill with the water accent, remaining ones stay outlined.
class _GlassDots extends StatelessWidget {
  final int glasses;
  final int goalGlasses;

  const _GlassDots({required this.glasses, required this.goalGlasses});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < goalGlasses; i++)
          Container(
            width: 15,
            height: 18,
            decoration: BoxDecoration(
              color: i < glasses ? AppColors.accentWater : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: i < glasses
                    ? AppColors.accentWater
                    : AppColors.textMuted.withValues(alpha: 0.45),
                width: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}
