import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../data/gym.dart';
import '../../data/gym_service.dart';
import '../../data/selected_gym.dart';
import '../gym_attendance_flow_screen.dart';
import '../map/gym_map_picker_screen.dart';

/// The configured gym's home surface: automatic tracking status, the active
/// gym, and "change gym" (re-save without touching attendance history).
///
/// Lives in two places: as the final step of [GymAttendanceFlowScreen] and
/// pushed directly from the profile entry card once a gym is configured.
class MyGymScreen extends StatefulWidget {
  const MyGymScreen({super.key});

  @override
  State<MyGymScreen> createState() => _MyGymScreenState();
}

class _MyGymScreenState extends State<MyGymScreen> {
  final GymService _gymService = GymService();

  Gym? _gym;
  bool _loading = true;
  bool _changing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gym = await _gymService.getActiveGym();
    if (!mounted) return;
    setState(() {
      _gym = gym;
      _loading = false;
    });
  }

  Future<void> _openFlow() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GymAttendanceFlowScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _changeGym() async {
    if (_changing) return;
    setState(() => _changing = true);
    try {
      final gym = await Navigator.of(context).push<SelectedGym>(
        MaterialPageRoute(builder: (_) => const GymMapPickerScreen()),
      );
      if (gym == null) return;
      await _gymService.saveGym(gym);
      if (mounted) await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          content: Text(
            AppLocalizations.of(context)!.gymAttSaveError,
            style: AppText.bodySm.copyWith(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildBackArrow(context),
            Expanded(
              child: _loading
                  ? Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ──
                    Text(
                      l10n.gymAttMyGymTitle,
                      style: AppText.headlineLg.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.gymAttTrackingOn,
                          style: AppText.labelLg.copyWith(
                            color: AppColors.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Hero status card ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderSubtle),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .03),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.fitness_center_rounded,
                              size: 24,
                              color: AppColors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.gymAttTrackingOn,
                            style: AppText.headlineSm.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.gymAttTrackingOnDesc,
                            style: AppText.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (_gym != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 16,
                                    color: AppColors.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _gym!.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.bodyMd.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Actions ──
                    if (_gym == null)
                      FilledButton(
                        onPressed: _openFlow,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryFixed,
                          foregroundColor: AppColors.onPrimary,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: AppText.buttonPrimary,
                        ),
                        child: Text(l10n.gymAttEntryTitle),
                      )
                    else
                      OutlinedButton(
                        onPressed: _changing ? null : _changeGym,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.borderSubtle),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: AppText.buttonSecondary,
                        ),
                        child: Text(l10n.gymAttChangeGym),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top back arrow — pops to wherever the screen was opened from (the
  /// profile entry card, or the whole onboarding flow when it's the final
  /// step). RTL-aware per the app's rounded back-arrow convention.
  Widget _buildBackArrow(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.arrow_forward_rounded
              : Icons.arrow_back_rounded,
          size: 22,
          color: AppColors.onSurface,
        ),
      ),
    );
  }
}
