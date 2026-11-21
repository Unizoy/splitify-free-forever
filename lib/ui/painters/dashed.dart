import 'package:flutter/rendering.dart';

/// Returns [source] cut into dashes of [dash] length separated by [gap].
Path dashPath(Path source, {double dash = 4, double gap = 4}) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = (distance + dash).clamp(0, metric.length).toDouble();
      out.addPath(metric.extractPath(distance, end), Offset.zero);
      distance = end + gap;
    }
  }
  return out;
}

/// A horizontal dashed line across the full width, vertically centred.
class DashedLinePainter extends CustomPainter {
  const DashedLinePainter({required this.color, this.strokeWidth = 1, this.dash = 4, this.gap = 4});

  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + dash).clamp(0, size.width).toDouble();
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x = end + gap;
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || old.dash != dash || old.gap != gap;
}

/// A dashed outline around a rounded rectangle (or a circle when [circle]).
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    this.radius = 999,
    this.strokeWidth = 1.5,
    this.dash = 8,
    this.gap = 6,
    this.circle = false,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path();
    if (circle) {
      path.addOval(rect);
    } else {
      final r = radius.clamp(0, rect.shortestSide / 2).toDouble();
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
    }
    canvas.drawPath(
      dashPath(path, dash: dash, gap: gap),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap ||
      old.circle != circle;
}
