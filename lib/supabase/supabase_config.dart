import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl =
      'https://mkrjvrnysuvtokqkyoll.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_JhvLrN-jg2v5aRr9DvLxdg_wqpip5Eq';

  /// OneSignal app id — provided by the OneSignal dashboard (public value,
  /// safe to ship in the app). The REST API key must NEVER live here; it is
  /// a Supabase Edge Function secret (ONESIGNAL_REST_API_KEY).
  static const String oneSignalAppId =
      'fdc71b2a-afae-4c45-ac44-238d2aeed089';

  /// Core Dashboard website — the ONLY path to a coach account.
  /// Customers are created in-app; coaches sign up on the website.
  /// TODO: replace with the production URL before release.
  static const String dashboardUrl = 'http://localhost:3000/signup';

  static SupabaseClient get client => Supabase.instance.client;
}
