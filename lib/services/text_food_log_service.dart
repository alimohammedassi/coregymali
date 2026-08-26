import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/text_food_log_result.dart';
import 'nutrition_service.dart';
import 'streak_service.dart';
import 'supabase_client.dart';

class TextFoodLogService {
  final StreakService _streakService = StreakService();
  final NutritionService _nutritionService = NutritionService();

  /// Sends a free-text meal description to the stateless `log-food-text`
  /// Edge Function, which extracts structured food items via Gemini.
  ///
  /// A non-food description is returned as [TextLogException]
  /// ([TextLogErrorType.notFood]) — the UI treats it as an error card, not
  /// a result (same contract as the voice logger).
  Future<TextFoodLogResult> analyze(String text) async {
    if (currentUserId == null) {
      throw TextLogException.fromType(TextLogErrorType.unauthorized);
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw TextLogException.fromType(TextLogErrorType.analysisFailed);
    }

    final Map<String, dynamic> data;
    try {
      final response = await supabase.functions.invoke(
        'log-food-text',
        body: {'text': trimmed},
      );
      data = Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } on SocketException catch (_) {
      throw TextLogException.fromType(TextLogErrorType.network);
    } catch (e) {
      debugPrint('❌ TextFoodLogService.analyze: $e');
      throw TextLogException.fromType(TextLogErrorType.unknown);
    }

    // Distinct error payloads from the function.
    if (data['error'] != null) {
      debugPrint('❌ log-food-text payload error: ${data['error']}');
      throw TextLogException.fromType(TextLogErrorType.analysisFailed);
    }

    final result = TextFoodLogResult.fromJson(data);
    if (!result.isFood) {
      throw TextLogException.fromType(TextLogErrorType.notFood);
    }
    // is_food=true but nothing extractable — never show an empty confirmation.
    if (result.items.isEmpty) {
      throw TextLogException.fromType(TextLogErrorType.analysisFailed);
    }
    return result;
  }

  /// Saves confirmed items into today's `nutrition_logs`, one row per item,
  /// scaled to each item's edited weight in [weightsG] (parallel to [items]).
  ///
  /// Same column mapping and daily-summary/streak contract as every other
  /// logger (`saveScannedItems`, `BarcodeLookupService.saveToLog`). Returns
  /// true when at least one row landed.
  Future<bool> saveToLog({
    required List<TextFoodLogItem> items,
    required List<double> weightsG,
    String mealType = 'breakfast',
  }) async {
    final userId = currentUserId;
    if (userId == null ||
        items.isEmpty ||
        weightsG.length != items.length) {
      return false;
    }

    final d = DateTime.now().toIso8601String().substring(0, 10);
    var savedCount = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final w = weightsG[i].clamp(10.0, 5000.0);
      try {
        final inserted = await supabase
            .from('nutrition_logs')
            .insert({
              'user_id': userId,
              'food_name': item.name,
              'meal_type': mealType,
              'quantity': w,
              'serving_unit': 'g',
              'calories': item.caloriesFor(w),
              'protein_g': item.proteinFor(w),
              'carbs_g': item.carbsFor(w),
              'fat_g': item.fatFor(w),
              'logged_date': d,
            })
            .select('id')
            .single();

        final logId = inserted['id']?.toString();
        debugPrint('✅ text item "${item.name}" → nutrition_log $logId');
        savedCount++;
      } on PostgrestException catch (e) {
        debugPrint(
            '❌ saveToLog [${e.code}]: ${e.message} — item "${item.name}" skipped');
      } catch (e, st) {
        debugPrint('❌ Error saving text item "${item.name}": $e\n$st');
      }
    }

    if (savedCount > 0) {
      // Keep daily_summary in sync so the Nutrition tab / home ring reflect
      // the save immediately (same contract as every other logger).
      await _nutritionService.syncDailySummary(d);

      // Text log → count today as active for the streak.
      _streakService.recordActivity('nutrition');

      debugPrint('✅ saved $savedCount/${items.length} text items for $d');
      return true;
    }
    return false;
  }

  TextLogException _mapFunctionException(FunctionException e) {
    debugPrint('❌ log-food-text failed [${e.status}]: ${e.reasonPhrase}');

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

    switch (code) {
      case 'analysis_failed':
        return TextLogException.fromType(TextLogErrorType.analysisFailed);
      case 'unauthorized':
        return TextLogException.fromType(TextLogErrorType.unauthorized);
      case 'bad_request':
        return TextLogException.fromType(TextLogErrorType.unknown);
    }

    if (e.status == 401) {
      return TextLogException.fromType(TextLogErrorType.unauthorized);
    }
    if (e.status == 0) {
      return TextLogException.fromType(TextLogErrorType.network);
    }
    return TextLogException.fromType(TextLogErrorType.analysisFailed);
  }
}
