import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';

// ── Coach feature shared design tokens ────────────────────────────────────────
// Aliases over AppColors (the single source of truth) so coach screens stay
// visually in sync with the rest of the app's light Kalee palette.
// NOTE: these previously pointed at dark-theme leftovers (white text / glass
// borders on a white canvas), which rendered coach screens unreadable.

const kCoachBg = AppColors.background;
const kCoachCard = AppColors.surface;
const kCoachCard2 = AppColors.surfaceContainerHigh;
const kCoachGold = AppColors.tertiary;
const kCoachMuted = AppColors.textSecondary;
const kCoachSubtle = AppColors.textMuted;
const kCoachBorder = AppColors.borderSubtle;

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
            return const Icon(Icons.star_rounded, color: AppColors.tertiary, size: 14);
          } else if (i < rating) {
            return const Icon(Icons.star_half_rounded,
                color: AppColors.tertiary, size: 14);
          }
          return const Icon(Icons.star_outline_rounded,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tertiary,
                  foregroundColor: Colors.black),
              onPressed: onRetry,
              child: Text('RETRY',
                  style: AppText.buttonPrimary.copyWith(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.outline, size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant, height: 1.6)),
          ],
        ),
      ),
    );
  }
}
