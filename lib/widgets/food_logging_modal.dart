import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/nutrition_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'pixel_art_icons.dart';

/// Interactive Food & Meal Logging Modal for CoreGym
/// Browses/searches the Supabase `foods` table (the seeded Egyptian food
/// database) and supports quick custom macro add. The former hardcoded
/// `_popularFoods` preset list was removed: the pre-search list now comes
/// from `NutritionService.getFoods()` so every entry point into food
/// logging shows the same real database-backed list.
class FoodLoggingModal extends StatefulWidget {
  final String initialMealType;
  final String? initialMode; // 'search', 'quick', 'ai', 'voice'

  const FoodLoggingModal({
    super.key,
    this.initialMealType = 'breakfast',
    this.initialMode,
  });

  static Future<bool?> show(
    BuildContext context, {
    String initialMealType = 'breakfast',
    String? initialMode,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodLoggingModal(
        initialMealType: initialMealType,
        initialMode: initialMode,
      ),
    );
  }

  @override
  State<FoodLoggingModal> createState() => _FoodLoggingModalState();
}

class _FoodLoggingModalState extends State<FoodLoggingModal>
    with SingleTickerProviderStateMixin {
  final _nutritionService = NutritionService();

  late String _selectedMeal;
  int _tabIndex = 0; // 0: Browse & Search DB, 1: Quick Custom Add
  bool _isSaving = false;

  // Search / browse state
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // Database browse list (seeded Egyptian foods) shown before any search
  List<Map<String, dynamic>> _browseFoods = [];
  bool _isLoadingBrowse = true;

  // Quick Add state
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _caloriesCtrl = TextEditingController();
  final TextEditingController _proteinCtrl = TextEditingController();
  final TextEditingController _carbsCtrl = TextEditingController();
  final TextEditingController _fatCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _selectedMeal = widget.initialMealType;
    if (widget.initialMode == 'quick') {
      _tabIndex = 1;
    } else if (widget.initialMode == 'ai') {
      _tabIndex = 1;
      _nameCtrl.text = 'AI Scanned Meal (وجبة ذكية)';
      _caloriesCtrl.text = '480';
      _proteinCtrl.text = '35';
      _carbsCtrl.text = '50';
      _fatCtrl.text = '14';
    } else if (widget.initialMode == 'voice') {
      _tabIndex = 1;
      _nameCtrl.text = 'Voice Logged Meal (تسجيل صوتي)';
      _caloriesCtrl.text = '350';
      _proteinCtrl.text = '25';
      _carbsCtrl.text = '40';
      _fatCtrl.text = '10';
    }
    _loadBrowseFoods();
  }

  Future<void> _loadBrowseFoods() async {
    final foods = await _nutritionService.getFoods();
    if (!mounted) return;
    setState(() {
      _browseFoods = foods;
      _isLoadingBrowse = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await _nutritionService.searchFoods(query);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _logFoodItem({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double quantity = 1.0,
    String? foodId,
  }) async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    // foodId is the real UUID from Supabase foods table (or null for custom)
    final bool success = await _nutritionService.logFood(
      foodId: foodId ?? '',
      foodName: name,
      mealType: _selectedMeal,
      quantity: quantity,
      calories: calories * quantity,
      proteinG: protein * quantity,
      carbsG: carbs * quantity,
      fatG: fat * quantity,
    );

    if (!mounted) return;

    if (!success) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ حدث خطأ عند الحفظ — تأكد من الاتصال بالإنترنت'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }


    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
             Icon(Icons.check_circle_rounded, color: AppColors.onPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم الحفظ: $name (${(calories * quantity).toInt()} سعرة)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.of(context).pop(true);
  }

  void _submitQuickAdd() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter food name / يرجى كتابة اسم الوجبة')),
      );
      return;
    }

    final cals = double.tryParse(_caloriesCtrl.text) ?? 0.0;
    final prot = double.tryParse(_proteinCtrl.text) ?? 0.0;
    final carb = double.tryParse(_carbsCtrl.text) ?? 0.0;
    final fat = double.tryParse(_fatCtrl.text) ?? 0.0;
    final qty = double.tryParse(_quantityCtrl.text) ?? 1.0;

    _logFoodItem(
      name: name,
      calories: cals,
      protein: prot,
      carbs: carb,
      fat: fat,
      quantity: qty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final meals = [
      ('breakfast', isArabic ? 'إفطار' : 'Breakfast', PixelIconType.egg),
      ('lunch', isArabic ? 'غداء' : 'Lunch', PixelIconType.plate),
      ('dinner', isArabic ? 'عشاء' : 'Dinner', PixelIconType.apple),
      ('snack', isArabic ? 'سناك' : 'Snack', PixelIconType.avocado),
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration:  BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Modal Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const PixelArtIcon(type: PixelIconType.robot, size: 20, animate: true),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'تسجيل وتغذية اليوم' : 'Log Food & Nutrition',
                      style: AppText.styledHeadlineMd(isArabic: isArabic, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon:  Icon(Icons.close_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Meal Type Selector Pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: meals.map((m) {
                final isSelected = _selectedMeal == m.$1;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedMeal = m.$1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryGreen : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryGreen.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          PixelArtIcon(type: m.$3, size: 14),
                          const SizedBox(height: 2),
                          Text(
                            m.$2,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
                              fontFamily: AppText.fontFamily(isArabic: isArabic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // Mode Toggle Tabs (Database Browse/Search vs Quick Add)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _tabIndex == 0
                              ? AppColors.surfaceContainerHighest
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: _tabIndex == 0
                              ? Border.all(color: AppColors.glassBorder)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            isArabic ? 'قاعدة البيانات' : 'Food Database',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _tabIndex == 0 ? FontWeight.w800 : FontWeight.w600,
                              color: _tabIndex == 0 ? AppColors.primaryGreen : AppColors.textSecondary,
                              fontFamily: AppText.fontFamily(isArabic: isArabic),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _tabIndex == 1
                              ? AppColors.surfaceContainerHighest
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: _tabIndex == 1
                              ? Border.all(color: AppColors.glassBorder)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            isArabic ? 'إضافة سريعة مخصصة' : 'Quick Custom Add',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _tabIndex == 1 ? FontWeight.w800 : FontWeight.w600,
                              color: _tabIndex == 1 ? AppColors.primaryGreen : AppColors.textSecondary,
                              fontFamily: AppText.fontFamily(isArabic: isArabic),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Main Tab Body
          Expanded(
            child: _tabIndex == 0
                ? _buildSearchAndPopularTab(isArabic)
                : _buildQuickAddTab(isArabic),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndPopularTab(bool isArabic) {
    return Column(
      children: [
        // Search TextField
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _performSearch,
            decoration: InputDecoration(
              hintText: isArabic ? 'ابحث عن طعام (مثل: دجاج، أرز، بيض...)' : 'Search food (e.g. Chicken, Rice, Eggs...)',
              hintStyle:  TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              prefixIcon:  Icon(Icons.search_rounded, color: AppColors.primaryGreen),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        _performSearch('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              filled: true,
              fillColor: AppColors.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:  BorderSide(color: AppColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:  BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:  BorderSide(color: AppColors.primaryGreen, width: 1.5),
              ),
            ),
          ),
        ),

        // Search results or DB browse list
        Expanded(
          child: _isSearching
              ?  Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : _searchResults.isNotEmpty
                  ? ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) =>  Divider(height: 1, color: AppColors.borderSubtle),
                      itemBuilder: (_, i) => _buildDbFoodTile(_searchResults[i], isArabic),
                    )
                  : _buildBrowseList(isArabic),
        ),
      ],
    );
  }

  /// The real database-backed list (Supabase `foods` — the seeded Egyptian
  /// food database). Shown before the user types anything; searching swaps
  /// it for filtered results from the same table.
  Widget _buildBrowseList(bool isArabic) {
    if (_isLoadingBrowse) {
      return  Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }

    if (_browseFoods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_rounded,
                size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'لا توجد أطعمة في قاعدة البيانات' : 'No foods in the database',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                fontFamily: AppText.fontFamily(isArabic: isArabic),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isArabic ? 'تحقق من الاتصال بالإنترنت' : 'Check your internet connection',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
                fontFamily: AppText.fontFamily(isArabic: isArabic),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            isArabic ? 'من قاعدة بيانات الأطعمة 🇪🇬' : 'From the food database 🇪🇬',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontFamily: AppText.fontFamily(isArabic: isArabic),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: _browseFoods.length,
            separatorBuilder: (_, __) =>
                 Divider(height: 1, color: AppColors.borderSubtle),
            itemBuilder: (_, i) => _buildDbFoodTile(_browseFoods[i], isArabic),
          ),
        ),
      ],
    );
  }

  /// One tile builder for both browse and search results — a single
  /// implementation for DB-backed foods so the two states can't drift.
  Widget _buildDbFoodTile(Map<String, dynamic> food, bool isArabic) {
    final name = (isArabic && food['name_ar'] != null && food['name_ar'].toString().isNotEmpty)
        ? food['name_ar'].toString()
        : (food['name'] ?? 'Food');
    final cals = ((food['calories'] as num?) ?? 0).toDouble();
    final prot = ((food['protein_g'] as num?) ?? 0).toDouble();
    final carb = ((food['carbs_g'] as num?) ?? 0).toDouble();
    final fat = ((food['fat_g'] as num?) ?? 0).toDouble();

    final imageUrl = food['image_url']?.toString();
    final category = food['category']?.toString();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: _FoodThumbnail(
        imageUrl: imageUrl,
        category: category,
        size: 48,
      ),
      title: Text(
        name,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${cals.toInt()} kcal · P: ${prot.toInt()}g | C: ${carb.toInt()}g | F: ${fat.toInt()}g',
        style:  TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      trailing: Container(
        padding: const EdgeInsets.all(6),
        decoration:  BoxDecoration(
          color: AppColors.primaryGreen,
          shape: BoxShape.circle,
        ),
        child:  Icon(Icons.add_rounded, color: AppColors.onPrimary, size: 16),
      ),
      onTap: () => _logFoodItem(
        name: name,
        calories: cals,
        protein: prot,
        carbs: carb,
        fat: fat,
        foodId: food['id']?.toString(),
      ),
    );
  }

  Widget _buildQuickAddTab(bool isArabic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Name
          Text(
            isArabic ? 'اسم الوجبة / الطعام' : 'Meal / Food Name',
            style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              hintText: isArabic ? 'مثال: وجبة بروتين بعد التمرين' : 'e.g. Post-workout protein meal',
              filled: true,
              fillColor: AppColors.surfaceContainerHigh,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.borderSubtle)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.borderSubtle)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.primaryGreen, width: 1.5)),
            ),
          ),

          const SizedBox(height: 14),

          // Calories + Servings Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'السعرات (kcal)' : 'Calories (kcal)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentCalories),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _caloriesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '450',
                        prefixIcon: const Icon(Icons.local_fire_department_rounded, color: AppColors.accentCalories, size: 18),
                        filled: true,
                        fillColor: AppColors.surfaceContainerHigh,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.borderSubtle)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.borderSubtle)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.primaryGreen, width: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'الكمية / الحصة' : 'Quantity / Servings',
                      style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _quantityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '1',
                        prefixIcon:  Icon(Icons.numbers_rounded, color: AppColors.textSecondary, size: 18),
                        filled: true,
                        fillColor: AppColors.surfaceContainerHigh,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.borderSubtle)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.borderSubtle)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.primaryGreen, width: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Macros (Protein, Carbs, Fat)
          Text(
            isArabic ? 'عناصر الماكروز (جرام)' : 'Macronutrients (grams)',
            style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Protein
              Expanded(
                child: TextField(
                  controller: _proteinCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'بروتين' : 'Protein',
                    labelStyle: const TextStyle(color: AppColors.accentProtein, fontSize: 12),
                    suffixText: 'g',
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.borderSubtle)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Carbs
              Expanded(
                child: TextField(
                  controller: _carbsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'كارب' : 'Carbs',
                    labelStyle: const TextStyle(color: AppColors.accentCarbs, fontSize: 12),
                    suffixText: 'g',
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.borderSubtle)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Fat
              Expanded(
                child: TextField(
                  controller: _fatCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'دهون' : 'Fat',
                    labelStyle: const TextStyle(color: AppColors.accentFat, fontSize: 12),
                    suffixText: 'g',
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide:  BorderSide(color: AppColors.borderSubtle)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submitQuickAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSaving
                  ?  SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2.5),
                    )
                  : Text(
                      isArabic ? 'حفظ في السجل اليومي 🔥' : 'Save to Daily Log 🔥',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFamily: AppText.fontFamily(isArabic: isArabic),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FoodThumbnail — shows a food photo (CachedNetworkImage) with graceful
// fallback when image_url is null or fails to load.
// ─────────────────────────────────────────────────────────────────────────────
class _FoodThumbnail extends StatelessWidget {
  final String? imageUrl;
  final String? category;
  final double size;

  const _FoodThumbnail({
    required this.imageUrl,
    required this.category,
    this.size = 48,
  });

  /// Returns a colour accent based on food category for the placeholder.
  /// Category accents are data-viz colours (like the chart/pixel-art
  /// palettes) — intentionally not mode-flipped; they read on both themes.
  Color _categoryColor() {
    switch ((category ?? '').toLowerCase()) {
      case 'meat':
      case 'poultry':
        return const Color(0xFFEF8354);
      case 'dairy':
        return const Color(0xFF4A90D9);
      case 'grain':
      case 'carbs':
        return const Color(0xFFEDC047);
      case 'vegetables':
      case 'salad':
        return const Color(0xFF56B870);
      case 'fruit':
        return const Color(0xFFE84393);
      case 'legumes':
        return const Color(0xFF9B6B3A);
      case 'seafood':
        return const Color(0xFF2BBCD4);
      case 'drinks':
        return const Color(0xFF6C5CE7);
      default:
        return AppColors.primaryGreen;
    }
  }

  Widget _fallback() {
    final color = _categoryColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Icon(Icons.restaurant_rounded, color: color, size: size * 0.42),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return _fallback();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.borderSubtle,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        errorWidget: (_, __, ___) => _fallback(),
      ),
    );
  }
}
