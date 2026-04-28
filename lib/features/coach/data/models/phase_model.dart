class PhaseModel {
  final String id;
  final int phaseNumber;
  final String title;
  final String type;          // 'workout' | 'nutrition' | 'combined'
  final String? description;
  final int? durationWeeks;
  final String status;        // 'upcoming' | 'in_progress' | 'completed'
  final DateTime? startedAt;
  final DateTime? completedAt;

  const PhaseModel({
    required this.id,
    required this.phaseNumber,
    required this.title,
    required this.type,
    this.description,
    this.durationWeeks,
    required this.status,
    this.startedAt,
    this.completedAt,
  });

  factory PhaseModel.fromMap(Map<String, dynamic> map) => PhaseModel(
    id:            map['id'],
    phaseNumber:   map['phase_number'],
    title:         map['title'],
    type:          map['type'] ?? 'workout',
    description:   map['description'],
    durationWeeks: map['duration_weeks'],
    status:        map['status'] ?? 'upcoming',
    startedAt:     map['started_at'] != null
                     ? DateTime.parse(map['started_at']) : null,
    completedAt:   map['completed_at'] != null
                     ? DateTime.parse(map['completed_at']) : null,
  );
}
