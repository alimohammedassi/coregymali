import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/subscription_repository_impl.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/repositories/subscription_repository.dart';

class SubscriptionRepositoryProvider extends ChangeNotifier {
  final ISubscriptionRepository _repository;

  SubscriptionRepositoryProvider({ISubscriptionRepository? repository})
      : _repository = repository ?? SubscriptionRepositoryImpl();

  ISubscriptionRepository get repository => _repository;
}

class ActiveSubscriptionNotifier extends ChangeNotifier {
  final ISubscriptionRepository _repository;

  bool _disposed = false;

  ActiveSubscriptionNotifier(this._repository);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  SubscriptionEntity? _subscription;
  bool _isLoading = false;
  String? _error;

  SubscriptionEntity? get subscription => _subscription;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchActiveSubscription() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _subscription = await _repository.getActiveSubscription();
      _isLoading = false;
      if (!_disposed) notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void clear() {
    _subscription = null;
    _error = null;
    _isLoading = false;
    if (!_disposed) notifyListeners();
  }
}

class CoachSubscribersNotifier extends ChangeNotifier {
  final ISubscriptionRepository _repository;

  bool _disposed = false;

  CoachSubscribersNotifier(this._repository);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<SubscriptionEntity>? _subscribers;
  bool _isLoading = false;
  String? _error;

  List<SubscriptionEntity>? get subscribers => _subscribers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchSubscribers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _subscribers = await _repository.getCoachSubscribers();
      _isLoading = false;
      if (!_disposed) notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void clear() {
    _subscribers = null;
    _error = null;
    _isLoading = false;
    if (!_disposed) notifyListeners();
  }
}

class SubscriptionNotifier extends ChangeNotifier {
  final ISubscriptionRepository _repository;

  bool _disposed = false;

  SubscriptionNotifier(this._repository);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  SubscriptionEntity? _subscription;
  bool _isLoading = false;
  String? _error;

  SubscriptionEntity? get subscription => _subscription;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> subscribeToCoach(String coachId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _subscription = await _repository.subscribeToCoach(coachId);
      _isLoading = false;
      if (!_disposed) notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> cancelSubscription(String subscriptionId) async {
    _isLoading = true;
    _error = null;
    if (!_disposed) notifyListeners();

    try {
      await _repository.cancelSubscription(subscriptionId);
      _subscription = null;
      _isLoading = false;
      if (!_disposed) notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void clear() {
    _subscription = null;
    _error = null;
    _isLoading = false;
    if (!_disposed) notifyListeners();
  }
}

class SubscriptionProviders {
  static Widget provideRepository({
    required Widget child,
    ISubscriptionRepository? repository,
  }) {
    return ChangeNotifierProvider(
      create: (_) => SubscriptionRepositoryProvider(repository: repository),
      child: child,
    );
  }

  static Widget provideActiveSubscription({
    required Widget child,
  }) {
    return ChangeNotifierProxyProvider<
        SubscriptionRepositoryProvider, ActiveSubscriptionNotifier>(
      create: (context) {
        final notifier = ActiveSubscriptionNotifier(
          context.read<SubscriptionRepositoryProvider>().repository,
        );
        notifier.fetchActiveSubscription();
        return notifier;
      },
      update: (_, repoProvider, previous) {
        return previous ?? ActiveSubscriptionNotifier(repoProvider.repository);
      },
      child: child,
    );
  }

  static Widget provideCoachSubscribers({
    required Widget child,
  }) {
    return ChangeNotifierProxyProvider<
        SubscriptionRepositoryProvider, CoachSubscribersNotifier>(
      create: (context) {
        final notifier = CoachSubscribersNotifier(
          context.read<SubscriptionRepositoryProvider>().repository,
        );
        notifier.fetchSubscribers();
        return notifier;
      },
      update: (_, repoProvider, previous) {
        return previous ?? CoachSubscribersNotifier(repoProvider.repository);
      },
      child: child,
    );
  }

  static Widget provideSubscriptionActions({
    required Widget child,
  }) {
    return ChangeNotifierProxyProvider<
        SubscriptionRepositoryProvider, SubscriptionNotifier>(
      create: (context) => SubscriptionNotifier(
        context.read<SubscriptionRepositoryProvider>().repository,
      ),
      update: (_, repoProvider, previous) {
        return previous ?? SubscriptionNotifier(repoProvider.repository);
      },
      child: child,
    );
  }
}
