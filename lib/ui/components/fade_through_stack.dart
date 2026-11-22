import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// An [IndexedStack] that fades through on index changes (S-263): the old child fades out over the first
/// 35 %, the new one fades in and settles from 98 % scale over the rest (220 ms in all). Every child keeps
/// its state; hidden children don't tick or take taps. The new tab takes taps at once.
class FadeThroughStack extends StatefulWidget {
  const FadeThroughStack({required this.index, required this.children, super.key});

  final int index;
  final List<Widget> children;

  @override
  State<FadeThroughStack> createState() => _FadeThroughStackState();
}

class _FadeThroughStackState extends State<FadeThroughStack> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, value: 1);
  late int _from = widget.index;

  static const _out = Interval(0, 0.35, curve: Curves.easeIn);
  static const _in = Interval(0.35, 1, curve: Curves.easeOut);

  @override
  void didUpdateWidget(FadeThroughStack old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    final motion = context.motion;
    _from = old.index;
    if (motion.reduced) {
      _c.value = 1;
      return;
    }
    _c
      ..duration = motion.tab
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final animating = t < 1 && _from != widget.index;
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _Slot(
                key: ValueKey(i),
                visible: i == widget.index || (animating && i == _from),
                interactive: i == widget.index,
                opacity: !animating
                    ? 1
                    : i == widget.index
                    ? _in.transform(t)
                    : 1 - _out.transform(t),
                scale: animating && i == widget.index ? 0.98 + 0.02 * _in.transform(t) : 1,
                child: widget.children[i],
              ),
          ],
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.visible,
    required this.interactive,
    required this.opacity,
    required this.scale,
    required this.child,
    super.key,
  });

  final bool visible;
  final bool interactive;
  final double opacity;
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: !visible,
    child: TickerMode(
      enabled: visible,
      child: IgnorePointer(
        ignoring: !interactive,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        ),
      ),
    ),
  );
}
