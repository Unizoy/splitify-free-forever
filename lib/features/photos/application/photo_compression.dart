import 'dart:math' as math;
import 'dart:typed_data';

import 'package:splitify/domain/entities/prepared_image.dart';

/// Pixel size of an encoded image.
typedef ImageSize = ({int width, int height});

/// Re-encodes [source] as JPEG at [quality] so that `min(width / bound, height / bound)` becomes the
/// scale (flutter_image_compress's `minWidth = minHeight = bound`; never upscales).
typedef JpegEncode = Future<Uint8List> Function(
  Uint8List source, {
  required int bound,
  required int quality,
});

/// Reads the pixel size of an encoded image (throws when it cannot be decoded).
typedef SizeReader = Future<ImageSize> Function(Uint8List bytes);

/// Photo limits (04 §6, 08 cross-cutting): JPEG q80, longer side ≤ 1600 px, ≤ 500 KB; thumbnails 480 px.
abstract final class PhotoLimits {
  static const maxSide = 1600;
  static const maxBytes = 500 * 1024;
  static const thumbSide = 480;
  static const thumbQuality = 70;

  /// Tried in order until the JPEG fits [maxBytes] (side, quality); the first one is the spec's q80.
  static const ladder = <(int, int)>[
    (1600, 80),
    (1600, 70),
    (1600, 60),
    (1280, 60),
    (1024, 55),
    (800, 50),
  ];
}

/// The square bound that makes the longer side of [size] at most [maxSide] (S-111): the encoder scales
/// by `min(w, h) / bound`, so a bound of `maxSide × short / long` scales the long side to [maxSide]
/// whichever way the photo is rotated. Smaller photos keep their size.
int squareBound(ImageSize size, int maxSide) {
  final long = math.max(size.width, size.height);
  final short = math.min(size.width, size.height);
  if (long <= maxSide) return math.max(1, short);
  return math.max(1, maxSide * short ~/ long);
}

/// Compresses a picked photo for upload and makes its thumbnail (TC-29-01). Photos the size reader
/// cannot decode (e.g. HEIC) are first re-encoded once as JPEG and measured from that.
Future<PreparedImage> preparePhoto(
  Uint8List source, {
  required JpegEncode encode,
  required SizeReader sizeOf,
}) async {
  var input = source;
  ImageSize size;
  try {
    size = await sizeOf(input);
  } on Exception {
    input = await encode(input, bound: PhotoLimits.maxSide * 2, quality: 95);
    size = await sizeOf(input);
  }
  late Uint8List full;
  for (final (side, quality) in PhotoLimits.ladder) {
    full = await encode(input, bound: squareBound(size, side), quality: quality);
    if (full.lengthInBytes <= PhotoLimits.maxBytes) break;
  }
  final thumb = await encode(
    input,
    bound: squareBound(size, PhotoLimits.thumbSide),
    quality: PhotoLimits.thumbQuality,
  );
  return PreparedImage(full: full, thumb: thumb);
}
