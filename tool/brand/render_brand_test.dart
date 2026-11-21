// Renders the brand PNGs (launcher icon layers and splash images) from
// BrandMarkPainter, the same geometry as assets/brand/icon.svg.
// Not part of the normal test run. Regenerate with:
//   flutter test tool/brand/render_brand_test.dart
// then: dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/painters/brand_mark_painter.dart';

Future<void> _render(String path, int size, BrandMarkPainter painter, {double inset = 0}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();
  canvas.translate(s * inset, s * inset);
  painter.paint(canvas, Size.square(s * (1 - inset * 2)));
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render brand PNGs', () async {
    const dir = 'assets/brand';
    // Legacy launcher icon: rounded tile.
    await _render('$dir/icon.png', 1024, const BrandMarkPainter(background: true, markScale: 0.86));
    // Adaptive icon layers (108 dp canvas, 66 dp safe circle).
    await _render(
      '$dir/icon_background.png',
      1024,
      const BrandMarkPainter(background: true, fullBleed: true, markScale: 0),
    );
    await _render('$dir/icon_foreground.png', 1024, const BrandMarkPainter(markScale: 0.62));
    await _render('$dir/icon_monochrome.png', 1024, const BrandMarkPainter(markScale: 0.62));
    // Splash: tile centred (legacy) and inside the Android 12 icon circle.
    await _render('$dir/splash.png', 768, const BrandMarkPainter(background: true, markScale: 0.86));
    await _render(
      '$dir/splash_android12.png',
      1152,
      const BrandMarkPainter(background: true, markScale: 0.86),
      inset: 0.25,
    );
  });
}
