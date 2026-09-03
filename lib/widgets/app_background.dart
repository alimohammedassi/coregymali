import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Kinetic Obsidian canvas for CoreGym.
/// Near-black (#000000) base with soft volt/cyan ambient glow orbs so cards
/// built on the glass token system read as liquid glass, not flat gray.
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
            // Soft ambient top-right volt glow
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
                      AppColors.glowOrbPrimary,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Soft ambient bottom-left cyan glow
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
                      AppColors.glowOrbSecondary,
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

/// Shared glass card: elevated obsidian surface, 8%-white hairline border,
/// deep shadow. The single card language for list items, panels and sheets.
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
        color: backgroundColor ?? AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.glassBorder,
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
