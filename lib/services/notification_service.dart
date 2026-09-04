import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../supabase/supabase_config.dart';

/// OneSignal push notification infrastructure (Task 1 of the notification
/// system). Initialization is a no-op until [SupabaseConfig.oneSignalAppId]
/// is filled in, so the app runs normally before the OneSignal dashboard
/// setup is finished.
///
/// Users are targeted server-side by their Supabase auth user id, registered
/// here as OneSignal's external_id alias via [login] — Edge Functions never
/// touch device tokens.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;
  bool get isReady => _initialized;

  Future<void> init() async {
    final appId = SupabaseConfig.oneSignalAppId;
    if (appId.isEmpty) {
      debugPrint('ℹ️ OneSignal: app id not set yet — push disabled');
      return;
    }
    if (_initialized) return;

    try {
      OneSignal.initialize(appId);
      // Android 13+ runtime permission — the OS dialog appears on first run.
      OneSignal.Notifications.requestPermission(true);
      _initialized = true;
      debugPrint('✅ OneSignal initialized');

      // One choke point for every sign-in path (email, Google, signup,
      // session restore): tag the OneSignal user with our auth user id so
      // Edge Functions can target pushes by external_id.
      SupabaseConfig.client.auth.onAuthStateChange.listen((state) {
        final user = state.session?.user;
        if (user != null) {
          login(user.id);
        }
      });

      // Session restored on app start — tag immediately.
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId != null) await login(userId);
    } catch (e) {
      debugPrint('❌ OneSignal init failed: $e');
    }
  }

  /// Tag the OneSignal user with our auth user id (external_id alias).
  Future<void> login(String userId) async {
    if (!_initialized) return;
    try {
      await OneSignal.login(userId);
    } catch (e) {
      debugPrint('❌ OneSignal login failed: $e');
    }
  }

  /// Called on sign-out so the device stops receiving this user's pushes.
  Future<void> logout() async {
    if (!_initialized) return;
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('❌ OneSignal logout failed: $e');
    }
  }
}
