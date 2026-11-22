import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Colour treatments of a [StatusPill].
enum StatusPillTone {
  /// Indigo fill, white text (532 header pill).
  primary,

  /// Lime on dark green (455 date chip): "You are owed".
  positive,

  /// Light red on dark red: "You owe".
  negative,

  /// Translucent white on photos and glass: "All settled".
  glass,

  /// No fill: coloured icon + letter-spaced caps (438 "APPROVED").
  flat,
}

/// Small pill with an optional leading icon.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    this.icon,
    this.tone = StatusPillTone.primary,
    this.iconColor,
    super.key,
  });

  final String label;
  final IconData? icon;
  final StatusPillTone tone;

  /// Overrides the icon colour (the flat pill's lime would say "owed" next to "You owe"; final QA).
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color fg, Color iconColor) = switch (tone) {
      StatusPillTone.primary => (c.primaryFill, c.onPrimaryFill, c.onPrimaryFill),
      StatusPillTone.positive => (c.chipDarkGreen, c.onChipDarkGreen, c.onChipDarkGreen),
      StatusPillTone.negative => (c.chipDarkRed, c.onChipDarkRed, c.onChipDarkRed),
      StatusPillTone.glass => (c.onHero.withValues(alpha: 0.16), c.onHero, c.onHero),
      StatusPillTone.flat => (AppPalette.clear, c.onHero, c.owedAccent),
    };
    final flat = tone == StatusPillTone.flat;
    final style = flat
        ? context.text.labelCaps.copyWith(color: fg)
        : context.text.bodySmall.w(600).copyWith(color: fg);
    return Container(
      padding: flat
          ? EdgeInsets.zero
          : const EdgeInsetsDirectional.fromSTEB(AppSpacing.s3, 6, AppSpacing.s4, 6),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.allPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: flat ? 20 : 16, color: this.iconColor ?? iconColor),
            const SizedBox(width: 6),
          ],
          Flexible(child: Text(flat ? label.toUpperCase() : label, style: style)),
        ],
      ),
    );
  }
}
