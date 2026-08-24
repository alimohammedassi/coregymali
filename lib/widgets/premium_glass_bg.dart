import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PremiumGlassmorphismBg extends StatefulWidget {
  final Widget child;

  const PremiumGlassmorphismBg({super.key, required this.child});

  @override
  State<PremiumGlassmorphismBg> createState() => _PremiumGlassmorphismBgState();
}

class _PremiumGlassmorphismBgState extends State<PremiumGlassmorphismBg> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505), // Deep obsidian black base
      body: Stack(
        children: [
          // Soft volumetric glow orb bottom-left — Electric Volt
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryFixed.withOpacity(0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),

          // Secondary diffused glow pulsing from top-right
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              final t = _animController.value;
              return Positioned(
                top: -100,
                right: -100 + 40 * sin(t * pi),
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.secondary.withOpacity(0.08 * (0.8 + 0.2 * cos(t * pi))),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                ),
              );
            },
          ),

          // Abstract organic shapes (amoeba-like blobs)
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              final t = _animController.value;
              return Stack(
                children: [
                  // Blob 1 — primary fixed lime
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.2 + 50 * sin(t * pi),
                    left: 50 * cos(t * pi),
                    child: _BlurredBlob(
                      width: 250,
                      height: 350,
                      color: AppColors.primaryFixed.withOpacity(0.16),
                      sigma: 70,
                    ),
                  ),
                  // Blob 2 — secondary cyan
                  Positioned(
                    bottom: MediaQuery.of(context).size.height * 0.15 + 60 * cos(t * pi * 1.5),
                    right: 40 * sin(t * pi * 1.2),
                    child: _BlurredBlob(
                      width: 300,
                      height: 250,
                      color: AppColors.secondary.withOpacity(0.10),
                      sigma: 80,
                    ),
                  ),
                  // Blob 3 — tertiary gold
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.4 + 40 * cos(t * pi * 0.8),
                    left: MediaQuery.of(context).size.width * 0.4 + 30 * sin(t * pi * 1.1),
                    child: _BlurredBlob(
                      width: 200,
                      height: 250,
                      color: AppColors.tertiary.withOpacity(0.08),
                      sigma: 60,
                    ),
                  ),
                ],
              );
            },
          ),

          // Layered Frosted Glass Panels underneath content
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.glass2,
                    border: Border.all(
                      color: AppColors.glassBorder,
                      width: 1,
                    ),
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurredBlob extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double sigma;

  const _BlurredBlob({
    required this.width,
    required this.height,
    required this.color,
    required this.sigma,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.all(Radius.elliptical(width, height * 1.2)),
        ),
      ),
    );
  }
}
