import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:splitify/ui/theme/app_colors.dart';

/// The Splitify "split" mark: a circle cut into two halves that slide apart
/// (planning/06-design-system.md §8). Same geometry as `assets/brand/icon.svg`
/// (1024 grid: radius 250, gap 40, halves offset ±40).
///
/// With [background] the mark sits on the rounded-square indigo→lavender
/// tile of the app icon; [markScale] shrinks the mark (adaptive icon safe zone).
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({
    this.color = AppPalette.brandMark,
    this.background = false,
    this.fullBleed = false,
    this.markScale = 1,
  });

  final Color color;

  /// Paints the gradient tile behind the mark.
  final bool background;

  /// With [background]: fill the whole square (adaptive icon layer) instead
  /// of a rounded tile.
  final bool fullBleed;

  /// Size of the mark relative to the 1024 grid (1 = icon size).
  final double markScale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 1024;
    canvas
      ..save()
      ..translate((size.width - 1024 * s) / 2, (size.height - 1024 * s) / 2)
      ..scale(s);
    if (background) {
      final tile = const Rect.fromLTWH(0, 0, 1024, 1024);
      final paint = Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(1024, 1024), const [
          AppPalette.brandStart,
          AppPalette.brandEnd,
        ]);
      if (fullBleed) {
        canvas.drawRect(tile, paint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(tile, const Radius.circular(232)), paint);
      }
    }
    canvas
      ..translate(512, 512)
      ..scale(markScale)
      ..translate(-512, -512);
    final paint = Paint()..color = color;
    const r = 250.0;
    // Left half, nudged up.
    canvas.drawPath(
      Path()
        ..moveTo(492, 262 - 40)
        ..arcToPoint(
          const Offset(492, 762 - 40),
          radius: const Radius.circular(r),
          clockwise: false,
        )
        ..close(),
      paint,
    );
    // Right half, nudged down.
    canvas.drawPath(
      Path()
        ..moveTo(532, 262 + 40)
        ..arcToPoint(const Offset(532, 762 + 40), radius: const Radius.circular(r))
        ..close(),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) =>
      old.color != color ||
      old.background != background ||
      old.fullBleed != fullBleed ||
      old.markScale != markScale;
}
