import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
String? get currentUserId => supabase.auth.currentUser?.id;

/// Incremented whenever the client's subscription changes (subscribe/cancel).
/// Home and MyProgram listen to this to reload coach assignments immediately
/// without waiting for a Realtime postgres event (which may not be enabled for
/// the subscriptions table).
final subscriptionChangeNotifier = ValueNotifier<int>(0);
