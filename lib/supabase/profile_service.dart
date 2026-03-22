import 'supabase_config.dart';

class ProfileService {
  final _client = SupabaseConfig.client;

  Future<Map<String, dynamic>?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      return await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    data['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('profiles').update(data).eq('id', userId);
  }
}
