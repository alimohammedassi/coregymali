import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/additional_nutrients.dart';
import 'nutrition_service.dart';
import 'streak_service.dart';
import 'supabase_client.dart';

/// One food row of an assigned meal, exactly as the enrollment materialized
/// it: the snapshot values (name/serving/macros) are frozen at assignment
/// time and must always be shown as-is, while `current_*` carries what the
/// client actually changed it to (null = untouched).
class AssignedNutritionFood {
  final String id;

  /// The library food this row snapshot came from (assignment rows always
  /// reference real `foods` ids — used when logging the meal as eaten).
  final String foodId;
  final String foodName;

  /// Snapshot serving basis from assignment time — never re-read from the
  /// live foods table, so later library edits can't rewrite history.
  final String servingUnit;
  final double servingSize;

  final double originalQuantity;
  final double originalCalories;
  final double originalProteinG;
  final double originalCarbsG;
  final double originalFatG;

  final double? currentQuantity;
  final double? currentCalories;
  final double? currentProteinG;
  final double? currentCarbsG;
  final double? currentFatG;

  /// Set only on substitution — resolved from the foods table at read time.
  final String? currentFoodName;
  final String? currentFoodId;
  final String? changeType;
  final int orderIndex;

  const AssignedNutritionFood({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.servingUnit,
    required this.servingSize,
    required this.originalQuantity,
    required this.originalCalories,
    required this.originalProteinG,
    required this.originalCarbsG,
    required this.originalFatG,
    this.currentQuantity,
    this.currentCalories,
    this.currentProteinG,
    this.currentCarbsG,
    this.currentFatG,
    this.currentFoodName,
    this.currentFoodId,
    this.changeType,
    required this.orderIndex,
  });

  bool get isChanged => (changeType ?? '').isNotEmpty;

  /// The client's current truth; snapshot originals when untouched.
  double get effectiveQuantity => currentQuantity ?? originalQuantity;
  double get effectiveCalories => currentCalories ?? originalCalories;
  double get effectiveProteinG => currentProteinG ?? originalProteinG;
  double get effectiveCarbsG => currentCarbsG ?? originalCarbsG;
  double get effectiveFatG => currentFatG ?? originalFatG;

  /// What the row shows as its name: the substituted food when the client
  /// swapped it, otherwise the frozen snapshot name.
  String get displayName => (currentFoodName ?? foodName).trim().isEmpty
      ? foodName
      : (currentFoodName ?? foodName);

  factory AssignedNutritionFood.fromMap(Map<String, dynamic> map) {
    final currentFood = map['foods'] as Map<String, dynamic>?;
    return AssignedNutritionFood(
      id: map['id'].toString(),
      foodId: (map['food_id'] ?? '').toString(),
      foodName: (map['food_name'] as String?) ?? '',
      servingUnit: (map['serving_unit'] as String?) ?? 'g',
      servingSize: (map['serving_size'] as num?)?.toDouble() ?? 100,
      originalQuantity: (map['original_quantity'] as num?)?.toDouble() ?? 0,
      originalCalories: (map['original_calories'] as num?)?.toDouble() ?? 0,
      originalProteinG: (map['original_protein_g'] as num?)?.toDouble() ?? 0,
      originalCarbsG: (map['original_carbs_g'] as num?)?.toDouble() ?? 0,
      originalFatG: (map['original_fat_g'] as num?)?.toDouble() ?? 0,
      currentQuantity: (map['current_quantity'] as num?)?.toDouble(),
      currentCalories: (map['current_calories'] as num?)?.toDouble(),
      currentProteinG: (map['current_protein_g'] as num?)?.toDouble(),
      currentCarbsG: (map['current_carbs_g'] as num?)?.toDouble(),
      currentFatG: (map['current_fat_g'] as num?)?.toDouble(),
      currentFoodName: currentFood?['name'] as String?,
      currentFoodId: (map['current_food_id'] as String?),
      changeType: map['change_type'] as String?,
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One assigned meal, with its food rows in plan order. Meals are fetched
/// per scheduled date — today's meals win; when today has none the nearest
/// upcoming day is carried so the coach's work stays visible.
class AssignedNutritionMeal {
  final String id;
  final String mealName;
  final String status; // 'assigned' | 'completed' | 'skipped'
  final DateTime? completedAt;
  final DateTime scheduledDate;
  final int? weekNumber;
  final int orderIndex;
  final List<AssignedNutritionFood> foods;

  const AssignedNutritionMeal({
    required this.id,
    required this.mealName,
    required this.status,
    this.completedAt,
    required this.scheduledDate,
    this.weekNumber,
    required this.orderIndex,
    required this.foods,
  });

  double get totalCalories =>
      foods.fold(0, (sum, f) => sum + f.effectiveCalories);
  double get totalProteinG =>
      foods.fold(0, (sum, f) => sum + f.effectiveProteinG);
  double get totalCarbsG =>
      foods.fold(0, (sum, f) => sum + f.effectiveCarbsG);
  double get totalFatG => foods.fold(0, (sum, f) => sum + f.effectiveFatG);

  AssignedNutritionMeal copyWith({String? status, DateTime? completedAt}) =>
      AssignedNutritionMeal(
        id: id,
        mealName: mealName,
        status: status ?? this.status,
        completedAt: completedAt ?? this.completedAt,
        scheduledDate: scheduledDate,
        weekNumber: weekNumber,
        orderIndex: orderIndex,
        foods: foods,
      );

  factory AssignedNutritionMeal.fromMap(Map<String, dynamic> map) {
    final rawFoods = (map['nutrition_assignment_foods'] as List?) ?? const [];
    final foods = rawFoods
        .whereType<Map<String, dynamic>>()
        .map(AssignedNutritionFood.fromMap)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return AssignedNutritionMeal(
      id: map['id'].toString(),
      mealName: (map['meal_name'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'assigned',
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.tryParse(map['completed_at'] as String),
      scheduledDate:
          DateTime.tryParse((map['scheduled_date'] as String?) ?? '') ??
          DateTime.now(),
      weekNumber: (map['week_number'] as num?)?.toInt(),
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
      foods: foods,
    );
  }
}

/// The client's active nutrition enrollment with its assigned meals —
/// the read model behind the assigned-workout screen's nutrition tab.
class AssignedNutritionPlan {
  final String enrollmentId;
  final String coachId;
  final String programName;
  final String? programDescription;
  final DateTime startDate;
  final int durationWeeks;
  final int currentWeek;
  final List<AssignedNutritionMeal> meals;

  /// The day [meals] belong to: today, or the nearest upcoming scheduled
  /// date when today has none ([isPreview] flags that case so the UI can
  /// label it instead of presenting future meals as today's).
  final DateTime displayDate;
  final bool isPreview;

  const AssignedNutritionPlan({
    required this.enrollmentId,
    required this.coachId,
    required this.programName,
    this.programDescription,
    required this.startDate,
    required this.durationWeeks,
    required this.currentWeek,
    required this.meals,
    required this.displayDate,
    required this.isPreview,
  });

  int get mealCount => meals.length;

  /// A new plan with [mealId] flipped to 'completed' in place — the UI's
  /// immediate truth between the write landing and the next refetch.
  AssignedNutritionPlan withMealCompleted(String mealId) =>
      AssignedNutritionPlan(
        enrollmentId: enrollmentId,
        coachId: coachId,
        programName: programName,
        programDescription: programDescription,
        startDate: startDate,
        durationWeeks: durationWeeks,
        currentWeek: currentWeek,
        meals: [
          for (final m in meals)
            if (m.id == mealId)
              m.copyWith(
                status: 'completed',
                completedAt: m.completedAt ?? DateTime.now(),
              )
            else
              m,
        ],
        displayDate: displayDate,
        isPreview: isPreview,
      );
  int get foodCount => meals.fold(0, (sum, m) => sum + m.foods.length);
  double get totalCalories =>
      meals.fold(0, (sum, m) => sum + m.totalCalories);
  double get totalProteinG =>
      meals.fold(0, (sum, m) => sum + m.totalProteinG);
  double get totalCarbsG => meals.fold(0, (sum, m) => sum + m.totalCarbsG);
  double get totalFatG => meals.fold(0, (sum, m) => sum + m.totalFatG);
}

/// Outcome of the client marking a meal as eaten.
enum MealCompleteResult {
  /// Assignment flipped to 'completed' and the food rows were logged.
  completed,

  /// The assignment was already completed — nothing written, UI just syncs.
  alreadyCompleted,

  /// The status flip or the whole logging path failed.
  failed,
}

/// Client read side of the dashboard's nutrition system: the active
/// enrollment plus today's materialized assignments with their snapshot
/// food rows. Every read is client-scoped (RLS enforces the same); a
/// missing migration or any failure degrades to "no plan", never an error
/// surface — same contract as [AssignedWorkoutService].
class AssignedNutritionService {
  /// PostgREST "could not find the table" — pre-migration deployments.
  static const _missingTable = 'PGRST205';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<bool> _hasActiveSubscription() async {
    if (currentUserId == null) return false;
    try {
      final row = await supabase
          .from('subscriptions')
          .select('id')
          .eq('client_id', currentUserId!)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();
      return row != null;
    } on PostgrestException catch (e) {
      if (e.code == _missingTable) return false;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<AssignedNutritionPlan?> fetchTodayPlan() async {
    if (currentUserId == null) return null;
    // Gate by active subscription — cancelled = no nutrition plan (all coach data disappears).
    if (!await _hasActiveSubscription()) return null;
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    try {
      final enrollments = await supabase
          .from('client_nutrition_enrollments')
          .select(
            'id, coach_id, start_date, duration_weeks, '
            'nutrition_programs(name, description)',
          )
          .eq('client_id', currentUserId!)
          .eq('status', 'active')
          .order('start_date', ascending: false)
          .limit(1);
      if (enrollments.isEmpty) return null;
      final e = enrollments.first;
      final start = DateTime.tryParse((e['start_date'] as String?) ?? '');
      final weeks = (e['duration_weeks'] as num?)?.toInt() ?? 0;
      if (start == null || weeks <= 0) return null;

      // 'active' can outlive its own window (coach hasn't closed it) —
      // only treat the enrollment as today's plan while inside it.
      final startDay = DateTime(start.year, start.month, start.day);
      final todayDay = DateTime(now.year, now.month, now.day);
      final endDay = startDay.add(Duration(days: weeks * 7));
      if (todayDay.isBefore(startDay) || !todayDay.isBefore(endDay)) {
        return null;
      }
      final currentWeek = (todayDay.difference(startDay).inDays ~/ 7) + 1;

      // One fetch covers today AND the nearest upcoming day: today's meals
      // win outright; otherwise the earliest later date is shown as a
      // preview, so a Monday-only plan stays visible on a Wednesday.
      final rows = await supabase
          .from('nutrition_assignments')
          .select(
            'id, meal_name, status, completed_at, scheduled_date, '
            'order_index, week_number, '
            'nutrition_assignment_foods(id, food_id, current_food_id, '
            'food_name, serving_unit, serving_size, original_quantity, '
            'original_calories, original_protein_g, original_carbs_g, '
            'original_fat_g, current_quantity, current_calories, '
            'current_protein_g, current_carbs_g, current_fat_g, '
            'change_type, order_index, '
            'foods!nutrition_assignment_foods_current_food_id_fkey(name))',
          )
          .eq('enrollment_id', e['id'].toString())
          .gte('scheduled_date', today)
          .order('scheduled_date')
          .order('order_index');

      final all = rows
          .whereType<Map<String, dynamic>>()
          .map(AssignedNutritionMeal.fromMap)
          .toList()
        ..sort((a, b) {
          final byDate = a.scheduledDate.compareTo(b.scheduledDate);
          return byDate != 0 ? byDate : a.orderIndex.compareTo(b.orderIndex);
        });

      List<AssignedNutritionMeal> meals;
      DateTime displayDate;
      bool isPreview;
      final todayMeals = all
          .where((m) => _sameDay(m.scheduledDate, todayDay))
          .toList();
      if (todayMeals.isNotEmpty) {
        meals = todayMeals;
        displayDate = todayDay;
        isPreview = false;
      } else if (all.isNotEmpty) {
        final nextDay = _dateOnly(all.first.scheduledDate);
        meals = all.where((m) => _dateOnly(m.scheduledDate) == nextDay).toList();
        displayDate = nextDay;
        isPreview = true;
      } else {
        meals = <AssignedNutritionMeal>[];
        displayDate = todayDay;
        isPreview = false;
      }

      final program = e['nutrition_programs'] as Map<String, dynamic>?;
      return AssignedNutritionPlan(
        enrollmentId: e['id'].toString(),
        coachId: (e['coach_id'] ?? '').toString(),
        programName: (program?['name'] as String?) ?? '',
        programDescription: program?['description'] as String?,
        startDate: startDay,
        durationWeeks: weeks,
        currentWeek: currentWeek.clamp(1, weeks),
        meals: meals,
        displayDate: displayDate,
        isPreview: isPreview,
      );
    } on PostgrestException catch (e) {
      if (e.code != _missingTable) {
        debugPrint(
          'Supabase error fetching nutrition plan: '
          '${e.message} | code: ${e.code}',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching nutrition plan: $e');
      return null;
    }
  }

  /// The client ate this meal. Flips the assignment to 'completed' with an
  /// atomic transition (only from 'assigned', client-scoped — so a double
  /// tap can never double-log), then writes every food row into
  /// `nutrition_logs` with the client's current (or snapshot) values so the
  /// meal's calories land in today's daily_summary through the exact same
  /// funnel as manual food logging — home's calories card, the nutrition
  /// page's today list and the streak all pick it up from there. A
  /// 'completion' record is added to nutrition_change_log (best-effort) so
  /// the coach's dashboard history sees it.
  Future<MealCompleteResult> markMealCompleted(
    AssignedNutritionPlan plan,
    AssignedNutritionMeal meal,
  ) async {
    final uid = currentUserId;
    if (uid == null) return MealCompleteResult.failed;
    try {
      final flipped = await supabase
          .from('nutrition_assignments')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', meal.id)
          .eq('client_id', uid)
          .eq('status', 'assigned')
          .select('id');
      if ((flipped as List).isEmpty) {
        return MealCompleteResult.alreadyCompleted;
      }
    } on PostgrestException catch (e) {
      debugPrint(
        'Supabase error completing meal: ${e.message} | code: ${e.code}',
      );
      return MealCompleteResult.failed;
    } catch (e) {
      debugPrint('Error completing meal: $e');
      return MealCompleteResult.failed;
    }

    final nutrition = NutritionService();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Micro-nutrients are NOT part of the assignment snapshot — the plan rows
    // carry macros only. Pull them from the live foods catalog for the exact
    // rows being logged (substituted foods included) and scale each bundle by
    // the same ratio the logged calories represent against the catalog row,
    // so client-edited quantities and substitutions stay proportional.
    final catalogRows = <String, Map<String, dynamic>>{};
    final foodIds = meal.foods
        .map((f) => f.currentFoodId ?? f.foodId)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (foodIds.isNotEmpty) {
      try {
        final rows = await supabase
            .from('foods')
            .select('id, calories, fiber_g, sugars_g, sodium_mg, '
                'potassium_mg, calcium_mg, iron_mg, cholesterol_mg, caffeine_mg')
            .inFilter('id', foodIds.toList());
        for (final row in rows) {
          catalogRows[row['id'].toString()] = row;
        }
      } on PostgrestException catch (e) {
        debugPrint('Micro-nutrient lookup for logged meal failed: ${e.code}');
      } catch (e) {
        debugPrint('Micro-nutrient lookup for logged meal failed: $e');
      }
    }

    AdditionalNutrients? extrasFor(AssignedNutritionFood f) {
      final row = catalogRows[f.currentFoodId ?? f.foodId];
      if (row == null) return null;
      final bundle = AdditionalNutrients.fromFoodRow(row);
      if (!bundle.hasAny) return null;
      final rowKcal = (row['calories'] as num?)?.toDouble() ?? 0;
      final factor = rowKcal > 0 && f.effectiveCalories > 0
          ? f.effectiveCalories / rowKcal
          : f.effectiveQuantity;
      return bundle.scaledBy(factor);
    }

    for (final f in meal.foods) {
      try {
        await nutrition.insertNutritionLogRow({
          'user_id': uid,
          'food_id': f.currentFoodId ?? f.foodId,
          'food_name': f.displayName,
          'meal_type': _mealTypeFor(meal.mealName),
          'quantity': f.effectiveQuantity,
          'serving_unit': f.servingUnit,
          'calories': f.effectiveCalories,
          'protein_g': f.effectiveProteinG,
          'carbs_g': f.effectiveCarbsG,
          'fat_g': f.effectiveFatG,
          'logged_date': today,
        }, extrasFor(f));
      } on PostgrestException catch (e) {
        debugPrint(
          'Supabase error logging eaten food "${f.displayName}": '
          '${e.message} | code: ${e.code}',
        );
      } catch (e) {
        debugPrint('Error logging eaten food "${f.displayName}": $e');
      }
    }

    await nutrition.syncDailySummary(today);
    StreakService().recordActivity('nutrition');
    unawaited(nutrition.maybeSendCalorieAlert());

    try {
      await supabase.from('nutrition_change_log').insert({
        'assignment_id': meal.id,
        'enrollment_id': plan.enrollmentId,
        'coach_id': plan.coachId,
        'client_id': uid,
        'plan_date': meal.scheduledDate.toIso8601String().substring(0, 10),
        'meal_name': meal.mealName,
        'change_type': 'completion',
        'source': 'app',
      });
    } on PostgrestException catch (e) {
      debugPrint(
        'Supabase error writing completion change-log: '
        '${e.message} | code: ${e.code}',
      );
    } catch (e) {
      debugPrint('Error writing completion change-log: $e');
    }
    return MealCompleteResult.completed;
  }

  /// The `nutrition_logs.meal_type` CHECK only knows
  /// breakfast/lunch/dinner/snack — assigned meal names are free-form
  /// ("Meal 2", Arabic names), so map by keyword and default to snack.
  static String _mealTypeFor(String mealName) {
    final n = mealName.trim().toLowerCase();
    if (n.contains('breakfast') || n.contains('فطار')) return 'breakfast';
    if (n.contains('lunch') || n.contains('غدا') || n.contains('غداء')) {
      return 'lunch';
    }
    if (n.contains('dinner') || n.contains('عشا') || n.contains('عشاء')) {
      return 'dinner';
    }
    return 'snack';
  }
}
