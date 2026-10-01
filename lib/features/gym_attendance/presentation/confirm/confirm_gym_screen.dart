import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../data/gym_service.dart';
import '../../data/location_service.dart';
import '../../data/selected_gym.dart';

/// Phase-1 geofence radius — mirrored from the SQL migration default.
const int _kTrackingRadiusM = 120;

/// Final review before tracking starts. Saves the gym on the primary CTA;
/// `onDone(false)` sends the flow back to the map to re-pick.
class ConfirmGymScreen extends StatefulWidget {
  final SelectedGym gym;
  final ValueChanged<bool> onDone;

  const ConfirmGymScreen({
    super.key,
    required this.gym,
    required this.onDone,
  });

  @override
  State<ConfirmGymScreen> createState() => _ConfirmGymScreenState();
}

class _ConfirmGymScreenState extends State<ConfirmGymScreen> {
  final GymService _gymService = GymService();
  final LocationService _location = LocationService();

  bool _saving = false;
  bool _failed = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await _gymService.saveGym(widget.gym);
      if (!mounted) return;
      widget.onDone(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final gym = widget.gym;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top back arrow — returns to the map step via onDone(false).
              // RTL-aware per the app's rounded back-arrow convention.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  onPressed: _saving ? null : () => widget.onDone(false),
                  icon: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.arrow_forward_rounded
                        : Icons.arrow_back_rounded,
                    size: 22,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              Text(
                l10n.gymAttConfirmAreaTitle,
                style: AppText.headlineMd.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
                          child: Text(
                            gym.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.titleMd.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (gym.distanceMeters != null) ...[
                      _Row(
                        icon: Icons.near_me_rounded,
                        label: l10n.gymAttDistanceValue(
                          _location.formatDistance(gym.distanceMeters!),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _Row(
                      icon: Icons.radar_rounded,
                      label:
                          '${l10n.gymAttTrackingRadius} · ${l10n.gymAttRadiusValue('$_kTrackingRadiusM')}',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        l10n.gymAttConfirmExplain,
                        style: AppText.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_failed) ...[
                Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.gymAttSaveError,
                        style: AppText.bodySm.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryFixed,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor:
                      AppColors.primaryFixed.withValues(alpha: .55),
                  disabledForegroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: AppText.buttonPrimary,
                ),
                child: _saving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(l10n.gymAttSaving),
                        ],
                      )
                    : Text(l10n.gymAttStartTracking),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _saving ? null : () => widget.onDone(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  textStyle: AppText.buttonSecondary,
                ),
                child: Text(l10n.gymAttChangeGym),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Row({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.onPrimaryContainer),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyMd.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
