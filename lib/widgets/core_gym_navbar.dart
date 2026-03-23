import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CoreGymNavBar
//
// Design:
//  • Dark frosted glass pill
//  • Active item = accent-colored filled icon + glowing dot below
//  • Inactive items = dim outlined icon, no dot
//  • Accent FAB circle protrudes from the right end of the pill
// ─────────────────────────────────────────────────────────────────────────────

class CoreGymNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Pass a callback to show the FAB, null to hide it.
  final VoidCallback? onFabTap;

  const CoreGymNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onFabTap,
  });

  static const _items = [
    _NavItem(
      icon: Icons.house_outlined,
      activeIcon: Icons.house_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.restaurant_outlined,
      activeIcon: Icons.restaurant_rounded,
      label: 'Nutrition',
    ),
    _NavItem(
      icon: Icons.fitness_center_outlined,
      activeIcon: Icons.fitness_center,
      label: 'Workout',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  static const double _pillH = 66.0;
  static const double _fabSize = 62.0;
  static const double _fabOverlap = 16.0;

  @override
  Widget build(BuildContext context) {
    final hasFab = onFabTap != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: SizedBox(
          height: _pillH,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerRight,
            children: [
              // Pill
              Positioned.fill(
                right: hasFab ? _fabSize - _fabOverlap : 0,
                child: _Pill(
                  items: _items,
                  currentIndex: currentIndex,
                  onTap: onTap,
                ),
              ),
              // FAB
              if (hasFab)
                Positioned(
                  right: 0,
                  child: _Fab(size: _fabSize, onTap: onFabTap!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill
// ─────────────────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _Pill({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(54),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1E).withOpacity(0.82),
            borderRadius: BorderRadius.circular(54),
            border: Border.all(
              color: Colors.white.withOpacity(0.09),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 30,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Specular top rim
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.30, 0.70, 1.0],
                    ),
                  ),
                ),
              ),
              // Items
              Row(
                children: List.generate(
                  items.length,
                  (i) => _NavItem2(
                    item: items[i],
                    isActive: i == currentIndex,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onTap(i);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB
// ─────────────────────────────────────────────────────────────────────────────

class _Fab extends StatefulWidget {
  final double size;
  final VoidCallback onTap;
  const _Fab({required this.size, required this.onTap});

  @override
  State<_Fab> createState() => _FabState();
}

class _FabState extends State<_Fab> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _rot;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.91,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _rot = Tween<double>(
      begin: 0.0,
      end: 0.12,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: Transform.rotate(angle: _rot.value * 3.14159, child: child),
        ),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryFixed,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryFixed.withOpacity(0.45),
                blurRadius: 20,
                spreadRadius: -3,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.primaryFixed.withOpacity(0.18),
                blurRadius: 36,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav item  (icon + animated dot, no label text)
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem2 extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem2({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItem2> createState() => _NavItem2State();
}

class _NavItem2State extends State<_NavItem2>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _bounce; // icon scale bounce
  late Animation<double> _colorT; // inactive → active color
  late Animation<double> _dotScale;
  late Animation<double> _dotOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _bounce = Tween<double>(
      begin: 0.75,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));

    _colorT = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );

    _dotScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.30, 0.72, curve: Curves.elasticOut),
      ),
    );

    _dotOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.30, 0.65, curve: Curves.easeOut),
    );

    if (widget.isActive) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_NavItem2 old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive)
      _ctrl.forward(from: 0);
    else if (!widget.isActive && old.isActive)
      _ctrl.reverse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _colorT.value;
            final iconColor = Color.lerp(
              Colors.white.withOpacity(0.36),
              AppColors.primaryFixed,
              t,
            )!;

            return SizedBox(
              height: 66,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Transform.scale(
                    scale: widget.isActive ? _bounce.value : 1.0,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow
                        if (t > 0.01)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryFixed.withOpacity(
                                    0.20 * t,
                                  ),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                          ),
                        Icon(
                          widget.isActive
                              ? widget.item.activeIcon
                              : widget.item.icon,
                          size: 24,
                          color: iconColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 5),

                  // Dot
                  Transform.scale(
                    scale: _dotScale.value,
                    child: Opacity(
                      opacity: _dotOpacity.value.clamp(0.0, 1.0),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryFixed,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryFixed.withOpacity(0.7),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
