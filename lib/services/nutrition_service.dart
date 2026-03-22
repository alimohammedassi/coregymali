import 'supabase_client.dart';

class NutritionService {
  // Search foods
  Future<List<Map<String,dynamic>>> searchFoods(String query) async {
    return await supabase
        .from('foods')
        .select()
        .ilike('name', '%$query%')
        .limit(20);
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
    final d = (date ?? DateTime.now()).toIso8601String().substring(0,10);
    await supabase.from('nutrition_logs').insert({
      'user_id': currentUserId,
      'food_id': foodId,
      'food_name': foodName,
      'meal_type': mealType,
      'quantity': quantity,
      'calories': calories * (quantity / 100),
      'protein_g': proteinG * (quantity / 100),
      'carbs_g': carbsG * (quantity / 100),
      'fat_g': fatG * (quantity / 100),
      'logged_date': d,
    });
  }

  // Get today's logs grouped by meal
  Future<Map<String, List<Map<String,dynamic>>>> getTodayLogs() async {
    if (currentUserId == null) return {};
    final today = DateTime.now().toIso8601String().substring(0,10);
    final rows = await supabase
        .from('nutrition_logs')
        .select()
        .eq('user_id', currentUserId!)
        .eq('logged_date', today)
        .order('logged_at');
    final Map<String, List<Map<String,dynamic>>> grouped = {
      'breakfast': [], 'lunch': [], 'dinner': [], 'snack': []
    };
    for (final row in rows) {
      grouped[row['meal_type']]?.add(row);
    }
    return grouped;
  }

  // Delete food log
  Future<void> deleteLog(String logId) async {
    await supabase.from('nutrition_logs').delete().eq('id', logId);
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
  }
}
