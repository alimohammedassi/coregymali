enum SubscriptionStatus {
  active,
  cancelled,
  expired,
  pending,
}

class SubscriptionEntity {
  final String id;
  final String clientId;
  final String coachId;
  final SubscriptionStatus status;
  final String tier;
  final DateTime startDate;
  final DateTime? endDate;
  final String? stripeSubId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SubscriptionEntity({
    required this.id,
    required this.clientId,
    required this.coachId,
    required this.status,
    required this.tier,
    required this.startDate,
    this.endDate,
    this.stripeSubId,
    required this.createdAt,
    required this.updatedAt,
  });

  SubscriptionEntity copyWith({
    String? id,
    String? clientId,
    String? coachId,
    SubscriptionStatus? status,
    String? tier,
    DateTime? startDate,
    DateTime? endDate,
    String? stripeSubId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionEntity(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      coachId: coachId ?? this.coachId,
      status: status ?? this.status,
      tier: tier ?? this.tier,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      stripeSubId: stripeSubId ?? this.stripeSubId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isActive => status == SubscriptionStatus.active;
}
