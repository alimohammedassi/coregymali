import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/coach_repository_impl.dart';
import '../../domain/entities/coach_entity.dart';
import '../../domain/repositories/coach_repository.dart';

class CoachRepositoryProvider extends ChangeNotifier {
  final ICoachRepository _repository;

  CoachRepositoryProvider({ICoachRepository? repository})
      : _repository = repository ?? CoachRepositoryImpl();

  ICoachRepository get repository => _repository;
}

class CoachListNotifier extends ChangeNotifier {
  final ICoachRepository _repository;

  bool _disposed = false;

  CoachListNotifier(this._repository);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<CoachEntity>? _coaches;
  bool _isLoading = false;
  String? _error;

  List<CoachEntity>? get coaches => _coaches;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCoaches({
    String? specialization,
    double? maxPrice,
    double? minRating,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _coaches = await _repository.getCoaches(
        specialization: specialization,
        maxPrice: maxPrice,
        minRating: minRating,
      );
      _isLoading = false;
      if (!_disposed) notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void clear() {
    _coaches = null;
    _error = null;
    _isLoading = false;
    if (!_disposed) notifyListeners();
  }
}

class SelectedCoachNotifier extends ChangeNotifier {
  final ICoachRepository _repository;

  bool _disposed = false;

  SelectedCoachNotifier(this._repository);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  CoachEntity? _coach;
  bool _isLoading = false;
  String? _error;

  CoachEntity? get coach => _coach;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCoach(String coachId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _coach = await _repository.getCoachById(coachId);
      _isLoading = false;
      if (!_disposed) notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void clear() {
    _coach = null;
    _error = null;
    _isLoading = false;
    if (!_disposed) notifyListeners();
  }
}

class CoachProviders {
  static Widget provideRepository({
    required Widget child,
    ICoachRepository? repository,
  }) {
    return ChangeNotifierProvider(
      create: (_) => CoachRepositoryProvider(repository: repository),
      child: child,
    );
  }

  static Widget provideCoachList({
    required Widget child,
    String? specialization,
    double? maxPrice,
    double? minRating,
  }) {
    return ChangeNotifierProxyProvider<CoachRepositoryProvider, CoachListNotifier>(
      create: (context) {
        final notifier = CoachListNotifier(
          context.read<CoachRepositoryProvider>().repository,
        );
        // Auto-fetch coaches when notifier is created
        notifier.fetchCoaches(
          specialization: specialization,
          maxPrice: maxPrice,
          minRating: minRating,
        );
        return notifier;
      },
      update: (_, repoProvider, previous) {
        return previous ?? CoachListNotifier(repoProvider.repository);
      },
      child: child,
    );
  }

  static Widget provideSelectedCoach({
    required Widget child,
    required String coachId,
  }) {
    return ChangeNotifierProxyProvider<CoachRepositoryProvider, SelectedCoachNotifier>(
      create: (context) {
        final notifier = SelectedCoachNotifier(
          context.read<CoachRepositoryProvider>().repository,
        );
        notifier.fetchCoach(coachId);
        return notifier;
      },
      update: (_, repoProvider, previous) {
        return previous ?? SelectedCoachNotifier(repoProvider.repository);
      },
      child: child,
    );
  }
}
