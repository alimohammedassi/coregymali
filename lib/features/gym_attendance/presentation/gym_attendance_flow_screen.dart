import 'package:flutter/material.dart';

import '../../../theme/app_animations.dart';
import '../../../theme/app_colors.dart';
import '../data/selected_gym.dart';
import 'confirm/confirm_gym_screen.dart';
import 'intro/gym_attendance_intro_screen.dart';
import 'map/gym_map_picker_screen.dart';
import 'my_gym/my_gym_screen.dart';
import 'permission_onboarding/activity_notifications_permission_screen.dart';
import 'permission_onboarding/background_location_permission_screen.dart';
import 'permission_onboarding/location_permission_screen.dart';
import 'success/gym_attendance_success_screen.dart';

/// Step indices for the onboarding flow. The host keeps a flat stepper —
/// every step (including the map picker) is built in the body, so the system
/// back button always pops the whole flow back to wherever it was pushed
/// from (profile).
abstract final class _Steps {
  static const intro = 0;
  static const location = 1;
  static const background = 2;
  static const activityNotifications = 3;
  static const map = 4;
  static const confirm = 5;
  static const success = 6;
  static const myGym = 7;
}

/// Host for the full Automatic Gym Attendance onboarding:
/// Intro → Location → Background → Activity+Notifications → Map → Confirm →
/// Success → MyGym.
///
/// Pushed full-screen from the profile entry card; owns nothing but the
/// step index and the selected gym. All permission screens are skippable —
/// skip advances to the next step so the gym can still be configured.
class GymAttendanceFlowScreen extends StatefulWidget {
  const GymAttendanceFlowScreen({super.key});

  @override
  State<GymAttendanceFlowScreen> createState() =>
      _GymAttendanceFlowScreenState();
}

class _GymAttendanceFlowScreenState extends State<GymAttendanceFlowScreen> {
  int _step = _Steps.intro;
  SelectedGym? _selected;

  void _next() => setState(() => _step++);

  @override
  Widget build(BuildContext context) {
    // The final step swaps in without the AnimatedSwitcher delay — success
    // hands off straight to MyGym.
    if (_step == _Steps.myGym) {
      return _scaffold(MyGymScreen());
    }
    return _scaffold(
      AnimatedSwitcher(
        duration: AppDurations.medium,
        switchInCurve: AppCurves.standard,
        switchOutCurve: AppCurves.exit,
        child: KeyedSubtree(
          key: ValueKey<int>(_step),
          child: SizedBox.expand(child: _buildStep()),
        ),
      ),
    );
  }

  Widget _scaffold(Widget body) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: body,
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Steps.intro:
        return GymAttendanceIntroScreen(
          onStart: _next,
          onLater: () => Navigator.of(context).pop(),
        );
      case _Steps.location:
        return LocationPermissionScreen(onContinue: _next, onSkip: _next);
      case _Steps.background:
        return BackgroundLocationPermissionScreen(
          onContinue: _next,
          onSkip: _next,
        );
      case _Steps.activityNotifications:
        return ActivityNotificationsPermissionScreen(
          onContinue: _next,
          onSkip: _next,
        );
      case _Steps.map:
        return GymMapPickerScreen(
          onSelected: (gym) => setState(() {
            _selected = gym;
            _step = _Steps.confirm;
          }),
        );
      case _Steps.confirm:
        final gym = _selected;
        // Unreachable in practice — the map step always sets a selection
        // before confirm — but fall back to the picker instead of crashing.
        if (gym == null) {
          return GymMapPickerScreen(
            onSelected: (g) => setState(() {
              _selected = g;
              _step = _Steps.confirm;
            }),
          );
        }
        return ConfirmGymScreen(
          gym: gym,
          onDone: (saved) => setState(() {
            _step = saved ? _Steps.success : _Steps.map;
          }),
        );
      case _Steps.success:
        return GymAttendanceSuccessScreen(
          onDone: () => setState(() => _step = _Steps.myGym),
        );
      default:
        return MyGymScreen();
    }
  }
}
