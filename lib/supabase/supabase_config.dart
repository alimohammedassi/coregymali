import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl =
      'https://mkrjvrnysuvtokqkyoll.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rcmp2cm55c3V2dG9rcWt5b2xsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNDExMTgsImV4cCI6MjA4OTcxNzExOH0.Nf1xdRt2W1Ped0gulhdId2iAFC0KEp36-JD_4ey9dzg';

  static SupabaseClient get client => Supabase.instance.client;
}
