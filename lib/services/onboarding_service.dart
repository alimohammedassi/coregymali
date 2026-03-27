import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class OnboardingService {
  Future<bool> isCompleted() async {
    if (currentUserId == null) return false;
    try {
      final row = await supabase
          .from('onboarding')
          .select('completed')
          .eq('user_id', currentUserId!)
          .single();
      return row['completed'] == true;
    } on PostgrestException catch (e) {
      print('Supabase error checking onboarding: ${e.message} | code: ${e.code}');
      return false;
    } catch (e) {
      print('Error checking onboarding: $e');
      return false;
    }
  }

  Future<void> saveOnboarding({
    required String name,
    required int age,
    required String gender,
    required double heightCm,
    required double weightKg,
    required String goal,
    required String activityLevel,
    required double targetWeight,
    required int weeklyWorkouts,
  }) async {
    if (currentUserId == null) return;
    try {
      await supabase.from('onboarding').upsert({
        'user_id': currentUserId,
        'age': age,
        'gender': gender,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'goal': goal,
        'activity_level': activityLevel,
        'target_weight': targetWeight,
        'weekly_workouts': weeklyWorkouts,
        'completed': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      // Also update profiles + create user_goals
      await supabase.from('profiles').update({
        'name': name.isEmpty ? null : name,
        'age': age,
        'gender': gender,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'fitness_goal': goal,
      }).eq('id', currentUserId!);

      // Calculate TDEE-based calorie goal
      // Using Mifflin-St Jeor equation (more accurate modern standard)
      double bmr = gender == 'male'
          ? (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5
          : (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
      
      final multipliers = {
        'sedentary': 1.2,
        'lightly_active': 1.375,
        'moderately_active': 1.55,
        'very_active': 1.725,
        'extra_active': 1.9
      };
      int tdee = (bmr * (multipliers[activityLevel] ?? 1.55)).round();
      if (goal == 'weight_loss') tdee -= 500;
      if (goal == 'muscle_gain') tdee += 300;
      
      // Ensure a safe minimum for daily calories
      if (tdee < 1200) tdee = 1200;

      // Calculate macros such that their total calories exactly match the TDEE
      // Protein: ~2g per kg of body weight
      int proteinGrams = (weightKg * 2.0).round();
      // Fat: 25% of total calories
      int fatGrams = ((tdee * 0.25) / 9).round();
      
      // Carbs: The remaining calories split into grams
      int proteinCals = proteinGrams * 4;
      int fatCals = fatGrams * 9;
      int remainingCals = tdee - (proteinCals + fatCals);
      int carbsGrams = (remainingCals / 4).round();
      
      if (carbsGrams < 0) {
        carbsGrams = 0; // Fallback in case goal was extremely aggressive
      }

      await supabase.from('user_goals').upsert({
        'user_id': currentUserId,
        'daily_calories': tdee,
        'daily_protein_g': proteinGrams,
        'daily_carbs_g': carbsGrams,
        'daily_fat_g': fatGrams,
        'target_weight_kg': targetWeight,
        'weekly_workouts': weeklyWorkouts,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      // Save initial body measurement
      await supabase.from('body_measurements').upsert({
        'user_id': currentUserId,
        'weight_kg': weightKg,
        'measured_date': DateTime.now().toIso8601String().substring(0, 10),
      }, onConflict: 'user_id,measured_date');
    } on PostgrestException catch (e) {
      print('Supabase error saving onboarding: ${e.message} | code: ${e.code}');
    } catch (e) {
      print('Error saving onboarding: $e');
    }
  }
}
