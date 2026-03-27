import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Enhanced ring painter with gradient and glow effects
class EnhancedRingPainter extends CustomPainter {
  final double progress;
  final List<Color> gradientColors;
  final Color trackColor;
  final double strokeWidth;
  final double glowRadius;
  final bool showGlow;

  EnhancedRingPainter({
    required this.progress,
    required this.gradientColors,
    this.trackColor = Colors.white24,
    this.strokeWidth = 12,
    this.glowRadius = 15,
    this.showGlow = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Draw progress arc with gradient
    if (progress <= 0) return;

    final sweepAngle = 2 * pi * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Glow effect
    if (showGlow) {
      final glowPaint = Paint()
        ..shader = SweepGradient(
          colors: gradientColors
              .map((c) => c.withOpacity(0.3))
              .toList(),
          startAngle: -pi / 2,
          endAngle: -pi / 2 + sweepAngle,
          transform: GradientRotation(-pi / 2),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + glowRadius
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        rect,
        -pi / 2,
        sweepAngle,
        false,
        glowPaint,
      );
    }

    // Main gradient arc
    final gradientPaint = Paint()
      ..shader = SweepGradient(
        colors: gradientColors,
        startAngle: -pi / 2,
        endAngle: -pi / 2 + sweepAngle,
        transform: GradientRotation(-pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -pi / 2,
      sweepAngle,
      false,
      gradientPaint,
    );

    // Draw end cap highlight
    if (progress > 0.02) {
      final endAngle = -pi / 2 + sweepAngle;
      final endX = center.dx + radius * cos(endAngle);
      final endY = center.dy + radius * sin(endAngle);

      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(endX, endY),
        strokeWidth / 2.5,
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant EnhancedRingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        gradientColors != oldDelegate.gradientColors;
  }
}

/// Animated ring widget with gradient and optional glow
class AnimatedRingChart extends StatefulWidget {
  final double progress;
  final List<Color> gradientColors;
  final String centerValue;
  final String centerLabel;
  final String? centerSublabel;
  final double size;
  final double strokeWidth;
  final bool showGlow;
  final Duration animationDuration;
  final Widget? badge;

  const AnimatedRingChart({
    super.key,
    required this.progress,
    required this.gradientColors,
    required this.centerValue,
    required this.centerLabel,
    this.centerSublabel,
    this.size = 140,
    this.strokeWidth = 12,
    this.showGlow = true,
    this.animationDuration = const Duration(milliseconds: 1600),
    this.badge,
  });

  @override
  State<AnimatedRingChart> createState() => _AnimatedRingChartState();
}

class _AnimatedRingChartState extends State<AnimatedRingChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedRingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: EnhancedRingPainter(
                  progress: widget.progress * _animation.value,
                  gradientColors: widget.gradientColors,
                  strokeWidth: widget.strokeWidth,
                  showGlow: widget.showGlow,
                ),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Text(
                      widget.centerValue,
                      style: TextStyle(
                        fontSize: widget.size * 0.2,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    );
                  },
                ),
                Text(
                  widget.centerLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                if (widget.centerSublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.centerSublabel!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: widget.gradientColors.first,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.badge != null)
            Positioned(
              top: 0,
              right: 0,
              child: widget.badge!,
            ),
        ],
      ),
    );
  }
}

/// Enhanced macro progress bar with gradient and glow
class EnhancedMacroBar extends StatefulWidget {
  final String label;
  final double current;
  final double goal;
  final List<Color> gradientColors;
  final IconData? icon;
  final String unit;
  final Duration animationDuration;

  const EnhancedMacroBar({
    super.key,
    required this.label,
    required this.current,
    required this.goal,
    required this.gradientColors,
    this.icon,
    this.unit = 'g',
    this.animationDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<EnhancedMacroBar> createState() => _EnhancedMacroBarState();
}

class _EnhancedMacroBarState extends State<EnhancedMacroBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(EnhancedMacroBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.goal > 0
        ? (widget.current / widget.goal).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.icon != null) ...[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.gradientColors
                        .map((c) => c.withOpacity(0.2))
                        .toList(),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  widget.icon,
                  size: 14,
                  color: widget.gradientColors.first,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.gradientColors.first,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Text(
                  '${(widget.current * _animation.value).toInt()}/${widget.goal.toInt()}${widget.unit}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final animatedProgress = progress * _animation.value;
            return LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Track
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Progress with gradient and glow
                    FractionallySizedBox(
                      widthFactor: animatedProgress.clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: widget.gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: widget.gradientColors.first.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Highlight at end
                    if (animatedProgress > 0.05)
                      Positioned(
                        left: constraints.maxWidth * animatedProgress - 4,
                        top: 1,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Macro pie/donut indicator for quick visual reference
class MacroPieIndicator extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;
  final double size;

  const MacroPieIndicator({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final total = protein + carbs + fat;
    if (total == 0) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _MacroPiePainter(
            proteinRatio: 0.33,
            carbsRatio: 0.33,
            fatRatio: 0.34,
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MacroPiePainter(
          proteinRatio: protein / total,
          carbsRatio: carbs / total,
          fatRatio: fat / total,
        ),
      ),
    );
  }
}

class _MacroPiePainter extends CustomPainter {
  final double proteinRatio;
  final double carbsRatio;
  final double fatRatio;

  _MacroPiePainter({
    required this.proteinRatio,
    required this.carbsRatio,
    required this.fatRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final strokeWidth = 6.0;

    final colors = [
      const Color(0xFFFF6B6B), // Protein - Red
      const Color(0xFF4A9EFF), // Carbs - Blue
      const Color(0xFFFFB84A), // Fat - Orange
    ];

    double startAngle = -pi / 2;
    final ratios = [proteinRatio, carbsRatio, fatRatio];

    for (int i = 0; i < 3; i++) {
      final sweepAngle = 2 * pi * ratios[i];
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroPiePainter oldDelegate) {
    return proteinRatio != oldDelegate.proteinRatio ||
        carbsRatio != oldDelegate.carbsRatio ||
        fatRatio != oldDelegate.fatRatio;
  }
}

/// Enhanced calories card with gradient background and glow effects
class EnhancedCaloriesCard extends StatelessWidget {
  final double progress;
  final int caloriesConsumed;
  final int caloriesGoal;
  final int caloriesRemaining;
  final String motivationalMessage;
  final Color ringColor;
  final Animation<double> animation;

  const EnhancedCaloriesCard({
    super.key,
    required this.progress,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.caloriesRemaining,
    required this.motivationalMessage,
    required this.ringColor,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = progress >= 1.0
        ? [const Color(0xFFFF5252), const Color(0xFFFF8A65)]
        : progress > 0.85
            ? [const Color(0xFFFFAB40), const Color(0xFFFFD54F)]
            : [AppColors.primaryFixed, AppColors.primaryDim];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Top banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradientColors.first.withOpacity(0.15),
                  gradientColors.last.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(23),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: ringColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ringColor.withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    motivationalMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: ringColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: animation,
                  builder: (_, __) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ringColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(progress * 100 * animation.value).toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: ringColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(
              children: [
                // Ring chart
                AnimatedRingChart(
                  progress: progress,
                  gradientColors: gradientColors,
                  centerValue: caloriesConsumed.toString(),
                  centerLabel: 'kcal',
                  centerSublabel: 'of $caloriesGoal',
                  size: 140,
                  strokeWidth: 12,
                  showGlow: true,
                ),
                const SizedBox(width: 20),
                // Stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CalorieStatRow(
                        label: 'Goal',
                        value: caloriesGoal.toString(),
                        unit: 'kcal',
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 12),
                      _CalorieStatRow(
                        label: 'Eaten',
                        value: caloriesConsumed.toString(),
                        unit: 'kcal',
                        color: gradientColors.first,
                      ),
                      const SizedBox(height: 12),
                      _CalorieStatRow(
                        label: progress >= 1 ? 'Over' : 'Left',
                        value: progress >= 1
                            ? '+${(caloriesConsumed - caloriesGoal)}'
                            : caloriesRemaining.toString(),
                        unit: 'kcal',
                        color: progress >= 1
                            ? const Color(0xFFFF5252)
                            : const Color(0xFF66BB6A),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: AnimatedBuilder(
              animation: animation,
              builder: (_, __) {
                final animatedProgress = progress * animation.value;
                return Column(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: animatedProgress.clamp(0.0, 1.0),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradientColors),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0', style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant)),
                        Text('${(caloriesGoal / 2).toInt()}', style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant)),
                        Text('$caloriesGoal kcal', style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieStatRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _CalorieStatRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Container(
          width: 3,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}