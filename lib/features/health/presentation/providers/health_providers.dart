import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../home/presentation/providers/activity_providers.dart'
    show activityWeekProvider;
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

    if (forceSync) {
      // Explicit sync (sync-now / connect): await the write so the outer
      // week card can refetch values that are guaranteed fresh.
      bool synced = false;
      try {
        synced = await service.syncTodayActivity(activity, force: true);
      } catch (_) {}
      if (synced) {
        // daily_summary just changed — the home week strip / steps card read
        // it through activityWeekProvider, which fetches only once otherwise.
        ref.invalidate(activityWeekProvider);
      }
    } else {
      // Quiet path (provider build): fire-and-forget, throttled by the
      // service; cold-start home load reads daily_summary after this lands.
      service.syncTodayActivity(activity, force: false).catchError((e) {
        // Background sync errors are logged in service and non-blocking
        return false;
      });
    }

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
