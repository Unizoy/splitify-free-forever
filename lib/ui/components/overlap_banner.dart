import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:splitify/ui/theme/theme.dart';

/// Indigo summary banner (712) that overhangs its parent card by 8 dp on each
/// side: outlined shield/check icon, a light first line and a bold second line.
/// Group summary: "You are owed here" / "₹2,400".
class OverlapBanner extends StatelessWidget {
  const OverlapBanner({
    required this.line1,
    required this.line2,
    this.icon = AppIcons.shieldCheck,
    this.overhang = AppSpacing.s2,
    super.key,
  });

  final String line1;
  final String line2;
  final IconData icon;

  /// How far it sticks out on each side.
  final double overhang;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = c.onPrimaryFill;
    final banner = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5, vertical: AppSpacing.s5),
      decoration: BoxDecoration(
        color: c.primaryFill,
        borderRadius: AppRadii.all24,
        boxShadow: AppShadows.lifted(c),
      ),
      child: Row(
        children: [
          Icon(icon, size: 48, color: fg),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line1, style: context.text.body.copyWith(color: fg.withValues(alpha: 0.9))),
                const SizedBox(height: 2),
                // Usually an amount: tabular figures like every amount (S-443).
                Text(
                  line2,
                  style: context.text.headline.copyWith(
                    color: fg,
                    fontFeatures: AppText.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      child: LayoutBuilder(
        builder: (context, constraints) => OverflowBox(
          fit: OverflowBoxFit.deferToChild,
          minWidth: constraints.maxWidth + overhang * 2,
          maxWidth: constraints.maxWidth + overhang * 2,
          child: banner,
        ),
      ),
    );
  }
}
