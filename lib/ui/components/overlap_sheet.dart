import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:splitify/ui/theme/theme.dart';

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
    // Once scrolled under the status bar the sheet (not the dark hero) decides the icon colour.
    final bars = (context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
      statusBarColor: AppPalette.clear,
    );
    // Its own layer: a scroll moves it without re-recording its content (S-267).
    return RepaintBoundary(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: bars,
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
      ),
    );
  }
}

/// Stacks [bottom] under [top] so that it overlaps the last [overlap] dp of
/// [top] and paints over it. Height = top + bottom − overlap.
class OverlapColumn extends MultiChildRenderObjectWidget {
  OverlapColumn({
    required Widget top,
    required Widget bottom,
    this.overlap = AppSpacing.sheetOverlap,
    super.key,
  }) : super(children: [top, bottom]);

  final double overlap;

  @override
  RenderOverlapColumn createRenderObject(BuildContext context) =>
      RenderOverlapColumn(overlap: overlap);

  @override
  void updateRenderObject(BuildContext context, RenderOverlapColumn renderObject) {
    renderObject.overlap = overlap;
  }
}

class _OverlapParentData extends ContainerBoxParentData<RenderBox> {}

/// Render object behind [OverlapColumn].
class RenderOverlapColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _OverlapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _OverlapParentData> {
  RenderOverlapColumn({required double overlap}) : _overlap = overlap;

  double _overlap;
  double get overlap => _overlap;
  set overlap(double value) {
    if (value == _overlap) return;
    _overlap = value;
    markNeedsLayout();
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
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
