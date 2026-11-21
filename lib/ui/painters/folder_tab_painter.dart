import 'package:flutter/rendering.dart';

/// One file-folder tab (712): rounded top-left corner, a slanted right edge
/// that curves into the baseline. The slant overlaps the next tab.
class FolderTabPainter extends CustomPainter {
  const FolderTabPainter({required this.fill, this.stroke, this.slant = 28, this.radius = 20});

  final Color fill;

  /// Outline colour (top and sides only), for the active tab.
  final Color? stroke;
  final double slant;
  final double radius;

  /// Outline of a tab whose body is [size] wide (the slant extends right).
  static Path shape(Size size, {double slant = 28, double radius = 20}) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, h)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(w - radius * 0.6, 0)
      ..cubicTo(w + slant * 0.15, 0, w + slant * 0.35, h * 0.35, w + slant * 0.55, h * 0.7)
      ..quadraticBezierTo(w + slant * 0.75, h, w + slant, h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = shape(size, slant: slant, radius: radius);
    canvas.drawPath(Path.from(path)..close(), Paint()..color = fill);
    if (stroke != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = stroke!,
      );
    }
  }

  @override
  bool shouldRepaint(FolderTabPainter old) =>
      old.fill != fill || old.stroke != stroke || old.slant != slant || old.radius != radius;
}
