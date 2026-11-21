import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Filter/category chip (442 Music/Sports): pill with a leading 24 dp coloured
/// circle icon. Outlined when unselected, filled `ink` when selected.
/// [onDark] draws it for dark heroes (white outline, 555).
class IconChip extends StatelessWidget {
  const IconChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.selected = false,
    this.onDark = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Colour of the icon circle; defaults to primary.
  final Color? iconColor;
  final bool selected;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Color bg;
    final Color fg;
    final Color outline;
    if (onDark) {
      bg = selected ? c.onHero : AppPalette.clear;
      fg = selected ? AppPalette.black : c.onHero;
      outline = c.onHero.withValues(alpha: selected ? 1 : 0.7);
    } else {
      bg = selected ? c.ink : c.surface;
      fg = selected ? c.onInk : c.textPrimary;
      outline = selected ? c.ink : c.border;
    }
    final circle = iconColor ?? c.primaryFill;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: outline, width: 1.2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                icon == null ? AppSpacing.s5 : AppSpacing.s3,
                AppSpacing.s2,
                AppSpacing.s5,
                AppSpacing.s2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
                      child: Icon(icon, size: 16, color: c.onPrimaryFill),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                  ],
                  Flexible(
                    child: Text(label, style: context.text.body.w(600).copyWith(color: fg)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
