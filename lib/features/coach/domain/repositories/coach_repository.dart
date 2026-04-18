import '../entities/coach_entity.dart';

abstract class ICoachRepository {
  Future<List<CoachEntity>> getCoaches({
    String? specialization,
    double? maxPrice,
    double? minRating,
  });

  Future<CoachEntity> getCoachById(String coachId);

  Future<CoachEntity> createCoachProfile(CoachEntity coach);

  Future<CoachEntity> updateCoachProfile(CoachEntity coach);
}
