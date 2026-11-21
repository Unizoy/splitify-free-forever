import 'package:flutter/widgets.dart';
import 'package:splitify/ui/painters/brand_mark_painter.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The Splitify mark as a widget: on its gradient tile ([tile]) or bare.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 48, this.tile = false, this.color, super.key});

  final double size;
  final bool tile;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: BrandMarkPainter(
          background: tile,
          color: color ?? AppPalette.brandMark,
          markScale: tile ? 0.86 : 1,
        ),
      ),
    );
  }
}
