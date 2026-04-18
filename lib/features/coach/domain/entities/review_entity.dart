class ReviewEntity {
  final String id;
  final String clientId;
  final String coachId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const ReviewEntity({
    required this.id,
    required this.clientId,
    required this.coachId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  ReviewEntity copyWith({
    String? id,
    String? clientId,
    String? coachId,
    int? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return ReviewEntity(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      coachId: coachId ?? this.coachId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
