import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food_scan_result.dart';
import 'supabase_client.dart';

class FoodScanService {
  /// Analyzes a food photo via the `analyze-food` Edge Function.
  ///
  /// The function runs the Gemini analysis, uploads the image to the private
  /// `food-scans` bucket and persists `food_scans` + `food_scan_items` rows,
  /// returning real DB ids which are parsed into [FoodScanResult].
  Future<FoodScanResult> analyzeFood(XFile image) async {
    if (currentUserId == null) {
      throw FoodScanException.fromType(FoodScanErrorType.unauthorized);
    }

    final Uint8List bytes;
    try {
      bytes = await image.readAsBytes();
    } catch (_) {
      throw FoodScanException.fromType(FoodScanErrorType.unknown);
    }

    final Map<String, dynamic> data;
    try {
      final response = await supabase.functions.invoke(
        'analyze-food',
        body: {
          'imageBase64': base64Encode(bytes),
          'mimeType': image.mimeType ?? 'image/jpeg',
        },
      );
      data = Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } on SocketException catch (_) {
      throw FoodScanException.fromType(FoodScanErrorType.network);
    } catch (e) {
      debugPrint('❌ FoodScanService.analyzeFood: $e');
      throw FoodScanException.fromType(FoodScanErrorType.unknown);
    }

    final result = FoodScanResult.fromJson(data);

    // The Edge Function returns 200 with rows persisted; a missing scan id
    // means an unexpected response shape.
    if (result.scanId.isEmpty) {
      throw FoodScanException.fromType(FoodScanErrorType.analysisFailed);
    }
    if (!result.isFood) {
      throw FoodScanException.fromType(FoodScanErrorType.notFood);
    }
    return result;
  }

  FoodScanException _mapFunctionException(FunctionException e) {
    debugPrint('❌ analyze-food failed [${e.status}]: ${e.reasonPhrase}');

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
      case 'persist_failed':
        // Gemini analysis succeeded but storage/DB write failed.
        return FoodScanException.fromType(FoodScanErrorType.serverError);
      case 'analysis_failed':
        return FoodScanException.fromType(FoodScanErrorType.analysisFailed);
      case 'unauthorized':
        return FoodScanException.fromType(FoodScanErrorType.unauthorized);
      case 'bad_request':
        return FoodScanException.fromType(FoodScanErrorType.unknown);
    }

    if (e.status == 401) {
      return FoodScanException.fromType(FoodScanErrorType.unauthorized);
    }
    if (e.status == 0) {
      return FoodScanException.fromType(FoodScanErrorType.network);
    }
    return FoodScanException.fromType(FoodScanErrorType.analysisFailed);
  }
}
