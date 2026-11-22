import 'dart:async';
import 'dart:ui' as ui show Image, ImageFilter, PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Frosted glass card over hero imagery (438): radius 32, dark translucent
/// fill, backdrop blur σ 18, thin white border, padding 20.
///
/// Inside a [GlassBackdropHost] (every [HeroHeader]) the blur is pre-rendered (S-267): the host snapshots
/// its static background once, blurs it once, and the card paints its slice of that image — so scrolling
/// never re-runs a backdrop blur. Until the snapshot is ready (and in tests) it uses a live
/// [BackdropFilter]. Use at most one per screen (§9 blur budget). With [blur] off — or when the user
/// removed animations — it falls back to a plain 45 % black fill.
class GlassCard extends StatelessWidget {
  const GlassCard({required this.child, this.blur = true, this.padding, super.key});

  final Widget child;
  final bool blur;
  final EdgeInsetsGeometry? padding;

  static const double sigma = 18;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final useBlur = blur && !context.motion.reduced;
    final host = useBlur ? GlassBackdropHost.maybeOf(context) : null;
    host?.request();
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: useBlur ? c.glassFill : c.glassFallback,
        borderRadius: AppRadii.all32,
        border: Border.all(color: c.glassBorder),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.s5),
        child: DefaultTextStyle.merge(
          style: context.text.body.copyWith(color: c.onHero),
          child: IconTheme.merge(
            data: IconThemeData(color: c.onHero),
            child: child,
          ),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: AppRadii.all32,
      child: host == null
          ? (useBlur
                ? BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: body,
                  )
                : body)
          : ValueListenableBuilder<_Snapshot?>(
              valueListenable: host._snapshot,
              // Same tree with or without the snapshot (the card's content keeps its state).
              builder: (context, snap, body) => Stack(
                children: [
                  Positioned.fill(
                    child: _BackdropPlate(snapshot: snap, background: host._backgroundBox),
                  ),
                  BackdropFilter(
                    enabled: snap == null,
                    filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: body!,
                  ),
                ],
              ),
              child: body,
            ),
    );
  }
}

/// A blurred copy of a host's background, at [scale] × its logical size.
class _Snapshot {
  _Snapshot(this.image, this.size, this.scale);

  final ui.Image image;
  final Size size;
  final double scale;
}

/// Static background ([background]) with content ([child]) on top, whose [GlassCard]s paint a pre-blurred
/// slice of the background instead of blurring live (S-267). The snapshot is taken only when a card asks,
/// and again when the background's size or the theme changes. Pass [snapshot] false when the background
/// is still loading (a cover photo): the cards then blur live.
class GlassBackdropHost extends StatefulWidget {
  const GlassBackdropHost({
    required this.background,
    required this.child,
    this.snapshot = true,
    super.key,
  });

  final Widget background;
  final Widget child;
  final bool snapshot;

  /// The nearest host, if any.
  static GlassBackdropHostState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_HostScope>()?.state;

  @override
  State<GlassBackdropHost> createState() => GlassBackdropHostState();
}

class GlassBackdropHostState extends State<GlassBackdropHost> {
  final _key = GlobalKey();
  final _snapshot = ValueNotifier<_Snapshot?>(null);
  bool _wanted = false;
  bool _scheduled = false;
  int _generation = 0;

  RenderBox? _backgroundBox() => _key.currentContext?.findRenderObject() as RenderBox?;

  /// A card wants the pre-blurred background.
  void request() {
    if (_wanted) return;
    _wanted = true;
    _schedule();
  }

  void _invalidate() {
    _generation++;
    final old = _snapshot.value;
    _snapshot.value = null;
    old?.image.dispose();
    _schedule();
  }

  void _schedule() {
    if (!_wanted || !widget.snapshot || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_capture());
    });
  }

  Future<void> _capture() async {
    final boundary = _key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize || boundary.size.isEmpty) return;
    final generation = _generation;
    // Half resolution is plenty for a σ 18 blur, and 4× cheaper to keep.
    const scale = 0.5;
    final size = boundary.size;
    try {
      final raw = await boundary.toImage(pixelRatio: scale);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImage(
        raw,
        Offset.zero,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: GlassCard.sigma * scale,
            sigmaY: GlassCard.sigma * scale,
            tileMode: TileMode.mirror,
          ),
      );
      final picture = recorder.endRecording();
      final blurred = await picture.toImage(raw.width, raw.height);
      picture.dispose();
      raw.dispose();
      if (!mounted || generation != _generation) {
        blurred.dispose();
        return;
      }
      _snapshot.value?.image.dispose();
      _snapshot.value = _Snapshot(blurred, size, scale);
    } on Object {
      // No snapshot: the cards keep the live blur.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme or text-size changes repaint the background differently.
    if (_snapshot.value != null) _invalidate();
  }

  @override
  void didUpdateWidget(GlassBackdropHost old) {
    super.didUpdateWidget(old);
    if (old.snapshot != widget.snapshot) _invalidate();
  }

  @override
  void dispose() {
    _snapshot.value?.image.dispose();
    _snapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme brightness is read so a mode switch re-runs didChangeDependencies.
    Theme.of(context);
    return _HostScope(
      state: this,
      child: Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (_) {
                _invalidate();
                return true;
              },
              child: SizeChangedLayoutNotifier(
                child: RepaintBoundary(key: _key, child: widget.background),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _HostScope extends InheritedWidget {
  const _HostScope({required this.state, required super.child});

  final GlassBackdropHostState state;

  @override
  bool updateShouldNotify(_HostScope old) => false;
}

/// Paints the card's slice of the host's blurred background.
class _BackdropPlate extends LeafRenderObjectWidget {
  const _BackdropPlate({required this.snapshot, required this.background});

  final _Snapshot? snapshot;
  final RenderBox? Function() background;

  @override
  _RenderBackdropPlate createRenderObject(BuildContext context) =>
      _RenderBackdropPlate(snapshot, background);

  @override
  void updateRenderObject(BuildContext context, _RenderBackdropPlate renderObject) {
    renderObject
      ..snapshot = snapshot
      ..background = background;
  }
}

class _RenderBackdropPlate extends RenderBox {
  _RenderBackdropPlate(this._snapshot, this.background);

  _Snapshot? _snapshot;
  set snapshot(_Snapshot? value) {
    if (identical(value, _snapshot)) return;
    _snapshot = value;
    markNeedsPaint();
  }

  RenderBox? Function() background;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final snap = _snapshot;
    final bg = background();
    if (snap == null || bg == null || !bg.hasSize || bg.size != snap.size) return;
    final origin = MatrixUtils.transformPoint(getTransformTo(bg), Offset.zero);
    final s = snap.scale;
    final src = Rect.fromLTWH(origin.dx * s, origin.dy * s, size.width * s, size.height * s);
    context.canvas.drawImageRect(
      snap.image,
      src,
      offset & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}
