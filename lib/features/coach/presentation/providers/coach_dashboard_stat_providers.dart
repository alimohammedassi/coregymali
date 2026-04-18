import 'package:flutter/material.dart';

import '../../../../services/supabase_client.dart';
import '../../domain/entities/client_summary_entity.dart';

class CoachStats {
  final int activeSubscribers;
  final double avgRating;
  final double monthlyRevenue;
  final int openSlots;

  CoachStats({
    required this.activeSubscribers,
    required this.avgRating,
    required this.monthlyRevenue,
    required this.openSlots,
  });
}

class CoachDashboardStatNotifier extends ChangeNotifier {
  CoachStats? _stats;
  bool _isLoading = false;
  String? _error;

  CoachStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetch() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _error = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Get coach row
      final coachRow = await supabase
          .from('coaches')
          .select('id, max_clients, price_monthly')
          .eq('user_id', userId)
          .maybeSingle();

      if (coachRow == null) {
        _stats = CoachStats(
          activeSubscribers: 0,
          avgRating: 0,
          monthlyRevenue: 0,
          openSlots: 0,
        );
        _isLoading = false;
        notifyListeners();
        return;
      }

      final coachId = coachRow['id'];
      final maxClients = coachRow['max_clients'] ?? 10;
      final priceMonthly = (coachRow['price_monthly'] ?? 0).toDouble();

      // Get active subscribers
      final subs = await supabase
          .from('subscriptions')
          .select('id, price_plan')
          .eq('coach_id', coachId)
          .eq('status', 'active');

      final activeCount = subs.length;
      final monthlyRevenue = subs.fold<double>(
        0,
        (sum, s) {
          final plan = s['price_plan'] ?? 'standard';
          // If premium, use premium price (stored separately, here we approximate)
          return sum + priceMonthly;
        },
      );

      // Get rating from reviews
      final reviews = await supabase
          .from('reviews')
          .select('rating')
          .eq('coach_id', coachId);

      double avgRating = 0;
      if (reviews.isNotEmpty) {
        final total = reviews.fold<int>(0, (sum, r) => sum + ((r['rating'] ?? 0) as int));
        avgRating = total / reviews.length;
      }

      _stats = CoachStats(
        activeSubscribers: activeCount,
        avgRating: avgRating,
        monthlyRevenue: monthlyRevenue,
        openSlots: maxClients - activeCount,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _stats = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
