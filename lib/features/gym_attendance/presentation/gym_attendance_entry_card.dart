import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';
import '../data/gym_geofence_watcher.dart';
import '../data/gym_service.dart';
import 'gym_attendance_flow_screen.dart';
import 'my_gym/my_gym_screen.dart';

/// Profile entry point for Automatic Gym Attendance. Routes to the active
/// gym's status screen when one is configured, otherwise starts the
/// onboarding flow.
class GymAttendanceEntryCard extends StatefulWidget {
  const GymAttendanceEntryCard({super.key});

  @override
  State<GymAttendanceEntryCard> createState() => _GymAttendanceEntryCardState();
}

class _GymAttendanceEntryCardState extends State<GymAttendanceEntryCard> {
  final GymService _gymService = GymService();

  /// Null while the first check is in flight — the subtitle falls back to
  /// the plain description until the state is known.
  bool? _configured;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final configured = await _gymService.hasConfiguredGym();
    if (!mounted) return;
    setState(() => _configured = configured);
  }

  Future<void> _open() async {
    HapticFeedback.lightImpact();
    // Re-check at tap time — the initState result may be stale.
    final configured = await _gymService.hasConfiguredGym();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            configured ? const MyGymScreen() : const GymAttendanceFlowScreen(),
      ),
    ).whenComplete(() {
      // Coming back: the flow may have just configured a gym — re-arm
      // detection so a newly-configured gym starts without an app restart.
      unawaited(GymGeofenceWatcher.instance.refresh());
    });
    // Coming back: refresh this card's configured subtitle too.
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final active = _configured == true;
    return Semantics(
      button: true,
      label: l10n.gymAttEntryTitle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Accent-tinted icon container — matches the profile card
              // icon-badge convention (coach CTA / legal rows).
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  size: 22,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.gymAttEntryTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyLg.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (active)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppColors.onPrimaryContainer,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              l10n.gymAttEntryActive,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodySm.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        l10n.gymAttEntryDesc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // RTL-aware chevron — same pattern as profile.dart's rows.
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.arrow_back_ios_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
