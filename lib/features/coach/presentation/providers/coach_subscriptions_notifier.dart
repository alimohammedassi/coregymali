import 'package:flutter/material.dart';
import '../../data/models/subscription_model.dart';
import '../../data/repositories/coach_subscription_repository.dart';

class CoachSubscriptionsNotifier extends ChangeNotifier {
  final CoachSubscriptionRepository _repo;
  CoachSubscriptionsNotifier(this._repo);

  List<SubscriptionModel>? subscriptions;
  bool isLoading = false;
  String? error;

  Future<void> fetch() async {
    isLoading = true; error = null; notifyListeners();
    try {
      subscriptions = await _repo.fetchSubscriptions();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false; notifyListeners();
    }
  }

  List<SubscriptionModel> filtered(int tabIndex) {
    final all = subscriptions ?? [];
    return switch (tabIndex) {
      1 => all.where((s) => s.status == 'active').toList(),
      2 => all.where((s) => s.status == 'pending').toList(),
      3 => all.where((s) =>
             s.status == 'expired' || s.status == 'cancelled').toList(),
      _ => all,
    };
  }
}
