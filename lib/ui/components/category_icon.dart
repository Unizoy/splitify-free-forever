import 'package:flutter/widgets.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Icon in a circle tinted 12 % with its own colour (category rows, §2).
class TintedIcon extends StatelessWidget {
  const TintedIcon({required this.icon, required this.color, this.size = 40, super.key});

  /// Convenience for an expense [Category].
  TintedIcon.category(Category category, {double size = 40, Key? key})
    : this(icon: category.icon, color: category.color, size: size, key: key);

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.2 : 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.5, color: color),
      ),
    );
  }
}
