// TC-29-01 (compression bounds): squareBound vectors and the preparePhoto ladder with a fake encoder.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/photos/application/photo_compression.dart';

/// Bytes whose first 8 bytes hold width and height; the rest pads the length.
Uint8List img(int w, int h, [int length = 8]) {
  final b = Uint8List(math.max(8, length));
  b.buffer.asByteData()
    ..setUint32(0, w)
    ..setUint32(4, h);
  return b;
}

ImageSize sizeOfImg(Uint8List b) {
  if (b.length < 8) throw const FormatException('undecodable');
  final d = b.buffer.asByteData(b.offsetInBytes);
  return (width: d.getUint32(0), height: d.getUint32(4));
}

class Call {
  Call(this.bound, this.quality);
  final int bound;
  final int quality;
}

/// Applies the real plugin rule: scale = max(1, min(w / bound, h / bound)); out = floor(w / scale).
class FakeEncoder {
  FakeEncoder({this.length = _small, this.undecodableAs = (width: 6000, height: 4500)});

  static int _small(int bound, int quality) => 1000;

  int Function(int bound, int quality) length;
  final ImageSize undecodableAs;
  final calls = <Call>[];
  final outputs = <ImageSize>[];

  Future<Uint8List> call(Uint8List source, {required int bound, required int quality}) async {
    calls.add(Call(bound, quality));
    final s = source.length < 8 ? undecodableAs : sizeOfImg(source);
    final scale = math.max(1, math.min(s.width / bound, s.height / bound));
    final out = (width: (s.width / scale).floor(), height: (s.height / scale).floor());
    outputs.add(out);
    return img(out.width, out.height, length(bound, quality));
  }
}

void main() {
  group('squareBound', () {
    // TC-29-01
    test('vectors', () {
      int b(int w, int h, int side) => squareBound((width: w, height: h), side);
      expect(b(4000, 3000, 1600), 1200);
      expect(b(3000, 4000, 1600), 1200);
      expect(b(8000, 1000, 1600), 200);
      expect(b(800, 600, 1600), 600);
      expect(b(1600, 1200, 1600), 1200);
      expect(b(1, 1, 1600), 1);
      expect(b(4000, 2999, 1600), 1199);
      expect(b(0, 0, 1600), 1);
      expect(b(4000, 3000, 480), 360);
    });

    // TC-29-01
    test('longer side of the encoded result stays within the limit for many sizes', () async {
      const sizes = <(int, int)>[
        (4000, 3000),
        (3000, 4000),
        (8000, 1000),
        (1000, 8000),
        (12000, 9000),
        (1600, 1600),
        (1601, 1599),
        (800, 600),
        (479, 481),
        (50, 20),
        (1, 1),
        (50, 5000),
        (30000, 300),
        (4000, 2999),
      ];
      for (final (w, h) in sizes) {
        for (final (side, _) in [(PhotoLimits.maxSide, 0), (PhotoLimits.thumbSide, 0)]) {
          final enc = FakeEncoder();
          await enc(img(w, h), bound: squareBound((width: w, height: h), side), quality: 80);
          final out = enc.outputs.single;
          expect(
            math.max(out.width, out.height),
            lessThanOrEqualTo(side),
            reason: '$w x $h @ $side',
          );
        }
      }
    });
  });

  group('preparePhoto', () {
    Future<(FakeEncoder, PreparedImage)> run(FakeEncoder enc, Uint8List src) async {
      final r = await preparePhoto(src, encode: enc.call, sizeOf: (b) async => sizeOfImg(b));
      return (enc, r);
    }

    // TC-29-01
    test(
      'a photo that fits on the first try uses 1600 / q80 and 480 / q70 for the thumb',
      () async {
        final enc = FakeEncoder();
        final (_, r) = await run(enc, img(4000, 3000));
        expect(enc.calls, hasLength(2));
        expect(enc.calls[0].bound, 1200);
        expect(enc.calls[0].quality, 80);
        expect(enc.calls[1].bound, 360);
        expect(enc.calls[1].quality, PhotoLimits.thumbQuality);
        final full = sizeOfImg(r.full);
        final thumb = sizeOfImg(r.thumb);
        expect(math.max(full.width, full.height), lessThanOrEqualTo(1600));
        expect(math.max(thumb.width, thumb.height), lessThanOrEqualTo(480));
        expect((r.full).length, 1000);
      },
    );

    // TC-29-01
    test('walks the ladder and stops at the first step that fits 500 KB', () async {
      // Only the 1280 / q60 step (bound 960 for 4:3) is small enough.
      final enc = FakeEncoder(length: (bound, q) => q <= 60 && bound <= 960 ? 1000 : 600 * 1024);
      final (_, r) = await run(enc, img(4000, 3000));
      expect(enc.calls.take(4).map((c) => (c.bound, c.quality)), [
        (1200, 80),
        (1200, 70),
        (1200, 60),
        (960, 60),
      ]);
      // 4 full tries + 1 thumb.
      expect(enc.calls, hasLength(5));
      expect((r.full).length, 1000);
    });

    // TC-29-01
    test('when nothing fits it returns the last ladder step', () async {
      final enc = FakeEncoder(length: (b, q) => 900 * 1024);
      final (_, r) = await run(enc, img(4000, 3000));
      expect(enc.calls, hasLength(PhotoLimits.ladder.length + 1));
      expect(enc.calls[PhotoLimits.ladder.length - 1].quality, 50);
      expect(enc.calls[PhotoLimits.ladder.length - 1].bound, 600);
      expect((r.full).length, 900 * 1024);
      final full = sizeOfImg(r.full);
      expect(math.max(full.width, full.height), lessThanOrEqualTo(800));
    });

    // TC-29-01
    test('exactly 500 KB fits', () async {
      final enc = FakeEncoder(length: (b, q) => PhotoLimits.maxBytes);
      await run(enc, img(4000, 3000));
      expect(enc.calls, hasLength(2));
    });

    // TC-29-01
    test('a source the size reader cannot decode is re-encoded once and measured again', () async {
      final enc = FakeEncoder();
      var reads = 0;
      final r = await preparePhoto(
        Uint8List.fromList([1, 2, 3]),
        encode: enc.call,
        sizeOf: (b) async {
          reads++;
          return sizeOfImg(b);
        },
      );
      expect(reads, 2);
      expect(enc.calls[0].bound, 3200);
      expect(enc.calls[0].quality, 95);
      // 6000x4500 -> 3200 bound -> 4266x3200, then squareBound(.., 1600) = 1600*3200/4266 = 1200.
      expect(enc.calls[1].bound, 1200);
      expect(enc.calls[1].quality, 80);
      expect(enc.calls, hasLength(3));
      expect(r.full, isNotEmpty);
    });

    // TC-29-01
    test('a second decode failure propagates', () async {
      final enc = FakeEncoder();
      await expectLater(
        preparePhoto(
          Uint8List.fromList([1]),
          encode: (s, {required bound, required quality}) async => Uint8List(2),
          sizeOf: (b) async => sizeOfImg(b),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(enc.calls, isEmpty);
    });
  });
}
