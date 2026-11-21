import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/rendering.dart';

/// Deterministic monochrome grain: tiny light and dark specks.
///
/// [density] is specks per 100 dp²; [opacity] the strongest speck alpha.
/// Specks are batched into a few alpha buckets so painting stays cheap.
void paintNoise(
  Canvas canvas,
  Size size, {
  required int seed,
  required Color light,
  required Color dark,
  double density = 6,
  double opacity = 0.06,
}) {
  const buckets = 4;
  final random = Random(seed);
  final count = (size.width * size.height / 100 * density).round().clamp(0, 40000);
  final points = List.generate(buckets * 2, (_) => <double>[]);
  for (var i = 0; i < count; i++) {
    final bucket = random.nextInt(buckets) + (random.nextBool() ? buckets : 0);
    points[bucket]
      ..add(random.nextDouble() * size.width)
      ..add(random.nextDouble() * size.height);
  }
  for (var b = 0; b < points.length; b++) {
    if (points[b].isEmpty) continue;
    final isLight = b >= buckets;
    final alpha = opacity * ((b % buckets) + 1) / buckets;
    final paint = Paint()
      ..color = (isLight ? light : dark).withValues(alpha: alpha)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.square;
    canvas.drawRawPoints(PointMode.points, Float32List.fromList(points[b]), paint);
  }
}

/// [CustomPainter] wrapper around [paintNoise].
class NoisePainter extends CustomPainter {
  const NoisePainter({
    required this.seed,
    required this.light,
    required this.dark,
    this.density = 6,
    this.opacity = 0.06,
  });

  final int seed;
  final Color light;
  final Color dark;
  final double density;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) => paintNoise(
    canvas,
    size,
    seed: seed,
    light: light,
    dark: dark,
    density: density,
    opacity: opacity,
  );

  @override
  bool shouldRepaint(NoisePainter old) =>
      old.seed != seed ||
      old.light != light ||
      old.dark != dark ||
      old.density != density ||
      old.opacity != opacity;
}
