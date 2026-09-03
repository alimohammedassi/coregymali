import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../../../widgets/app_state_views.dart';

// ── Coach feature shared design tokens ────────────────────────────────────────
// Aliases over AppColors (the single source of truth) so coach screens stay
// visually in sync with the app-wide Kinetic Obsidian & Electric Volt system.

Color get kCoachBg => AppColors.background;
Color get kCoachCard => AppColors.surfaceContainer;
Color get kCoachCard2 => AppColors.surfaceContainerHigh;
Color get kCoachGold => AppColors.tertiary;
Color get kCoachMuted => AppColors.textSecondary;
Color get kCoachSubtle => AppColors.textMuted;
Color get kCoachBorder => AppColors.glassBorder;

// ── Shared widgets ─────────────────────────────────────────────────────────────

class CoachAvatar extends StatelessWidget {
  final String? url;
  final double size;
  const CoachAvatar({super.key, this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surfaceContainerHigh,
      backgroundImage: url != null ? NetworkImage(url!) : null,
      child: url == null
          ? Icon(Icons.person_rounded, color: AppColors.onSurfaceVariant, size: size * 0.5)
          : null,
    );
  }
}

class CoachStarRating extends StatelessWidget {
  final double rating;
  const CoachStarRating({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          if (i < rating.floor()) {
            return  Icon(Icons.star_rounded, color: AppColors.tertiary, size: 14);
          } else if (i < rating) {
            return  Icon(Icons.star_half_rounded,
                color: AppColors.tertiary, size: 14);
          }
          return  Icon(Icons.star_outline_rounded,
              color: AppColors.outline, size: 14);
        }),
        const SizedBox(width: 4),
        Text(rating.toStringAsFixed(1),
            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
      ],
    );
  }
}

class CoachSpecChip extends StatelessWidget {
  final String label;
  const CoachSpecChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.25)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppText.labelMd.copyWith(color: AppColors.tertiary, letterSpacing: 0.5),
      ),
    );
  }
}

class CoachErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const CoachErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppStateViews.error(message: message, onRetry: onRetry);
  }
}

class CoachEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const CoachEmptyState(
      {super.key,
      required this.message,
      this.icon = Icons.inbox_rounded});

  @override
  Widget build(BuildContext context) {
    return AppStateViews.empty(message: message, icon: icon);
  }
}
