import 'package:flutter/material.dart';
import 'package:splitify/ui/components/motion_widgets.dart';
import 'package:splitify/ui/components/pressable.dart';
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
    // Resting (0) and selected (1) looks; the chip moves between them in 150 ms (S-451).
    final (Color bg0, Color bg1, Color fg0, Color fg1, Color line0, Color line1) = onDark
        ? (
            AppPalette.clear,
            c.onHero,
            c.onHero,
            AppPalette.black,
            c.onHero.withValues(alpha: 0.7),
            c.onHero,
          )
        : (c.surface, c.ink, c.textPrimary, c.onInk, c.border, c.ink);
    final circle = iconColor ?? c.primaryFill;
    return Semantics(
      button: true,
      selected: selected,
      child: SelectionMotion(
        selected: selected,
        builder: (context, t, _) {
          final fg = Color.lerp(fg0, fg1, t)!;
          return Pressable(
            onTap: onTap,
            borderRadius: AppRadii.allPill,
            scale: 0.95,
            haptic: PressHaptic.selection,
            highlightColor: fg,
            child: Material(
              color: Color.lerp(bg0, bg1, t),
              shape: StadiumBorder(
                side: BorderSide(color: Color.lerp(line0, line1, t)!, width: 1.2),
              ),
              clipBehavior: Clip.antiAlias,
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
          );
        },
      ),
    );
  }
}
