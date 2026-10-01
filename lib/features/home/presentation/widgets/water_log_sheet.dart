import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../services/stats_service.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../../../widgets/food/log_telemetry_widgets.dart';
import '../providers/activity_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Water control sheet — opened from the Home water card. Two zones:
//  • Daily water goal: −/+ stepper (250ml steps) + quick goal chips, applied
//    on Save through StatsService.updateGoals and reflected everywhere by
//    invalidating [activityGoalsProvider].
//  • Quick log: amount chips that write TODAY's total immediately through
//    [ActivityWeekNotifier.addWaterMl] (same optimistic path as +250ml).
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showWaterControlSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _WaterControlSheet(),
  );
}

class _WaterControlSheet extends ConsumerStatefulWidget {
  const _WaterControlSheet();

  @override
  ConsumerState<_WaterControlSheet> createState() => _WaterControlSheetState();
}

class _WaterControlSheetState extends ConsumerState<_WaterControlSheet> {
  /// Local goal draft — only written to user_goals on Save (initialized once,
  /// not reset when the provider refreshes mid-session).
  late final int _goalDraft;

  bool _saving = false;
  static const _step = 250;
  static const _minGoal = 1000;
  static const _maxGoal = 6000;

  int _draft = 0;

  @override
  void initState() {
    super.initState();
    final goals = ref.read(activityGoalsProvider).value;
    _goalDraft =
        goals?.waterGoalMl ?? ActivityGoals.defaults.waterGoalMl;
    _draft = _goalDraft;
  }

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode == 'ar';

  TextStyle _style(double size, FontWeight weight, Color color) => TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFamily: AppText.fontFamily(isArabic: _isArabic),
      );

  Future<void> _saveGoal() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      await StatsService().updateGoals({'daily_water_ml': _draft});
      if (!mounted) return;
      // Every surface reads the goal through this provider.
      ref.invalidate(activityGoalsProvider);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final weekAsync = ref.watch(activityWeekProvider);
    final todayMl = weekAsync.value?.last.waterMl ?? 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(22),
            ),
            border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.water_drop_rounded,
                    size: 17,
                    color: AppColors.accentWater,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      l10n.water,
                      style:
                          _style(16, FontWeight.w800, AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    '$todayMl / $_draft ml',
                    style: _style(
                      11,
                      FontWeight.w800,
                      AppColors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Goal editor ──
              TelemetryCapsLabel(l10n.waterGoalEdit, isArabic: _isArabic),
              const SizedBox(height: 10),
              Row(
                children: [
                  _roundButton(
                    icon: Icons.remove_rounded,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _draft = (_draft - _step).clamp(_minGoal, _maxGoal);
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_draft ml',
                        style:
                            _style(16, FontWeight.w900, AppColors.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _roundButton(
                    icon: Icons.add_rounded,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _draft = (_draft + _step).clamp(_minGoal, _maxGoal);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in const [1500, 2000, 2500, 3000, 4000])
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _draft = preset);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _draft == preset
                              ? AppColors.accentWater.withValues(alpha: 0.15)
                              : AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                          border: _draft == preset
                              ? Border.all(
                                  color: AppColors.accentWater.withValues(
                                    alpha: 0.4,
                                  ),
                                )
                              : null,
                        ),
                        child: Text(
                          '$preset ml',
                          style: _style(
                            11,
                            FontWeight.w700,
                            _draft == preset
                                ? AppColors.accentWater
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Quick log (chips write immediately, optimistic) ──
              TelemetryCapsLabel(l10n.waterQuickLog, isArabic: _isArabic),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amount in const [150, 250, 500, 750])
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(activityWeekProvider.notifier)
                            .addWaterMl(amount);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+',
                              style: _style(
                                13,
                                FontWeight.w900,
                                AppColors.accentWater,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$amount ml',
                              style: _style(
                                12.5,
                                FontWeight.w700,
                                AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _saving ? null : _saveGoal,
                      child: Center(
                        child: _saving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : Text(
                                l10n.save,
                                style: _style(
                                  15,
                                  FontWeight.w800,
                                  AppColors.onPrimary,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceContainer,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}
