/// The gym the user just picked on the map — an in-memory value object that
/// travels through the onboarding flow (map → confirm → saved as a `gyms`
/// row by GymService). Not persisted directly; see [Gym].
class SelectedGym {
  final String name;
  final double latitude;
  final double longitude;
  final int radiusM;

  /// Straight-line distance from the user's position to the gym at pick time
  /// (null when the user's location was unknown — the UI hides the distance).
  final double? distanceMeters;

  const SelectedGym({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusM = 120,
    this.distanceMeters,
  });
}
