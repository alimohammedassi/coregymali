import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/barcode_product_result.dart';
import 'streak_service.dart';
import 'supabase_client.dart';

class BarcodeLookupService {
  final StreakService _streakService = StreakService();
  /// Looks up a product via the `lookup-barcode` Edge Function.
  ///
  /// Three-tier lookup happens server-side (shared cache → Open Food Facts →
  /// Gemini text estimate) so most scans never consume any Gemini quota.
  ///
  /// A "not found" response (`needs_name_hint: true`) is returned as a normal
  /// result — the UI treats it as an input state, not an error.
  Future<BarcodeProductResult> lookup(
    String barcode, {
    String? productNameHint,
  }) async {
    if (currentUserId == null) {
      throw BarcodeLookupException.fromType(BarcodeLookupErrorType.unauthorized);
    }

    final Map<String, dynamic> data;
    try {
      final response = await supabase.functions.invoke(
        'lookup-barcode',
        body: {
          'barcode': barcode,
          if (productNameHint != null) 'productNameHint': productNameHint,
        },
      );
      data = Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } on SocketException catch (_) {
      throw BarcodeLookupException.fromType(BarcodeLookupErrorType.network);
    } catch (e) {
      debugPrint('❌ BarcodeLookupService.lookup: $e');
      throw BarcodeLookupException.fromType(BarcodeLookupErrorType.unknown);
    }

    // Distinct error payloads from the function.
    if (data['error'] != null) {
      throw BarcodeLookupException.fromType(_errorFor(data['error'].toString()));
    }

    final result = Map<String, dynamic>.from(data['result'] as Map? ?? {});
    final product = BarcodeProductResult.fromJson(result);

    if (product.needsNameHint && product.barcode.isEmpty) {
      throw BarcodeLookupException.fromType(BarcodeLookupErrorType.invalidRequest);
    }
    return product;
  }

  /// Saves the scanned product into today's `nutrition_logs` (same column
  /// mapping as `NutritionService.saveScannedItems`) and records a
  /// `barcode_scan_history` row linking back to the new log.
  ///
  /// Returns true when the nutrition log row was created.
  Future<bool> saveToLog({
    required BarcodeProductResult product,
    required double quantityG,
    String mealType = 'breakfast',
  }) async {
    final userId = currentUserId;
    if (userId == null || quantityG <= 0) return false;

    final d = DateTime.now().toIso8601String().substring(0, 10);
    final name = product.brand == null || product.brand!.isEmpty
        ? product.productName
        : '${product.productName} (${product.brand})';

    try {
      final inserted = await supabase
          .from('nutrition_logs')
          .insert({
            'user_id': userId,
            'food_name': name,
            'meal_type': mealType,
            'quantity': quantityG,
            'serving_unit': 'g',
            'calories': product.caloriesFor(quantityG),
            'protein_g': product.proteinFor(quantityG),
            'carbs_g': product.carbsFor(quantityG),
            'fat_g': product.fatFor(quantityG),
            'logged_date': d,
          })
          .select('id')
          .single();

      final logId = inserted['id']?.toString();
      debugPrint('✅ barcode "${product.barcode}" → nutrition_log $logId');

      // History is best-effort — never let it fail the save UX.
      try {
        await supabase.from('barcode_scan_history').insert({
          'user_id': userId,
          'barcode': product.barcode,
          'quantity_g': quantityG,
          if (logId != null && logId.isNotEmpty) 'nutrition_log_id': logId,
        });
      } catch (e) {
        debugPrint('⚠️ barcode_scan_history insert failed (log saved): $e');
      }

      // Barcode scan → count today as active for the streak.
      _streakService.recordActivity('nutrition');

      return true;
    } on PostgrestException catch (e) {
      debugPrint('❌ saveToLog [${e.code}]: ${e.message}');
      return false;
    } catch (e, st) {
      debugPrint('❌ Error saving barcode scan: $e\n$st');
      return false;
    }
  }

  BarcodeLookupErrorType _errorFor(String code) {
    switch (code) {
      case 'unauthorized':
        return BarcodeLookupErrorType.unauthorized;
      case 'invalid_request_body':
        return BarcodeLookupErrorType.invalidRequest;
      case 'upstream_unreachable':
        return BarcodeLookupErrorType.upstreamUnreachable;
      case 'analysis_failed':
        return BarcodeLookupErrorType.analysisFailed;
      default:
        return BarcodeLookupErrorType.serverError;
    }
  }

  BarcodeLookupException _mapFunctionException(FunctionException e) {
    debugPrint('❌ lookup-barcode failed [${e.status}]: ${e.reasonPhrase}');

    String? code;
    final details = e.details;
    if (details is Map) {
      code = details['error']?.toString();
    } else if (details is String && details.isNotEmpty) {
      try {
        code = (jsonDecode(details) as Map)['error']?.toString();
      } catch (_) {}
    }
    if (code != null) return BarcodeLookupException.fromType(_errorFor(code));

    if (e.status == 401) {
      return BarcodeLookupException.fromType(BarcodeLookupErrorType.unauthorized);
    }
    if (e.status == 0) {
      return BarcodeLookupException.fromType(BarcodeLookupErrorType.network);
    }
    return BarcodeLookupException.fromType(BarcodeLookupErrorType.analysisFailed);
  }
}
