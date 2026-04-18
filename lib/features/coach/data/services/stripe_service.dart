import 'package:supabase_flutter/supabase_flutter.dart';

class StripeService {
  final SupabaseClient _supabase;

  StripeService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  /// Calls the create-checkout-session edge function.
  /// Returns the Stripe Checkout URL to open in the browser.
  Future<({String checkoutUrl, String sessionId})> createCheckoutSession({
    required String coachId,
    required String tier,
  }) async {
    final response = await _supabase.functions.invoke(
      'create-checkout-session',
      body: {'coach_id': coachId, 'tier': tier},
    );

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unknown error';
      throw Exception('Checkout failed: $error');
    }

    final data = response.data as Map<String, dynamic>;
    return (
      checkoutUrl: data['checkout_url'] as String,
      sessionId: data['session_id'] as String,
    );
  }

  /// Calls the get-subscription-status edge function after the deep link redirect.
  Future<Map<String, dynamic>> getSessionStatus(String sessionId) async {
    final response = await _supabase.functions.invoke(
      'get-subscription-status',
      body: {'session_id': sessionId},
    );

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unknown error';
      throw Exception('Status check failed: $error');
    }

    return response.data as Map<String, dynamic>;
  }
}
