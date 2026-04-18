import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/stripe_service.dart';
import 'subscription_providers.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum StripePaymentStatus { idle, loading, success, failure }

class StripePaymentState {
  final StripePaymentStatus status;
  final String? errorMessage;

  const StripePaymentState({
    this.status = StripePaymentStatus.idle,
    this.errorMessage,
  });

  StripePaymentState copyWith({
    StripePaymentStatus? status,
    String? errorMessage,
  }) =>
      StripePaymentState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class StripePaymentNotifier extends ChangeNotifier {
  final StripeService _stripeService;
  final ActiveSubscriptionNotifier _subscriptionNotifier;

  StripePaymentState _state = const StripePaymentState();
  StreamSubscription<Uri>? _deepLinkSub;
  String? _pendingSessionId;

  StripePaymentState get state => _state;
  bool get isLoading => _state.status == StripePaymentStatus.loading;

  StripePaymentNotifier({
    required StripeService stripeService,
    required ActiveSubscriptionNotifier subscriptionNotifier,
  })  : _stripeService = stripeService,
        _subscriptionNotifier = subscriptionNotifier;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> subscribe(String coachId, {String tier = 'standard'}) async {
    _setState(StripePaymentStatus.loading);
    _cancelDeepLinkListener();

    try {
      // 1. Create Stripe Checkout session
      final result = await _stripeService.createCheckoutSession(
        coachId: coachId,
        tier: tier,
      );
      _pendingSessionId = result.sessionId;

      // 2. Listen for the deep link BEFORE launching the URL
      _listenForDeepLink();

      // 3. Open Stripe Checkout in external browser
      final uri = Uri.parse(result.checkoutUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open payment page');
      }
    } catch (e) {
      _setState(StripePaymentStatus.failure, error: e.toString());
    }
  }

  void reset() {
    _cancelDeepLinkListener();
    _pendingSessionId = null;
    _state = const StripePaymentState();
    notifyListeners();
  }

  // ── Deep link handling ────────────────────────────────────────────────────

  void _listenForDeepLink() {
    final appLinks = AppLinks();
    _deepLinkSub = appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (_) => _setState(StripePaymentStatus.failure, error: 'Deep link error'),
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    _cancelDeepLinkListener();

    // coregym://payment/cancel
    if (uri.host == 'payment' && uri.path == '/cancel') {
      _setState(StripePaymentStatus.failure, error: 'Payment was cancelled.');
      return;
    }

    // coregym://payment/success?session_id=cs_xxx
    if (uri.host == 'payment' && uri.path == '/success') {
      final sessionId = uri.queryParameters['session_id'] ?? _pendingSessionId;
      if (sessionId == null) {
        _setState(StripePaymentStatus.failure, error: 'Missing session ID');
        return;
      }

      try {
        final status = await _stripeService.getSessionStatus(sessionId);
        if (status['status'] == 'paid') {
          // Refresh the active subscription state
          await _subscriptionNotifier.fetchActiveSubscription();
          _setState(StripePaymentStatus.success);
        } else {
          _setState(
            StripePaymentStatus.failure,
            error: 'Payment not confirmed (status: ${status['status']})',
          );
        }
      } catch (e) {
        _setState(StripePaymentStatus.failure, error: e.toString());
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setState(StripePaymentStatus status, {String? error}) {
    _state = _state.copyWith(status: status, errorMessage: error);
    notifyListeners();
  }

  void _cancelDeepLinkListener() {
    _deepLinkSub?.cancel();
    _deepLinkSub = null;
  }

  @override
  void dispose() {
    _cancelDeepLinkListener();
    super.dispose();
  }
}

// ── Provider factory ──────────────────────────────────────────────────────────

class StripeProviders {
  /// Wraps a subtree with StripePaymentNotifier, reading ActiveSubscriptionNotifier
  /// from context (must already be provided above).
  static Widget providePayment({required Widget child}) {
    return ChangeNotifierProxyProvider<ActiveSubscriptionNotifier, StripePaymentNotifier>(
      create: (ctx) => StripePaymentNotifier(
        stripeService: StripeService(),
        subscriptionNotifier: ctx.read<ActiveSubscriptionNotifier>(),
      ),
      update: (ctx, subNotifier, previous) =>
          previous ??
          StripePaymentNotifier(
            stripeService: StripeService(),
            subscriptionNotifier: subNotifier,
          ),
      child: child,
    );
  }
}
