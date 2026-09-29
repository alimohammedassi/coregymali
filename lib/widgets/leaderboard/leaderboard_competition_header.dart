import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Level-1 hierarchy: "what competition am I in, and when does it reset?"
///
/// Presents the rolling commitment board as a live event — weekly (7d) or
/// monthly (30d) cycle, real elapsed progress, real reset date. Urgency is
/// communicated by a calm amber shift when ≤2 days remain; never flashing.
class LeaderboardCompetitionHeader extends StatelessWidget {
  final bool monthly;
  final int windowDays;
  final int daysLeft;
  final double cycleProgress; // 0..1, today inclusive
  final DateTime resetsOn;
  final ValueChanged<int>? onWindowChanged;

  const LeaderboardCompetitionHeader({
    super.key,
    required this.monthly,
    required this.windowDays,
    required this.daysLeft,
    required this.cycleProgress,
    required this.resetsOn,
    this.onWindowChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final urgent = daysLeft <= 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthly ? l10n.lbMonthlyChallenge : l10n.lbWeeklyChallenge,
                  style: AppText.titleMd.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _windowToggle(l10n),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.lbDaysLeft(daysLeft),
            style: AppText.labelMd.copyWith(
              color: urgent ? AppColors.overGoalWarning : AppColors.textSecondary,
              fontWeight: urgent ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          // Elapsed cycle progress — animates from zero once on entry.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: cycleProgress.clamp(0.0, 1.0)),
            duration: AppDurations.reveal,
            curve: AppCurves.standard,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: AppColors.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation(AppColors.primaryFixed),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.lbResetsOn('${resetsOn.day}/${resetsOn.month}'),
            style: AppText.labelSm.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// Weekly ↔ monthly competition switch — the same 7/30 range selector the
  /// screen always had, promoted into the event header it actually controls.
  Widget _windowToggle(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _windowOption(7, l10n.lbWindowWeekly),
          _windowOption(30, l10n.lbWindowMonthly),
        ],
      ),
    );
  }

  Widget _windowOption(int days, String label) {
    final active = windowDays == days;
    return GestureDetector(
      onTap: () => onWindowChanged?.call(days),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryFixed : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
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
}
