import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// One big number with its label.
typedef StatItem = ({String value, String label});

/// Two-column grid of big numbers with labels (542 trips/vault cards).
class StatGrid extends StatelessWidget {
  const StatGrid({
    required this.stats,
    required this.valueColor,
    required this.labelColor,
    this.columns = 2,
    super.key,
  });

  final List<StatItem> stats;
  final Color valueColor;
  final Color labelColor;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final columns = large ? 1 : this.columns;
    final rows = <List<StatItem>>[];
    for (var i = 0; i < stats.length; i += columns) {
      rows.add(stats.sublist(i, (i + columns).clamp(0, stats.length)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: AppSpacing.s5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columns; i++)
                Expanded(
                  child: i < rows[r].length
                      ? Padding(
                          // A gap between columns, so a shrunk amount never touches its neighbour.
                          padding: EdgeInsetsDirectional.only(
                            end: i < columns - 1 ? AppSpacing.s3 : 0,
                          ),
                          child: MergeSemantics(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Long amounts ("₹12,345.50") shrink instead of breaking mid-number.
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    rows[r][i].value,
                                    maxLines: 1,
                                    style: context.text.amountHero.copyWith(
                                      color: valueColor,
                                      fontSize: 32,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s1),
                                Text(
                                  rows[r][i].label,
                                  style: context.text.body.w(500).copyWith(color: labelColor),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Card header used by the showpiece cards: icon, letter-spaced title,
/// chevron, thin divider below.
class ShowcaseCardHeader extends StatelessWidget {
  const ShowcaseCardHeader({
    required this.icon,
    required this.title,
    required this.color,
    required this.dividerColor,
    this.showChevron = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color dividerColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title.toUpperCase(),
                  style: context.text.labelCaps.copyWith(
                    color: color,
                    fontSize: 14,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ),
            if (showChevron) Icon(AppIcons.chevronRight, size: 18, color: color),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        Divider(height: 1, thickness: 1, color: dividerColor),
        const SizedBox(height: AppSpacing.s5),
      ],
    );
  }
}
