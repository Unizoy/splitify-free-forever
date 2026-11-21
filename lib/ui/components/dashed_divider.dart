import 'package:flutter/widgets.dart';
import 'package:splitify/ui/painters/dashed.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Full-width 1 dp dashed divider in the `divider` colour (534, 614).
class DashedDivider extends StatelessWidget {
  const DashedDivider({this.color, this.height = 1, super.key});

  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: DashedLinePainter(color: color ?? context.colors.divider, strokeWidth: height),
        ),
      ),
    );
  }
}
