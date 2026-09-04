import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../supabase/supabase_config.dart';

/// OneSignal push notification infrastructure (Task 1 of the notification
/// system). Users are targeted server-side by their Supabase auth user id,
/// registered as OneSignal's external_id alias via [login] - Edge Functions
/// never touch device tokens.
///
/// OneSignal integration rules followed here (per the official SDK guide):
/// - All SDK calls live in this wrapper only.
/// - The push-subscription observer is held in a field (locally-scoped
///   observers get deallocated and never fire).
/// - The notification permission is requested ONLY from the verification
///   dialog's button tap ([requestPermission]) - never at app launch.
/// - A subscription id starting with `local-` is a placeholder, not a real
///   registration.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;
  bool get isReady => _initialized;

  OnPushSubscriptionChangeObserver? _subscriptionObserver;
  String? _subscriptionId;
  final List<void Function()> _verifiedCallbacks = [];

  /// The real OneSignal subscription id, once registered (never `local-`).
  String? get subscriptionId => _subscriptionId;

  /// True when the device has a real push subscription with OneSignal.
  bool get pushRegistered =>
      _subscriptionId != null && _subscriptionId!.isNotEmpty;

  Future<void> init() async {
    final appId = SupabaseConfig.oneSignalAppId;
    if (appId.isEmpty) {
      debugPrint('OneSignal: app id not set yet - push disabled');
      return;
    }
    if (_initialized) return;

    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }
      OneSignal.initialize(appId);

      // Field-held observer (see class doc). Detects the moment the device
      // really registers, then fires the verification callbacks once.
      _subscriptionObserver = (OSPushSubscriptionChangedState state) {
        final id = state.current.id;
        final isReal =
            id != null && id.isNotEmpty && !id.startsWith('local-');
        if (!isReal) return;
        _subscriptionId = id;
        debugPrint('OneSignal push subscription: $id');
        for (final cb in List<void Function()>.from(_verifiedCallbacks)) {
          cb();
        }
        _verifiedCallbacks.clear();
      };
      OneSignal.User.pushSubscription.addObserver(_subscriptionObserver!);

      // The id may already exist (previous install/launch).
      final existing = OneSignal.User.pushSubscription.id;
      if (existing != null &&
          existing.isNotEmpty &&
          !existing.startsWith('local-')) {
        _subscriptionId = existing;
      }

      _initialized = true;
      debugPrint('OneSignal initialized');

      // One choke point for every sign-in path (email, Google, signup,
      // session restore): tag the OneSignal user with our auth user id so
      // Edge Functions can target pushes by external_id.
      SupabaseConfig.client.auth.onAuthStateChange.listen((state) {
        final user = state.session?.user;
        if (user != null) {
          login(user.id);
        }
      });

      // Session restored on app start - tag immediately.
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId != null) await login(userId);
    } catch (e) {
      debugPrint('OneSignal init failed: $e');
    }
  }

  /// Fires [callback] once when the device gets a real push subscription
  /// (or immediately if it already has one). Used to time the verification
  /// dialog.
  void onPushVerified(void Function() callback) {
    if (pushRegistered) {
      callback();
      return;
    }
    _verifiedCallbacks.add(callback);
  }

  /// MUST be called from the verification dialog's button tap - the
  /// notification permission is never requested anywhere else.
  Future<void> requestPermission() async {
    if (!_initialized) return;
    final granted = await OneSignal.Notifications.requestPermission(true);
    debugPrint('OneSignal permission granted: $granted');
  }

  /// Task 2 — welcome push right after account creation. Fired with the
  /// user's own JWT (the function allows self-push), delayed a few seconds
  /// so OneSignal.login has time to sync the new external_id alias.
  /// Both languages are sent; OneSignal picks per device language.
  Future<void> sendWelcomePush() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null || !_initialized) return;
    Future.delayed(const Duration(seconds: 6), () async {
      try {
        final res = await SupabaseConfig.client.functions.invoke(
          'send-notification',
          body: {
            'user_id': userId,
            'title': 'Welcome to CoreGym! 👋',
            'body': "Let's log your first meal and kick off your journey. 🍽️",
            'title_ar': 'أهلاً بيك في CoreGym! 👋',
            'body_ar': 'سجّل أول وجبة وابدأ رحلتك. 🍽️',
            'type': 'welcome',
          },
        );
        debugPrint('Welcome push: ${res.data}');
      } catch (e) {
        debugPrint('Welcome push failed (non-critical): $e');
      }
    });
  }

  /// Tag the OneSignal user with our auth user id (external_id alias).
  Future<void> login(String userId) async {
    if (!_initialized) return;
    try {
      await OneSignal.login(userId);
    } catch (e) {
      debugPrint('OneSignal login failed: $e');
    }
  }

  /// Called on sign-out so the device stops receiving this user's pushes.
  Future<void> logout() async {
    if (!_initialized) return;
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('OneSignal logout failed: $e');
    }
  }
}
