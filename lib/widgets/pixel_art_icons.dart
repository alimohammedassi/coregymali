import 'package:flutter/material.dart';

/// PixelArtIcon types available in the custom 8-bit illustration system
enum PixelIconType {
  fire,
  chicken,
  grain,
  avocado,
  waterDrop,
  sneaker,
  dumbbell,
  trophy,
  robot,
  star,
  apple,
  egg,
  plate,
  scale,
  sparkles,
  bolt,
}

/// A crisp, lightweight, resolution-independent Pixel Art widget.
/// Renders authentic 8-bit / pixel grid icons using Flutter's CustomPainter.
class PixelArtIcon extends StatelessWidget {
  final PixelIconType type;
  final double size;
  final Color? color;
  final bool animate;

  const PixelArtIcon({
    super.key,
    required this.type,
    this.size = 24.0,
    this.color,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = CustomPaint(
      size: Size(size, size),
      painter: _PixelArtPainter(type: type, customColor: color),
    );

    if (animate) {
      return _PixelBounce(child: iconWidget);
    }
    return iconWidget;
  }
}

class _PixelBounce extends StatefulWidget {
  final Widget child;
  const _PixelBounce({required this.child});

  @override
  State<_PixelBounce> createState() => _PixelBounceState();
}

class _PixelBounceState extends State<_PixelBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _offsetAnimation = Tween<double>(begin: 0.0, end: -3.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
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
      animation: _offsetAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _offsetAnimation.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _PixelArtPainter extends CustomPainter {
  final PixelIconType type;
  final Color? customColor;

  _PixelArtPainter({required this.type, this.customColor});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _getGridForType(type);
    final rows = grid.length;
    final cols = grid[0].length;

    final pixelWidth = size.width / cols;
    final pixelHeight = size.height / rows;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final code = grid[r][c];
        if (code != 0) {
          final paintColor = _resolveColor(code);
          final paint = Paint()
            ..color = paintColor
            ..style = PaintingStyle.fill;

          final rect = Rect.fromLTWH(
            c * pixelWidth,
            r * pixelHeight,
            pixelWidth + 0.2, // slight overlap to prevent anti-aliasing gaps
            pixelHeight + 0.2,
          );
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  Color _resolveColor(int code) {
    if (customColor != null && code == 1) return customColor!;
    switch (code) {
      case 1: // Primary base
        return const Color(0xFF18A957);
      case 2: // Flame Orange / Calorie Orange
        return const Color(0xFFFF8A00);
      case 3: // Flame Yellow / Gold
        return const Color(0xFFFFC107);
      case 4: // Protein Red
        return const Color(0xFFEF4444);
      case 5: // Carbs Blue
        return const Color(0xFF3B82F6);
      case 6: // Water Sky Blue
        return const Color(0xFF38BDF8);
      case 7: // Dark outline / Detail
        return const Color(0xFF1F2937);
      case 8: // White / Highlight
        return const Color(0xFFFFFFFF);
      case 9: // Bone / Light meat / Beige
        return const Color(0xFFFFE0B2);
      case 10: // Avocado Light Green
        return const Color(0xFF86EFAC);
      case 11: // Avocado Dark Green
        return const Color(0xFF22A06B);
      case 12: // Avocado Seed Brown
        return const Color(0xFF78350F);
      case 13: // Purple / Steps
        return const Color(0xFF8B5CF6);
      case 14: // Gray / Metal
        return const Color(0xFF9CA3AF);
      case 15: // Dark Metal
        return const Color(0xFF4B5563);
      case 16: // Gold Trophy
        return const Color(0xFFF59E0B);
      case 17: // Light Gold
        return const Color(0xFFFDE68A);
      default:
        return Colors.black;
    }
  }

  List<List<int>> _getGridForType(PixelIconType type) {
    switch (type) {
      case PixelIconType.fire:
        return [
          [0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 2, 3, 2, 0, 0, 0, 0, 0],
          [0, 0, 0, 2, 3, 3, 2, 0, 2, 0, 0, 0],
          [0, 0, 2, 2, 3, 8, 3, 2, 2, 0, 0, 0],
          [0, 2, 2, 3, 3, 8, 8, 3, 2, 2, 0, 0],
          [0, 2, 3, 3, 8, 8, 8, 3, 3, 2, 0, 0],
          [2, 2, 3, 8, 8, 8, 8, 8, 3, 2, 2, 0],
          [2, 3, 3, 8, 8, 8, 8, 8, 3, 3, 2, 0],
          [2, 3, 3, 3, 8, 8, 8, 3, 3, 3, 2, 0],
          [0, 2, 3, 3, 3, 3, 3, 3, 3, 2, 0, 0],
          [0, 0, 2, 2, 3, 3, 3, 2, 2, 0, 0, 0],
          [0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 0, 0],
        ];

      case PixelIconType.chicken:
        return [
          [0, 0, 0, 0, 4, 4, 4, 4, 0, 0, 0, 0],
          [0, 0, 0, 4, 4, 4, 4, 4, 4, 0, 0, 0],
          [0, 0, 4, 4, 8, 4, 4, 4, 4, 4, 0, 0],
          [0, 4, 4, 4, 8, 8, 4, 4, 4, 4, 4, 0],
          [0, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 0],
          [0, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 0],
          [0, 0, 4, 4, 4, 4, 4, 4, 4, 4, 0, 0],
          [0, 0, 0, 4, 4, 4, 4, 4, 4, 0, 0, 0],
          [0, 0, 0, 0, 9, 9, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 9, 9, 9, 9, 0, 0, 0, 0, 0],
          [0, 0, 9, 9, 0, 0, 9, 9, 0, 0, 0, 0],
          [0, 0, 9, 9, 0, 0, 9, 9, 0, 0, 0, 0],
        ];

      case PixelIconType.grain:
        return [
          [0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 5, 8, 5, 0, 0, 0, 0, 0],
          [0, 0, 0, 5, 5, 8, 5, 5, 0, 0, 0, 0],
          [0, 0, 5, 8, 5, 5, 5, 8, 5, 0, 0, 0],
          [0, 5, 8, 5, 0, 5, 0, 5, 8, 5, 0, 0],
          [0, 0, 5, 0, 5, 8, 5, 0, 5, 0, 0, 0],
          [0, 0, 5, 8, 5, 5, 5, 8, 5, 0, 0, 0],
          [0, 5, 8, 5, 0, 5, 0, 5, 8, 5, 0, 0],
          [0, 0, 5, 0, 0, 5, 0, 0, 5, 0, 0, 0],
          [0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0],
        ];

      case PixelIconType.avocado:
        return [
          [0, 0, 0, 0, 11, 11, 11, 11, 0, 0, 0, 0],
          [0, 0, 0, 11, 10, 10, 10, 10, 11, 0, 0, 0],
          [0, 0, 11, 10, 10, 10, 10, 10, 10, 11, 0, 0],
          [0, 11, 10, 10, 10, 10, 10, 10, 10, 10, 11, 0],
          [0, 11, 10, 10, 12, 12, 12, 12, 10, 10, 11, 0],
          [11, 10, 10, 12, 12, 8, 12, 12, 12, 10, 10, 11],
          [11, 10, 10, 12, 8, 8, 12, 12, 12, 10, 10, 11],
          [11, 10, 10, 12, 12, 12, 12, 12, 12, 10, 10, 11],
          [0, 11, 10, 10, 12, 12, 12, 12, 10, 10, 11, 0],
          [0, 11, 10, 10, 10, 10, 10, 10, 10, 10, 11, 0],
          [0, 0, 11, 10, 10, 10, 10, 10, 10, 11, 0, 0],
          [0, 0, 0, 11, 11, 11, 11, 11, 11, 0, 0, 0],
        ];

      case PixelIconType.waterDrop:
        return [
          [0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 6, 8, 6, 6, 0, 0, 0, 0, 0],
          [0, 0, 6, 8, 8, 6, 6, 6, 0, 0, 0, 0],
          [0, 6, 8, 8, 6, 6, 6, 6, 6, 0, 0, 0],
          [0, 6, 8, 6, 6, 6, 6, 6, 6, 0, 0, 0],
          [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 0, 0],
          [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 0, 0],
          [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 0, 0],
          [0, 6, 6, 6, 6, 6, 6, 6, 6, 0, 0, 0],
          [0, 0, 6, 6, 6, 6, 6, 6, 0, 0, 0, 0],
          [0, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0, 0],
        ];

      case PixelIconType.sneaker:
        return [
          [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 13, 13, 13, 0, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 13, 8, 13, 13, 13, 0, 0, 0, 0, 0, 0],
          [0, 0, 13, 13, 8, 8, 13, 13, 13, 0, 0, 0, 0, 0],
          [0, 13, 13, 13, 13, 8, 8, 13, 13, 13, 13, 0, 0, 0],
          [13, 13, 13, 13, 13, 13, 8, 8, 13, 13, 13, 13, 0, 0],
          [13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 0],
          [8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8],
          [14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14],
          [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        ];

      case PixelIconType.dumbbell:
        return [
          [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          [0, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0],
          [2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2],
          [2, 8, 2, 2, 14, 14, 14, 14, 14, 14, 2, 8, 2, 2],
          [2, 8, 2, 2, 14, 8, 8, 8, 8, 14, 2, 8, 2, 2],
          [2, 2, 2, 2, 14, 14, 14, 14, 14, 14, 2, 2, 2, 2],
          [0, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0],
          [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        ];

      case PixelIconType.trophy:
        return [
          [0, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 0],
          [16, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 16],
          [16, 8, 17, 17, 17, 17, 17, 17, 17, 17, 17, 16],
          [16, 16, 17, 17, 17, 17, 17, 17, 17, 17, 16, 16],
          [0, 16, 16, 17, 17, 17, 17, 17, 17, 16, 16, 0],
          [0, 0, 16, 16, 17, 17, 17, 17, 16, 16, 0, 0],
          [0, 0, 0, 16, 16, 17, 17, 16, 16, 0, 0, 0],
          [0, 0, 0, 0, 16, 16, 16, 16, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 16, 16, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 16, 16, 16, 16, 0, 0, 0, 0],
          [0, 0, 0, 16, 17, 17, 17, 17, 16, 0, 0, 0],
          [0, 0, 16, 16, 16, 16, 16, 16, 16, 16, 0, 0],
        ];

      case PixelIconType.robot:
        return [
          [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0],
          [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0],
          [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
          [1, 1, 7, 7, 1, 1, 1, 1, 7, 7, 1, 1],
          [1, 1, 7, 8, 1, 1, 1, 1, 7, 8, 1, 1],
          [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
          [0, 1, 1, 7, 7, 7, 7, 7, 7, 1, 1, 0],
          [0, 1, 1, 7, 8, 7, 8, 7, 8, 1, 1, 0],
          [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0],
          [0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0],
          [0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0],
        ];

      case PixelIconType.star:
        return [
          [0, 0, 0, 0, 0, 3, 3, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 3, 8, 3, 3, 0, 0, 0, 0],
          [3, 3, 3, 3, 3, 8, 3, 3, 3, 3, 3, 3],
          [0, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0],
          [0, 0, 3, 3, 3, 3, 3, 3, 3, 3, 0, 0],
          [0, 0, 0, 3, 3, 3, 3, 3, 3, 0, 0, 0],
          [0, 0, 3, 3, 3, 3, 3, 3, 3, 3, 0, 0],
          [0, 3, 3, 3, 0, 3, 3, 0, 3, 3, 3, 0],
          [3, 3, 3, 0, 0, 3, 3, 0, 0, 3, 3, 3],
          [3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3],
        ];

      case PixelIconType.apple:
        return [
          [0, 0, 0, 0, 0, 11, 11, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 12, 11, 0, 0, 0, 0, 0],
          [0, 0, 4, 4, 4, 12, 4, 4, 4, 0, 0, 0],
          [0, 4, 4, 8, 4, 4, 4, 4, 4, 4, 0, 0],
          [4, 4, 8, 8, 4, 4, 4, 4, 4, 4, 4, 0],
          [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 0],
          [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 0],
          [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 0],
          [0, 4, 4, 4, 4, 4, 4, 4, 4, 4, 0, 0],
          [0, 0, 4, 4, 4, 0, 4, 4, 4, 0, 0, 0],
        ];

      case PixelIconType.egg:
        return [
          [0, 0, 0, 0, 8, 8, 8, 8, 0, 0, 0, 0],
          [0, 0, 0, 8, 8, 8, 8, 8, 8, 0, 0, 0],
          [0, 0, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0],
          [0, 8, 8, 8, 3, 3, 3, 8, 8, 8, 8, 0],
          [0, 8, 8, 3, 3, 3, 3, 3, 8, 8, 8, 0],
          [8, 8, 8, 3, 3, 17, 3, 3, 8, 8, 8, 8],
          [8, 8, 8, 3, 3, 3, 3, 3, 8, 8, 8, 8],
          [0, 8, 8, 8, 3, 3, 3, 8, 8, 8, 8, 0],
          [0, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 0],
          [0, 0, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0],
          [0, 0, 0, 8, 8, 8, 8, 8, 8, 0, 0, 0],
          [0, 0, 0, 0, 8, 8, 8, 8, 0, 0, 0, 0],
        ];

      case PixelIconType.plate:
        return [
          [0, 0, 14, 14, 14, 14, 14, 14, 14, 14, 0, 0],
          [0, 14, 8, 8, 8, 8, 8, 8, 8, 8, 14, 0],
          [14, 8, 8, 14, 14, 14, 14, 14, 8, 8, 8, 14],
          [14, 8, 14, 8, 8, 8, 8, 8, 14, 8, 8, 14],
          [14, 8, 14, 8, 1, 1, 1, 8, 14, 8, 8, 14],
          [14, 8, 14, 8, 1, 8, 1, 8, 14, 8, 8, 14],
          [14, 8, 14, 8, 1, 1, 1, 8, 14, 8, 8, 14],
          [14, 8, 14, 8, 8, 8, 8, 8, 14, 8, 8, 14],
          [14, 8, 8, 14, 14, 14, 14, 14, 8, 8, 8, 14],
          [0, 14, 8, 8, 8, 8, 8, 8, 8, 8, 14, 0],
          [0, 0, 14, 14, 14, 14, 14, 14, 14, 14, 0, 0],
        ];

      case PixelIconType.scale:
        return [
          [0, 0, 14, 14, 14, 14, 14, 14, 14, 14, 0, 0],
          [0, 14, 8, 8, 8, 8, 8, 8, 8, 8, 14, 0],
          [14, 8, 8, 7, 7, 7, 7, 7, 8, 8, 8, 14],
          [14, 8, 7, 1, 1, 1, 1, 1, 7, 8, 8, 14],
          [14, 8, 8, 7, 7, 7, 7, 7, 8, 8, 8, 14],
          [14, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 14],
          [14, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 14],
          [14, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 14],
          [0, 14, 8, 8, 8, 8, 8, 8, 8, 8, 14, 0],
          [0, 0, 14, 14, 14, 14, 14, 14, 14, 14, 0, 0],
        ];

      case PixelIconType.sparkles:
        return [
          [0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 3, 3, 3, 0, 0, 0, 0, 0],
          [0, 0, 0, 3, 3, 8, 3, 3, 0, 0, 0, 0],
          [0, 0, 3, 3, 8, 8, 8, 3, 3, 0, 0, 0],
          [3, 3, 3, 8, 8, 8, 8, 8, 3, 3, 3, 0],
          [0, 0, 3, 3, 8, 8, 8, 3, 3, 0, 0, 0],
          [0, 0, 0, 3, 3, 8, 3, 3, 0, 0, 0, 0],
          [0, 0, 0, 0, 3, 3, 3, 0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0],
        ];

      case PixelIconType.bolt:
        return [
          [0, 0, 0, 0, 3, 3, 3, 0, 0, 0],
          [0, 0, 0, 3, 3, 3, 0, 0, 0, 0],
          [0, 0, 3, 3, 3, 0, 0, 0, 0, 0],
          [0, 3, 3, 3, 3, 3, 3, 3, 0, 0],
          [0, 0, 0, 0, 3, 3, 3, 0, 0, 0],
          [0, 0, 0, 3, 3, 3, 0, 0, 0, 0],
          [0, 0, 3, 3, 3, 0, 0, 0, 0, 0],
          [0, 3, 3, 0, 0, 0, 0, 0, 0, 0],
        ];
    }
  }

  @override
  bool shouldRepaint(covariant _PixelArtPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.customColor != customColor;
}
