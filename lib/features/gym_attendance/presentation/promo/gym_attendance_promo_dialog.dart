import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../services/supabase_client.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../data/gym_service.dart';
import '../widgets/gym_pin_glyph.dart';

/// Home promo popup for Automatic Gym Attendance — the in-app "ad": the
/// pin + geofence animation, a one-line pitch in the app's active language,
/// and a CTA that lands the user on Profile where the entry card lives.
///
/// Show policy: only while NO gym is configured, at most once every
/// [_reshowAfter] days per signed-in user (persisted), and at most once per
/// app session. A dismissal and a CTA tap both count as "shown" — the next
/// eligible moment is [_reshowAfter] later, and configuring a gym silences
/// the promo forever.
class GymAttendancePromo {
  GymAttendancePromo._();

  static const String _kPrefsPrefix = 'gym_att_promo_last_shown_';
  static const Duration _reshowAfter = Duration(days: 7);
  static bool _checkedThisSession = false;

  /// Fire-and-forget from Home's first frame. Best-effort by design — any
  /// failure stays swallowed so the promo can never break the dashboard.
  static Future<void> maybeShow(
    BuildContext context, {
    required VoidCallback onOpenProfile,
  }) async {
    if (_checkedThisSession) return;
    _checkedThisSession = true;
    try {
      // Only for users who haven't set the feature up yet.
      if (await GymService().hasConfiguredGym()) return;

      // Frequency cap — once per [_reshowAfter] per signed-in user.
      final prefs = await SharedPreferences.getInstance();
      final key = '$_kPrefsPrefix${currentUserId ?? 'anon'}';
      final lastShownMs = prefs.getInt(key);
      if (lastShownMs != null &&
          DateTime.now().difference(
                DateTime.fromMillisecondsSinceEpoch(lastShownMs),
              ) <
              _reshowAfter) {
        return;
      }
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);

      // Let the dashboard settle (and any first-frame dialogs land) before
      // the promo appears.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => _GymAttendancePromoCard(
          onOpenProfile: () {
            Navigator.of(dialogContext).pop();
            onOpenProfile();
          },
          onDismiss: () => Navigator.of(dialogContext).pop(),
        ),
      );
    } catch (_) {
      // Promo is never worth an error surface.
    }
  }
}

class _GymAttendancePromoCard extends StatelessWidget {
  final VoidCallback onOpenProfile;
  final VoidCallback onDismiss;

  const _GymAttendancePromoCard({
    required this.onOpenProfile,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GymPinGlyph(),
          const SizedBox(height: 16),
          Text(
            l10n.gymAttIntroTitle,
            textAlign: TextAlign.center,
            style: AppText.headlineMd.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.gymAttIntroBody,
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onOpenProfile,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryFixed,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: AppText.buttonPrimary,
            ),
            child: Text(l10n.gymAttPromoCta),
          ),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(l10n.gymAttPermSkip),
          ),
        ],
      ),
    );
  }
}
