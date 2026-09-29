import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/rank_service.dart';
import '../../theme/app_animations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import 'leaderboard_rank_delta.dart';
import 'leaderboard_sparkline.dart';
import 'leaderboard_tier_chip.dart';

/// The signed-in client's competitive card — Level-2 hierarchy. Answers in
/// one glance: where am I, am I climbing, and what's my next achievable
/// target ("18 pts to #11"). Overall board adds the tier milestone.
class LeaderboardUserCard extends StatelessWidget {
  final LeaderboardStanding me;
  final LeaderboardCategory category;
  final VoidCallback? onOpenProfile;

  const LeaderboardUserCard({
    super.key,
    required this.me,
    required this.category,
    this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: onOpenProfile,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryFixed, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.lbYourRank,
              style: AppText.labelSm.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '#${me.rank}',
                  style: AppText.displaySm.copyWith(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                LeaderboardRankDelta(delta: me.rankDelta),
                const Spacer(),
                LeaderboardSparkline(values: me.trend),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${me.score}',
                  style: AppText.metricLg.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(width: 5),
                Text(
                  _unitLabel(l10n),
                  style: AppText.labelMd.copyWith(color: AppColors.textSecondary),
                ),
                const Spacer(),
                if (me.currentStreak > 0) ...[
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 14,
                    color: AppColors.primaryFixed,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    l10n.lbDayStreakN(me.currentStreak),
                    style: AppText.labelSm.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _targetLine(l10n),
          ],
        ),
      ),
    );
  }

  String _unitLabel(AppLocalizations l10n) => switch (category) {
        LeaderboardCategory.overall => l10n.lbUnitPts,
        LeaderboardCategory.calories => l10n.lbUnitPts,
        LeaderboardCategory.water => l10n.lbUnitPts,
        LeaderboardCategory.workouts => l10n.lbUnitWorkouts,
        LeaderboardCategory.streak => l10n.lbUnitDays,
        LeaderboardCategory.longestStreak => l10n.lbUnitDays,
      };

  /// The psychological heart of the card: the next achievable target.
  Widget _targetLine(AppLocalizations l10n) {
    final isOverall = category == LeaderboardCategory.overall;
    final Widget target;
    if (me.rank == 1) {
      target = Row(
        children: [
          Icon(Icons.emoji_events_rounded, size: 15, color: AppColors.tertiary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              l10n.lbLeadingBoard,
              style: AppText.labelMd.copyWith(
                color: AppColors.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    } else if (me.nextUser != null && me.pointsToNext <= 0) {
      target = Text(
        l10n.lbTiedWith(me.nextRank ?? me.rank - 1),
        style: AppText.labelMd.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      );
    } else if (me.nextUser != null) {
      target = Text(
        l10n.lbPtsToNextRank(me.pointsToNext, me.nextRank ?? me.rank - 1),
        style: AppText.labelMd.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      );
    } else {
      target = const SizedBox.shrink();
    }

    if (isOverall && me.tier != RankTier.unranked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          target,
          if (target is! SizedBox) const SizedBox(height: 10),
          _MilestoneBar(score: me.score),
        ],
      );
    }
    return target;
  }
}

/// Tier progression: SILVER → GOLD bar + "58 pts to Gold". Progress runs
/// between the current tier's floor and the next tier's threshold so the
/// bar never lies about how far the climb already came.
class _MilestoneBar extends StatelessWidget {
  final int score;
  const _MilestoneBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final next = nextTierThreshold(score);
    final curTier = tierForScore(score);
    if (next == null) {
      // Diamond: the bar is done — celebrate quietly.
      return Row(
        children: [
          Icon(Icons.verified_rounded, size: 15, color: lbTierColor(curTier)),
          const SizedBox(width: 5),
          Text(
            l10n.lbTopTier,
            style: AppText.labelMd.copyWith(
              color: lbTierColor(curTier),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    final floor = switch (curTier) {
      RankTier.unranked => 0,
      RankTier.bronze => 0,
      RankTier.silver => 50,
      RankTier.gold => 70,
      RankTier.diamond => 85,
    };
    final progress = ((score - floor) / (next - floor)).clamp(0.05, 1.0);
    final nextTier = tierForScore(next);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              lbTierLabel(curTier, l10n),
              style: AppText.labelSm.copyWith(
                color: lbTierColor(curTier),
                fontWeight: FontWeight.w800,
              ),
            ),
            Icon(Icons.arrow_forward_rounded,
                size: 12, color: AppColors.textMuted),
            Text(
              lbTierLabel(nextTier, l10n),
              style: AppText.labelSm.copyWith(
                color: lbTierColor(nextTier),
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '$score / $next',
              style: AppText.labelSm.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: AppDurations.reveal,
          curve: AppCurves.standard,
          builder: (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(lbTierColor(nextTier)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.lbPtsToTier(next - score, lbTierLabel(nextTier, l10n)),
          style: AppText.labelSm.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
