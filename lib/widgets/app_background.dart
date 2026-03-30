import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated background with gradient overlay and floating glow orbs
/// Matches the Kinetic Obsidian — Electric Volt design system
class AppBackground extends StatefulWidget {
  final Widget child;
  final bool showGlowOrbs;
  final bool animate;
  final List<Color>? additionalGlowColors;

  const AppBackground({
    super.key,
    required this.child,
    this.showGlowOrbs = true,
    this.animate = true,
    this.additionalGlowColors,
  });

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with TickerProviderStateMixin {
  late AnimationController _orb1Controller;
  late AnimationController _orb2Controller;
  late AnimationController _orb3Controller;

  @override
  void initState() {
    super.initState();
    _orb1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat(reverse: true);

    _orb2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    )..repeat(reverse: true);

    _orb3Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    )..repeat(reverse: true);

    if (!widget.animate) {
      _orb1Controller.stop();
      _orb2Controller.stop();
      _orb3Controller.stop();
    }
  }

  @override
  void dispose() {
    _orb1Controller.dispose();
    _orb2Controller.dispose();
    _orb3Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Base: pure dark, no color tint ──
        Container(
          color: const Color(0xFF090909),
        ),

        // ── Subtle dot-grid texture ──
        CustomPaint(
          painter: _DotGridPainter(),
          size: Size.infinite,
        ),

        // ── Single corner accent (Electric Volt, top-left only) ──
        if (widget.showGlowOrbs)
          Positioned(
            left: -60,
            top: -60,
            child: AnimatedBuilder(
              animation: _orb1Controller,
              builder: (_, __) => Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryFixed.withValues(alpha:
                          0.04 + 0.015 * _orb1Controller.value),
                      const Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Content ──
        widget.child,
      ],
    );
  }
}


/// Ultra-subtle dot grid for premium texture — pure white dots at ~1.5% opacity
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 0;

    const spacing = 24.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Glass card container with blur effect and subtle glow
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final bool showGlow;
  final Color? glowColor;
  final double glowIntensity;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.borderColor,
    this.borderWidth = 1,
    this.showGlow = false,
    this.glowColor,
    this.glowIntensity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor =
        borderColor ?? Colors.white.withOpacity(0.07);
    final effectiveGlowColor = glowColor ?? AppColors.primaryFixed;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: effectiveGlowColor.withOpacity(glowIntensity),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: effectiveBorderColor,
              width: borderWidth,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.03),
                Colors.white.withOpacity(0.0),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Animated gradient container for hero sections
class AnimatedGradientContainer extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final Duration duration;
  final BorderRadius? borderRadius;

  const AnimatedGradientContainer({
    super.key,
    required this.child,
    required this.colors,
    this.duration = const Duration(milliseconds: 3000),
    this.borderRadius,
  });

  @override
  State<AnimatedGradientContainer> createState() =>
      _AnimatedGradientContainerState();
}

class _AnimatedGradientContainerState
    extends State<AnimatedGradientContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.colors,
              transform: GradientRotation(_animation.value * 2 * pi),
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Pulsing glow effect widget
class PulsingGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final Duration pulseDuration;
  final double minOpacity;
  final double maxOpacity;

  const PulsingGlow({
    super.key,
    required this.child,
    required this.glowColor,
    this.pulseDuration = const Duration(milliseconds: 2000),
    this.minOpacity = 0.1,
    this.maxOpacity = 0.3,
  });

  @override
  State<PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<PulsingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pulseDuration,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(_animation.value),
                blurRadius: 30,
                spreadRadius: -10,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}