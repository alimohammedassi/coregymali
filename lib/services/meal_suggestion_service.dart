import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meal_suggestion.dart';

/// Why a suggestion attempt failed — drives the card's error copy.
enum MealSuggestionError {
  /// No calorie room left today (or no goals set) — nothing to size.
  noRemaining,

  /// The model(s) could not produce a catalog-valid meal within ±10%.
  noMatch,

  /// OpenRouter/model provider unavailable after all retries.
  unavailable,

  network,

  unknown,
}

class MealSuggestionException implements Exception {
  final MealSuggestionError type;
  const MealSuggestionException(this.type);
}

/// Calls the `suggest-meal` Edge Function (standard Supabase JWT auth, no
/// request body) and returns the server-validated suggestion.
class MealSuggestionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// [mealType] / [style] are the sheet's optional preferences.
  /// [calorieFraction] is the share of the remaining budget the meal should
  /// cover (owner v2.1 calorie picker). [targetCalories] is the NEW 2026-09-24
  /// finish field: user-typed kcal that overrides fraction/remaining entirely.
  /// The edge function treats absent values as "no hint" — caller supplies
  /// EITHER targetCalories OR calorieFraction, targetCalories wins.
  Future<MealSuggestion> suggestMeal({
    String? mealType,
    String? style,
    double? calorieFraction,
    int? targetCalories,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'suggest-meal',
        body: {
          if (mealType != null) 'meal_type': mealType,
          if (style != null) 'style': style,
          if (calorieFraction != null) 'calorie_fraction': calorieFraction,
          if (targetCalories != null) 'target_calories': targetCalories,
        },
      );
      return MealSuggestion.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on FunctionException catch (e) {
      debugPrint('❌ suggest-meal failed [${e.status}]: ${e.reasonPhrase}');
      // The error payload rides in `details` for non-2xx responses.
      String? code;
      final details = e.details;
      if (details is Map) {
        code = details['error']?.toString();
      } else if (details is String && details.isNotEmpty) {
        try {
          code = (jsonDecode(details) as Map)['error']?.toString();
        } catch (_) {}
      }
      throw MealSuggestionException(switch (code) {
        'no_remaining' => MealSuggestionError.noRemaining,
        'no_match' => MealSuggestionError.noMatch,
        'ai_unavailable' => MealSuggestionError.unavailable,
        _ => MealSuggestionError.unknown,
      });
    } on SocketException catch (_) {
      throw const MealSuggestionException(MealSuggestionError.network);
    } catch (e) {
      debugPrint('❌ MealSuggestionService.suggestMeal: $e');
      throw const MealSuggestionException(MealSuggestionError.unknown);
    }
  }
}
