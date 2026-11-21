import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:splitify/ui/painters/cover_painter.dart';
import 'package:splitify/ui/theme/app_covers.dart';
import 'package:splitify/ui/theme/context_ext.dart';

/// Renders each cover once to an image and keeps it, keyed by
/// `(family, seed, size, brightness, scrim)` (§7). Least recently used images
/// are dropped after [maxEntries].
class CoverCache {
  CoverCache._();

  static final instance = CoverCache._();

  static const maxEntries = 48;

  final _images = LinkedHashMap<String, ui.Image>();
  final _pending = <String>{};

  /// Cache key for a cover.
  static String keyFor(CoverPainter p, Size size, double dpr) =>
      '${p.family.name}|${p.seed}|${size.width.round()}x${size.height.round()}@$dpr'
      '|${p.dark}|${p.legibilityScrim}';

  /// The cached image for [key], if it is ready.
  ui.Image? get(String key) {
    final image = _images.remove(key);
    if (image != null) _images[key] = image;
    return image;
  }

  /// Number of cached images (for tests).
  int get length => _images.length;

  /// Renders [painter] at [size] × [dpr] in the background and stores it.
  /// Calls [onReady] when the image is cached.
  Future<void> warm(CoverPainter painter, Size size, double dpr, VoidCallback onReady) async {
    final key = keyFor(painter, size, dpr);
    if (_images.containsKey(key) || _pending.contains(key) || size.isEmpty) return;
    _pending.add(key);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(dpr);
      painter.paint(canvas, size);
      final picture = recorder.endRecording();
      final image = await picture.toImage((size.width * dpr).ceil(), (size.height * dpr).ceil());
      picture.dispose();
      _images[key] = image;
      while (_images.length > maxEntries) {
        _images.remove(_images.keys.first)?.dispose();
      }
      onReady();
    } finally {
      _pending.remove(key);
    }
  }

  /// Drops every cached image.
  void clear() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }
}

/// Paints a generated cover, filling its parent. Uses the [CoverCache] image
/// once it is ready and paints directly until then.
class CoverArt extends StatefulWidget {
  const CoverArt({
    required this.seed,
    required this.family,
    this.legibilityScrim = true,
    this.cache = true,
    super.key,
  });

  final String seed;
  final CoverFamily family;
  final bool legibilityScrim;

  /// Turn off to always paint directly (golden tests, one-off art).
  final bool cache;

  @override
  State<CoverArt> createState() => _CoverArtState();
}

class _CoverArtState extends State<CoverArt> {
  @override
  Widget build(BuildContext context) {
    final painter = CoverPainter(
      seed: widget.seed,
      family: widget.family,
      dark: context.isDark,
      legibilityScrim: widget.legibilityScrim,
    );
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (!widget.cache || !size.isFinite) {
            return CustomPaint(painter: painter, size: size.isFinite ? size : Size.zero);
          }
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final image = CoverCache.instance.get(CoverCache.keyFor(painter, size, dpr));
          if (image != null) {
            return RawImage(image: image, width: size.width, height: size.height, fit: BoxFit.fill);
          }
          CoverCache.instance.warm(painter, size, dpr, () {
            if (mounted) setState(() {});
          });
          return RepaintBoundary(
            child: CustomPaint(painter: painter, size: size),
          );
        },
      ),
    );
  }
}
