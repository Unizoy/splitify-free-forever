import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Side of the grain tile in logical pixels.
const _tileSize = 128;

final _tiles = <String, ui.Image>{};

/// A small seamless tile of light and dark specks, drawn once and reused.
///
/// Thousands of points per frame stall Impeller's GLES backend (seen on the
/// emulator: the first frame never finished), so grain is painted as a
/// repeating image shader instead of individual points.
ui.Image _tile({
  required int seed,
  required Color light,
  required Color dark,
  required double density,
  required double opacity,
}) {
  final key = '$seed|${light.toARGB32()}|${dark.toARGB32()}|$density|$opacity';
  final cached = _tiles[key];
  if (cached != null) return cached;
  const buckets = 4;
  final random = Random(seed);
  final count = (_tileSize * _tileSize / 100 * density).round();
  final points = List.generate(buckets * 2, (_) => <double>[]);
  for (var i = 0; i < count; i++) {
    final bucket = random.nextInt(buckets) + (random.nextBool() ? buckets : 0);
    points[bucket]
      ..add(random.nextDouble() * _tileSize)
      ..add(random.nextDouble() * _tileSize);
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (var b = 0; b < points.length; b++) {
    if (points[b].isEmpty) continue;
    final isLight = b >= buckets;
    final alpha = opacity * ((b % buckets) + 1) / buckets;
    final paint = Paint()
      ..color = (isLight ? light : dark).withValues(alpha: alpha)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.square;
    canvas.drawRawPoints(ui.PointMode.points, Float32List.fromList(points[b]), paint);
  }
  final picture = recorder.endRecording();
  final image = picture.toImageSync(_tileSize, _tileSize);
  picture.dispose();
  return _tiles[key] = image;
}

/// Deterministic monochrome grain over [size]: tiny light and dark specks.
///
/// [density] is specks per 100 dp²; [opacity] the strongest speck alpha.
void paintNoise(
  Canvas canvas,
  Size size, {
  required int seed,
  required Color light,
  required Color dark,
  double density = 6,
  double opacity = 0.06,
}) {
  final tile = _tile(
    seed: seed % 997,
    light: light,
    dark: dark,
    density: density,
    opacity: opacity,
  );
  final shift = (seed % _tileSize).toDouble();
  final matrix = Float64List(16)
    ..[0] = 1
    ..[5] = 1
    ..[10] = 1
    ..[15] = 1
    ..[12] = shift
    ..[13] = shift / 2;
  canvas.drawRect(
    Offset.zero & size,
    Paint()..shader = ui.ImageShader(tile, TileMode.repeated, TileMode.repeated, matrix),
  );
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
