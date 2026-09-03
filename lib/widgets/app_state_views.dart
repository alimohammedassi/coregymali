import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Kinetic Obsidian — shared async-state views.
///
/// One loading / empty / error language for every screen: volt progress,
/// glass panel, icon inside a volt-tinted ring. Feature-local state widgets
/// (e.g. CoachEmptyState) delegate here instead of re-styling.
class AppStateViews {
  AppStateViews._();

  static Widget loading({
    String? message,
    double strokeWidth = 2.5,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: AppColors.primaryFixed,
                strokeWidth: strokeWidth,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.bodyMd.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget empty({
    required String message,
    IconData icon = Icons.inbox_rounded,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lightGreen,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.glassBorderActive),
                ),
              ),
              child: Icon(icon, color: AppColors.primaryFixed, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.bodyMd.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryFixed,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  actionLabel.toUpperCase(),
                  style: AppText.labelLg.copyWith(
                    color: AppColors.primaryFixed,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget error({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.10),
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.error.withValues(alpha: 0.30)),
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.bodyMd.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(
                'RETRY',
                style: AppText.labelLg.copyWith(
                  color: AppColors.onPrimary,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
