import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/rank_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Shared tier presentation for the leaderboard + client profile screens
/// (was duplicated as a private function in both). Colors are the
/// [AppColors] tier tokens; labels are localized — no emoji glyphs
/// (owner rule: no emojis in UI).
Color lbTierColor(RankTier tier) => switch (tier) {
      RankTier.diamond => AppColors.tierDiamond,
      RankTier.gold => AppColors.tierGold,
      RankTier.silver => AppColors.tierSilver,
      RankTier.bronze => AppColors.tierBronze,
      RankTier.unranked => AppColors.textSecondary,
    };

String lbTierLabel(RankTier tier, AppLocalizations l10n) => switch (tier) {
      RankTier.diamond => l10n.lbTierDiamond,
      RankTier.gold => l10n.rankGold,
      RankTier.silver => l10n.rankSilver,
      RankTier.bronze => l10n.rankBronze,
      RankTier.unranked => '—',
    };

/// "GOLD 74" pill — tier name + commitment score in the tier's accent.
/// Only meaningful on the Overall board (score-based tiers); category
/// boards show their own value chip instead.
class LeaderboardTierChip extends StatelessWidget {
  final RankTier tier;
  final int score;

  const LeaderboardTierChip({super.key, required this.tier, required this.score});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = lbTierColor(tier);
    final label = tier == RankTier.unranked ? '$score' : '${lbTierLabel(tier, l10n)} $score';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppText.labelSm.copyWith(
          color: tier == RankTier.unranked ? AppColors.textSecondary : color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
