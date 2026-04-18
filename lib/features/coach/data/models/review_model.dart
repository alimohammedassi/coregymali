import '../../domain/entities/review_entity.dart';

class ReviewModel {
  final String id;
  final String clientId;
  final String coachId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.clientId,
    required this.coachId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? '',
      clientId: json['client_id'] ?? '',
      coachId: json['coach_id'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'coach_id': coachId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ReviewModel copyWith({
    String? id,
    String? clientId,
    String? coachId,
    int? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      coachId: coachId ?? this.coachId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  ReviewEntity toEntity() {
    return ReviewEntity(
      id: id,
      clientId: clientId,
      coachId: coachId,
      rating: rating,
      comment: comment,
      createdAt: createdAt,
    );
  }

  factory ReviewModel.fromEntity(ReviewEntity entity) {
    return ReviewModel(
      id: entity.id,
      clientId: entity.clientId,
      coachId: entity.coachId,
      rating: entity.rating,
      comment: entity.comment,
      createdAt: entity.createdAt,
    );
  }
}
