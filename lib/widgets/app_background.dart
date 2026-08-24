import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Fresh, energetic and playful background for CoreGym
/// Supports light clean canvas (#F7F9F8) with soft green ambient glow accents
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showGlowOrbs;

  const AppBackground({
    super.key,
    required this.child,
    this.showGlowOrbs = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          if (showGlowOrbs) ...[
            // Soft ambient top-right green glow
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryGreen.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Soft ambient bottom-left subtle glow
            Positioned(
              bottom: 100,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accentWater.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
          widgetChild(child),
        ],
      ),
    );
  }

  Widget widgetChild(Widget c) => SafeArea(
        top: false,
        bottom: false,
        child: c,
      );
}

/// Soft white card with rounded corners, crisp subtle border and lightweight shadow
class PlayfulCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const PlayfulCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 20,
    this.borderColor,
    this.borderWidth = 1.0,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.borderSubtle,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }
    return cardContent;
  }
}