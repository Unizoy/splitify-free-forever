import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:splitify/ui/painters/dashed.dart';
import 'package:splitify/ui/painters/noise_painter.dart';

/// The leather sleeve of the wallet showpiece (542 "INFINITY" wallet):
/// rounded body whose top edge dips in the middle (the pocket mouth the card
/// peeks out of), grain, a lit pocket lip and a stitched dashed edge.
class SleevePainter extends CustomPainter {
  const SleevePainter({
    required this.top,
    required this.bottom,
    required this.stitch,
    required this.lip,
    this.earHeight = 36,
    this.radius = 40,
  });

  final Color top;
  final Color bottom;
  final Color stitch;

  /// Light edge along the pocket mouth.
  final Color lip;

  /// How far the side "ears" rise above the pocket mouth.
  final double earHeight;
  final double radius;

  /// Sleeve outline for [size]. The pocket mouth sits at y = [earHeight].
  Path outline(Size size, {double inset = 0}) {
    final w = size.width;
    final h = size.height;
    final r = radius - inset;
    final e = earHeight;
    final mouthIn = w * 0.12; // where the dip starts from each side
    return Path()
      ..moveTo(inset, inset + r)
      ..quadraticBezierTo(inset, inset, inset + r, inset)
      ..lineTo(mouthIn - 8, inset)
      ..cubicTo(mouthIn + 10, inset, mouthIn + 4, e + inset, mouthIn + 34, e + inset)
      ..lineTo(w - mouthIn - 34, e + inset)
      ..cubicTo(w - mouthIn - 4, e + inset, w - mouthIn - 10, inset, w - mouthIn + 8, inset)
      ..lineTo(w - inset - r, inset)
      ..quadraticBezierTo(w - inset, inset, w - inset, inset + r)
      ..lineTo(w - inset, h - inset - r)
      ..quadraticBezierTo(w - inset, h - inset, w - inset - r, h - inset)
      ..lineTo(inset + r, h - inset)
      ..quadraticBezierTo(inset, h - inset, inset, h - inset - r)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final body = outline(size);
    canvas
      ..save()
      ..clipPath(body)
      ..drawRect(
        Offset.zero & size,
        Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [top, bottom]),
      );
    paintNoise(canvas, size, seed: 42, light: lip, dark: bottom, density: 30, opacity: 0.18);
    // Soft inner shadow under the pocket mouth.
    canvas
      ..drawRect(
        Rect.fromLTWH(0, earHeight, size.width, 28),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, earHeight), Offset(0, earHeight + 28), [
            bottom.withValues(alpha: 0.7),
            bottom.withValues(alpha: 0),
          ]),
      )
      ..restore();
    // Pocket lip highlight.
    canvas
      ..drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = lip.withValues(alpha: 0.35),
      )
      // Stitching.
      ..drawPath(
        dashPath(outline(size, inset: 9), dash: 5, gap: 4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = stitch,
      );
  }

  @override
  bool shouldRepaint(SleevePainter old) =>
      old.top != top ||
      old.bottom != bottom ||
      old.stitch != stitch ||
      old.lip != lip ||
      old.earHeight != earHeight ||
      old.radius != radius;
}
