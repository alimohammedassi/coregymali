import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class NutritionService {
  // Search foods
  Future<List<Map<String, dynamic>>> searchFoods(String query, {String category = 'all'}) async {
    List<Map<String, dynamic>> results = [];
    try {
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
      debugPrint('DB Error [${e.code}]: ${e.message}');
      return results;
    } catch (e) {
      debugPrint('Error searching foods: $e');
      return results;
    }
  }

  // Log food
  Future<void> logFood({
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
    if (currentUserId == null) return;
    try {
      final d = (date ?? DateTime.now()).toIso8601String().substring(0, 10);
      await supabase.from('nutrition_logs').insert({
        'user_id': currentUserId,
        'food_id': foodId,
        'food_name': foodName,
        'meal_type': mealType,
        'quantity': quantity,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'logged_date': d,
      });

      await _updateDailySummary(d);
    } on PostgrestException catch (e) {
      print('Supabase error logging food: ${e.message} | code: ${e.code}');
    } catch (e) {
      print('Error logging food: $e');
    }
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
          .order('logged_at');
      for (final row in rows) {
        grouped[row['meal_type']]?.add(row);
      }
      return grouped;
    } on PostgrestException catch (e) {
      print('Supabase error getting today logs: ${e.message} | code: ${e.code}');
      return grouped;
    } catch (e) {
      print('Error getting today logs: $e');
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
      print('Supabase error deleting log: ${e.message} | code: ${e.code}');
    } catch (e) {
      print('Error deleting log: $e');
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

      await supabase.from('daily_summary').upsert({
        'user_id': currentUserId,
        'summary_date': dateStr,
        'calories_consumed': totalCals.round(),
        'protein_g': totalProtein.round(),
        'carbs_g': totalCarbs.round(),
        'fat_g': totalFat.round(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,summary_date');
    } catch (e) {
      print('Error updating daily summary: $e');
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
      print('Supabase error adding custom food: ${e.message} | code: ${e.code}');
    } catch (e) {
      print('Error adding custom food: $e');
    }
  }
}
