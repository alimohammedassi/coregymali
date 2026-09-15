import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

/// Shared card chrome for the Activity section's Water/Steps pair — same
/// surface, radius, hairline border and soft shadow language as the hero
/// fuel card above it.
class ActivityCardShell extends StatelessWidget {
  final Widget child;

  const ActivityCardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: child,
    );
  }
}
