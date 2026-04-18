import '../entities/subscription_entity.dart';

abstract class ISubscriptionRepository {
  Future<SubscriptionEntity> subscribeToCoach(String coachId);

  Future<void> cancelSubscription(String subscriptionId);

  Future<SubscriptionEntity?> getActiveSubscription();

  Future<List<SubscriptionEntity>> getCoachSubscribers();
}
