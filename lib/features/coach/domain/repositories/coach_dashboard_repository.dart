import '../entities/client_summary_entity.dart';
import '../entities/client_full_data_entity.dart';

abstract class ICoachDashboardRepository {
  /// Returns summaries for all active clients subscribed to the current coach.
  Future<List<ClientSummary>> getActiveClients();

  /// Returns full health & training data for [clientId] within the given range.
  /// [from] defaults to 30 days ago; [to] defaults to today when null.
  Future<ClientFullData> getClientData(
    String clientId, {
    DateTime? from,
    DateTime? to,
  });
}
