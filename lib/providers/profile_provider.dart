import 'package:flutter/material.dart';
import '../services/supabase_client.dart';
import '../services/onboarding_service.dart';

class ProfileProvider extends ChangeNotifier {
  bool _needsUserOnboarding = false;
  bool _needsCoachSetup = false;
  bool _isCoach = false;
  bool _isLoading = true;

  bool get needsUserOnboarding => _needsUserOnboarding;
  bool get needsCoachSetup => _needsCoachSetup;
  bool get isCoach => _isCoach;
  bool get isReady => !_isLoading && !_needsUserOnboarding && !_needsCoachSetup;
  bool get isLoading => _isLoading;

  Future<void> fetchProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Check user onboarding
      final done = await OnboardingService().isCompleted();
      _needsUserOnboarding = !done;

      // check role
      final profileRow = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      
      _isCoach = profileRow?['role'] == 'coach';

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

  void clear() {
    _needsUserOnboarding = false;
    _needsCoachSetup = false;
    _isCoach = false;
    _isLoading = true;
    notifyListeners();
  }
}
