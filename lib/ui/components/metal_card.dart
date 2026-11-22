import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:splitify/ui/components/pressable.dart';
import 'package:splitify/ui/components/stat_grid.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Brushed-silver stats card (542 vault card) with a slow sheen sweep.
/// "Your stats": expenses this month, groups.
class MetalCard extends StatefulWidget {
  const MetalCard({
    required this.title,
    required this.stats,
    this.icon = AppIcons.shieldCheckFill,
    this.onTap,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<StatItem> stats;
  final VoidCallback? onTap;

  @override
  State<MetalCard> createState() => _MetalCardState();
}

class _MetalCardState extends State<MetalCard> with SingleTickerProviderStateMixin {
  late final _sheen = AnimationController(vsync: this, duration: const Duration(seconds: 5));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.motion.reduced) {
      _sheen
        ..stop()
        ..value = 0.35;
    } else if (!_sheen.isAnimating) {
      _sheen.repeat();
    }
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: widget.onTap != null,
      container: true,
      child: Pressable(
        onTap: widget.onTap,
        borderRadius: AppRadii.all32,
        child: ClipRRect(
          borderRadius: AppRadii.all32,
          child: ColoredBox(
            color: c.metal,
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _BrushedMetalPainter(
                        base: c.metal,
                        highlight: c.metalHighlight,
                        shade: c.metalShade,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SheenPainter(sheen: _sheen, highlight: c.metalHighlight),
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
                        icon: widget.icon,
                        title: widget.title,
                        color: c.onMetal,
                        dividerColor: c.onMetal.withValues(alpha: 0.14),
                        showChevron: widget.onTap != null,
                      ),
                      StatGrid(
                        stats: widget.stats,
                        valueColor: c.onMetal,
                        labelColor: c.onMetal.withValues(alpha: 0.72),
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

class _BrushedMetalPainter extends CustomPainter {
  const _BrushedMetalPainter({required this.base, required this.highlight, required this.shade});

  final Color base;
  final Color highlight;
  final Color shade;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Brushed look: vertical bands of highlight and shade across the width.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, 0),
          [base, highlight, base, shade, base, highlight, base],
          const [0, 0.18, 0.36, 0.55, 0.7, 0.86, 1],
        ),
    );
    // Fine horizontal brush strokes.
    final random = Random(11);
    final stroke = Paint()..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 2) {
      stroke.color = (random.nextBool() ? highlight : shade).withValues(
        alpha: 0.05 + random.nextDouble() * 0.08,
      );
      canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke);
    }
  }

  @override
  bool shouldRepaint(_BrushedMetalPainter old) =>
      old.base != base || old.highlight != highlight || old.shade != shade;
}

/// A soft diagonal band of light that sweeps across, then rests.
class _SheenPainter extends CustomPainter {
  _SheenPainter({required this.sheen, required this.highlight}) : super(repaint: sheen);

  final Animation<double> sheen;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final t = (sheen.value * 1.6).clamp(0.0, 1.0);
    if (t >= 1) return;
    final x = -size.width * 0.5 + t * size.width * 2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x - 80, 0),
          Offset(x + 80, size.height),
          [
            highlight.withValues(alpha: 0),
            highlight.withValues(alpha: 0.55),
            highlight.withValues(alpha: 0),
          ],
          const [0, 0.5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_SheenPainter old) => old.highlight != highlight;
}
