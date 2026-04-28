import 'phase_model.dart';

class SubscriptionModel {
  final String id;
  final String clientId;
  final String clientName;
  final String? clientAvatarUrl;
  final String planName;
  final double priceUsd;
  final String status;         // pending|active|paused|expired|cancelled
  final String paymentStatus;  // unpaid|paid|refunded
  final DateTime startedAt;
  final DateTime expiresAt;
  final String? goals;
  final String? notes;
  final List<PhaseModel> phases; // sorted by phase_number ASC

  const SubscriptionModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.clientAvatarUrl,
    required this.planName,
    required this.priceUsd,
    required this.status,
    required this.paymentStatus,
    required this.startedAt,
    required this.expiresAt,
    this.goals,
    this.notes,
    required this.phases,
  });

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    final client = map['client'] as Map<String, dynamic>? ?? {};
    final plan   = map['plan']   as Map<String, dynamic>? ?? {};
    final rawPhases = (map['phases'] as List<dynamic>? ?? []);

    return SubscriptionModel(
      id:              map['id'],
      clientId:        client['id'] ?? '',
      clientName:      client['name'] ?? 'Unknown',
      clientAvatarUrl: client['avatar_url'],
      planName:        plan['name'] ?? 'No Plan',
      priceUsd:        (plan['price_usd'] as num?)?.toDouble() ?? 0.0,
      status:          map['status'] ?? 'active',
      paymentStatus:   map['payment_status'] ?? 'unpaid',
      startedAt:       map['started_at'] != null
                         ? DateTime.parse(map['started_at'])
                         : DateTime.now(),
      expiresAt:       map['expires_at'] != null
                         ? DateTime.parse(map['expires_at'])
                         : DateTime.now().add(const Duration(days: 30)),
      goals:           map['goals'],
      notes:           map['notes'],
      phases:          rawPhases
                         .map((p) => PhaseModel.fromMap(p))
                         .toList()
                         ..sort((a, b) => a.phaseNumber.compareTo(b.phaseNumber)),
    );
  }
}
