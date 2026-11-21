import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/painters/cover_painter.dart';
import 'package:splitify/ui/theme/app_covers.dart';

const _size = Size(120, 160);

Future<Uint8List> render(CoverPainter p) async {
  final recorder = ui.PictureRecorder();
  p.paint(Canvas(recorder), _size);
  final image = await recorder.endRecording().toImage(_size.width.toInt(), _size.height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  // TC-B3-03: covers are deterministic per seed and family.
  testWidgets('same seed and family render identical bytes', (tester) async {
    await tester.runAsync(() async {
      for (final family in CoverFamily.values) {
        final a = await render(CoverPainter(seed: 'g1', family: family));
        final b = await render(CoverPainter(seed: 'g1', family: family));
        expect(a, b, reason: family.name);
      }
    });
  });

  // TC-B3-03
  testWidgets('different seed or family renders differently', (tester) async {
    await tester.runAsync(() async {
      final a = await render(const CoverPainter(seed: 'g1', family: CoverFamily.trip));
      final b = await render(const CoverPainter(seed: 'g2', family: CoverFamily.trip));
      final c = await render(const CoverPainter(seed: 'g1', family: CoverFamily.home));
      expect(a, isNot(b));
      expect(a, isNot(c));
    });
  });

  // TC-B3-03
  test('shouldRepaint reacts to every input', () {
    const base = CoverPainter(seed: 's', family: CoverFamily.trip);
    expect(base.shouldRepaint(const CoverPainter(seed: 's', family: CoverFamily.trip)), isFalse);
    expect(base.shouldRepaint(const CoverPainter(seed: 't', family: CoverFamily.trip)), isTrue);
    expect(base.shouldRepaint(const CoverPainter(seed: 's', family: CoverFamily.home)), isTrue);
    expect(
      base.shouldRepaint(const CoverPainter(seed: 's', family: CoverFamily.trip, dark: true)),
      isTrue,
    );
    expect(
      base.shouldRepaint(
        const CoverPainter(seed: 's', family: CoverFamily.trip, legibilityScrim: false),
      ),
      isTrue,
    );
  });

  // TC-B3-03
  test('CoverCache.keyFor differs by seed, size, dpr and brightness', () {
    const p = CoverPainter(seed: 's', family: CoverFamily.trip);
    const other = CoverPainter(seed: 'x', family: CoverFamily.trip);
    const dark = CoverPainter(seed: 's', family: CoverFamily.trip, dark: true);
    const size = Size(100, 100);
    final k = CoverCache.keyFor(p, size, 2);
    expect(k, CoverCache.keyFor(p, size, 2));
    expect(k, isNot(CoverCache.keyFor(p, const Size(101, 100), 2)));
    expect(k, isNot(CoverCache.keyFor(p, size, 3)));
    expect(k, isNot(CoverCache.keyFor(other, size, 2)));
    expect(k, isNot(CoverCache.keyFor(dark, size, 2)));
  });

  // TC-B3-03
  testWidgets('CoverCache.warm stores an image and clear drops it', (tester) async {
    await tester.runAsync(() async {
      final cache = CoverCache.instance..clear();
      const p = CoverPainter(seed: 'warm', family: CoverFamily.couple);
      var ready = 0;
      final key = CoverCache.keyFor(p, const Size(50, 60), 1);
      expect(cache.get(key), isNull);
      await cache.warm(p, const Size(50, 60), 1, () => ready++);
      expect(ready, 1);
      expect(cache.get(key), isNotNull);
      expect(cache.length, 1);
      await cache.warm(p, const Size(50, 60), 1, () => ready++);
      expect(ready, 1, reason: 'already cached');
      cache.clear();
      expect(cache.length, 0);
    });
  });
}
