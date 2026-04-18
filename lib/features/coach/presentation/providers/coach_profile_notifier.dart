import 'package:flutter/material.dart';

import '../../domain/entities/coach_entity.dart';
import '../../domain/repositories/coach_repository.dart';

class CoachProfileNotifier extends ChangeNotifier {
  final ICoachRepository _repository;

  CoachProfileNotifier(this._repository);

  CoachEntity? _coach;
  bool _isLoading = false;
  String? _error;

  CoachEntity? get coach => _coach;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> createProfile(CoachEntity coach) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _coach = await _repository.createCoachProfile(coach);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(CoachEntity coach) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _coach = await _repository.updateCoachProfile(coach);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _coach = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
