import 'dart:math';

import 'package:flutter/rendering.dart';

/// A globe drawn from dots (542 trips card): dots on a grid inside a circle,
/// larger and brighter towards the lit side, with seeded "land" patches.
class DotMatrixPainter extends CustomPainter {
  const DotMatrixPainter({required this.color, this.seed = 7, this.spacing = 7});

  final Color color;
  final int seed;
  final double spacing;

  /// Smooth pseudo-noise from a few seeded sine waves (stable, cheap).
  static double _land(double x, double y, int seed) {
    final r = Random(seed);
    var v = 0.0;
    for (var i = 0; i < 4; i++) {
      final fx = 2 + r.nextDouble() * 4;
      final fy = 2 + r.nextDouble() * 4;
      final px = r.nextDouble() * pi * 2;
      final py = r.nextDouble() * pi * 2;
      v += sin(x * fx + px) * cos(y * fy + py);
    }
    return v / 4;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = color;
    for (var y = -radius; y <= radius; y += spacing) {
      for (var x = -radius; x <= radius; x += spacing) {
        final d2 = (x * x + y * y) / (radius * radius);
        if (d2 > 1) continue;
        final z = sqrt(1 - d2); // sphere height: 1 at centre, 0 at edge
        // Map to longitude/latitude for the land pattern.
        final lon = atan2(x / radius, z);
        final lat = asin((y / radius).clamp(-1.0, 1.0));
        final land = _land(lon, lat, seed) > -0.05;
        final light = (0.35 + 0.65 * z) * (0.6 + 0.4 * ((-x / radius + 1) / 2));
        // Ocean dots stay faint so the sphere reads as a globe.
        final alpha = land ? 0.25 + 0.6 * light : 0.06 + 0.1 * light;
        paint.color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
        canvas.drawCircle(center + Offset(x, y), land ? 0.8 + 1.4 * z : 0.6 + 0.8 * z, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotMatrixPainter old) =>
      old.color != color || old.seed != seed || old.spacing != spacing;
}
