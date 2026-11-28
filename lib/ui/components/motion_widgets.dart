import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// A value that changes in place (S-451): the old look fades out while the new one fades in and settles from
/// 96 % scale, 180 ms. Give [child] a key per state ("in INR" / "by currency", simplified / original, a split
/// mode). [grow] makes the two heights cross too (a card that comes or goes, like the monthly summary): each
/// child folds in or out from the top instead of scaling. Instant when the user removed animations. The new
/// child takes taps at once; the old one never does. The first build shows [child] without a move.
class MotionSwitcher extends StatelessWidget {
  const MotionSwitcher({
    required this.child,
    this.alignment = Alignment.topCenter,
    this.scale = true,
    this.grow = false,
    super.key,
  });

  final Widget child;

  /// Where the two children line up while they cross (top: the content below doesn't jump).
  final AlignmentGeometry alignment;

  /// Settle from 96 % (off for wide blocks, where a scale reads as a zoom).
  final bool scale;

  /// Fold the height in and out (220 ms) instead of scaling.
  final bool grow;

  static const double from = 0.96;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    return AnimatedSwitcher(
      duration: grow ? motion.expand : motion.swap,
      reverseDuration: grow ? motion.expand : motion.swap,
      // The switcher curves the animation it hands out (no CurvedAnimation per build to dispose).
      switchInCurve: grow ? AppMotion.standard : Curves.easeOut,
      switchOutCurve: grow ? AppMotion.standard : Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [
          for (final p in previous) IgnorePointer(child: p),
          ?current,
        ],
      ),
      transitionBuilder: (child, animation) {
        final faded = FadeTransition(opacity: animation, child: child);
        if (grow) {
          return SizeTransition(sizeFactor: animation, axisAlignment: -1, child: faded);
        }
        if (!scale) return faded;
        return ScaleTransition(
          scale: Tween<double>(begin: from, end: 1).animate(animation),
          child: faded,
        );
      },
      child: child,
    );
  }
}

/// A section that opens and closes in place (S-451): it grows from the top while its content fades in
/// (220 ms, standard curve) and folds back the same way. Nothing is built while it is closed. Instant when the
/// user removed animations. Taps work during the move.
class AppExpand extends StatefulWidget {
  const AppExpand({required this.open, required this.child, super.key});

  final bool open;
  final Widget child;

  @override
  State<AppExpand> createState() => _AppExpandState();
}

class _AppExpandState extends State<AppExpand> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, value: widget.open ? 1 : 0)
    ..addStatusListener((_) => setState(() {}));
  late final _size = CurvedAnimation(parent: _c, curve: AppMotion.standard);
  late final _fade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
    reverseCurve: const Interval(0.4, 1, curve: Curves.easeIn),
  );

  @override
  void didUpdateWidget(AppExpand old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    final motion = context.motion;
    if (motion.reduced) {
      _c.value = widget.open ? 1 : 0;
      return;
    }
    _c.duration = motion.expand;
    if (widget.open) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _fade.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_c.isDismissed) return const SizedBox(width: double.infinity);
    // The same wrappers open and moving, so the content keeps its state when the move ends.
    return SizeTransition(
      sizeFactor: _size,
      axisAlignment: -1,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }
}

/// The 0 → 1 progress of a control moving between its resting and selected looks (S-451): chips, payer
/// pills, picker rows. [builder] lerps its colours with `t`; 150 ms, instant when animations are removed.
/// The first build shows the current look without a move.
class SelectionMotion extends StatelessWidget {
  const SelectionMotion({required this.selected, required this.builder, this.child, super.key});

  final bool selected;
  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: selected ? 1 : 0),
    duration: context.motion.select,
    curve: Curves.easeOut,
    builder: builder,
    child: child,
  );
}
