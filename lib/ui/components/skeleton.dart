import 'dart:async';

import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Loading placeholder with a soft sweep of light across it (S-266): one sweep every 1.2 s for the whole
/// subtree (one controller, one shader), 8 sweeps at most (then it rests, so tests settle), still when the
/// user removed animations.
/// Put [SkeletonBox]es under it.
class Shimmer extends StatefulWidget {
  const Shimmer({required this.child, super.key});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const AppMotion(reduced: false).shimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.motion.reduced || !TickerMode.of(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      unawaited(_c.repeat(count: 8));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = c.surfaceMuted;
    final shine = context.isDark ? c.chip : c.bg;
    if (context.motion.reduced) return widget.child;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final x = -1.5 + 3 * _c.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(x - 0.6, -0.2),
              end: Alignment(x + 0.6, 0.2),
              colors: [
                base.withValues(alpha: 0),
                shine.withValues(alpha: 0.9),
                base.withValues(alpha: 0),
              ],
            ).createShader(rect),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// One placeholder block: `surfaceMuted` with the given radius. Size it with [width]/[height] or by the
/// parent.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({this.width, this.height, this.radius = AppRadii.all16, super.key});

  final double? width;
  final double? height;
  final BorderRadius radius;

  /// A text line placeholder (12 dp tall, pill ends).
  const SkeletonBox.line({this.width, super.key}) : height = 12, radius = AppRadii.allPill;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: DecoratedBox(
      decoration: BoxDecoration(color: context.colors.surfaceMuted, borderRadius: radius),
    ),
  );
}

/// A list-row placeholder: round icon, two text lines and an amount, like the real rows.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({this.lineWidth = 0.55, super.key});

  /// Width of the first line as a fraction of the space (vary it so rows don't look stamped).
  final double lineWidth;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
    child: Row(
      children: [
        const SkeletonBox(width: 40, height: 40, radius: AppRadii.allPill),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox.line(width: constraints.maxWidth * lineWidth),
                const SizedBox(height: AppSpacing.s2),
                SkeletonBox.line(width: constraints.maxWidth * 0.35),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s4),
        const SkeletonBox.line(width: 56),
      ],
    ),
  );
}
