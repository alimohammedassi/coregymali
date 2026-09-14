import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/additional_nutrients.dart';
import '../models/food_filter.dart';
import '../models/food_scan_result.dart';
import '../models/voice_food_log_result.dart';
import 'streak_service.dart';
import 'supabase_client.dart';

class NutritionService {
  final StreakService _streakService = StreakService();

  /// Whether the DB has the additional-nutrient columns (fiber_g, sodium_mg,
  /// …). Flips to false the first time Postgres says one is missing, so the
  /// app keeps logging macros normally when the migration hasn't been
  /// applied yet. Reset on every app start.
  bool _extraNutrientsReady = true;

  static const List<String> _extraNutrientColumns = [
    'fiber_g', 'sugars_g', 'sodium_mg', 'potassium_mg',
    'calcium_mg', 'iron_mg', 'cholesterol_mg', 'caffeine_mg',
  ];

  /// Inserts one `nutrition_logs` row and returns it (with `id`), or null on
  /// failure. Transparently strips the extra-nutrient columns and retries
  /// once when the deployment predates the migration.
  Future<Map<String, dynamic>?> insertNutritionLogRow(
    Map<String, dynamic> base,
    AdditionalNutrients? extras,
  ) async {
    final map = Map<String, dynamic>.from(base);
    if (extras != null && extras.hasAny && _extraNutrientsReady) {
      map.addAll(extras.toInsertColumns());
    }
    try {
      return await supabase
          .from('nutrition_logs')
          .insert(map)
          .select('id')
          .single();
    } on PostgrestException catch (e) {
      if (_extraNutrientsReady &&
          (e.code == 'PGRST204' || e.code == '42703')) {
        _extraNutrientsReady = false;
        debugPrint('⚠️ additional-nutrient columns missing in DB — '
            'falling back to legacy schema for this session');
        for (final c in _extraNutrientColumns) {
          map.remove(c);
        }
        return await supabase
            .from('nutrition_logs')
            .insert(map)
            .select('id')
            .single();
      }
      rethrow;
    }
  }

  /// True (once) when [e] means the extra-nutrient columns aren't in the DB
  /// yet; also flips [_extraNutrientsReady] so later calls skip them.
  bool _maybeDisableExtraNutrients(PostgrestException e) {
    if (_extraNutrientsReady && (e.code == 'PGRST204' || e.code == '42703')) {
      _extraNutrientsReady = false;
      debugPrint('⚠️ additional-nutrient columns missing in DB — '
          'falling back to legacy schema for this session');
      return true;
    }
    return false;
  }

  /// Ranks DB matches by relevance: exact name first, then names that start
  /// with the query, then by the position of the first match (earlier wins),
  /// alphabetical as final tie-break. Positional ranking matters for Arabic:
  /// users type the stem ("رز") which sits INSIDE the word ("أرز"), so a
  /// startsWith-only strategy would fail every Arabic match.
  /// Pure function (unit-tested).
  static List<Map<String, dynamic>> rankFoods(
    List<Map<String, dynamic>> results,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return results;
    final qAr = query.trim();
    int tier(Map<String, dynamic> food) {
      final name = (food['name'] ?? '').toString().toLowerCase();
      final nameAr = (food['name_ar'] ?? '').toString();
      if (name == q || nameAr == qAr) return 0;
      if (name.startsWith(q) || nameAr.startsWith(qAr)) return 1;
      return 2;
    }

    int firstMatchPos(Map<String, dynamic> food) {
      final inEn = (food['name'] ?? '')
          .toString()
          .toLowerCase()
          .indexOf(q);
      final inAr = (food['name_ar'] ?? '').toString().indexOf(qAr);
      if (inEn == -1) return inAr == -1 ? 1 << 30 : inAr;
      if (inAr == -1) return inEn;
      return inEn < inAr ? inEn : inAr;
    }

    final ranked = List<Map<String, dynamic>>.from(results);
    ranked.sort((a, b) {
      final byTier = tier(a).compareTo(tier(b));
      if (byTier != 0) return byTier;
      final byPos = firstMatchPos(a).compareTo(firstMatchPos(b));
      if (byPos != 0) return byPos;
      return (a['name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['name'] ?? '').toString().toLowerCase());
    });
    return ranked;
  }

  // Search foods
  //
  // [filter] combines with the search term using AND logic server-side:
  // category (.eq), calorie range (.gte/.lte) and protein range (.gte/.lte)
  // all constrain the same query.
  Future<List<Map<String, dynamic>>> searchFoods(
    String query, {
    FoodFilter filter = const FoodFilter(),
  }) async {
    List<Map<String, dynamic>> results = [];
    try {
      // Try searching both name and name_ar columns
      var dbQuery = supabase
          .from('foods')
          .select()
          .or('name.ilike.%$query%,name_ar.ilike.%$query%');
      dbQuery = _applyFilter(dbQuery, filter);

      final dbResults = await dbQuery.order('name').limit(100);
      results = rankFoods(List<Map<String, dynamic>>.from(dbResults), query);
      return results;
    } on PostgrestException catch (e) {
      debugPrint('DB Error [${e.code}]: ${e.message} — trying name only fallback');
      // Fallback: search by name only (in case name_ar column doesn't exist)
      try {
        var dbQuery = supabase
            .from('foods')
            .select()
            .ilike('name', '%$query%');
        dbQuery = _applyFilter(dbQuery, filter);
        final dbResults = await dbQuery.order('name').limit(100);
        results = rankFoods(List<Map<String, dynamic>>.from(dbResults), query);
        return results;
      } catch (fallbackError) {
        debugPrint('Fallback search also failed: $fallbackError');
        return results;
      }
    } catch (e) {
      debugPrint('Error searching foods: $e');
      return results;
    }
  }

  /// Adds [filter]'s category + macro-range constraints to an already-started
  /// `foods` query. Category and both macro dimensions AND together; a null
  /// bound is open-ended (no constraint emitted).
  PostgrestFilterBuilder<List<Map<String, dynamic>>> _applyFilter(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> dbQuery,
    FoodFilter filter,
  ) {
    if (filter.category.toLowerCase() != 'all') {
      dbQuery = dbQuery.eq('category', filter.category);
    }
    if (filter.minCalories != null) {
      dbQuery = dbQuery.gte('calories', filter.minCalories!);
    }
    if (filter.maxCalories != null) {
      dbQuery = dbQuery.lte('calories', filter.maxCalories!);
    }
    if (filter.minProtein != null) {
      dbQuery = dbQuery.gte('protein_g', filter.minProtein!);
    }
    if (filter.maxProtein != null) {
      dbQuery = dbQuery.lte('protein_g', filter.maxProtein!);
    }
    return dbQuery;
  }

  /// Browse the seeded `foods` table without a search term (the "popular /
  /// browse" list shown by food pickers before the user types anything).
  /// Single source of truth for both FoodLoggingModal and AddFoodSheet.
  Future<List<Map<String, dynamic>>> getFoods({
    FoodFilter filter = const FoodFilter(),
  }) async {
    try {
      var dbQuery = supabase.from('foods').select();
      dbQuery = _applyFilter(dbQuery, filter);
      final dbResults = await dbQuery.order('name').limit(200);
      return List<Map<String, dynamic>>.from(dbResults);
    } catch (e) {
      debugPrint('Error loading foods: $e');
      return [];
    }
  }

  /// Distinct category values present in the catalog, so the filter chips
  /// always match what can actually be returned (new seed categories show up
  /// without a UI change). Empty list on failure — callers fall back to the
  /// static vocabulary.
  Future<List<String>> getFoodCategories() async {
    try {
      final rows = await supabase.from('foods').select('category').limit(2000);
      final categories = <String>{};
      for (final row in rows) {
        final c = (row['category'] ?? '').toString().trim();
        if (c.isNotEmpty) categories.add(c);
      }
      return categories.toList()..sort();
    } catch (e) {
      debugPrint('Error loading food categories: $e');
      return [];
    }
  }

  // Log food
  Future<bool> logFood({
    required String foodId,
    required String foodName,
    required String mealType,
    required double quantity,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    AdditionalNutrients? extras,
    DateTime? date,
  }) async {
    if (currentUserId == null) {
      debugPrint('❌ logFood: currentUserId is null — user not logged in');
      return false;
    }
    try {
      final d = (date ?? DateTime.now()).toIso8601String().substring(0, 10);

      // Only include food_id if it looks like a real UUID (not a custom string)
      final bool isUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(foodId);

      final insertMap = <String, dynamic>{
        'user_id': currentUserId,
        'food_name': foodName,
        'meal_type': mealType,
        'quantity': quantity,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'logged_date': d,
      };

      // Micro-nutrients: omitted keys stay SQL NULL (unknown), never 0.
      if (isUuid) {
        insertMap['food_id'] = foodId;
      }

      debugPrint('✅ Inserting nutrition_log: $insertMap');

      await insertNutritionLogRow(insertMap, extras);
      await _updateDailySummary(d);
      // Logged food → count today as active for the streak.
      _streakService.recordActivity('nutrition');
      debugPrint('✅ nutrition_log inserted & daily_summary updated for $d');
      unawaited(maybeSendCalorieAlert());
      return true;
    } on PostgrestException catch (e) {
      if (_maybeDisableExtraNutrients(e)) {
        return logFood(
          foodId: foodId,
          foodName: foodName,
          mealType: mealType,
          quantity: quantity,
          calories: calories,
          proteinG: proteinG,
          carbsG: carbsG,
          fatG: fatG,
          extras: null,
          date: date,
        );
      }
      debugPrint('❌ Supabase error logging food: ${e.message} | code: ${e.code} | details: ${e.details}');
      return false;
    } catch (e, st) {
      debugPrint('❌ Error logging food: $e\n$st');
      return false;
    }
  }

  // Save confirmed AI food-scan items into the daily log.
  // For each item: insert a nutrition_logs row, then write the new log's id
  // back onto food_scan_items.nutrition_log_id.
  Future<bool> saveScannedItems({
    required List<FoodScanItem> items,
    required String mealType, // breakfast/lunch/dinner/snack
  }) async {
    final userId = currentUserId;
    if (userId == null || items.isEmpty) return false;

    final d = DateTime.now().toIso8601String().substring(0, 10);
    var savedCount = 0;

    for (final item in items) {
      try {
        final insertMap = <String, dynamic>{
          'user_id': userId,
          'food_name': item.name,
          'meal_type': mealType,
          'quantity': item.estimatedWeightG,
          'serving_unit': 'g',
          'calories': item.calories,
          'protein_g': item.proteinG,
          'carbs_g': item.carbsG,
          'fat_g': item.fatG,
          'logged_date': d,
        };

        final inserted = await insertNutritionLogRow(insertMap, item.extras);

        final logId = inserted?['id']?.toString();
        debugPrint('✅ scanned item "${item.name}" → nutrition_log $logId');

        if (logId != null && logId.isNotEmpty) {
          await supabase
              .from('food_scan_items')
              .update({'nutrition_log_id': logId})
              .eq('id', item.id);
        }
        savedCount++;
      } on PostgrestException catch (e) {
        debugPrint('❌ saveScannedItems [${e.code}]: ${e.message} — item "${item.name}" skipped');
      } catch (e, st) {
        debugPrint('❌ Error saving scanned item "${item.name}": $e\n$st');
      }
    }

    if (savedCount > 0) {
      await _updateDailySummary(d);
      // AI food scan → count today as active for the streak.
      _streakService.recordActivity('nutrition');
      debugPrint('✅ saved $savedCount/${items.length} scanned items for $d');
      unawaited(maybeSendCalorieAlert());
      return true;
    }
    return false;
  }

  // Save confirmed voice food-log items into the daily log.
  // For each item: insert a nutrition_logs row, then write the new log's id
  // back onto voice_food_log_items.nutrition_log_id.
  Future<bool> saveVoiceLogItems({
    required List<VoiceFoodLogItem> items,
    required String mealType, // breakfast/lunch/dinner/snack
  }) async {
    final userId = currentUserId;
    if (userId == null || items.isEmpty) return false;

    final d = DateTime.now().toIso8601String().substring(0, 10);
    var savedCount = 0;

    for (final item in items) {
      try {
        final insertMap = <String, dynamic>{
          'user_id': userId,
          'food_name': item.name,
          'meal_type': mealType,
          'quantity': item.estimatedWeightG,
          'serving_unit': 'g',
          'calories': item.calories,
          'protein_g': item.proteinG,
          'carbs_g': item.carbsG,
          'fat_g': item.fatG,
          'logged_date': d,
        };

        final inserted = await insertNutritionLogRow(insertMap, item.extras);

        final logId = inserted?['id']?.toString();
        debugPrint('✅ voice item "${item.name}" → nutrition_log $logId');

        if (logId != null && logId.isNotEmpty) {
          await supabase
              .from('voice_food_log_items')
              .update({'nutrition_log_id': logId})
              .eq('id', item.id);
        }
        savedCount++;
      } on PostgrestException catch (e) {
        debugPrint('❌ saveVoiceLogItems [${e.code}]: ${e.message} — item "${item.name}" skipped');
      } catch (e, st) {
        debugPrint('❌ Error saving voice item "${item.name}": $e\n$st');
      }
    }

    if (savedCount > 0) {
      await _updateDailySummary(d);
      // Voice food log → count today as active for the streak.
      _streakService.recordActivity('nutrition');
      debugPrint('✅ saved $savedCount/${items.length} voice items for $d');
      unawaited(maybeSendCalorieAlert());
      return true;
    }
    return false;
  }

  // Get today's logs grouped by meal
  Future<Map<String, List<Map<String, dynamic>>>> getTodayLogs() async {
    final Map<String, List<Map<String, dynamic>>> grouped = {
      'breakfast': [],
      'lunch': [],
      'dinner': [],
      'snack': []
    };
    if (currentUserId == null) return grouped;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await supabase
          .from('nutrition_logs')
          .select()
          .eq('user_id', currentUserId!)
          .eq('logged_date', today)
          .order('logged_at', ascending: true);
      for (final row in rows) {
        grouped[row['meal_type']]?.add(row);
      }
      return grouped;
    } on PostgrestException catch (e) {
      debugPrint('❌ Supabase error getting today logs: ${e.message} | code: ${e.code}');
      // Try without ordering if column doesn't exist
      try {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final rows = await supabase
            .from('nutrition_logs')
            .select()
            .eq('user_id', currentUserId!)
            .eq('logged_date', today);
        for (final row in rows) {
          grouped[row['meal_type']]?.add(row);
        }
        return grouped;
      } catch (_) {
        return grouped;
      }
    } catch (e) {
      debugPrint('❌ Error getting today logs: $e');
      return grouped;
    }
  }

  // Delete food log
  Future<void> deleteLog(String logId) async {
    if (currentUserId == null) return;
    try {
      // Get the log to know the date before deleting
      final log = await supabase
          .from('nutrition_logs')
          .select('logged_date')
          .eq('id', logId)
          .eq('user_id', currentUserId!)
          .single();
      
      await supabase.from('nutrition_logs').delete().eq('id', logId).eq('user_id', currentUserId!);
      
      if (log['logged_date'] != null) {
        await _updateDailySummary(log['logged_date'].toString());
      }
    } on PostgrestException catch (e) {
      debugPrint('❌ Supabase error deleting log: ${e.message} | code: ${e.code}');
    } catch (e) {
      debugPrint('❌ Error deleting log: $e');
    }
  }

  // Helper to sync daily_summary based on logs
  Future<void> _updateDailySummary(String dateStr) async {
    if (currentUserId == null) return;
    try {
      final logs = await supabase
          .from('nutrition_logs')
          .select(_extraNutrientsReady
              ? 'calories, protein_g, carbs_g, fat_g, '
                  'fiber_g, sugars_g, sodium_mg, potassium_mg, '
                  'calcium_mg, iron_mg, cholesterol_mg, caffeine_mg'
              : 'calories, protein_g, carbs_g, fat_g')
          .eq('user_id', currentUserId!)
          .eq('logged_date', dateStr);

      double totalCals = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;
      double totalFiber = 0;
      double totalSugars = 0;
      double totalSodium = 0;
      double totalPotassium = 0;
      double totalCalcium = 0;
      double totalIron = 0;
      double totalCholesterol = 0;
      double totalCaffeine = 0;

      for (var log in logs) {
        totalCals += (log['calories'] as num?)?.toDouble() ?? 0;
        totalProtein += (log['protein_g'] as num?)?.toDouble() ?? 0;
        totalCarbs += (log['carbs_g'] as num?)?.toDouble() ?? 0;
        totalFat += (log['fat_g'] as num?)?.toDouble() ?? 0;
        totalFiber += (log['fiber_g'] as num?)?.toDouble() ?? 0;
        totalSugars += (log['sugars_g'] as num?)?.toDouble() ?? 0;
        totalSodium += (log['sodium_mg'] as num?)?.toDouble() ?? 0;
        totalPotassium += (log['potassium_mg'] as num?)?.toDouble() ?? 0;
        totalCalcium += (log['calcium_mg'] as num?)?.toDouble() ?? 0;
        totalIron += (log['iron_mg'] as num?)?.toDouble() ?? 0;
        totalCholesterol += (log['cholesterol_mg'] as num?)?.toDouble() ?? 0;
        totalCaffeine += (log['caffeine_mg'] as num?)?.toDouble() ?? 0;
      }

      debugPrint('📊 _updateDailySummary [$dateStr]: cals=$totalCals protein=$totalProtein carbs=$totalCarbs fat=$totalFat fiber=$totalFiber sodium=$totalSodium (from ${logs.length} logs)');

      final summaryMap = <String, dynamic>{
        'user_id': currentUserId,
        'summary_date': dateStr,
        'calories_consumed': totalCals.round(),
        'protein_g': totalProtein.round(),
        'carbs_g': totalCarbs.round(),
        'fat_g': totalFat.round(),
        if (_extraNutrientsReady) ...{
          'fiber_g': _round1(totalFiber),
          'sugars_g': _round1(totalSugars),
          'sodium_mg': totalSodium.round(),
          'potassium_mg': totalPotassium.round(),
          'calcium_mg': totalCalcium.round(),
          'iron_mg': _round1(totalIron),
          'cholesterol_mg': totalCholesterol.round(),
          'caffeine_mg': totalCaffeine.round(),
        },
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase
          .from('daily_summary')
          .upsert(summaryMap, onConflict: 'user_id,summary_date');

      debugPrint('✅ daily_summary upserted for $dateStr');
    } on PostgrestException catch (e) {
      if (_maybeDisableExtraNutrients(e)) {
        await _updateDailySummary(dateStr);
        return;
      }
      debugPrint('❌ _updateDailySummary Supabase error: ${e.message} | code: ${e.code} | details: ${e.details}');
    } catch (e, st) {
      debugPrint('❌ _updateDailySummary error: $e\n$st');
    }
  }

  /// One decimal place for gram-scale micros (fiber/sugars/iron); mg-scale
  /// values round to whole numbers.
  static double _round1(double v) => (v * 10).round() / 10;

  /// Public wrapper so other logging entry points (e.g. the barcode scanner)
  /// refresh the same daily-summary row without duplicating the logic.
  Future<void> syncDailySummary(String dateStr) => _updateDailySummary(dateStr);

  // Add custom food
  Future<void> addCustomFood({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double servingSize = 100,
  }) async {
    try {
      await supabase.from('foods').insert({
        'name': name,
        'calories': calories,
        'protein_g': protein,
        'carbs_g': carbs,
        'fat_g': fat,
        'serving_size': servingSize,
        'is_custom': true,
        'created_by': currentUserId,
      });
    } on PostgrestException catch (e) {
      debugPrint('❌ Supabase error adding custom food: ${e.message} | code: ${e.code}');
    } catch (e) {
      debugPrint('❌ Error adding custom food: $e');
    }
  }

  // Update existing food log
  Future<bool> updateLog({
    required String logId,
    required double quantity,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    String? mealType,
  }) async {
    if (currentUserId == null) return false;
    try {
      // Read the old row's micro-nutrients so they can be rescaled to the
      // new quantity (same proportional treatment as the macros in the UI).
      final oldRow = await supabase
          .from('nutrition_logs')
          .select(_extraNutrientsReady
              ? 'quantity, fiber_g, sugars_g, sodium_mg, potassium_mg, '
                  'calcium_mg, iron_mg, cholesterol_mg, caffeine_mg'
              : 'quantity')
          .eq('id', logId)
          .eq('user_id', currentUserId!)
          .maybeSingle();

      final updateData = <String, dynamic>{
        'quantity': quantity,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };
      if (mealType != null) {
        updateData['meal_type'] = mealType;
      }

      if (oldRow != null) {
        final oldExtras = AdditionalNutrients.fromJson(oldRow);
        if (oldExtras.hasAny) {
          final oldQty = (oldRow['quantity'] as num?)?.toDouble() ?? 0;
          final factor = oldQty > 0 ? quantity / oldQty : 1.0;
          updateData.addAll(oldExtras.scaledBy(factor).toInsertColumns());
        }
      }

      final log = await supabase
          .from('nutrition_logs')
          .update(updateData)
          .eq('id', logId)
          .eq('user_id', currentUserId!)
          .select('logged_date')
          .single();

      if (log['logged_date'] != null) {
        await _updateDailySummary(log['logged_date'].toString());
      }
      unawaited(maybeSendCalorieAlert());
      return true;
    } on PostgrestException catch (e) {
      if (_maybeDisableExtraNutrients(e)) {
        return updateLog(
          logId: logId,
          quantity: quantity,
          calories: calories,
          proteinG: proteinG,
          carbsG: carbsG,
          fatG: fatG,
          mealType: mealType,
        );
      }
      debugPrint('❌ Supabase error updating log: ${e.message} | code: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('❌ Error updating log: $e');
      return false;
    }
  }

  // Quick calorie logger
  Future<bool> logQuickCalories({
    required String foodName,
    required String mealType,
    required double calories,
    double proteinG = 0,
    double carbsG = 0,
    double fatG = 0,
  }) async {
    return logFood(
      foodId: 'quick_${DateTime.now().millisecondsSinceEpoch}',
      foodName: foodName.isEmpty ? 'Quick Calories' : foodName,
      mealType: mealType,
      quantity: 1,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
    );
  }


  // ── Task 5 — calorie-limit alert ────────────────────────────────────────
  /// Called after any successful food logging/edit. Fires a one-per-day
  /// bilingual push once today's total crosses 90% of daily_calories.
  /// Respects notification_preferences.calorie_alerts_enabled (missing row
  /// = enabled). Failures are silent — logging already succeeded.
  Future<void> maybeSendCalorieAlert() async {
    try {
      final uid = currentUserId;
      if (uid == null) return;

      final pref = await supabase
          .from('notification_preferences')
          .select('calorie_alerts_enabled')
          .eq('user_id', uid)
          .maybeSingle();
      if (pref != null && pref['calorie_alerts_enabled'] == false) return;

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final startIso = DateTime.parse(today).toIso8601String();

      final rows = await supabase
          .from('nutrition_logs')
          .select('calories')
          .eq('user_id', uid)
          .gte('logged_at', startIso);
      final total = rows.fold<double>(
        0,
        (sum, r) => sum + ((r['calories'] as num?)?.toDouble() ?? 0),
      );

      final goals = await supabase
          .from('user_goals')
          .select('daily_calories')
          .eq('user_id', uid)
          .maybeSingle();
      final goal = (goals?['daily_calories'] as num?)?.toDouble() ?? 2000;
      if (goal <= 0 || total < goal * 0.9) return;

      final prior = await supabase
          .from('notification_log')
          .select('id')
          .eq('user_id', uid)
          .eq('type', 'calorie_alert')
          .gte('sent_at', startIso)
          .limit(1);
      if ((prior as List).isNotEmpty) return;

      final left = (goal - total).round();
      await supabase.functions.invoke('send-notification', body: {
        'user_id': uid,
        'title': 'Close to your calorie goal 🔥',
        'body': 'You have $left kcal left today — nice pacing!',
        'title_ar': 'قربت توصل لهدف سعراتك 🔥',
        'body_ar': 'باقي $left كالوري النهاردة — ممتاز! 💪',
        'type': 'calorie_alert',
        'data': {'left_kcal': left},
      });
    } catch (e) {
      debugPrint('calorie alert check skipped: $e');
    }
  }
}
