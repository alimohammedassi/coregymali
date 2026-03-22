import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
String? get currentUserId => supabase.auth.currentUser?.id;
