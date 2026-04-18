import 'coach_entity.dart';

// ── Lightweight data holders for client dashboard ──
// These mirror the Supabase table rows; they are NOT re-using
// separate feature models to avoid cross-feature coupling.

class NutritionLog {
  final String id;
  final String userId;
  final String foodName;
  final String mealType;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final DateTime loggedDate;

  const NutritionLog({
    required this.id,
    required this.userId,
    required this.foodName,
    required this.mealType,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.loggedDate,
  });

  factory NutritionLog.fromJson(Map<String, dynamic> json) => NutritionLog(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        foodName: json['food_name'] ?? '',
        mealType: json['meal_type'] ?? '',
        calories: (json['calories'] ?? 0).toDouble(),
        proteinG: (json['protein_g'] ?? 0).toDouble(),
        carbsG: (json['carbs_g'] ?? 0).toDouble(),
        fatG: (json['fat_g'] ?? 0).toDouble(),
        loggedDate: DateTime.tryParse(json['logged_date'] ?? '') ??
            DateTime.now(),
      );
}

class WorkoutSession {
  final String id;
  final String userId;
  final String muscleGroup;
  final String sessionName;
  final int durationMin;
  final DateTime sessionDate;

  const WorkoutSession({
    required this.id,
    required this.userId,
    required this.muscleGroup,
    required this.sessionName,
    required this.durationMin,
    required this.sessionDate,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        muscleGroup: json['muscle_group'] ?? '',
        sessionName: json['session_name'] ?? '',
        durationMin: json['duration_min'] ?? 0,
        sessionDate: DateTime.tryParse(json['session_date'] ?? '') ??
            DateTime.now(),
      );
}

class BodyMeasurement {
  final String id;
  final String userId;
  final double? weightKg;
  final double? bodyFatPct;
  final double? muscleMass;
  final DateTime measuredDate;

  const BodyMeasurement({
    required this.id,
    required this.userId,
    this.weightKg,
    this.bodyFatPct,
    this.muscleMass,
    required this.measuredDate,
  });

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) =>
      BodyMeasurement(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
        bodyFatPct: (json['body_fat_pct'] as num?)?.toDouble(),
        muscleMass: (json['muscle_mass'] as num?)?.toDouble(),
        measuredDate: DateTime.tryParse(json['measured_date'] ?? '') ??
            DateTime.now(),
      );
}

class DailySummary {
  final String id;
  final String userId;
  final DateTime summaryDate;
  final double caloriesConsumed;
  final double caloriesBurned;
  final bool workoutDone;
  final int steps;

  const DailySummary({
    required this.id,
    required this.userId,
    required this.summaryDate,
    required this.caloriesConsumed,
    required this.caloriesBurned,
    required this.workoutDone,
    required this.steps,
  });

  factory DailySummary.fromJson(Map<String, dynamic> json) => DailySummary(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        summaryDate: DateTime.tryParse(json['summary_date'] ?? '') ??
            DateTime.now(),
        caloriesConsumed: (json['calories_consumed'] ?? 0).toDouble(),
        caloriesBurned: (json['calories_burned'] ?? 0).toDouble(),
        workoutDone: json['workout_done'] ?? false,
        steps: json['steps'] ?? 0,
      );
}

class ClientFullData {
  final CoachProfile profile; // name + avatarUrl from profiles table
  final List<NutritionLog> nutritionLogs;
  final List<WorkoutSession> workoutSessions;
  final List<BodyMeasurement> bodyMeasurements;
  final List<DailySummary> dailySummaries;

  const ClientFullData({
    required this.profile,
    required this.nutritionLogs,
    required this.workoutSessions,
    required this.bodyMeasurements,
    required this.dailySummaries,
  });
}
