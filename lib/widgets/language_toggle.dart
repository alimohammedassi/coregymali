import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../theme/app_colors.dart';

class LanguageToggle extends StatelessWidget {
  final bool compact; // true = icon only, false = full pill
  const LanguageToggle({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocaleProvider>();
    final isAr = provider.isArabic;

    if (compact) {
      // Icon-only version for inside the app (top bar)
      return GestureDetector(
        onTap: provider.toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryFixed.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🌐', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              isAr ? 'EN' : 'عر',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryFixed,
              ),
            ),
          ]),
        ),
      );
    }

    // Full pill version for login screen
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _LangOption(
          label: 'EN',
          flag: '🇺🇸',
          isSelected: !isAr,
          onTap: () => provider.setLocale(const Locale('en')),
        ),
        _LangOption(
          label: 'عر',
          flag: '🇸🇦',
          isSelected: isAr,
          onTap: () => provider.setLocale(const Locale('ar')),
        ),
      ]),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label, flag;
  final bool isSelected;
  final VoidCallback onTap;
  const _LangOption({required this.label, required this.flag,
    required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryFixed : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(flag, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          )),
        ]),
      ),
    );
  }
}
