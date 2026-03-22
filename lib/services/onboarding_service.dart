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
    } catch (_) { return false; }
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
    double bmr = gender == 'male'
        ? 88.36 + (13.4 * weightKg) + (4.8 * heightCm) - (5.7 * age)
        : 447.6 + (9.2 * weightKg) + (3.1 * heightCm) - (4.3 * age);
    final multipliers = {
      'sedentary': 1.2, 'lightly_active': 1.375,
      'moderately_active': 1.55, 'very_active': 1.725,
      'extra_active': 1.9
    };
    int tdee = (bmr * (multipliers[activityLevel] ?? 1.55)).round();
    if (goal == 'weight_loss') tdee -= 500;
    if (goal == 'muscle_gain') tdee += 300;

    await supabase.from('user_goals').upsert({
      'user_id': currentUserId,
      'daily_calories': tdee,
      'daily_protein_g': (weightKg * 2.2).round(),
      'daily_carbs_g': ((tdee * 0.45) / 4).round(),
      'daily_fat_g': ((tdee * 0.25) / 9).round(),
      'target_weight_kg': targetWeight,
      'weekly_workouts': weeklyWorkouts,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');

    // Save initial body measurement
    await supabase.from('body_measurements').upsert({
      'user_id': currentUserId,
      'weight_kg': weightKg,
      'measured_date': DateTime.now().toIso8601String().substring(0,10),
    }, onConflict: 'user_id,measured_date');
  }
}
