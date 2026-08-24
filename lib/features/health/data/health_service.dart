import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/daily_activity.dart';
import '../../../services/supabase_client.dart';

enum HealthPermissionStatus {
  granted,
  denied,
  notInstalled,
  unsupported,
  loading,
}

class HealthPermissionResult {
  final bool isSuccess;
  final String message;
  final HealthPermissionStatus status;

  const HealthPermissionResult({
    required this.isSuccess,
    required this.message,
    required this.status,
  });
}

class HealthService {
  final Health _health = Health();

  static const List<HealthDataType> _requestedTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.WORKOUT,
  ];

  static const List<HealthDataAccess> _requestedPermissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  DateTime? _lastSyncTime;

  /// Check whether Health Connect is available or needs installation on Android
  Future<HealthPermissionStatus> checkPlatformStatus() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return HealthPermissionStatus.unsupported;
    }

    try {
      await _health.configure();

      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status == HealthConnectSdkStatus.sdkUnavailable ||
            status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          return HealthPermissionStatus.notInstalled;
        }
      }

      final hasPerms = await _health.hasPermissions(
        _requestedTypes,
        permissions: _requestedPermissions,
      );

      if (hasPerms == true) {
        return HealthPermissionStatus.granted;
      }

      // Fallback verification: test read (HealthKit on iOS does not reveal read authorization)
      try {
        final now = DateTime.now();
        final testSteps = await _health.getTotalStepsInInterval(
          now.subtract(const Duration(hours: 1)),
          now,
        );
        if (testSteps != null) {
          return HealthPermissionStatus.granted;
        }
      } catch (_) {}

      return HealthPermissionStatus.denied;
    } catch (e) {
      debugPrint('Health platform status error: $e');
      return HealthPermissionStatus.denied;
    }
  }

  /// Request permissions from Apple Health or Health Connect
  Future<HealthPermissionResult> requestPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const HealthPermissionResult(
        isSuccess: false,
        message: 'ميزة ربط الساعة متوفرة على أجهزة الهواتف الحقيقية (iOS و Android).',
        status: HealthPermissionStatus.unsupported,
      );
    }

    try {
      await _health.configure();

      if (Platform.isAndroid) {
        // Request Activity Recognition on Android
        try {
          await Permission.activityRecognition.request();
        } catch (e) {
          debugPrint('Activity recognition permission request error: $e');
        }

        final status = await _health.getHealthConnectSdkStatus();
        if (status == HealthConnectSdkStatus.sdkUnavailable ||
            status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          await _health.installHealthConnect();
          return const HealthPermissionResult(
            isSuccess: false,
            message: 'تطبيق Health Connect مطلوب. جاري توجيهك إلى Google Play...',
            status: HealthPermissionStatus.notInstalled,
          );
        }
      }

      final granted = await _health.requestAuthorization(
        _requestedTypes,
        permissions: _requestedPermissions,
      );

      // Verify read access via test fetch
      bool canRead = false;
      try {
        final now = DateTime.now();
        final steps = await _health.getTotalStepsInInterval(
          DateTime(now.year, now.month, now.day),
          now,
        );
        if (steps != null) {
          canRead = true;
        }
      } catch (e) {
        debugPrint('Verification read after auth error: $e');
      }

      if (granted == true || canRead) {
        return const HealthPermissionResult(
          isSuccess: true,
          message: 'تم ربط الساعة ومزامنة البيانات بنجاح!',
          status: HealthPermissionStatus.granted,
        );
      } else {
        return const HealthPermissionResult(
          isSuccess: false,
          message: 'يرجى تفعيل خيارات الصلاحيات في شاشة الصحة (Apple Health / Health Connect).',
          status: HealthPermissionStatus.denied,
        );
      }
    } catch (e) {
      debugPrint('Error requesting health permissions: $e');
      return HealthPermissionResult(
        isSuccess: false,
        message: 'حدث خطأ أثناء طلب الصلاحية: $e',
        status: HealthPermissionStatus.denied,
      );
    }
  }

  /// Fetch today's activity metrics (midnight to now)
  Future<DailyActivity> fetchTodayActivity() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final source = Platform.isIOS ? 'healthkit' : 'health_connect';

    int steps = 0;
    double activeCalories = 0.0;
    double totalCalories = 0.0;
    double? heartRateAvg;
    double? exerciseMinutes;

    try {
      await _health.configure();

      // 1. Fetch Steps via interval aggregate
      try {
        final stepsCount = await _health.getTotalStepsInInterval(midnight, now);
        if (stepsCount != null && stepsCount > 0) {
          steps = stepsCount;
        }
      } catch (e) {
        debugPrint('getTotalStepsInInterval error: $e');
      }

      // 2. Query data points for steps (fallback), active energy, total calories, heart rate, and workouts
      try {
        final healthData = await _health.getHealthDataFromTypes(
          types: [
            HealthDataType.STEPS,
            HealthDataType.ACTIVE_ENERGY_BURNED,
            HealthDataType.TOTAL_CALORIES_BURNED,
            HealthDataType.HEART_RATE,
            HealthDataType.WORKOUT,
          ],
          startTime: midnight,
          endTime: now,
        );

        int dataPointSteps = 0;
        final heartRates = <double>[];
        double totalWorkoutMinutes = 0.0;

        for (final data in healthData) {
          if (data.type == HealthDataType.STEPS) {
            final val = (data.value as NumericHealthValue).numericValue;
            dataPointSteps += val.toInt();
          } else if (data.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
            final val = (data.value as NumericHealthValue).numericValue;
            activeCalories += val.toDouble();
          } else if (data.type == HealthDataType.TOTAL_CALORIES_BURNED) {
            final val = (data.value as NumericHealthValue).numericValue;
            totalCalories += val.toDouble();
          } else if (data.type == HealthDataType.HEART_RATE) {
            final val = (data.value as NumericHealthValue).numericValue;
            heartRates.add(val.toDouble());
          } else if (data.type == HealthDataType.WORKOUT) {
            final diff = data.dateTo.difference(data.dateFrom).inMinutes;
            totalWorkoutMinutes += diff.toDouble();
          }
        }

        // Use summed step data points if aggregate was 0
        if (steps == 0 && dataPointSteps > 0) {
          steps = dataPointSteps;
        }

        // Use total calories if active calories is 0
        if (activeCalories == 0 && totalCalories > 0) {
          activeCalories = totalCalories;
        }

        if (heartRates.isNotEmpty) {
          heartRateAvg = heartRates.reduce((a, b) => a + b) / heartRates.length;
        }

        if (totalWorkoutMinutes > 0) {
          exerciseMinutes = totalWorkoutMinutes;
        }
      } catch (e) {
        debugPrint('Error querying health data points: $e');
      }

      final activity = DailyActivity(
        steps: steps,
        activeCaloriesBurned: double.parse(activeCalories.toStringAsFixed(1)),
        heartRateAvg: heartRateAvg != null ? double.parse(heartRateAvg.toStringAsFixed(1)) : null,
        exerciseMinutes: exerciseMinutes != null ? double.parse(exerciseMinutes.toStringAsFixed(1)) : null,
        date: now,
        source: source,
        syncedAt: _lastSyncTime,
      );

      debugPrint('📊 Live Activity Fetched: Steps=$steps, Cals=$activeCalories, HR=$heartRateAvg, Workouts=$exerciseMinutes');
      return activity;
    } catch (e) {
      debugPrint('Error in fetchTodayActivity: $e');
      return DailyActivity.empty(now).copyWith(source: source);
    }
  }

  /// Sync today's activity to Supabase `daily_activity` & `daily_summary`
  Future<bool> syncTodayActivity(DailyActivity activity, {bool force = false}) async {
    if (currentUserId == null) {
      debugPrint('Sync skipped: User not logged in');
      return false;
    }

    // Throttle syncs to every 30 minutes unless forced
    final now = DateTime.now();
    if (!force && _lastSyncTime != null && now.difference(_lastSyncTime!).inMinutes < 30) {
      debugPrint('Sync throttled: Last synced ${_lastSyncTime!.toIso8601String()}');
      return true;
    }

    final dateStr = activity.date.toIso8601String().substring(0, 10);

    try {
      // 1. Upsert into daily_activity
      await supabase.from('daily_activity').upsert(
        {
          'user_id': currentUserId!,
          'activity_date': dateStr,
          'steps': activity.steps,
          'active_calories_burned': activity.activeCaloriesBurned,
          'heart_rate_avg': activity.heartRateAvg,
          'exercise_minutes': activity.exerciseMinutes,
          'source': activity.source,
          'synced_at': now.toIso8601String(),
        },
        onConflict: 'user_id,activity_date',
      );

      // 2. Also keep daily_summary updated so existing widgets reflect live smartwatch stats
      await supabase.from('daily_summary').upsert(
        {
          'user_id': currentUserId!,
          'summary_date': dateStr,
          'steps': activity.steps,
          if (activity.activeCaloriesBurned > 0)
            'calories_burned': activity.activeCaloriesBurned.round(),
          'updated_at': now.toIso8601String(),
        },
        onConflict: 'user_id,summary_date',
      );

      _lastSyncTime = now;
      debugPrint('✅ Smartwatch activity synced to Supabase for $dateStr');
      return true;
    } on PostgrestException catch (e) {
      debugPrint('❌ Supabase error syncing health data: ${e.message} (code: ${e.code})');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected error syncing health data: $e');
      return false;
    }
  }

  /// Fetch historical activity rows for charts / analytics
  Future<List<DailyActivity>> fetchRecentActivityHistory({int days = 7}) async {
    if (currentUserId == null) return [];

    final fromDate = DateTime.now()
        .subtract(Duration(days: days - 1))
        .toIso8601String()
        .substring(0, 10);

    try {
      final rows = await supabase
          .from('daily_activity')
          .select()
          .eq('user_id', currentUserId!)
          .gte('activity_date', fromDate)
          .order('activity_date', ascending: true);

      return (rows as List<dynamic>)
          .map((r) => DailyActivity.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching activity history: $e');
      return [];
    }
  }
}
