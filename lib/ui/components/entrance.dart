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
  CurvedAnimation? _t;

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
    // The curve too: an undisposed CurvedAnimation stayed behind for every row that rose in (S-457).
    _t?.dispose();
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

/// Fades its child in once when it first builds (220 ms): the content of a newly picked in-page tab
/// (S-263). Give it a key per tab so a switch replays it. [sliver] for sliver children.
class FadeIn extends StatefulWidget {
  const FadeIn({required this.child, this.sliver = false, super.key});

  final Widget child;
  final bool sliver;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this);
  late final _t = CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    final motion = context.motion;
    if (motion.reduced) {
      _c.value = 1;
    } else {
      _c
        ..duration = motion.tab
        ..forward();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.sliver
      ? SliverFadeTransition(opacity: _t, sliver: widget.child)
      : FadeTransition(opacity: _t, child: widget.child);
}

/// Lists that grow while they are on screen (S-451): rows whose id shows up after the list first appeared —
/// a saved expense coming back to its group, a comment, a chip, an item, rows a sync brings, settled history
/// unfolding — grow and fade in once ([InsertMotion], 240 ms). Give it every id of the list (lazy lists build
/// only the rows on screen; the ids say which ones are new). Ids present in the first 400 ms count as the
/// first load ([Entrance] covers that), and an id only plays if its row is built within 600 ms. More than
/// [maxBatch] new ids at once is a reload (a filter, a tab), not an arrival: nothing plays.
class InsertMotionScope extends StatefulWidget {
  const InsertMotionScope({required this.ids, required this.child, this.maxBatch = 3, super.key});

  final Iterable<String> ids;
  final Widget child;

  /// Most new ids that still grow in together; null = any number (settled history unfolding).
  final int? maxBatch;

  /// Ids that arrive this soon after the scope first built are part of the first load.
  static const settle = Duration(milliseconds: 400);

  /// A new id whose row is built later than this (scrolled to afterwards) just appears.
  static const window = Duration(milliseconds: 600);

  @override
  State<InsertMotionScope> createState() => _InsertMotionScopeState();
}

class _InsertMotionScopeState extends State<InsertMotionScope> {
  final _clock = Stopwatch()..start();

  /// Ids of the last build (set in initState: a lazy field would first read the NEW ids in the first
  /// didUpdateWidget, and the first arrival would never play).
  late Set<String> _known;

  /// New ids → when they arrived (ms on [_clock]).
  final _fresh = <String, int>{};

  @override
  void didUpdateWidget(InsertMotionScope old) {
    super.didUpdateWidget(old);
    if (identical(old.ids, widget.ids)) return;
    final now = _clock.elapsedMilliseconds;
    final ids = widget.ids.toSet();
    if (_clock.elapsed >= InsertMotionScope.settle) {
      final added = [
        for (final id in ids)
          if (!_known.contains(id)) id,
      ];
      final max = widget.maxBatch;
      if (max == null || added.length <= max) {
        for (final id in added) {
          _fresh[id] = now;
        }
      }
    }
    _fresh.removeWhere(
      (id, at) => !ids.contains(id) || now - at > InsertMotionScope.window.inMilliseconds,
    );
    // An id that leaves and comes back (undo, restore) grows in again.
    _known = ids;
  }

  @override
  void initState() {
    super.initState();
    _known = widget.ids.toSet();
  }

  /// Whether the row for [id] should grow in now (once).
  bool _take(String id) {
    final at = _fresh.remove(id);
    return at != null && _clock.elapsedMilliseconds - at <= InsertMotionScope.window.inMilliseconds;
  }

  @override
  Widget build(BuildContext context) => _InsertScope(state: this, child: widget.child);
}

class _InsertScope extends InheritedWidget {
  const _InsertScope({required this.state, required super.child});

  final _InsertMotionScopeState state;

  @override
  bool updateShouldNotify(_InsertScope old) => false;
}

/// One row of an [InsertMotionScope] list: grows from zero height and fades in when its [id] is new,
/// otherwise it is just the row. [grow] false (grid cells, whose size is fixed) fades it in from 92 % scale
/// instead. Instant when the user removed animations.
class InsertMotion extends StatefulWidget {
  const InsertMotion({required this.id, required this.child, this.grow = true, super.key});

  final String id;
  final Widget child;
  final bool grow;

  /// Where a [grow] false cell starts.
  static const double fromScale = 0.92;

  @override
  State<InsertMotion> createState() => _InsertMotionState();
}

class _InsertMotionState extends State<InsertMotion> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  CurvedAnimation? _size;
  CurvedAnimation? _fade;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final scope = context.getInheritedWidgetOfExactType<_InsertScope>();
    if (scope == null || !scope.state._take(widget.id)) return;
    final motion = context.motion;
    if (motion.reduced) return;
    final c = AnimationController(vsync: this, duration: motion.insert);
    _c = c;
    _size = CurvedAnimation(parent: c, curve: AppMotion.emphasized);
    _fade = CurvedAnimation(
      parent: c,
      curve: const Interval(0.25, 1, curve: Curves.easeOut),
    );
    c.forward();
  }

  @override
  void dispose() {
    _size?.dispose();
    _fade?.dispose();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    if (size == null) return widget.child;
    // The same wrappers to the end, so the row keeps its state.
    final faded = FadeTransition(opacity: _fade!, child: widget.child);
    if (!widget.grow) {
      return ScaleTransition(
        scale: Tween<double>(begin: InsertMotion.fromScale, end: 1).animate(size),
        child: faded,
      );
    }
    return SizeTransition(
      sizeFactor: size,
      axisAlignment: -1,
      fixedCrossAxisSizeFactor: 1,
      child: faded,
    );
  }
}
