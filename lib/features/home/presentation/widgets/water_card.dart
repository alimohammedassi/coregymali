import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../providers/activity_providers.dart';
import 'activity_card_shell.dart';

/// Water card for the Home Activity section: glasses progress as a dot row
/// ("X of N glasses") plus a +250ml quick-add. The goal comes from
/// `user_goals.daily_water_ml` — never hardcoded. Editing is today-only,
/// matching the vitals bar's canEditDaily rule (past days are read-only).
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final glasses = waterMl ~/ 250;
    final goalGlasses = (goalMl / 250).round().clamp(1, 20);

    return ActivityCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.water,
            style: AppText.styledScaleBodySm(
              isArabic: isArabic,
              color: AppColors.accentWater,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$glasses',
                style: AppText.styledScaleTitleSm(
                  isArabic: isArabic,
                  color: AppColors.textPrimary,
                ).copyWith(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  l10n.ofGlassesCount('$goalGlasses'),
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
          const SizedBox(height: 10),
          _GlassDots(glasses: glasses, goalGlasses: goalGlasses),
          const Spacer(),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: TextButton(
              onPressed: canEdit
                  ? () async {
                      // Optimistic tick lands inside the notifier; the write
                      // goes through StatsService like every other water
                      // entry point. Double-taps are debounced there.
                      await ref
                          .read(activityWeekProvider.notifier)
                          .addWaterGlass();
                      onChanged?.call();
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
    );
  }
}

class _GlassDots extends StatelessWidget {
  final int glasses;
  final int goalGlasses;

  const _GlassDots({required this.glasses, required this.goalGlasses});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (var i = 0; i < goalGlasses; i++)
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < glasses ? AppColors.accentWater : Colors.transparent,
              border: i < glasses
                  ? null
                  : Border.all(
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                      width: 1,
                    ),
            ),
          ),
      ],
    );
  }
}
