import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/food_scan_result.dart';
import '../models/voice_food_log_result.dart';
import 'supabase_client.dart';

class NutritionService {
  // Search foods
  Future<List<Map<String, dynamic>>> searchFoods(String query, {String category = 'all'}) async {
    List<Map<String, dynamic>> results = [];
    try {
      // Try searching both name and name_ar columns
      var dbQuery = supabase
          .from('foods')
          .select()
          .or('name.ilike.%$query%,name_ar.ilike.%$query%');

      if (category.toLowerCase() != 'all') {
        dbQuery = dbQuery.eq('category', category);
      }

      final dbResults = await dbQuery.order('name').limit(40);
      results = List<Map<String, dynamic>>.from(dbResults);
      return results;
    } on PostgrestException catch (e) {
      debugPrint('DB Error [${e.code}]: ${e.message} — trying name only fallback');
      // Fallback: search by name only (in case name_ar column doesn't exist)
      try {
        var dbQuery = supabase
            .from('foods')
            .select()
            .ilike('name', '%$query%');
        if (category.toLowerCase() != 'all') {
          dbQuery = dbQuery.eq('category', category);
        }
        final dbResults = await dbQuery.order('name').limit(40);
        results = List<Map<String, dynamic>>.from(dbResults);
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

      if (isUuid) {
        insertMap['food_id'] = foodId;
      }

      debugPrint('✅ Inserting nutrition_log: $insertMap');

      await supabase.from('nutrition_logs').insert(insertMap);
      await _updateDailySummary(d);
      debugPrint('✅ nutrition_log inserted & daily_summary updated for $d');
      return true;
    } on PostgrestException catch (e) {
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
        final inserted = await supabase
            .from('nutrition_logs')
            .insert({
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
            })
            .select('id')
            .single();

        final logId = inserted['id']?.toString();
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
      debugPrint('✅ saved $savedCount/${items.length} scanned items for $d');
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
        final inserted = await supabase
            .from('nutrition_logs')
            .insert({
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
            })
            .select('id')
            .single();

        final logId = inserted['id']?.toString();
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
      debugPrint('✅ saved $savedCount/${items.length} voice items for $d');
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
      // Use 'created_at' for ordering as 'logged_at' may not exist in some schemas
      final rows = await supabase
          .from('nutrition_logs')
          .select()
          .eq('user_id', currentUserId!)
          .eq('logged_date', today)
          .order('created_at', ascending: true);
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
          .select('calories, protein_g, carbs_g, fat_g')
          .eq('user_id', currentUserId!)
          .eq('logged_date', dateStr);

      double totalCals = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;

      for (var log in logs) {
        totalCals += (log['calories'] as num?)?.toDouble() ?? 0;
        totalProtein += (log['protein_g'] as num?)?.toDouble() ?? 0;
        totalCarbs += (log['carbs_g'] as num?)?.toDouble() ?? 0;
        totalFat += (log['fat_g'] as num?)?.toDouble() ?? 0;
      }

      debugPrint('📊 _updateDailySummary [$dateStr]: cals=$totalCals protein=$totalProtein carbs=$totalCarbs fat=$totalFat (from ${logs.length} logs)');

      await supabase.from('daily_summary').upsert({
        'user_id': currentUserId,
        'summary_date': dateStr,
        'calories_consumed': totalCals.round(),
        'protein_g': totalProtein.round(),
        'carbs_g': totalCarbs.round(),
        'fat_g': totalFat.round(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,summary_date');

      debugPrint('✅ daily_summary upserted for $dateStr');
    } on PostgrestException catch (e) {
      debugPrint('❌ _updateDailySummary Supabase error: ${e.message} | code: ${e.code} | details: ${e.details}');
    } catch (e, st) {
      debugPrint('❌ _updateDailySummary error: $e\n$st');
    }
  }

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
      return true;
    } on PostgrestException catch (e) {
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
}

