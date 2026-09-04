import 'package:flutter_test/flutter_test.dart';

import 'package:core/screens/exercise_detail_sheet.dart';

/// Contract tests for the workout-set payload produced by ExerciseDetailSheet
/// and consumed by FitnessCoachScreen / WorkoutService.logSet.
///
/// Regression guard: fitness_coach_screen.dart reads `setData['setNumber']`,
/// `setData['reps']` and `setData['weightKg']` — if a key here ever drifts
/// (e.g. renaming weightKg back to weight), set logging silently breaks.
void main() {
  group('SetData.toJson contract', () {
    final json = SetData(
      setNumber: 2,
      reps: 10,
      weight: 47.5,
      timestamp: DateTime.parse('2026-09-04T10:00:00.000Z'),
    ).toJson();

    test('exposes the keys the log-set consumers read', () {
      expect(json['setNumber'], 2);
      expect(json['reps'], 10);
      expect(json['weightKg'], 47.5);
    });

    test('uses weightKg (never "weight") so map reads cannot null-crash', () {
      expect(json.containsKey('weightKg'), isTrue);
      expect(json.containsKey('weight'), isFalse);
    });

    test('value types survive the map hop (int setNumber, double weightKg)', () {
      expect(json['setNumber'], isA<int>());
      expect(json['weightKg'], isA<double>());
    });

    test('null reps is allowed and preserved', () {
      final json = SetData(
        setNumber: 1,
        reps: null,
        weight: 0,
        timestamp: DateTime.parse('2026-09-04T10:00:00.000Z'),
      ).toJson();
      expect(json['reps'], isNull);
      expect(json['weightKg'], 0.0);
    });
  });
}
