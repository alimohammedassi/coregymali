import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Thin wrapper over geolocator — position fixes only. Permissions are NOT
/// handled here: the permission-onboarding screens use permission_handler
/// directly (geolocator's permission API is intentionally unused).
class LocationService {
  /// One-shot position fix. Returns null on any failure (service disabled,
  /// permission denied, timeout after ~10s, plugin error) so callers can
  /// fall back to a default map center / hide distance without crashing.
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('❌ getCurrentPosition failed: $e');
      return null;
    }
  }

  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Straight-line distance in meters — passthrough to geolocator.
  Future<double> distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Future.value(
      Geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      ),
    );
  }

  /// Plain formatted distance for l10n placeholders:
  /// <1000 → "850 m", ≥1000 → "1.2 km".
  String formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}
