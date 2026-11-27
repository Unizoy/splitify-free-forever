import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Status-bar icons over a hero or its scrim: light in both themes (the hero is dark in both).
const heroBarStyle = SystemUiOverlayStyle(
  statusBarColor: AppPalette.clear,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

/// How far the page scrolls before the status-bar scrim is fully opaque: the hero's buttons sit this far
/// below the status bar.
const _scrimRamp = AppSpacing.s2;

/// Wraps a page whose hero scrolls up under the status bar (D-033): once the page scrolls, a
/// status-bar-high band in the hero colour sits under the clock and icons (light in both themes), so text
/// and buttons never run under them. It follows the first vertical scroll view below it and stays at the top
/// of the screen however far the page scrolls, also when the rows are slivers after the hero.
/// An [OverlapColumn] inside leaves its own band to it.
class HeroScrim extends StatefulWidget {
  const HeroScrim({required this.child, super.key});

  final Widget child;

  @override
  State<HeroScrim> createState() => _HeroScrimState();
}

class _HeroScrimState extends State<HeroScrim> {
  /// 0 = page at the top (no band), 1 = scrolled by [_scrimRamp] or more.
  final _shown = ValueNotifier<double>(0);

  @override
  void dispose() {
    _shown.dispose();
    super.dispose();
  }

  void _follow(ScrollMetrics m) {
    if (m.axis != Axis.vertical) return;
    _shown.value = ((m.pixels - m.minScrollExtent) / _scrimRamp).clamp(0.0, 1.0);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0) _follow(n.metrics);
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification n) {
    if (n.depth == 0) _follow(n.metrics);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bar = MediaQuery.paddingOf(context).top;
    final color = context.colors.heroTop;
    return _HeroScrimScope(
      child: Stack(
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: _onMetrics,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.child,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: bar,
            child: IgnorePointer(
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: heroBarStyle,
                child: ValueListenableBuilder<double>(
                  valueListenable: _shown,
                  builder: (context, shown, _) => Opacity(
                    key: const Key('hero-status-scrim'),
                    opacity: shown,
                    child: ColoredBox(color: color),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marks a subtree that has a [HeroScrim] above it.
class _HeroScrimScope extends InheritedWidget {
  const _HeroScrimScope({required super.child});

  static bool inside(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_HeroScrimScope>() != null;

  @override
  bool updateShouldNotify(_HeroScrimScope old) => false;
}

/// Page-coloured sheet with a 36 dp top radius that rides up over the hero
/// (438). Put it as the `bottom` of an [OverlapColumn].
class OverlapSheet extends StatelessWidget {
  const OverlapSheet({required this.child, this.padding, super.key});

  final Widget child;

  /// Defaults to 20 dp sides, 28 dp top and room for the floating nav below.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    // Its own layer: a scroll moves it without re-recording its content (S-267). The status bar over a
    // scrolled sheet is the hero-coloured band of [OverlapColumn] / [HeroScrim] (D-033).
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(color: context.colors.bg, borderRadius: AppRadii.overlapTop),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.s6 + AppSpacing.s1,
                AppSpacing.screen,
                bottom + AppSpacing.s6,
              ),
          child: child,
        ),
      ),
    );
  }
}

/// Stacks [bottom] under [top] so that it overlaps the last [overlap] dp of
/// [top] and paints over it. Height = top + bottom − overlap.
///
/// When [bottom] is an [OverlapSheet] and the page scrolls (the hero moves up under the status bar), a
/// status-bar-high band in the hero colour is painted under the clock with light icons, so text and buttons
/// never run under it (S-255, D-033). Inside a [HeroScrim] (pages whose rows are slivers after the hero)
/// the scrim draws that band instead.
class OverlapColumn extends MultiChildRenderObjectWidget {
  OverlapColumn({
    required Widget top,
    required Widget bottom,
    this.overlap = AppSpacing.sheetOverlap,
    super.key,
  }) : sheetBelow = bottom is OverlapSheet,
       super(children: [top, bottom]);

  final double overlap;

  /// [bottom] is an [OverlapSheet]: a hero page, which gets the status-bar band.
  final bool sheetBelow;

  double _bar(BuildContext context) =>
      sheetBelow && !_HeroScrimScope.inside(context) ? MediaQuery.paddingOf(context).top : 0;

  @override
  RenderOverlapColumn createRenderObject(BuildContext context) => RenderOverlapColumn(
    overlap: overlap,
    statusBar: _bar(context),
    scrimColor: context.colors.heroTop,
  );

  @override
  void updateRenderObject(BuildContext context, RenderOverlapColumn renderObject) {
    renderObject
      ..overlap = overlap
      ..statusBar = _bar(context)
      ..scrimColor = context.colors.heroTop;
  }
}

class _OverlapParentData extends ContainerBoxParentData<RenderBox> {}

/// Render object behind [OverlapColumn].
class RenderOverlapColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _OverlapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _OverlapParentData> {
  RenderOverlapColumn({
    required double overlap,
    double statusBar = 0,
    Color scrimColor = AppPalette.clear,
  }) : _overlap = overlap,
       _statusBar = statusBar,
       _scrimColor = scrimColor;

  double _overlap;
  double get overlap => _overlap;
  set overlap(double value) {
    if (value == _overlap) return;
    _overlap = value;
    markNeedsLayout();
  }

  /// Status bar height; 0 = no scrim.
  double _statusBar;
  double get statusBar => _statusBar;
  set statusBar(double value) {
    if (value == _statusBar) return;
    _statusBar = value;
    markNeedsPaint();
  }

  Color _scrimColor;
  Color get scrimColor => _scrimColor;
  set scrimColor(Color value) {
    if (value == _scrimColor) return;
    _scrimColor = value;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _OverlapParentData) child.parentData = _OverlapParentData();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final childConstraints = BoxConstraints.tightFor(width: width);
    final top = firstChild!;
    final bottom = childAfter(top)!;
    top.layout(childConstraints, parentUsesSize: true);
    bottom.layout(childConstraints, parentUsesSize: true);
    (top.parentData! as _OverlapParentData).offset = Offset.zero;
    final y = math.max(0, top.size.height - overlap).toDouble();
    (bottom.parentData! as _OverlapParentData).offset = Offset(0, y);
    size = constraints.constrain(Size(width, y + bottom.size.height));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _sumHeights(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _sumHeights(width);

  double _sumHeights(double width) {
    final top = firstChild;
    final bottom = top == null ? null : childAfter(top);
    if (top == null || bottom == null) return 0;
    return math.max(0, top.getMinIntrinsicHeight(width) - overlap) +
        bottom.getMinIntrinsicHeight(width);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
    final bar = _statusBar;
    if (bar <= 0 || !attached) return;
    // Where this box sits on the screen: scrolled up by -global.dy.
    final global = localToGlobal(Offset.zero);
    final scrolled = -global.dy;
    if (scrolled <= 0) return;
    final band = Rect.fromLTWH(offset.dx, offset.dy + scrolled, size.width, bar);
    final opacity = (scrolled / _scrimRamp).clamp(0.0, 1.0);
    // The icons follow the band (light); the hero above already asks for light ones.
    context.pushLayer(
      AnnotatedRegionLayer<SystemUiOverlayStyle>(
        heroBarStyle,
        size: band.size,
        offset: band.topLeft,
      ),
      (context, offset) => context.canvas.drawRect(
        band,
        Paint()
          ..color = opacity >= 1
              ? _scrimColor
              : _scrimColor.withValues(alpha: _scrimColor.a * opacity),
      ),
      Offset.zero,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
