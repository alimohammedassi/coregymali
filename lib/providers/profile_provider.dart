import 'package:flutter/material.dart';
import '../services/supabase_client.dart';
import '../services/onboarding_service.dart';

class ProfileProvider extends ChangeNotifier {
  bool _needsUserOnboarding = false;
  bool _needsCoachSetup = false;
  bool _needsRoleSelection = false;
  bool _isCoach = false;
  bool _isLoading = true;

  bool get needsUserOnboarding => _needsUserOnboarding;
  bool get needsCoachSetup => _needsCoachSetup;
  bool get needsRoleSelection => _needsRoleSelection;
  bool get isCoach => _isCoach;
  bool get isReady => !_isLoading && !_needsUserOnboarding && !_needsCoachSetup && !_needsRoleSelection;
  bool get isLoading => _isLoading;

  Future<void> fetchProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = supabase.auth.currentUser;
      debugPrint("ProfileProvider: Fetching for user ${user?.id}");
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Check user onboarding
      final done = await OnboardingService().isCompleted();
      _needsUserOnboarding = !done;
      debugPrint("ProfileProvider: User onboarding done: $done");

      // check role
      debugPrint("ProfileProvider: Checking role in profiles table...");
      final profileRow = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      
      debugPrint("ProfileProvider: profileRow: $profileRow");
      
      if (profileRow == null || profileRow['role'] == null) {
        _needsRoleSelection = true;
        _isCoach = false;
      } else {
        _isCoach = profileRow['role'] == 'coach';
        
        // If the database assigned a default 'user' role but they haven't completed
        // onboarding yet, it means they are a brand new user who hasn't explicitly
        // chosen their path. We should ask them!
        if (profileRow['role'] == 'user' && !done) {
          _needsRoleSelection = true;
        } else {
          _needsRoleSelection = false;
        }
      }
      debugPrint("ProfileProvider: needsRoleSelection: $_needsRoleSelection, isCoach: $_isCoach");

      if (_isCoach) {
        // Check coach onboarding
        final coachRow = await supabase
            .from('coach_onboarding')
            .select('is_completed')
            .eq('user_id', user.id)
            .maybeSingle();
            
        _needsCoachSetup = coachRow?['is_completed'] != true;
      } else {
        _needsCoachSetup = false;
      }

    } catch (e) {
      debugPrint("ProfileProvider error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setRole(String role) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('profiles').upsert({
        'id': user.id,
        'role': role,
        'email': user.email,
        'name': user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? user.email?.split('@')[0] ?? 'User',
      }, onConflict: 'id');
      
      await fetchProfile();
    } catch (e) {
      debugPrint("Error setting role: $e");
      rethrow;
    }
  }

  void clear() {
    _needsUserOnboarding = false;
    _needsCoachSetup = false;
    _isCoach = false;
    _isLoading = true;
    notifyListeners();
  }
}
