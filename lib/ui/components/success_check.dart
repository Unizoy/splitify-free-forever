import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The success mark (S-452): a filled circle pops in (spring) and its check draws itself, 280 ms in all.
/// Plays once when it first builds; shows the finished mark when the user removed animations. Saved
/// expenses (the editor's overlay) and the success snackbar use it. No haptic: the caller plays
/// [AppHaptics.success] where the save happened.
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({this.size = 96, this.color, this.checkColor, super.key});

  final double size;

  /// Circle colour (ink by default).
  final Color? color;

  /// Check colour (the lime "owed" accent by default).
  final Color? checkColor;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final motion = context.motion;
    if (motion.reduced) {
      _c.value = 1;
    } else {
      _c
        ..duration = motion.success
        ..forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _pop = Interval(0, 0.6);
  static const _draw = Interval(0.35, 1, curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spring = context.motion.spring;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: SuccessCheckPainter(
            pop: spring.transform(_pop.transform(_c.value)),
            draw: _draw.transform(_c.value),
            circle: widget.color ?? c.ink,
            check: widget.checkColor ?? c.owedAccent,
          ),
        ),
      ),
    );
  }
}

/// Paints [SuccessCheck]: the circle at [pop] scale (may overshoot 1 a little) and the first [draw] part of
/// the check stroke.
class SuccessCheckPainter extends CustomPainter {
  const SuccessCheckPainter({
    required this.pop,
    required this.draw,
    required this.circle,
    required this.check,
  });

  final double pop;
  final double draw;
  final Color circle;
  final Color check;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    if (pop > 0) {
      canvas.drawCircle(center, r * math.max(0, pop), Paint()..color = circle);
    }
    if (draw <= 0) return;
    // The check: short leg down-right, long leg up-right (Phosphor-like proportions).
    final a = center + Offset(-0.42 * r, 0.02 * r);
    final b = center + Offset(-0.12 * r, 0.32 * r);
    final d = center + Offset(0.44 * r, -0.28 * r);
    final first = (b - a).distance;
    final total = first + (d - b).distance;
    final len = total * draw.clamp(0, 1);
    final path = Path()..moveTo(a.dx, a.dy);
    if (len <= first) {
      final p = Offset.lerp(a, b, len / first)!;
      path.lineTo(p.dx, p.dy);
    } else {
      final p = Offset.lerp(b, d, (len - first) / (total - first))!;
      path
        ..lineTo(b.dx, b.dy)
        ..lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = check
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, r * 0.17)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(SuccessCheckPainter old) =>
      old.pop != pop || old.draw != draw || old.circle != circle || old.check != check;
}
