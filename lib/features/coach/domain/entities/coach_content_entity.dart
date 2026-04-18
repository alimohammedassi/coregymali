class CoachContentEntity {
  final String id;
  final String coachId;
  final String title;
  final String? description;
  final String type;
  final String fileUrl;
  final String? thumbnailUrl;
  final bool isPublic;
  final int? fileSizeKb;
  final int? sortOrder;
  final DateTime createdAt;

  CoachContentEntity({
    required this.id,
    required this.coachId,
    required this.title,
    this.description,
    required this.type,
    required this.fileUrl,
    this.thumbnailUrl,
    required this.isPublic,
    this.fileSizeKb,
    this.sortOrder,
    required this.createdAt,
  });

  factory CoachContentEntity.fromJson(Map<String, dynamic> json) {
    return CoachContentEntity(
      id: json['id'].toString(),
      coachId: json['coach_id'].toString(),
      title: json['title'] ?? '',
      description: json['description'],
      type: json['type'] ?? 'unknown',
      fileUrl: json['file_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      isPublic: json['is_public'] ?? false,
      fileSizeKb: json['file_size_kb'],
      sortOrder: json['sort_order'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
