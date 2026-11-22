import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Marks where a list first appears (S-265). [Entrance] rows under it fade and rise in, 30 ms apart, but
/// only during the scope's first moments on screen: rows built later (scrolled in, recycled, rebuilt by a
/// data change, a tab revisited) just appear. Put it where the loaded list replaces its skeleton.
class EntranceScope extends StatefulWidget {
  const EntranceScope({required this.child, super.key});

  final Widget child;

  /// Rows built this long after the scope first built skip the entrance.
  static const window = Duration(milliseconds: 400);

  @override
  State<EntranceScope> createState() => _EntranceScopeState();
}

class _EntranceScopeState extends State<EntranceScope> {
  final _born = Stopwatch()..start();

  @override
  Widget build(BuildContext context) => _EntranceClock(born: _born, child: widget.child);
}

class _EntranceClock extends InheritedWidget {
  const _EntranceClock({required this.born, required super.child});

  final Stopwatch born;

  bool get fresh => born.elapsed < EntranceScope.window;

  @override
  bool updateShouldNotify(_EntranceClock old) => old.born != born;
}

/// One row of a list's first-load entrance: rows 0–7 fade in and rise 12 dp over 220 ms, each 30 ms after
/// the last (≤ 430 ms for the whole list). Never blocks taps; instant when the user removed animations or
/// outside a fresh [EntranceScope].
class Entrance extends StatefulWidget {
  const Entrance({required this.index, required this.child, super.key});

  /// Position in the list; rows at [AppMotion.entranceMax] and below appear at once.
  final int index;
  final Widget child;

  static const double rise = 12;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  Animation<double>? _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final scope = context.getInheritedWidgetOfExactType<_EntranceClock>();
    final motion = context.motion;
    if (scope == null || !scope.fresh || motion.reduced || widget.index >= AppMotion.entranceMax) {
      return;
    }
    final delay = motion.stagger * widget.index;
    final total = delay + motion.entrance;
    final c = AnimationController(vsync: this, duration: total);
    _c = c;
    final start = delay.inMicroseconds / total.inMicroseconds;
    _t = CurvedAnimation(
      parent: c,
      curve: Interval(start, 1, curve: AppMotion.emphasized),
    );
    c.forward();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) return widget.child;
    // The same two wrappers to the end (at rest they add no layer), so the row keeps its state.
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) => Opacity(
        opacity: t.value,
        child: Transform.translate(offset: Offset(0, Entrance.rise * (1 - t.value)), child: child),
      ),
      child: widget.child,
    );
  }
}
