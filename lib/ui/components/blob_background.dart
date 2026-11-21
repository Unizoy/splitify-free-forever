import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Soft colour blobs behind [child] (636): lavender and pink glows used by
/// comments and activity empty states. Painted as radial gradients, so no
/// blur filter is needed.
class BlobBackground extends StatelessWidget {
  const BlobBackground({required this.child, this.seed = 3, super.key});

  final Widget child;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CustomPaint(
      painter: _BlobPainter(colors: [c.blobLavender, c.blobPink, c.blobLavender], seed: seed),
      child: child,
    );
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter({required this.colors, required this.seed});

  final List<Color> colors;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    // Upper-left lavender, lower-right pink, plus a third seeded glow.
    final anchors = [
      Offset(size.width * 0.2, size.height * 0.25),
      Offset(size.width * 0.8, size.height * 0.75),
      Offset(size.width * (0.3 + random.nextDouble() * 0.4), size.height * 0.6),
    ];
    for (var i = 0; i < anchors.length; i++) {
      final r = size.shortestSide * (0.45 + random.nextDouble() * 0.2);
      canvas.drawCircle(
        anchors[i],
        r,
        Paint()
          ..shader = ui.Gradient.radial(anchors[i], r, [colors[i], colors[i].withValues(alpha: 0)]),
      );
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.seed != seed || old.colors != colors;
}
