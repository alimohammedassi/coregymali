import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'food_category_visuals.dart';

/// Horizontal category chip row for the food library. Chips are built from
/// [categories] (DB order for known categories, [FoodCategoryVisuals.all]
/// order otherwise) so the row always matches what the catalog can return.
/// Label lookup is delegated to [labelOf] — widget files stay free of
/// hardcoded strings.
class FoodCategoryChips extends StatelessWidget {
  final List<FoodCategoryVisuals> categories;
  final String selectedDb;
  final ValueChanged<String> onSelect;
  final String Function(String db) labelOf;

  const FoodCategoryChips({
    super.key,
    required this.categories,
    required this.selectedDb,
    required this.onSelect,
    required this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          final selected = cat.db == selectedDb;
          return GestureDetector(
            onTap: () => onSelect(cat.db),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: selected
                    ? null
                    : Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                '${cat.emoji} ${labelOf(cat.db)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      selected ? AppColors.onPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
