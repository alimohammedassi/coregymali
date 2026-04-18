class ClientSummary {
  final String clientId;
  final String name;
  final String? avatarUrl;
  final DateTime subscriptionSince;
  final DateTime? lastActive; // from daily_summary.summary_date
  final double todayCalories;
  final bool todayWorkoutDone;

  const ClientSummary({
    required this.clientId,
    required this.name,
    this.avatarUrl,
    required this.subscriptionSince,
    this.lastActive,
    required this.todayCalories,
    required this.todayWorkoutDone,
  });

  ClientSummary copyWith({
    String? clientId,
    String? name,
    String? avatarUrl,
    DateTime? subscriptionSince,
    DateTime? lastActive,
    double? todayCalories,
    bool? todayWorkoutDone,
  }) {
    return ClientSummary(
      clientId: clientId ?? this.clientId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      subscriptionSince: subscriptionSince ?? this.subscriptionSince,
      lastActive: lastActive ?? this.lastActive,
      todayCalories: todayCalories ?? this.todayCalories,
      todayWorkoutDone: todayWorkoutDone ?? this.todayWorkoutDone,
    );
  }
}
