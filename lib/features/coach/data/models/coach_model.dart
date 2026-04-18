import '../../domain/entities/coach_entity.dart';

class CoachProfileModel {
  final String name;
  final String? avatarUrl;

  const CoachProfileModel({
    required this.name,
    this.avatarUrl,
  });

  factory CoachProfileModel.fromJson(Map<String, dynamic> json) {
    return CoachProfileModel(
      name: json['name'] ?? '',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'avatar_url': avatarUrl,
    };
  }

  CoachProfile toEntity() {
    return CoachProfile(
      name: name,
      avatarUrl: avatarUrl,
    );
  }

  factory CoachProfileModel.fromEntity(CoachProfile entity) {
    return CoachProfileModel(
      name: entity.name,
      avatarUrl: entity.avatarUrl,
    );
  }

  CoachProfileModel copyWith({
    String? name,
    String? avatarUrl,
  }) {
    return CoachProfileModel(
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class CoachModel {
  final String id;
  final String userId;
  final String bio;
  final double priceMonthly;
  final List<String> specialization;
  final double rating;
  final bool isActive;
  final String? stripeAccountId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CoachProfileModel? profile;

  const CoachModel({
    required this.id,
    required this.userId,
    required this.bio,
    required this.priceMonthly,
    required this.specialization,
    required this.rating,
    required this.isActive,
    this.stripeAccountId,
    required this.createdAt,
    required this.updatedAt,
    this.profile,
  });

  factory CoachModel.fromJson(Map<String, dynamic> json) {
    return CoachModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      bio: json['bio'] ?? '',
      priceMonthly: (json['price_monthly'] ?? 0.0).toDouble(),
      specialization: (json['specialization'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rating: (json['rating'] ?? 0.0).toDouble(),
      isActive: json['is_active'] ?? false,
      stripeAccountId: json['stripe_account_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      profile: json['profiles'] != null
          ? CoachProfileModel.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'bio': bio,
      'price_monthly': priceMonthly,
      'specialization': specialization,
      'rating': rating,
      'is_active': isActive,
      'stripe_account_id': stripeAccountId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CoachModel copyWith({
    String? id,
    String? userId,
    String? bio,
    double? priceMonthly,
    List<String>? specialization,
    double? rating,
    bool? isActive,
    String? stripeAccountId,
    DateTime? createdAt,
    DateTime? updatedAt,
    CoachProfileModel? profile,
  }) {
    return CoachModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bio: bio ?? this.bio,
      priceMonthly: priceMonthly ?? this.priceMonthly,
      specialization: specialization ?? this.specialization,
      rating: rating ?? this.rating,
      isActive: isActive ?? this.isActive,
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profile: profile ?? this.profile,
    );
  }

  CoachEntity toEntity() {
    return CoachEntity(
      id: id,
      userId: userId,
      bio: bio,
      priceMonthly: priceMonthly,
      specialization: specialization,
      rating: rating,
      isActive: isActive,
      stripeAccountId: stripeAccountId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      profile: profile?.toEntity(),
    );
  }

  factory CoachModel.fromEntity(CoachEntity entity) {
    return CoachModel(
      id: entity.id,
      userId: entity.userId,
      bio: entity.bio,
      priceMonthly: entity.priceMonthly,
      specialization: entity.specialization,
      rating: entity.rating,
      isActive: entity.isActive,
      stripeAccountId: entity.stripeAccountId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      profile: entity.profile != null
          ? CoachProfileModel.fromEntity(entity.profile!)
          : null,
    );
  }
}
