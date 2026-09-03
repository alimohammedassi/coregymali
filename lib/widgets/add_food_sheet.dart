import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/nutrition_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AddFoodSheet — browses/searches the Supabase `foods` table, then logs the
// picked food with smart serving calculations. Shared by Home (Add Meal)
// and Nutrition screen entry points.
// ─────────────────────────────────────────────────────────────────────────────

class AddFoodSheet extends StatefulWidget {
  final String preselectedMeal;
  final VoidCallback onFoodLogged;

  const AddFoodSheet({
    super.key,
    required this.preselectedMeal,
    required this.onFoodLogged,
  });

  static Future<void> show(
    BuildContext context, {
    String? preselectedMeal,
    required VoidCallback onFoodLogged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddFoodSheet(
        preselectedMeal: preselectedMeal ?? 'breakfast',
        onFoodLogged: onFoodLogged,
      ),
    );
  }

  @override
  State<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<AddFoodSheet> {
  final _nutritionService = NutritionService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _hasSearched = false;
  String _selectedCategory = 'all';

  List<({String label, String db, String emoji})> get _categories => [
        (label: 'All', db: 'all', emoji: '🍽'),
        (label: 'Arabic', db: 'arabic', emoji: '🧆'),
        (label: 'Protein', db: 'protein', emoji: '🍗'),
        (label: 'Carbs', db: 'carbs', emoji: '🍚'),
        (label: 'Veggies', db: 'vegetables', emoji: '🥦'),
        (label: 'Fruits', db: 'fruits', emoji: '🍎'),
        (label: 'Dairy', db: 'dairy', emoji: '🧀'),
        (label: 'Fats', db: 'fats', emoji: '🥑'),
        (label: 'Fast Food', db: 'fastfood', emoji: '🍔'),
        (label: 'Drinks', db: 'drinks', emoji: '🥤'),
      ];

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty && _selectedCategory == 'all') return;
    setState(() {
      _searching = true;
      _hasSearched = true;
    });

    final results = await _nutritionService.searchFoods(
      query,
      category: _selectedCategory,
    );
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context)!.searchFood,
                          style: AppText.headlineSm.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      Text(
                        'Targeting: ${widget.preselectedMeal.toUpperCase()} · English / Arabic',
                        style:  TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon:  Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (v) {
                if (v.length > 1) _search();
              },
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'e.g. Chicken breast, دجاج, rice, oats...',
                hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 14),
                filled: true,
                fillColor: AppColors.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon:  Icon(Icons.search_rounded,
                    color: AppColors.primary, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon:  Icon(Icons.clear_rounded,
                            size: 18, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _results = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // Category Chips
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final sel = cat.db == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat.db);
                    _search();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.primary
                          : AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: sel
                          ? null
                          : Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      '${cat.emoji} ${cat.label}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_hasSearched && !_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Text(
                    '${_results.length} result${_results.length != 1 ? 's' : ''} found',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          Expanded(
            child: _searching
                ?  Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2.5),
                  )
                : !_hasSearched
                    ? _buildSearchSuggestions()
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🔍',
                                    style: TextStyle(fontSize: 36)),
                                const SizedBox(height: 12),
                                Text('No foods found',
                                    style: AppText.headlineSm.copyWith(
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text('Try another spelling or search keyword',
                                    style: AppText.bodySm.copyWith(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            itemCount: _results.length,
                            itemBuilder: (_, i) =>
                                _buildFoodResultTile(_results[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    final suggestions = [
      'Chicken breast',
      'White rice',
      'Eggs',
      'Oats',
      'Banana',
      'Greek yogurt',
      'Almonds',
      'Tuna can',
      'Whey protein',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'POPULAR FOODS',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions
                .map((s) => GestureDetector(
                      onTap: () {
                        _searchController.text = s;
                        _search();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodResultTile(Map<String, dynamic> food) {
    return GestureDetector(
      onTap: () => _showLogFoodSheet(food),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _foodEmoji(food['category'] ?? ''),
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food['name'] ?? '',
                    style: AppText.headlineSm.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (food['name_ar'] != null && food['name_ar'] != food['name'])
                    Text(
                      food['name_ar'],
                      style: AppText.bodySm.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _resultBadge('${food['calories']} kcal', AppColors.primary),
                      _resultBadge(
                          'P ${food['protein_g']}g', AppColors.accentProtein),
                      _resultBadge(
                          'C ${food['carbs_g']}g', AppColors.accentCarbs),
                      _resultBadge('F ${food['fat_g']}g', AppColors.accentFat),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child:  Icon(Icons.add_rounded,
                  color: AppColors.primary, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  String _foodEmoji(String category) {
    const map = {
      'protein': '🍗',
      'carbs': '🍚',
      'vegetables': '🥦',
      'fruits': '🍎',
      'dairy': '🧀',
      'fats': '🥑',
      'fastfood': '🍔',
      'drinks': '🥤',
      'arabic': '🧆',
      'breakfast': '🍳',
    };
    return map[category.toLowerCase()] ?? '🍽';
  }

  Widget _resultBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  void _showLogFoodSheet(Map<String, dynamic> food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogFoodSheet(
        food: food,
        initialMeal: widget.preselectedMeal,
        onLogged: () {
          Navigator.pop(context); // close log sheet
          Navigator.pop(context); // close search sheet
          widget.onFoodLogged();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log Food Sheet (Smart Unit Conversions & Portion Multipliers)
// ─────────────────────────────────────────────────────────────────────────────
class _LogFoodSheet extends StatefulWidget {
  final Map<String, dynamic> food;
  final String initialMeal;
  final VoidCallback onLogged;

  const _LogFoodSheet({
    required this.food,
    required this.initialMeal,
    required this.onLogged,
  });

  @override
  State<_LogFoodSheet> createState() => _LogFoodSheetState();
}

class _LogFoodSheetState extends State<_LogFoodSheet> {
  final _nutritionService = NutritionService();
  late TextEditingController _quantityCtrl;
  late String _mealType;
  late double _quantity;
  late String _unit;
  bool _logging = false;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMeal;
    final units = _servingUnitsFor(widget.food['name'] ?? '');
    _unit = units.first.label;
    _quantity = _unit == 'g' ? 100.0 : 1.0;
    _quantityCtrl = TextEditingController(text: _quantity.toStringAsFixed(0));
  }

  bool _kw(String name, List<String> keys) =>
      keys.any((k) => name.toLowerCase().contains(k));

  List<({String label, double grams, String icon, String hint})>
      _servingUnitsFor(String rawName) {
    final n = rawName.toLowerCase();

    if (_kw(n, ['egg', 'بيض', 'beyd'])) {
      return [
        (label: 'piece (حبة)', grams: 50.0, icon: '🥚', hint: '1 egg ≈ 50g'),
        (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams'),
      ];
    }
    if (_kw(n, ['bread', 'toast', 'خبز', 'عيش', 'pita'])) {
      return [
        (
          label: 'slice (شريحة)',
          grams: 25.0,
          icon: '🍞',
          hint: '1 slice ≈ 25g'
        ),
        (label: 'loaf (رغيف)', grams: 150.0, icon: '🥖', hint: '1 loaf ≈ 150g'),
        (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams'),
      ];
    }
    if (_kw(n, ['milk', 'حليب', 'lait'])) {
      return [
        (label: 'cup (كوب)', grams: 240.0, icon: '🥛', hint: '1 cup = 240ml'),
        (label: 'glass (كأس)', grams: 200.0, icon: '🥛', hint: '1 glass ≈ 200ml'),
        (label: 'ml', grams: 1.0, icon: '💧', hint: 'Milliliters'),
      ];
    }
    if (_kw(n, ['rice', 'أرز', 'ارز', 'ruz'])) {
      return [
        (
          label: 'cup cooked (كوب)',
          grams: 186.0,
          icon: '🍚',
          hint: '1 cup cooked ≈ 186g'
        ),
        (
          label: 'cup dry (جاف)',
          grams: 185.0,
          icon: '🌾',
          hint: '1 cup dry ≈ 185g'
        ),
        (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams'),
      ];
    }
    if (_kw(n, ['chicken', 'دجاج', 'djaj'])) {
      return [
        (
          label: 'piece (قطعة)',
          grams: 150.0,
          icon: '🍗',
          hint: '1 breast ≈ 150g'
        ),
        (label: '½ piece', grams: 75.0, icon: '🍗', hint: 'Half breast ≈ 75g'),
        (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams'),
      ];
    }
    if (_kw(n, ['banana', 'موز'])) {
      return [
        (
          label: 'piece (حبة)',
          grams: 118.0,
          icon: '🍌',
          hint: '1 medium banana ≈ 118g'
        ),
        (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams'),
      ];
    }
    if (_kw(n, ['apple', 'تفاح'])) {
      return [
        (
          label: 'piece (حبة)',
          grams: 182.0,
          icon: '🍎',
          hint: '1 medium apple ≈ 182g'
        ),
        (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams'),
      ];
    }

    return [
      (label: 'g', grams: 1.0, icon: '⚖️', hint: 'Grams'),
      (label: 'cup (كوب)', grams: 240.0, icon: '☕', hint: '1 cup ≈ 240g'),
      (label: 'tbsp', grams: 15.0, icon: '🥄', hint: '1 tbsp ≈ 15g'),
      (label: 'serving', grams: 100.0, icon: '🥣', hint: '1 serving = 100g'),
    ];
  }

  double get _grams {
    final units = _servingUnitsFor(widget.food['name'] ?? '');
    final match =
        units.firstWhere((u) => u.label == _unit, orElse: () => units.first);
    return _quantity * match.grams;
  }

  double _calc(String key) =>
      ((widget.food[key] as num?)?.toDouble() ?? 0) * _grams / 100;

  @override
  void dispose() {
    _quantityCtrl.dispose();
    super.dispose();
  }

  Widget _mealChoice(String type, String label, String emoji) {
    final sel = _mealType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mealType = type),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: sel ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final units = _servingUnitsFor(widget.food['name'] ?? '');

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.borderSubtle),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.food['name'] ?? '',
                          style: AppText.headlineSm.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                      if (widget.food['name_ar'] != null)
                        Text(widget.food['name_ar'],
                            style: AppText.bodySm
                                .copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:  Text('per 100g',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Macro preview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _liveStatCol(
                      _calc('calories').toInt().toString(),
                      'Calories',
                      'kcal',
                      AppColors.primary),
                  _divider(),
                  _liveStatCol(
                      _calc('protein_g').toStringAsFixed(1),
                      'Protein',
                      'g',
                      AppColors.accentProtein),
                  _divider(),
                  _liveStatCol(
                      _calc('carbs_g').toStringAsFixed(1),
                      'Carbs',
                      'g',
                      AppColors.accentCarbs),
                  _divider(),
                  _liveStatCol(
                      _calc('fat_g').toStringAsFixed(1),
                      'Fat',
                      'g',
                      AppColors.accentFat),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quantity + Unit Dropdown
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      filled: true,
                      fillColor: AppColors.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) =>
                        setState(() => _quantity = double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: units.any((u) => u.label == _unit)
                          ? _unit
                          : units.first.label,
                      dropdownColor: AppColors.surface,
                      items: units
                          .map((u) => DropdownMenuItem(
                                value: u.label,
                                child: Text('${u.icon} ${u.label}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _unit = v ?? units.first.label),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Meal Type Selector
            Text('Assign to Meal',
                style: AppText.labelMd.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                _mealChoice('breakfast', 'Breakfast', '🍳'),
                _mealChoice('lunch', 'Lunch', '🥗'),
                _mealChoice('dinner', 'Dinner', '🍽'),
                _mealChoice('snack', 'Snack', '🥜'),
              ],
            ),
            const SizedBox(height: 22),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _logging
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        setState(() => _logging = true);
                        await _nutritionService.logFood(
                          foodId: widget.food['id'].toString(),
                          foodName: widget.food['name'],
                          mealType: _mealType,
                          quantity: _grams,
                          calories: _calc('calories'),
                          proteinG: _calc('protein_g'),
                          carbsG: _calc('carbs_g'),
                          fatG: _calc('fat_g'),
                        );
                        widget.onLogged();
                      },
                child: _logging
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Confirm & Log Food',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 32, color: AppColors.borderSubtle);

  Widget _liveStatCol(
          String val, String label, String unit, Color color) =>
      Column(
        children: [
          Text(val,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          Text('$label ($unit)',
              style: TextStyle(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
        ],
      );
}
