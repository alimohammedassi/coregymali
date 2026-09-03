import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_mode_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Segmented System / Light / Dark control for the Profile screen.
/// Selected option gets the volt fill with ink text (never white-on-volt).
class ThemeModeToggle extends StatelessWidget {
  const ThemeModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<ThemeModeProvider>();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeOption(
              icon: Icons.brightness_auto_outlined,
              label: l10n.themeSystem,
              isSelected: provider.mode == ThemeMode.system,
              onTap: () => _select(context, provider, ThemeMode.system),
            ),
          ),
          Expanded(
            child: _ModeOption(
              icon: Icons.light_mode_outlined,
              label: l10n.themeLight,
              isSelected: provider.mode == ThemeMode.light,
              onTap: () => _select(context, provider, ThemeMode.light),
            ),
          ),
          Expanded(
            child: _ModeOption(
              icon: Icons.dark_mode_outlined,
              label: l10n.themeDark,
              isSelected: provider.mode == ThemeMode.dark,
              onTap: () => _select(context, provider, ThemeMode.dark),
            ),
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
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryFixed : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryGlow,
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppColors.onPrimary
                  : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.onPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
