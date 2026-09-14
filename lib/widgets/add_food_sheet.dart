import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/additional_nutrients.dart';
import '../models/food_filter.dart';
import '../services/nutrition_service.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'food/food_category_chips.dart';
import 'food/food_category_visuals.dart';
import 'food/food_empty_state.dart';
import 'food/food_filter_sheet.dart';
import 'food/food_thumbnail.dart';

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

class _AddFoodSheetState extends State<AddFoodSheet>
    with SingleTickerProviderStateMixin {
  final _nutritionService = NutritionService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _hasSearched = false;
  FoodFilter _filter = const FoodFilter();

  /// Chip vocabulary: 'all' + every category actually present in the DB
  /// (known ones keep display order, unknown ones are appended with the
  /// fallback plate), so the chips can never filter down to an empty set of
  /// categories the catalog doesn't have.
  List<FoodCategoryVisuals> _categories = FoodCategoryVisuals.all;
  late final AnimationController _sheetCtrl;
  late final Animation<Offset> _sheetSlide;
  late final Animation<double> _sheetFade;

  @override
  void initState() {
    super.initState();
    final bool reduce = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _sheetCtrl = AnimationController(
      vsync: this,
      duration: reduce ? Duration.zero : AppDurations.medium,
    );
    _sheetSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sheetCtrl, curve: AppCurves.standard));
    _sheetFade = CurvedAnimation(parent: _sheetCtrl, curve: AppCurves.standard);
    _sheetCtrl.forward();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final dbCategories = await _nutritionService.getFoodCategories();
    if (!mounted || dbCategories.isEmpty) return;
    final known = FoodCategoryVisuals.all
        .where((v) => v.db == 'all' || dbCategories.contains(v.db))
        .toList();
    final knownDb = known.map((v) => v.db).toSet();
    final extra = dbCategories
        .where((c) => !knownDb.contains(c))
        .map(FoodCategoryVisuals.forDb)
        .toList();
    setState(() => _categories = [...known, ...extra]);
  }

  /// Whether anything constrains the list (search term or any filter).
  bool get _hasConstraints =>
      _searchController.text.trim().isNotEmpty || _filter.hasActiveFilters;

  Future<void> _search() async {
    if (!_hasConstraints) return;
    setState(() {
      _searching = true;
      _hasSearched = true;
    });

    final query = _searchController.text.trim();
    final results = query.isEmpty
        ? await _nutritionService.getFoods(filter: _filter)
        : await _nutritionService.searchFoods(query, filter: _filter);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  void _selectCategory(String db) {
    setState(() => _filter = _filter.copyWith(category: db));
    _search();
  }

  Future<void> _openFilterSheet() async {
    final applied = await FoodFilterSheet.show(context, _filter);
    if (applied == null || !mounted) return;
    setState(() => _filter = applied);
    _search();
  }

  /// Back to the initial suggestions view: clears the search term and every
  /// filter dimension (used by the empty-state reset).
  void _resetAll() {
    setState(() {
      _searchController.clear();
      _filter = const FoodFilter();
      _results = [];
      _searching = false;
      _hasSearched = false;
    });
  }

  String _categoryLabel(String db) {
    final l10n = AppLocalizations.of(context)!;
    switch (db) {
      case 'all':
        return l10n.allCategories;
      case 'arabic':
        return l10n.catArabic;
      case 'protein':
        return l10n.catProtein;
      case 'carbs':
        return l10n.catCarbs;
      case 'vegetables':
        return l10n.catVegetables;
      case 'fruits':
        return l10n.catFruits;
      case 'dairy':
        return l10n.catDairy;
      case 'fats':
        return l10n.catFats;
      case 'fastfood':
        return l10n.catFastfood;
      case 'drinks':
        return l10n.catDrinks;
      case 'snacks':
        return l10n.catSnacks;
      case 'desserts':
        return l10n.catDesserts;
      case 'street_food':
        return l10n.catStreetFood;
      case 'burgers':
        return l10n.catBurgers;
      case 'pizza':
        return l10n.catPizza;
      case 'pasta':
        return l10n.catPasta;
      case 'sandwiches':
        return l10n.catSandwiches;
      case 'sushi':
        return l10n.catSushi;
      case 'fried_chicken':
        return l10n.catFriedChicken;
      case 'breakfast':
        return l10n.catBreakfast;
      case 'other':
        return l10n.catOther;
      default:
        return db.replaceAll('_', ' ');
    }
  }

  String _mealLabel() {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.preselectedMeal) {
      case 'lunch':
        return l10n.lunch;
      case 'dinner':
        return l10n.dinner;
      case 'snack':
        return l10n.snack;
      default:
        return l10n.breakfast;
    }
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    final Widget sheet = Container(
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
                      Text(
                        AppLocalizations.of(context)!.searchFood,
                        style: AppText.headlineSm.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.foodTargetingMeal(_mealLabel()),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.filter_list_rounded,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: AppLocalizations.of(context)!.foodFilters,
                      onPressed: _openFilterSheet,
                    ),
                    if (_filter.macroRangeCount > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accentCalories,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                  ),
                  // Icon-only control — needs an accessible label even
                  // though it has no visible text (a11y checklist item).
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
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
                hintText: AppLocalizations.of(context)!.searchHint,
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).deleteButtonTooltip,
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
          FoodCategoryChips(
            categories: _categories,
            selectedDb: _filter.category,
            onSelect: _selectCategory,
            labelOf: _categoryLabel,
          ),

          if (_hasSearched && !_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.foodResultsFound(_results.length),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          Expanded(
            child: _searching
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  )
                : !_hasSearched
                ? _buildSearchSuggestions()
                : _results.isEmpty
                ? FoodEmptyState(
                    filtersActive: _filter.hasActiveFilters,
                    onReset: _resetAll,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final item = _StaggeredFoodTile(
                        index: i,
                        child: _buildFoodResultTile(_results[i]),
                      );
                      return item;
                    },
                  ),
          ),
        ],
      ),
    );
    if (reduce) return sheet;
    return SlideTransition(
      position: _sheetSlide,
      child: FadeTransition(opacity: _sheetFade, child: sheet),
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
            AppLocalizations.of(context)!.foodPopularFoods,
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
                .map(
                  (s) => GestureDetector(
                    onTap: () {
                      _searchController.text = s;
                      _search();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
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
                  ),
                )
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
            FoodThumbnail(
              imageUrl: food['image_url']?.toString(),
              category: food['category']?.toString(),
              size: 44,
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
                  if (food['name_ar'] != null &&
                      food['name_ar'] != food['name'])
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
                      _resultBadge(
                        '${food['calories']} kcal',
                        AppColors.primary,
                      ),
                      _resultBadge(
                        'P ${food['protein_g']}g',
                        AppColors.accentProtein,
                      ),
                      _resultBadge(
                        'C ${food['carbs_g']}g',
                        AppColors.accentCarbs,
                      ),
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
              child: Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800),
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

class _LogFoodSheetState extends State<_LogFoodSheet>
    with SingleTickerProviderStateMixin {
  final _nutritionService = NutritionService();
  late TextEditingController _quantityCtrl;
  late String _mealType;
  late double _quantity;
  late String _unit;
  bool _logging = false;
  bool _confirmed = false;
  late final AnimationController _confirmCtrl;
  late final Animation<double> _confirmScale;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMeal;
    final units = _servingUnitsFor(widget.food['name'] ?? '');
    _unit = units.first.label;
    _quantity = _unit == 'g' ? 100.0 : 1.0;
    _quantityCtrl = TextEditingController(text: _quantity.toStringAsFixed(0));
    _confirmCtrl = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _confirmScale = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _confirmCtrl, curve: AppCurves.standard));
  }

  bool _kw(String name, List<String> keys) =>
      keys.any((k) => name.toLowerCase().contains(k));

  // Icons instead of emoji per the app's icon standard — emoji render
  // inconsistently across devices/fonts and can't be themed or scaled.
  List<({String label, double grams, IconData icon, String hint})>
  _servingUnitsFor(String rawName) {
    final n = rawName.toLowerCase();

    if (_kw(n, ['egg', 'بيض', 'beyd'])) {
      return [
        (
          label: 'piece (حبة)',
          grams: 50.0,
          icon: Icons.egg_rounded,
          hint: '1 egg ≈ 50g',
        ),
        (label: 'g', grams: 1.0, icon: Icons.straighten_rounded, hint: 'Grams'),
      ];
    }
    if (_kw(n, ['bread', 'toast', 'خبز', 'عيش', 'pita'])) {
      return [
        (
          label: 'slice (شريحة)',
          grams: 25.0,
          icon: Icons.bakery_dining_rounded,
          hint: '1 slice ≈ 25g',
        ),
        (
          label: 'loaf (رغيف)',
          grams: 150.0,
          icon: Icons.bakery_dining_rounded,
          hint: '1 loaf ≈ 150g',
        ),
        (label: 'g', grams: 1.0, icon: Icons.straighten_rounded, hint: 'Grams'),
      ];
    }
    if (_kw(n, ['milk', 'حليب', 'lait'])) {
      return [
        (
          label: 'cup (كوب)',
          grams: 240.0,
          icon: Icons.local_cafe_rounded,
          hint: '1 cup = 240ml',
        ),
        (
          label: 'glass (كأس)',
          grams: 200.0,
          icon: Icons.local_drink_rounded,
          hint: '1 glass ≈ 200ml',
        ),
        (
          label: 'ml',
          grams: 1.0,
          icon: Icons.water_drop_rounded,
          hint: 'Milliliters',
        ),
      ];
    }
    if (_kw(n, ['rice', 'أرز', 'ارز', 'ruz'])) {
      return [
        (
          label: 'cup cooked (كوب)',
          grams: 186.0,
          icon: Icons.rice_bowl_rounded,
          hint: '1 cup cooked ≈ 186g',
        ),
        (
          label: 'cup dry (جاف)',
          grams: 185.0,
          icon: Icons.grass_rounded,
          hint: '1 cup dry ≈ 185g',
        ),
        (label: 'g', grams: 1.0, icon: Icons.straighten_rounded, hint: 'Grams'),
      ];
    }
    if (_kw(n, ['chicken', 'دجاج', 'djaj'])) {
      return [
        (
          label: 'piece (قطعة)',
          grams: 150.0,
          icon: Icons.kebab_dining_rounded,
          hint: '1 breast ≈ 150g',
        ),
        (
          label: '½ piece',
          grams: 75.0,
          icon: Icons.kebab_dining_rounded,
          hint: 'Half breast ≈ 75g',
        ),
        (label: 'g', grams: 1.0, icon: Icons.straighten_rounded, hint: 'Grams'),
      ];
    }
    if (_kw(n, ['banana', 'موز'])) {
      return [
        (
          label: 'piece (حبة)',
          grams: 118.0,
          icon: Icons.eco_rounded,
          hint: '1 medium banana ≈ 118g',
        ),
        (label: 'g', grams: 1.0, icon: Icons.straighten_rounded, hint: 'Grams'),
      ];
    }
    if (_kw(n, ['apple', 'تفاح'])) {
      return [
        (
          label: 'piece (حبة)',
          grams: 182.0,
          icon: Icons.eco_rounded,
          hint: '1 medium apple ≈ 182g',
        ),
        (label: 'g', grams: 1.0, icon: Icons.straighten_rounded, hint: 'Grams'),
      ];
    }

    return [
      (label: 'g', grams: 1.0, icon: Icons.straighten_rounded, hint: 'Grams'),
      (
        label: 'cup (كوب)',
        grams: 240.0,
        icon: Icons.local_cafe_rounded,
        hint: '1 cup ≈ 240g',
      ),
      (
        label: 'tbsp',
        grams: 15.0,
        icon: Icons.soup_kitchen_rounded,
        hint: '1 tbsp ≈ 15g',
      ),
      (
        label: 'serving',
        grams: 100.0,
        icon: Icons.restaurant_rounded,
        hint: '1 serving = 100g',
      ),
    ];
  }

  double get _grams {
    final units = _servingUnitsFor(widget.food['name'] ?? '');
    final match = units.firstWhere(
      (u) => u.label == _unit,
      orElse: () => units.first,
    );
    return _quantity * match.grams;
  }

  double _calc(String key) =>
      ((widget.food[key] as num?)?.toDouble() ?? 0) * _grams / 100;

  @override
  void dispose() {
    _confirmCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  Widget _mealChoice(String type, String label, IconData icon) {
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
              Icon(
                icon,
                size: 18,
                color: sel ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
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
    final l10n = AppLocalizations.of(context)!;
    final units = _servingUnitsFor(widget.food['name'] ?? '');
    final selectedUnit = units.firstWhere(
      (u) => u.label == _unit,
      orElse: () => units.first,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                FoodThumbnail(
                  imageUrl: widget.food['image_url']?.toString(),
                  category: widget.food['category']?.toString(),
                  size: 52,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.food['name'] ?? '',
                        style: AppText.headlineSm.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.food['name_ar'] != null)
                        Text(
                          widget.food['name_ar'],
                          style: AppText.bodySm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.foodLogPer100g,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
                    l10n.foodLogCalories,
                    'kcal',
                    AppColors.primary,
                  ),
                  _divider(),
                  _liveStatCol(
                    _calc('protein_g').toStringAsFixed(1),
                    l10n.foodLogProtein,
                    'g',
                    AppColors.accentProtein,
                  ),
                  _divider(),
                  _liveStatCol(
                    _calc('carbs_g').toStringAsFixed(1),
                    l10n.foodLogCarbs,
                    'g',
                    AppColors.accentCarbs,
                  ),
                  _divider(),
                  _liveStatCol(
                    _calc('fat_g').toStringAsFixed(1),
                    l10n.foodLogFat,
                    'g',
                    AppColors.accentFat,
                  ),
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.foodLogQuantity,
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
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.label,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    u.icon,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    u.label,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _unit = v ?? units.first.label),
                    ),
                  ),
                ),
              ],
            ),
            // Was computed but never shown before — surfaces the "1 egg ≈
            // 50g" style guidance so the quantity field isn't a guessing game.
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                selectedUnit.hint,
                style: AppText.bodySm.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Meal Type Selector
            Text(
              l10n.foodLogAssignMeal,
              style: AppText.labelMd.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _mealChoice(
                  'breakfast',
                  l10n.breakfast,
                  Icons.free_breakfast_rounded,
                ),
                _mealChoice('lunch', l10n.lunch, Icons.lunch_dining_rounded),
                _mealChoice('dinner', l10n.dinner, Icons.dinner_dining_rounded),
                _mealChoice('snack', l10n.snack, Icons.cookie_rounded),
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
                onPressed: (_logging || _confirmed)
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final bool disableAnimations =
                            MediaQuery.disableAnimationsOf(context);
                        HapticFeedback.mediumImpact();
                        setState(() => _logging = true);
                        final ok = await _nutritionService.logFood(
                          foodId: widget.food['id'].toString(),
                          foodName: widget.food['name'],
                          mealType: _mealType,
                          quantity: _grams,
                          calories: _calc('calories'),
                          proteinG: _calc('protein_g'),
                          carbsG: _calc('carbs_g'),
                          fatG: _calc('fat_g'),
                          // Catalog micro-nutrients (per-100g) scaled to the
                          // logged grams; null when the catalog row has none.
                          extras:
                              AdditionalNutrients.fromFoodRow(
                                widget.food,
                              ).hasAny
                              ? AdditionalNutrients.fromFoodRow(
                                  widget.food,
                                ).scaledBy(_grams / 100)
                              : null,
                        );
                        if (!ok) {
                          if (!mounted) return;
                          setState(() => _logging = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(l10n.foodLogSaveError)),
                                ],
                              ),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        if (!mounted) return;
                        setState(() {
                          _logging = false;
                          _confirmed = true;
                        });
                        if (!mounted) return;
                        HapticFeedback.lightImpact();
                        if (!disableAnimations) {
                          await _confirmCtrl.forward();
                          if (!mounted) return;
                          await _confirmCtrl.reverse();
                        }
                        // Brief checkmark moment before closing sheets
                        await Future.delayed(const Duration(milliseconds: 180));
                        if (!mounted) return;
                        widget.onLogged();
                      },
                child: _logging
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : _confirmed
                    ? ScaleTransition(
                        scale: _confirmScale,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              l10n.foodLogLogged,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            l10n.foodLogConfirm,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 32, color: AppColors.borderSubtle);

  Widget _liveStatCol(String val, String label, String unit, Color color) =>
      Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            '$label ($unit)',
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

class _StaggeredFoodTile extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredFoodTile({required this.index, required this.child});

  @override
  State<_StaggeredFoodTile> createState() => _StaggeredFoodTileState();
}

class _StaggeredFoodTileState extends State<_StaggeredFoodTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final bool reduce = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _c = AnimationController(
      vsync: this,
      duration: reduce ? Duration.zero : AppDurations.medium,
    );
    _fade = CurvedAnimation(parent: _c, curve: AppCurves.standard);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: AppCurves.standard));
    final delay = (widget.index * 30).clamp(0, 200);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
