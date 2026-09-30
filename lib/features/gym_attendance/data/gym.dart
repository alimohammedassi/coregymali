import 'selected_gym.dart';

/// A `gyms` table row. Multiple rows per user are allowed over time; the
/// newest row (created_at desc) is the active gym.
class Gym {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusM;

  const Gym({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusM = 120,
  });

  factory Gym.fromMap(Map<String, dynamic> map) {
    return Gym(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radiusM: (map['radius_m'] as num?)?.toInt() ?? 120,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius_m': radiusM,
    };
  }

  /// View-model for the picker/confirm screens.
  SelectedGym toSelected({double? distanceMeters}) {
    return SelectedGym(
      name: name,
      latitude: latitude,
      longitude: longitude,
      radiusM: radiusM,
      distanceMeters: distanceMeters,
    );
  }
}
