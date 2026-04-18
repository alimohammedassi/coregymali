class CoachProfile {
  final String name;
  final String? avatarUrl;
  final List<String>? galleryImages;

  const CoachProfile({
    required this.name,
    this.avatarUrl,
    this.galleryImages,
  });
}

class CoachEntity {
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
  final CoachProfile? profile;

  const CoachEntity({
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

  CoachEntity copyWith({
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
    CoachProfile? profile,
  }) {
    return CoachEntity(
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
}
