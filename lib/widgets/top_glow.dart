import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Top-down ambient light bleed, from the approved prototype.
///
/// Two radial layers anchored ABOVE the screen's top edge (negative top
/// offset, so the "source" feels off-screen), both centered horizontally:
///  1. Outer glow — wide and soft: ~1.3x screen width, 720:560 aspect,
///     accent at 0.20 → 0.10 → 0.04 → 0 (stops 0% / 26% / 46% / 68%).
///  2. Inner core — narrower and brighter, 360:180 aspect: near-white 0.28
///     at the top, through the accent at 0.16, transparent by ~70%.
///
/// Both layers can breathe together (opt-in via [animate]): opacity
/// 1.0 ↔ 0.72 on a 6s ease-in-out loop (same repeat-reverse pattern as
/// ProfilePage's `_bgCtrl`). Breathing is OFF by default — the pulse reads
/// as motion and throbs against the neon dark-mode accent.
///
/// In dark mode every stop alpha is scaled down (dark volt on near-black
/// blows out where the same stops read "dim and wide" on cream in light
/// mode). Light-mode output is exactly the approved values.
///
/// Layering: place as the FIRST child of the screen's background [Stack],
/// above the base background color and below the content. It is fully
/// [IgnorePointer]d and fills whatever space the Stack gives it (no fixed
/// height), so it stays pinned to the screen top while scroll content
/// moves underneath it.
class TopGlow extends StatefulWidget {
  /// Tint of the bleed. Defaults to [AppColors.accent] (volt); pass another
  /// color to reuse the effect elsewhere.
  final Color? color;

  /// Outer-glow width as a multiple of the prototype's ~1.3x screen width.
  /// 1.0 renders the approved ratios; raise to widen, lower to narrow.
  final double spread;

  /// Master dimmer (0–1) multiplying every gradient stop. 1.0 renders the
  /// approved "dimmer" look exactly as specified; lower to fade further.
  final double intensity;

  /// When true, opacity breathes 1.0 ↔ 0.72 on a 6s ease-in-out loop.
  /// Defaults to false (static glow) so the effect never reads as moving.
  final bool animate;

  const TopGlow({
    super.key,
    this.color,
    this.spread = 1.0,
    this.intensity = 1.0,
    this.animate = false,
  })
    : assert(spread > 0, 'TopGlow spread must be positive'),
      assert(
        intensity >= 0 && intensity <= 1,
        'TopGlow intensity must be 0–1',
      );

  @override
  State<TopGlow> createState() => _TopGlowState();
}

class _TopGlowState extends State<TopGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.animate) _ctrl.repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 1.0,
      end: 0.72,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(TopGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.stop();
      _ctrl.value = 0.0; // Tween start = full opacity, frozen.
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.color ?? AppColors.accent;
    // Dark-mode volt (#D1FC00) on near-black is far more luminous than the
    // darkened volt on cream in light mode — the identical stops blow out
    // into a green wash. Scale them down here (tune this factor, not the
    // stops) so light mode stays exactly as approved.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dim = (widget.intensity * (dark ? 0.35 : 1.0)).clamp(0.0, 1.0);
    final size = MediaQuery.sizeOf(context);

    // ── Outer layer: 1.3x screen width, 720:560 aspect ────────────────────
    final outerW = size.width * 1.3 * widget.spread;
    final outerH = outerW * 560 / 720;
    // Source sits 30% of the box height above the top edge…
    final outerTop = -outerH * 0.30;
    // …and the gradient is scaled so the last visible stop (68%) lands
    // ~45% down the screen: 0.68 * R - |top| = 0.45 * height.
    // (RadialGradient radius is a fraction of the box's shortest side.)
    final outerRadius =
        (0.45 * size.height + outerTop.abs()) / 0.68 / outerH;

    // ── Inner core: half the outer width, 360:180 aspect ──────────────────
    final coreW = outerW * 0.5;
    final coreH = coreW * 180 / 360;
    final coreTop = -coreH * 0.15;
    // …scaled so its 70% stop lands ~16% down the screen: soft light near
    // the edge, not a hard shape.
    final coreRadius =
        (0.16 * size.height + coreTop.abs()) / 0.70 / coreH;

    return IgnorePointer(
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _pulse,
          // Static blurred layers are built ONCE (child) — each frame only
          // re-composites opacity, so the breathing loop stays cheap.
          child: Stack(
            children: [
              Positioned(
                top: outerTop,
                left: (size.width - outerW) / 2,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: outerW,
                    height: outerH,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: outerRadius,
                        stops: const [0.0, 0.26, 0.46, 0.68, 1.0],
                        colors: [
                          glow.withValues(alpha: 0.20 * dim),
                          glow.withValues(alpha: 0.10 * dim),
                          glow.withValues(alpha: 0.04 * dim),
                          Colors.transparent,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: coreTop,
                left: (size.width - coreW) / 2,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    width: coreW,
                    height: coreH,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: coreRadius,
                        stops: const [0.0, 0.38, 0.70, 1.0],
                        colors: [
                          Colors.white.withValues(alpha: 0.28 * dim),
                          glow.withValues(alpha: 0.16 * dim),
                          Colors.transparent,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          builder: (_, child) => Opacity(opacity: _pulse.value, child: child),
        ),
      ),
    );
  }
}
