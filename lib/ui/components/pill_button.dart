import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/dots_pulse.dart';
import 'package:splitify/ui/components/pressable.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Button styles (planning/06-design-system.md §6 `PillButton`).
enum PillVariant {
  /// Black pill, white text (white/black in dark mode). Default primary.
  ink,

  /// White pill with black text, for dark heroes and glass cards.
  inverse,

  /// Amber money action: Save expense, Settle up, Mark as paid.
  money,

  /// Indigo outline, radius 16 (option lists, 532).
  outline,

  /// Text only.
  ghost,

  /// Red pill for actions that cannot be undone (Delete my account; final QA).
  danger,
}

/// Button heights: 56 (primary) or 44 (secondary).
enum PillSize { large, medium }

/// Pill-shaped button with press, focus, loading (3-dot pulse) and disabled
/// states. Grows with the text scale; never clips its label.
class PillButton extends StatefulWidget {
  const PillButton({
    required this.label,
    required this.onPressed,
    this.variant = PillVariant.ink,
    this.size = PillSize.large,
    this.icon,
    this.leading,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
    super.key,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final PillVariant variant;
  final PillSize size;
  final IconData? icon;

  /// Drawn before the label instead of [icon] (the Google "G", which keeps its own colours).
  final Widget? leading;

  /// Drawn after the label (the welcome's "Get started →", S-282).
  final IconData? trailingIcon;

  /// Shows the 3-dot pulse instead of the label and ignores taps.
  final bool loading;

  /// Fills the available width.
  final bool expand;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final _press = PressMotion(this);

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _highlight(bool v) {
    _press.set(context.motion, pressed: v);
    setState(() => _pressed = v);
  }

  void _tap() {
    // Primary actions tick (§5); outline and ghost buttons stay quiet.
    if (widget.variant == PillVariant.ink || widget.variant == PillVariant.money) {
      AppHaptics.light();
    }
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.onPressed != null && !widget.loading;
    final disabledSolid = widget.onPressed == null && !widget.loading;
    var (bg, fg, border) = switch (widget.variant) {
      PillVariant.ink => (c.ink, c.onInk, null),
      PillVariant.inverse => (c.onHero, AppPalette.black, null),
      PillVariant.money => (c.money, c.onMoney, null),
      PillVariant.outline => (AppPalette.clear, c.primary, c.primary),
      PillVariant.ghost => (AppPalette.clear, c.textPrimary, null),
      PillVariant.danger =>
        context.isDark
            ? (c.chipDarkRed, c.onChipDarkRed, null)
            : (c.oweText, AppPalette.white, null),
    };
    final solid = widget.variant == PillVariant.ink || widget.variant == PillVariant.money;
    if (disabledSolid && solid) {
      bg = c.primaryDisabled;
      fg = context.isDark ? c.textSecondary : c.onPrimaryFill;
    }
    if (disabledSolid && widget.variant == PillVariant.danger) {
      bg = c.chip;
      fg = c.textTertiary;
    }
    if (_pressed && enabled) {
      bg = switch (widget.variant) {
        PillVariant.money => c.moneyPressed,
        PillVariant.outline => c.primaryContainer,
        PillVariant.ghost => c.chip,
        _ => bg,
      };
    }
    final radius = widget.variant == PillVariant.outline ? AppRadii.all16 : AppRadii.allPill;
    final height = widget.size == PillSize.large ? AppSpacing.buttonLarge : AppSpacing.buttonMedium;
    final style =
        (widget.size == PillSize.large ? context.text.button : context.text.bodySmall.w(600))
            .copyWith(color: fg);

    final content = widget.loading
        ? DotsPulse(color: fg, semanticLabel: AppLocalizations.of(context).loading)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.leading case final leading?) ...[
                leading,
                const SizedBox(width: AppSpacing.s3),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: fg),
                const SizedBox(width: AppSpacing.s2),
              ],
              Flexible(
                child: Text(widget.label, style: style, textAlign: TextAlign.center),
              ),
              if (widget.trailingIcon != null) ...[
                const SizedBox(width: AppSpacing.s2),
                Icon(widget.trailingIcon, size: 20, color: fg),
              ],
            ],
          );

    const range = 1 - AppMotion.pressScale;
    final button = AnimatedBuilder(
      animation: _press.controller,
      builder: (context, child) => Transform.scale(scale: 1 - range * _press.value, child: child),
      child: Opacity(
        opacity: disabledSolid && !solid ? 0.4 : 1,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: border == null ? BorderSide.none : BorderSide(color: border, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? _tap : null,
            onHighlightChanged: _highlight,
            splashFactory: NoSplash.splashFactory,
            highlightColor: fg.withValues(alpha: 0.08),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: height,
                minWidth: widget.expand ? double.infinity : height,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s6,
                  vertical: AppSpacing.s2,
                ),
                child: Center(widthFactor: 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.loading ? widget.label : null,
      child: button,
    );
  }
}
