import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:splitify/core/utils/stable_hash.dart';
import 'package:splitify/ui/painters/noise_painter.dart';
import 'package:splitify/ui/theme/app_colors.dart';
import 'package:splitify/ui/theme/app_covers.dart';

/// Generated group cover (planning/06-design-system.md §7, D-013): a seeded
/// mesh gradient — 3–4 soft radial blobs over a base linear gradient — plus
/// 2 % grain and a bottom-to-top dark gradient so white text stays legible.
///
/// The same [seed] and [family] always give the same picture.
class CoverPainter extends CustomPainter {
  const CoverPainter({
    required this.seed,
    required this.family,
    this.dark = false,
    this.legibilityScrim = true,
  });

  final String seed;
  final CoverFamily family;

  /// Dims the art a little for dark mode.
  final bool dark;

  /// Adds the bottom dark gradient (0 → 55 %) for text on the cover.
  final bool legibilityScrim;

  @override
  void paint(Canvas canvas, Size size) {
    final hash = stableHash('${family.name}:$seed');
    final random = Random(hash);
    final rect = Offset.zero & size;
    final base = CoverPalettes.base[family]!;
    final colors = CoverPalettes.colors[family]!;

    // Base gradient at a seeded angle.
    final angle = random.nextDouble() * pi * 2;
    final dir = Offset(cos(angle), sin(angle));
    final center = rect.center;
    final reach = size.longestSide / 2;
    canvas.drawRect(
      rect,
      Paint()..shader = ui.Gradient.linear(center - dir * reach, center + dir * reach, base),
    );

    // Soft blobs.
    final blobs = 3 + random.nextInt(2);
    for (var i = 0; i < blobs; i++) {
      final color = colors[(i + random.nextInt(colors.length)) % colors.length];
      final c = Offset(
        size.width * (0.05 + random.nextDouble() * 0.9),
        size.height * (0.05 + random.nextDouble() * 0.9),
      );
      final r = size.longestSide * (0.35 + random.nextDouble() * 0.4);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            r,
            [
              color.withValues(alpha: 0.95),
              color.withValues(alpha: 0.45),
              color.withValues(alpha: 0),
            ],
            const [0, 0.45, 1],
          ),
      );
    }

    // Grain.
    paintNoise(
      canvas,
      size,
      seed: hash,
      light: AppPalette.white,
      dark: AppPalette.black,
      density: 8,
      opacity: 0.08,
    );

    if (legibilityScrim) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, size.height * 0.35), Offset(0, size.height), [
            AppPalette.black.withValues(alpha: 0),
            AppPalette.black.withValues(alpha: 0.55),
          ]),
      );
    }
    if (dark) {
      canvas.drawRect(rect, Paint()..color = AppPalette.black.withValues(alpha: 0.15));
    }
  }

  @override
  bool shouldRepaint(CoverPainter old) =>
      old.seed != seed ||
      old.family != family ||
      old.dark != dark ||
      old.legibilityScrim != legibilityScrim;
}
