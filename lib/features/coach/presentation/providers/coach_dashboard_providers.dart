import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/coach_dashboard_repository_impl.dart';
import '../../domain/entities/client_full_data_entity.dart';
import '../../domain/entities/client_summary_entity.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import '../providers/coach_dashboard_stat_providers.dart';
// ── Repository provider ───────────────────────────────────────────────────────

class CoachDashboardRepositoryProvider extends ChangeNotifier {
  final ICoachDashboardRepository _repository;

  CoachDashboardRepositoryProvider({ICoachDashboardRepository? repository})
      : _repository = repository ?? CoachDashboardRepositoryImpl();

  ICoachDashboardRepository get repository => _repository;
}

// ── Active clients ────────────────────────────────────────────────────────────

class ActiveClientsNotifier extends ChangeNotifier {
  final ICoachDashboardRepository _repository;

  ActiveClientsNotifier(this._repository);

  List<ClientSummary>? _clients;
  bool _isLoading = false;
  String? _error;

  List<ClientSummary>? get clients => _clients;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetch() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _clients = await _repository.getActiveClients();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _clients = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

// ── Client full data ──────────────────────────────────────────────────────────

class ClientDataNotifier extends ChangeNotifier {
  final ICoachDashboardRepository _repository;

  ClientDataNotifier(this._repository);

  ClientFullData? _data;
  bool _isLoading = false;
  String? _error;
  String? _lastClientId;

  ClientFullData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetch(
    String clientId, {
    DateTime? from,
    DateTime? to,
  }) async {
    _lastClientId = clientId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _repository.getClientData(clientId, from: from, to: to);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Re-fetch with a new date range (e.g. when picker changes).
  Future<void> refetch({DateTime? from, DateTime? to}) async {
    if (_lastClientId == null) return;
    await fetch(_lastClientId!, from: from, to: to);
  }

  void clear() {
    _data = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

// ── Selected date range ───────────────────────────────────────────────────────

class SelectedDateRangeNotifier extends ChangeNotifier {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  DateTimeRange get range => _range;

  void update(DateTimeRange newRange) {
    _range = newRange;
    notifyListeners();
  }
}

// ── Dashboard providers static helper ────────────────────────────────────────


class CoachDashboardProviders {
  static Widget provideAll({required Widget child}) {
    return ChangeNotifierProvider<CoachDashboardStatNotifier>(
      create: (_) => CoachDashboardStatNotifier()..fetch(),
      child: ChangeNotifierProvider<CoachDashboardRepositoryProvider>(
        create: (_) => CoachDashboardRepositoryProvider(),
        child: ChangeNotifierProvider<SelectedDateRangeNotifier>(
          create: (_) => SelectedDateRangeNotifier(),
          child: ChangeNotifierProxyProvider<CoachDashboardRepositoryProvider,
              ActiveClientsNotifier>(
            create: (ctx) {
              final n = ActiveClientsNotifier(
                  ctx.read<CoachDashboardRepositoryProvider>().repository);
              n.fetch();
              return n;
            },
            update: (_, repoProvider, previous) =>
                previous ??
                ActiveClientsNotifier(repoProvider.repository),
            child: ChangeNotifierProxyProvider<CoachDashboardRepositoryProvider,
                ClientDataNotifier>(
              create: (ctx) => ClientDataNotifier(
                  ctx.read<CoachDashboardRepositoryProvider>().repository),
              update: (_, repoProvider, previous) =>
                  previous ?? ClientDataNotifier(repoProvider.repository),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
