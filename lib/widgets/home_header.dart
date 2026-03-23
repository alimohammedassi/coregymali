import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final String avatarUrl;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.avatarUrl,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _greetingEmoji {
    final h = DateTime.now().hour;
    if (h < 12) return '👋';
    if (h < 17) return '☀️';
    return '🌙';
  }

  String get _dayLabel {
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return days[DateTime.now().weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final firstName = userName.isNotEmpty
        ? userName.split(' ').first
        : 'User';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Greeting row with emoji
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _greeting,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(_greetingEmoji, style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 2),
                // Name
                Text(
                  firstName,
                  style: AppText.headlineMd.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.05,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                // Day pill
                _DayPill(label: _dayLabel),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          _Avatar(name: firstName, avatarUrl: avatarUrl),
        ],
      ),
    );
  }
}

// ─── Day pill ─────────────────────────────────────────────────────────────────

class _DayPill extends StatelessWidget {
  final String label;
  const _DayPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryFixed.withOpacity(0.22),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryFixed,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatefulWidget {
  final String name;
  final String avatarUrl;
  const _Avatar({required this.name, required this.avatarUrl});

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isNotEmpty
        ? widget.name[0].toUpperCase()
        : 'U';

    return ScaleTransition(
      scale: _scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryFixed.withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Orange border ring
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryFixed.withOpacity(0.45),
                width: 1.5,
              ),
            ),
          ),
          // Avatar image
          ClipOval(
            child: SizedBox(
              width: 44, height: 44,
              child: widget.avatarUrl.isNotEmpty
                  ? Image.network(
                      widget.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initialsWidget(initial),
                    )
                  : _initialsWidget(initial),
            ),
          ),
          // Online indicator dot
          Positioned(
            bottom: 4, right: 4,
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF4DC591),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surface,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4DC591).withOpacity(0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initialsWidget(String initial) {
    return Container(
      color: AppColors.primaryFixed.withOpacity(0.12),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.primaryFixed,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          height: 1,
        ),
      ),
    );
  }
}