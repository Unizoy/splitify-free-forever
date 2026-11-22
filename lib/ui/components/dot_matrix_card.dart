import 'package:flutter/material.dart';
import 'package:splitify/ui/components/pressable.dart';
import 'package:splitify/ui/components/stat_grid.dart';
import 'package:splitify/ui/painters/dot_matrix_painter.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Navy stats card with a dotted globe (542 trips card): letter-spaced title,
/// big numbers with labels. Entry to Insights.
class DotMatrixCard extends StatelessWidget {
  const DotMatrixCard({
    required this.title,
    required this.stats,
    this.icon = AppIcons.chart,
    this.onTap,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<StatItem> stats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: onTap != null,
      container: true,
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadii.all32,
        child: ClipRRect(
          borderRadius: AppRadii.all32,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.navyTop, c.navyBottom],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -60,
                  bottom: -70,
                  width: 260,
                  height: 260,
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: DotMatrixPainter(color: c.onHero.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s6,
                    AppSpacing.s6,
                    AppSpacing.s6,
                    AppSpacing.s8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShowcaseCardHeader(
                        icon: icon,
                        title: title,
                        color: c.onHero,
                        dividerColor: c.onHero.withValues(alpha: 0.14),
                        showChevron: onTap != null,
                      ),
                      FractionallySizedBox(
                        widthFactor: MediaQuery.textScalerOf(context).scale(1) >= 1.6 ? 1 : 0.72,
                        child: StatGrid(
                          stats: stats,
                          valueColor: c.onHero,
                          labelColor: c.onHero.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
