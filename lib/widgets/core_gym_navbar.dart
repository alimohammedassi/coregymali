import 'package:flutter/material.dart';
import 'package:coregym2/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class CoreGymNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onFabTap;

  const CoreGymNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onFabTap,
  });

  static const _navItems = [
    _NavItem(
      icon: Icons.other_houses_outlined,
      activeIcon: Icons.other_houses_rounded,
    ),
    _NavItem(
      icon: Icons.restaurant_outlined,
      activeIcon: Icons.restaurant_rounded,
    ),
    _NavItem(
      icon: Icons.fitness_center_outlined,
      activeIcon: Icons.fitness_center,
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(50),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.07),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 0; i < _navItems.length; i++) ...[
                Expanded(
                  child: _NavItemWidget(
                    item: _navItems[i],
                    isActive: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────

class _NavItemWidget extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItemWidget> createState() => _NavItemWidgetState();
}

class _NavItemWidgetState extends State<_NavItemWidget>
    with TickerProviderStateMixin {
  late AnimationController _activeCtrl;
  late Animation<double> _bounce;

  late AnimationController _pressCtrl;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();

    _activeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _bounce = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _activeCtrl, curve: Curves.elasticOut));

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _pressScale = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));

    if (widget.isActive) _activeCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_NavItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _activeCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _activeCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _pressCtrl.forward();

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_activeCtrl, _pressCtrl]),
        builder: (_, child) {
          final scale = _bounce.value * _pressScale.value;
          return Transform.scale(scale: scale, child: child);
        },
        child: _ItemCircle(item: widget.item, isActive: widget.isActive),
      ),
    );
  }
}

// ─────────────────────────────────────────

class _ItemCircle extends StatelessWidget {
  final _NavItem item;
  final bool isActive;

  const _ItemCircle({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          width: isActive ? 52 : 44,
          height: isActive ? 52 : 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color.fromARGB(255, 6, 6, 5) : Colors.transparent,
            border: isActive
                ? null
                : Border.all(
                    color: AppColors.outline.withOpacity(0.3),
                    width: 1.5,
                  ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primaryFixed.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isActive ? item.activeIcon : item.icon,
            size: isActive ? 26 : 22,
            color: isActive ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 4,
          width: isActive ? 4 : 0,
          decoration: BoxDecoration(
            color: AppColors.primaryFixed,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primaryFixed.withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({required this.icon, required this.activeIcon});
}
