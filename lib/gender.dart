import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'login_sign_up.dart';
import 'theme/app_animations.dart';
import 'theme/app_colors.dart';
import 'theme/auth_app_text.dart';

class GenderSelectionScreen extends StatefulWidget {
  const GenderSelectionScreen({super.key});

  @override
  State<GenderSelectionScreen> createState() => _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends State<GenderSelectionScreen>
    with TickerProviderStateMixin {
  String? selectedGender;
  late AnimationController _animationController;
  late AnimationController _floatingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: AppCurves.emphasized),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surfaceLowest,
      body: Stack(
        children: [
          // Glow orb top
          Positioned(
            top: -100,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryFixed.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Grid overlay
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Header branding
                  Row(
                    children: [
                      Text(
                        'KINETIC',
                        style: AuthAppText.headlineSm.copyWith(
                          color: AppColors.primaryFixed,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${l10n.onbStepLabel} 01/03',
                        style: AuthAppText.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Title Section
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.onbSelectYour,
                                style: AuthAppText.displaySm.copyWith(
                                  color: AppColors.onSurface,
                                ),
                              ),
                              Text(
                                l10n.onbIdentity,
                                style: AuthAppText.displaySm.copyWith(
                                  color: AppColors.primaryFixed,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: 60,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryFixed,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.onbPersonalize,
                                style: AuthAppText.bodyMd.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  height: 1.6,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 60),

                  // Gender Options
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _slideAnimation.value * 2),
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Column(
                            children: [
                              // Female Option
                              _buildGenderCard(
                                label: l10n.onbFemale,
                                icon: Icons.female,
                                value: 'female',
                                accentColor: const Color(0xFFFF6B9D),
                              ),

                              const SizedBox(height: 16),

                              // Male Option
                              _buildGenderCard(
                                label: l10n.onbMale,
                                icon: Icons.male,
                                value: 'male',
                                accentColor: AppColors.secondary,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Explicit confirmation — the Continue button only appears
                  // once a gender is picked, replacing the old invisible
                  // "tap the selected card again" affordance.
                  AnimatedSwitcher(
                    duration: AppDurations.medium,
                    switchInCurve: AppCurves.emphasized,
                    switchOutCurve: AppCurves.emphasized,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: AppCurves.emphasized,
                          ),
                        ),
                        child: child,
                      ),
                    ),
                    child: selectedGender == null
                        ? const SizedBox(width: double.infinity)
                        : SizedBox(
                            key: const ValueKey('gender-continue'),
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                                onPressed: _proceedToAuth,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryFixed,
                                  foregroundColor: AppColors.onPrimary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      l10n.onbContinue.toUpperCase(),
                                      style: AuthAppText.buttonPrimary,
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      Directionality.of(context) ==
                                              TextDirection.rtl
                                          ? Icons.arrow_back
                                          : Icons.arrow_forward,
                                      color: AppColors.onPrimary,
                                      size: 18,
                                    ),
                                  ],
                                ),
                            ),
                        ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderCard({
    required String label,
    required IconData icon,
    required String value,
    required Color accentColor,
  }) {
    final bool isSelected = selectedGender == value;

    return GestureDetector(
      onTap: () {
        // Tapping a card only selects it — the Continue button that appears
        // underneath is the explicit confirmation step to proceed.
        HapticFeedback.selectionClick();
        setState(() => selectedGender = value);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AnimatedContainer(
            duration: AppDurations.medium,
            curve: AppCurves.emphasized,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.08)
                  : AppColors.glass1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.4)
                    : AppColors.glassBorder,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.15)
                        : AppColors.glass2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.3)
                          : AppColors.glassBorder,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: isSelected ? accentColor : AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 20),

                // Label
                Text(
                  label,
                  style: AuthAppText.headlineSm.copyWith(
                    color: isSelected ? AppColors.onSurface : AppColors.onSurfaceVariant,
                    fontSize: 22,
                    letterSpacing: 3,
                  ),
                ),

                const Spacer(),

                // Check icon / arrow
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child:  Icon(
                      Icons.check,
                      color: AppColors.onPrimary,
                      size: 18,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.outline,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _proceedToAuth() {
    if (selectedGender == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'auth'),
        builder: (context) => const AuthWrapper(),
      ),
    );
  }
}

// Grid background painter
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 0.5;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

