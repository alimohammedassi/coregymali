import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_mode_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';

/// Compact System / Light / Dark segmented control for the profile
/// appearance row. Icon-only so it fits as a row's trailing control —
/// selected option gets the volt fill with ink text (never white-on-volt).
class ThemeModeToggle extends StatelessWidget {
  const ThemeModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<ThemeModeProvider>();

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeOption(
            icon: Icons.brightness_auto_outlined,
            tooltip: l10n.themeSystem,
            isSelected: provider.mode == ThemeMode.system,
            onTap: () => _select(context, provider, ThemeMode.system),
          ),
          _ModeOption(
            icon: Icons.light_mode_outlined,
            tooltip: l10n.themeLight,
            isSelected: provider.mode == ThemeMode.light,
            onTap: () => _select(context, provider, ThemeMode.light),
          ),
          _ModeOption(
            icon: Icons.dark_mode_outlined,
            tooltip: l10n.themeDark,
            isSelected: provider.mode == ThemeMode.dark,
            onTap: () => _select(context, provider, ThemeMode.dark),
          ),
        ],
      ),
    );
  }

  void _select(
    BuildContext context,
    ThemeModeProvider provider,
    ThemeMode mode,
  ) {
    HapticFeedback.selectionClick();
    provider.setMode(mode);
  }
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppDurations.medium,
          curve: AppCurves.standard,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryFixed : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected
                ? AppColors.onPrimary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
