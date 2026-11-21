import 'dart:math';

import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Three dots that pulse in turn: the busy state of buttons. Static when the
/// user removed animations.
class DotsPulse extends StatefulWidget {
  const DotsPulse({required this.color, this.semanticLabel, this.size = 7, super.key});

  final Color color;
  final String? semanticLabel;
  final double size;

  @override
  State<DotsPulse> createState() => _DotsPulseState();
}

class _DotsPulseState extends State<DotsPulse> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.motion.reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Opacity(
                  opacity: _opacity(i),
                  child: SizedBox.square(
                    dimension: widget.size,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _opacity(int i) {
    if (context.motion.reduced) return 0.7;
    final phase = (_controller.value - i / 3) % 1;
    return 0.3 + 0.7 * (0.5 + 0.5 * sin(phase * 2 * pi));
  }
}
