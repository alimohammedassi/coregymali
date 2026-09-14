import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/food_filter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Bottom sheet for the food library macro-range filters: calories and
/// protein. Range ends mean "no constraint" — dragging to the max keeps
/// foods above the slider max visible (a full-range filter is stored as
/// null and emits no DB clause). Returns the new [FoodFilter], or null if
/// the user dismissed without applying.
class FoodFilterSheet extends StatefulWidget {
  final FoodFilter initial;

  const FoodFilterSheet({super.key, required this.initial});

  /// Returns the applied filter, or null when dismissed.
  static Future<FoodFilter?> show(BuildContext context, FoodFilter initial) {
    return showModalBottomSheet<FoodFilter>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodFilterSheet(initial: initial),
    );
  }

  @override
  State<FoodFilterSheet> createState() => _FoodFilterSheetState();
}

class _FoodFilterSheetState extends State<FoodFilterSheet> {
  late RangeValues _calories;
  late RangeValues _protein;

  @override
  void initState() {
    super.initState();
    _calories = RangeValues(
      widget.initial.minCalories ?? 0,
      widget.initial.maxCalories ?? FoodFilter.calorieSliderMax,
    );
    _protein = RangeValues(
      widget.initial.minProtein ?? 0,
      widget.initial.maxProtein ?? FoodFilter.proteinSliderMax,
    );
  }

  void _apply() {
    Navigator.pop(
      context,
      FoodFilter(
        category: widget.initial.category,
        minCalories: _calories.start > 0 ? _calories.start : null,
        maxCalories: _calories.end < FoodFilter.calorieSliderMax
            ? _calories.end
            : null,
        minProtein: _protein.start > 0 ? _protein.start : null,
        maxProtein:
            _protein.end < FoodFilter.proteinSliderMax ? _protein.end : null,
      ),
    );
  }

  void _reset() {
    setState(() {
      _calories = const RangeValues(0, FoodFilter.calorieSliderMax);
      _protein = const RangeValues(0, FoodFilter.proteinSliderMax);
    });
  }

  String _rangeLabel(RangeValues v, double max, String unit) {
    final noMin = v.start <= 0;
    final noMax = v.end >= max;
    if (noMin && noMax) {
      return AppLocalizations.of(context)!.foodFilterAny;
    }
    final lo = noMin ? '0' : v.start.round().toString();
    final hi = noMax ? '${max.round()}+' : v.end.round().toString();
    return '$lo – $hi $unit';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(l10n.foodFilters,
                      style: AppText.headlineSm.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),

            _rangeSection(
              icon: Icons.local_fire_department_rounded,
              iconColor: AppColors.accentCalories,
              title: l10n.foodFilterCalories,
              value: _rangeLabel(_calories, FoodFilter.calorieSliderMax,
                  l10n.foodFilterKcal),
              slider: RangeSlider(
                values: _calories,
                min: 0,
                max: FoodFilter.calorieSliderMax,
                divisions: FoodFilter.calorieSliderMax.round() ~/ 20,
                activeColor: AppColors.accentCalories,
                inactiveColor: AppColors.surfaceContainerHighest,
                labels: RangeLabels(
                  '${_calories.start.round()}',
                  '${_calories.end.round()}',
                ),
                onChanged: (v) => setState(() => _calories = v),
              ),
            ),
            _rangeSection(
              icon: Icons.fitness_center_rounded,
              iconColor: AppColors.accentProtein,
              title: l10n.foodFilterProtein,
              value: _rangeLabel(
                  _protein, FoodFilter.proteinSliderMax, l10n.foodFilterGrams),
              slider: RangeSlider(
                values: _protein,
                min: 0,
                max: FoodFilter.proteinSliderMax,
                divisions: FoodFilter.proteinSliderMax.round(),
                activeColor: AppColors.accentProtein,
                inactiveColor: AppColors.surfaceContainerHighest,
                labels: RangeLabels(
                  '${_protein.start.round()}',
                  '${_protein.end.round()}',
                ),
                onChanged: (v) => setState(() => _protein = v),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(l10n.foodResetFilters),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(l10n.foodApplyFilters),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Widget slider,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(title,
                style: AppText.titleSm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Text(value,
                style: AppText.labelSm.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        slider,
      ],
    );
  }
}
