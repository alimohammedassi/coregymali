import '../../domain/entities/subscription_entity.dart';

class SubscriptionModel {
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

  const SubscriptionModel({
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

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] ?? '',
      clientId: json['client_id'] ?? '',
      coachId: json['coach_id'] ?? '',
      status: _statusFromString(json['status'] ?? 'pending'),
      tier: json['tier'] ?? '',
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
      stripeSubId: json['stripe_sub_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'coach_id': coachId,
      'status': _statusToString(status),
      'tier': tier,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'stripe_sub_id': stripeSubId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SubscriptionModel copyWith({
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
    return SubscriptionModel(
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

  SubscriptionEntity toEntity() {
    return SubscriptionEntity(
      id: id,
      clientId: clientId,
      coachId: coachId,
      status: status,
      tier: tier,
      startDate: startDate,
      endDate: endDate,
      stripeSubId: stripeSubId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory SubscriptionModel.fromEntity(SubscriptionEntity entity) {
    return SubscriptionModel(
      id: entity.id,
      clientId: entity.clientId,
      coachId: entity.coachId,
      status: entity.status,
      tier: entity.tier,
      startDate: entity.startDate,
      endDate: entity.endDate,
      stripeSubId: entity.stripeSubId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  static SubscriptionStatus _statusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return SubscriptionStatus.active;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'pending':
      default:
        return SubscriptionStatus.pending;
    }
  }

  static String _statusToString(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return 'active';
      case SubscriptionStatus.cancelled:
        return 'cancelled';
      case SubscriptionStatus.expired:
        return 'expired';
      case SubscriptionStatus.pending:
        return 'pending';
    }
  }
}
