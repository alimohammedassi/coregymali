import 'package:flutter/material.dart';

import '../../../../theme/app_text.dart';

// ── Coach feature shared design tokens ────────────────────────────────────────
// Centralised so every coach screen can import a single file.

const kCoachBg = Color(0xFF0E0E0E);
const kCoachCard = Color(0xFF1A1919);
const kCoachCard2 = Color(0xFF201F1F);
const kCoachGold = Color(0xFFC9A84C);
const kCoachMuted = Color(0xFF8E8E93);
const kCoachSubtle = Color(0xFF636366);
const kCoachBorder = Color(0x14FFFFFF);

// ── Shared widgets ─────────────────────────────────────────────────────────────

class CoachAvatar extends StatelessWidget {
  final String? url;
  final double size;
  const CoachAvatar({super.key, this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: kCoachCard2,
      backgroundImage: url != null ? NetworkImage(url!) : null,
      child: url == null
          ? Icon(Icons.person_rounded, color: kCoachMuted, size: size * 0.5)
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
            return const Icon(Icons.star_rounded, color: kCoachGold, size: 14);
          } else if (i < rating) {
            return const Icon(Icons.star_half_rounded,
                color: kCoachGold, size: 14);
          }
          return const Icon(Icons.star_outline_rounded,
              color: kCoachSubtle, size: 14);
        }),
        const SizedBox(width: 4),
        Text(rating.toStringAsFixed(1),
            style: AppText.bodySm.copyWith(color: kCoachMuted)),
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
        color: kCoachGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kCoachGold.withOpacity(0.25)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppText.labelMd.copyWith(color: kCoachGold, letterSpacing: 0.5),
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
                color: Color(0xFFFF7351), size: 48),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: AppText.bodySm.copyWith(color: kCoachMuted)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kCoachGold,
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
            Icon(icon, color: kCoachSubtle, size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: AppText.bodyMd.copyWith(color: kCoachMuted, height: 1.6)),
          ],
        ),
      ),
    );
  }
}
