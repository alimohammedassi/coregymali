import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Explicit empty state for the food library: shown instead of a blank list
/// when nothing matches the active search + filters. Offers a one-tap reset
/// when any filter dimension is active.
class FoodEmptyState extends StatelessWidget {
  /// Whether any filter (category or macro range) is active — controls the
  /// reset button. A bare search miss shows the softer "try another keyword"
  /// copy without the button.
  final bool filtersActive;
  final VoidCallback onReset;

  const FoodEmptyState({
    super.key,
    required this.filtersActive,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('🔍', style: TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 16),
            Text(
              filtersActive
                  ? l10n.foodNoResultsTitle
                  : l10n.foodNoFoodsTitle,
              textAlign: TextAlign.center,
              style: AppText.headlineSm
                  .copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              filtersActive
                  ? l10n.foodNoResultsSubtitle
                  : l10n.foodNoFoodsSubtitle,
              textAlign: TextAlign.center,
              style: AppText.bodySm
                  .copyWith(color: AppColors.textSecondary),
            ),
            if (filtersActive) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onReset,
                icon: Icon(Icons.filter_alt_off_rounded, size: 18),
                label: Text(l10n.foodResetFilters),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
