import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

/// The app's single calorie-estimation formula — used here when persisting
/// user_goals AND by the onboarding flow's live previews, so the number the
/// user sees is always the number that gets saved.
///
/// Mifflin-St Jeor by default; switches to Katch-McArdle (more precise —
/// BMR from lean body mass) when the user knows their body-fat %. [pace]
/// scales the goal adjustment: slow/standard/fast → ±250/500/750 kcal for
/// weight loss, +150/300/450 for muscle gain (standard matches the
/// historical fixed values).
({int bmr, int tdee, int adjustment, int daily}) estimateCalorieBreakdown({
  required String gender,
  required int age,
  required double heightCm,
  required double weightKg,
  required String goal,
  required String activityLevel,
  double? bodyFatPct,
  String pace = 'standard',
}) {
  final bf = (bodyFatPct != null && bodyFatPct >= 4 && bodyFatPct <= 60)
      ? bodyFatPct
      : null;
  final int bmr = bf != null
      ? // Katch-McArdle: BMR from lean body mass.
        (370 + 21.6 * weightKg * (1 - bf / 100)).round()
      : (gender == 'male'
            ? (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5
            : (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161)
          .round();

  const multipliers = {
    'sedentary': 1.2,
    'lightly_active': 1.375,
    'moderately_active': 1.55,
    'very_active': 1.725,
    'extra_active': 1.9,
  };
  final tdee = (bmr * (multipliers[activityLevel] ?? 1.55)).round();

  int adjustment = 0;
  if (goal == 'weight_loss') {
    adjustment = switch (pace) {
      'slow' => -250,
      'fast' => -750,
      _ => -500,
    };
  } else if (goal == 'muscle_gain') {
    adjustment = switch (pace) {
      'slow' => 150,
      'fast' => 450,
      _ => 300,
    };
  }

  int daily = tdee + adjustment;
  // Ensure a safe minimum for daily calories
  if (daily < 1200) daily = 1200;
  return (bmr: bmr, tdee: tdee, adjustment: adjustment, daily: daily);
}

/// Macro split stored alongside the calorie goal: protein ~2 g/kg, fat 25%
/// of calories, carbs fill the remainder. Returns grams.
({int proteinG, int carbsG, int fatG}) computeGoalMacros({
  required int dailyCalories,
  required double weightKg,
}) {
  final proteinGrams = (weightKg * 2.0).round();
  final fatGrams = ((dailyCalories * 0.25) / 9).round();
  final remaining = dailyCalories - (proteinGrams * 4 + fatGrams * 9);
  var carbsGrams = (remaining / 4).round();
  if (carbsGrams < 0) carbsGrams = 0; // Aggressive-goal fallback
  return (proteinG: proteinGrams, carbsG: carbsGrams, fatG: fatGrams);
}

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
    // Optional: the profile name is captured once at sign-up (auth form or
    // the Google/Apple account). Only overwrite it when onboarding actually
    // collected one — the old `name.isEmpty ? null : name` write used to
    // NULL the profile name for everyone who skipped that field.
    String? name,
    required int age,
    required String gender,
    required double heightCm,
    required double weightKg,
    required String goal,
    required String activityLevel,
    required double targetWeight,
    required int weeklyWorkouts,
    // Calc-only inputs — they shape daily_calories but aren't persisted as
    // columns (no schema change): body fat enables the Katch-McArdle BMR,
    // pace scales the goal adjustment.
    double? bodyFatPct,
    String pace = 'standard',
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
      final profileUpdate = <String, dynamic>{
        'age': age,
        'gender': gender,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'fitness_goal': goal,
      };
      final trimmedName = name?.trim() ?? '';
      if (trimmedName.isNotEmpty) profileUpdate['name'] = trimmedName;
      await supabase
          .from('profiles')
          .update(profileUpdate)
          .eq('id', currentUserId!);

      // TDEE-based calorie goal — the shared formula above (Mifflin-St Jeor,
      // or Katch-McArdle when body fat is known), adjusted by goal + pace.
      final tdee = estimateCalorieBreakdown(
        gender: gender,
        age: age,
        heightCm: heightCm,
        weightKg: weightKg,
        goal: goal,
        activityLevel: activityLevel,
        bodyFatPct: bodyFatPct,
        pace: pace,
      ).daily;

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
