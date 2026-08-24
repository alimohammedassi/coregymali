import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/health_service.dart';
import '../../domain/daily_activity.dart';

/// Singleton HealthService Provider
final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

/// Permission status provider
final healthPermissionStatusProvider =
    FutureProvider.autoDispose<HealthPermissionStatus>((ref) async {
  final service = ref.watch(healthServiceProvider);
  return await service.checkPlatformStatus();
});

/// Today's live activity notifier & provider
class TodayActivityNotifier extends AsyncNotifier<DailyActivity> {
  @override
  Future<DailyActivity> build() async {
    return _loadAndSync(forceSync: false);
  }

  Future<DailyActivity> _loadAndSync({required bool forceSync}) async {
    final service = ref.read(healthServiceProvider);
    final activity = await service.fetchTodayActivity();

    // Silently sync to Supabase in the background
    service.syncTodayActivity(activity, force: forceSync).catchError((e) {
      // Background sync errors are logged in service and non-blocking
      return false;
    });

    return activity;
  }

  /// Request permissions and reload data on success
  Future<HealthPermissionResult> requestPermissions() async {
    final service = ref.read(healthServiceProvider);
    final result = await service.requestPermissions();
    if (result.isSuccess) {
      ref.invalidate(healthPermissionStatusProvider);
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() => _loadAndSync(forceSync: true));
    }
    return result;
  }

  /// Refresh today's activity and force sync to Supabase
  Future<void> refresh({bool forceSync = true}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadAndSync(forceSync: forceSync));
  }
}

final todayActivityProvider =
    AsyncNotifierProvider<TodayActivityNotifier, DailyActivity>(
  TodayActivityNotifier.new,
);

/// Recent activity history provider (for charts / analytics)
final activityHistoryProvider =
    FutureProvider.family<List<DailyActivity>, int>((ref, days) async {
  final service = ref.watch(healthServiceProvider);
  return await service.fetchRecentActivityHistory(days: days);
});
