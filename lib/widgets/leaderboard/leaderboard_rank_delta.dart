import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Compact rank-movement indicator: ▲n (improved), ▼n (dropped), — (flat)
/// or NEW (wasn't on the previous board). Colors come from the existing
/// semantic tokens — lime = climbing, coral (redAccent data-viz family) =
/// dropping; the raw [error] token is reserved for real failures.
///
/// Never color-only: the arrow direction, the signed number and a semantics
/// label each carry the meaning on their own.
class LeaderboardRankDelta extends StatelessWidget {
  /// previous_rank - current_rank; positive = improved. Null = new entrant.
  final int? delta;

  /// Rows show the tiny variant; the pinned/me cards the regular one.
  final bool compact;

  const LeaderboardRankDelta({super.key, required this.delta, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fontSize = compact ? 10.0 : 11.0;
    final iconSize = compact ? 11.0 : 13.0;

    final (Widget? icon, String text, Color color, String semantics) =
        switch (delta) {
      null => (
          null,
          l10n.lbNewHere,
          AppColors.onPrimaryContainer,
          l10n.lbNewHere,
        ),
      0 => (
          null,
          '—',
          AppColors.textMuted,
          l10n.lbSameRank,
        ),
      final d when d > 0 => (
          Icon(Icons.arrow_drop_up_rounded, size: iconSize + 4, color: AppColors.primaryFixed),
          '$d',
          AppColors.onPrimaryContainer,
          l10n.lbMovedUp(d),
        ),
      final d => (
          Icon(Icons.arrow_drop_down_rounded, size: iconSize + 4, color: AppColors.redAccent),
          '${-d}',
          AppColors.redAccent,
          l10n.lbMovedDown(-d),
        ),
    };

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) icon,
        Text(
          text,
          style: AppText.labelSm.copyWith(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ],
    );

    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: delta == null
          ? Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 4 : 6,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: content,
            )
          : content,
    );
  }
}
