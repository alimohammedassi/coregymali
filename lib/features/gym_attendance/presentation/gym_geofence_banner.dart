import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_animations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';
import '../data/gym_geofence_watcher.dart';

/// In-app surface of [GymGeofenceWatcher] on Home: a compact accent-tinted
/// banner — the app's inline-banner anatomy (tint + hairline border), at the
/// gym-attendance card radius — that counts the 25-minute dwell down while
/// the user is inside their gym's area and confirms the recorded visit.
///
/// Idle renders [SizedBox.shrink] and NOTHING else runs: the pulse ticker
/// only exists while the inside card is mounted, and watcher notifications
/// are scoped to this slot (the home scroll body never rebuilds from them).
class GymGeofenceBanner extends StatelessWidget {
  const GymGeofenceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final watcher = GymGeofenceWatcher.instance;
    return AnimatedBuilder(
      animation: watcher,
      builder: (context, _) => switch (watcher.state) {
        GymGeofenceState.idle => const SizedBox.shrink(),
        GymGeofenceState.inside => _InsideCard(watcher: watcher),
        GymGeofenceState.confirmed => _ConfirmedCard(
            minutes: watcher.confirmedMinutes ?? GymGeofenceWatcher.dwellMinutes,
          ),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inside — pulsing dot + title + mm:ss countdown + cancel (the only action)
// ─────────────────────────────────────────────────────────────────────────────

class _InsideCard extends StatelessWidget {
  final GymGeofenceWatcher watcher;

  const _InsideCard({required this.watcher});

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _formatMmSs(Duration remaining) =>
      '${_twoDigits(remaining.inMinutes)}:'
      '${_twoDigits(remaining.inSeconds.remainder(60))}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final remaining = watcher.remainingDwell ?? Duration.zero;

    return Container(
      // Bottom margin keeps the home rhythm (12px within a section) while
      // the idle slot above stays exactly zero-height.
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const _PulsingDot(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.gymAttBannerInsideTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelLg.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                // One Text so RTL bidi ordering keeps label + clock together;
                // tabular figures stop the mm:ss digits from wobbling.
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: l10n.gymAttBannerCountdownLabel,
                        style: AppText.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextSpan(
                        text: '  ${_formatMmSs(remaining)}',
                        style: AppText.labelLg.copyWith(
                          color: AppColors.onPrimaryContainer,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: watcher.cancelSession,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.onPrimaryContainer,
              textStyle: AppText.labelLg,
            ),
            child: Text(l10n.gymAttBannerCancel),
          ),
        ],
      ),
    );
  }
}

/// Accent dot with a subtle 2 s breathing halo. The ticker lives ONLY here —
/// unmounted the moment the banner collapses, and fully static under
/// reduced-motion.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  // Subtle 2 s pulse — slow token × 5.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppDurations.slow * 5,
  );

  bool _repeating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is only readable here (never in initState) — and this stays
    // subscribed, so a reduced-motion toggle stops/restarts the pulse.
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced && _repeating) {
      _pulse.stop();
      _repeating = false;
    } else if (!reduced && !_repeating) {
      _pulse.repeat();
      _repeating = true;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: reducedMotion
            ? _dot()
            : AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final breathe = math.sin(_pulse.value * 2 * math.pi);
                  return _dot(scale: 1 + 0.20 * breathe);
                },
              ),
      ),
    );
  }

  Widget _dot({double scale = 1}) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.35),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirmed — visit recorded, echo state (no actions)
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmedCard extends StatelessWidget {
  final int minutes;

  const _ConfirmedCard({required this.minutes});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 22,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.gymAttBannerConfirmed,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelLg.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.gymAttBannerConfirmedDesc('$minutes'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
