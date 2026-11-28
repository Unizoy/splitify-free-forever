import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/theme/theme.dart';

import 'contrast.dart';

/// R3-A (S-445): every piece of text on screen, against the solid colour actually painted behind it, meets
/// WCAG AA — 4.5:1, or 3:1 for large text (≥ 18 sp, or ≥ 14 sp bold; planning/06-design-system.md §2).
///
/// Flutter's own `textContrastGuideline` samples screenshot pixels, which the obscured CI goldens cannot give.
/// This guideline reads colours from the render tree instead: the text style colour (with any opacity on
/// the way) and the first opaque background above it (decorated and coloured boxes, Material, physical
/// shapes; translucent layers are blended). Text over a gradient, image, custom painter, blur or a stacked
/// sibling has no single background colour and is skipped (the hero and cover texts are checked per token
/// pair in `test/ui/theme/contrast_test.dart`). `textTertiary` is for placeholders and disabled text only
/// (§2) and is exempt.
const AccessibilityGuideline textOnSolidContrastGuideline = _TextOnSolid();

class _TextOnSolid extends AccessibilityGuideline {
  const _TextOnSolid();

  @override
  String get description => 'Text has AA contrast against the solid colour behind it';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    var result = const Evaluation.pass();
    final exempt = {AppColors.light.textTertiary, AppColors.dark.textTertiary};
    void visit(RenderObject node) {
      if (node is RenderOffstage && node.offstage) return;
      if (node is RenderOpacity && node.opacity == 0) return;
      if (node is RenderAnimatedOpacity && node.opacity.value == 0) return;
      if (node is RenderParagraph) {
        result += _check(node, exempt);
        return;
      }
      // Only what is painted: the top route of an overlay, the shown child of an indexed stack.
      if (node is RenderIndexedStack) {
        final i = node.index;
        var child = node.firstChild;
        for (var n = 0; child != null; n++) {
          if (n == i) visit(child);
          child = node.childAfter(child);
        }
        return;
      }
      if (node.runtimeType.toString() == '_RenderTheater') {
        node.visitChildrenForSemantics(visit);
        return;
      }
      node.visitChildren(visit);
    }

    for (final view in tester.binding.renderViews) {
      visit(view);
    }
    return result;
  }
}

/// Why a background cannot be judged from the render tree.
class _Unknown implements Exception {
  const _Unknown();
}

/// Something to read: a letter or a digit (not just spaces or zero-width break hints).
final _letters = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Whether [element] sits in a control marked disabled for accessibility services.
bool _insideDisabled(Element element) {
  var disabled = false;
  element.visitAncestorElements((e) {
    final w = e.widget;
    if (w is Semantics && w.properties.enabled == false) {
      disabled = true;
      return false;
    }
    return true;
  });
  return disabled;
}

Evaluation _check(RenderParagraph p, Set<Color> exempt) {
  if (!p.hasSize || p.size.isEmpty) return const Evaluation.pass();
  // Only the app's own text (under the app theme), not a test frame's labels.
  final creator = p.debugCreator;
  if (creator is DebugCreator && Theme.of(creator.element).extension<AppColors>() == null) {
    return const Evaluation.pass();
  }
  // Text of a disabled control is exempt (WCAG 1.4.3: inactive user interface components).
  if (creator is DebugCreator && _insideDisabled(creator.element)) return const Evaluation.pass();
  final Color bg;
  final double opacity;
  try {
    (bg, opacity) = _background(p);
  } on _Unknown {
    return const Evaluation.pass();
  }
  var result = const Evaluation.pass();
  void walk(InlineSpan span, TextStyle? parent) {
    final style = parent == null ? span.style : parent.merge(span.style);
    if (span is TextSpan) {
      final text = span.text?.trim() ?? '';
      final readable = _letters.hasMatch(text);
      final color = style?.color;
      if (readable && color != null && style?.foreground == null && !exempt.contains(color)) {
        final fg = Color.alphaBlend(color.withValues(alpha: color.a * opacity), bg);
        final size = style?.fontSize ?? 14;
        final bold = (style?.fontWeight?.value ?? 400) >= 700;
        final min = size >= 18 || (bold && size >= 14) ? 3.0 : 4.5;
        final ratio = contrastRatio(fg, bg);
        if (ratio < min) {
          result += Evaluation.fail(
            '"$text" ${_hex(color)} on ${_hex(bg)}: ${ratio.toStringAsFixed(2)}:1 < $min:1',
          );
        }
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        walk(child, style);
      }
    }
  }

  walk(p.text, null);
  return result;
}

/// The opaque colour behind [p] (translucent layers blended in) and the opacity applied to the text.
(Color, double) _background(RenderParagraph p) {
  final layers = <Color>[];
  var opacity = 1.0;
  RenderObject child = p;
  var node = p.parent;
  while (node != null) {
    if (node is RenderStack && node is! RenderIndexedStack && node.firstChild != child) {
      // Something painted before this child in the stack (a photo, a cover): no single colour.
      throw const _Unknown();
    }
    if (node is RenderOpacity) opacity *= node.opacity;
    if (node is RenderAnimatedOpacity) opacity *= node.opacity.value;
    if (node is RenderBackdropFilter) throw const _Unknown();
    if (node is RenderCustomPaint && node.painter != null) throw const _Unknown();
    final color = _paintedColor(node);
    if (color != null && color.a > 0) {
      if (color.a >= 1) {
        var bg = color;
        for (final layer in layers.reversed) {
          bg = Color.alphaBlend(layer, bg);
        }
        return (bg, opacity);
      }
      layers.add(color);
    }
    child = node;
    node = node.parent;
  }
  throw const _Unknown();
}

/// The fill [node] paints behind its child, or null; throws for gradients and images.
Color? _paintedColor(RenderObject node) {
  if (node is RenderDecoratedBox && node.position == DecorationPosition.background) {
    final d = node.decoration;
    if (d is BoxDecoration) {
      if (d.gradient != null || d.image != null) throw const _Unknown();
      return d.color;
    }
    if (d is ShapeDecoration) {
      if (d.gradient != null || d.image != null) throw const _Unknown();
      return d.color;
    }
    return null;
  }
  if (node is RenderPhysicalModel) return node.color;
  if (node is RenderPhysicalShape) return node.color;
  if (node.runtimeType.toString() == '_RenderColoredBox') {
    // ColoredBox's render object is private; its colour is public.
    return (node as dynamic).color as Color;
  }
  return null;
}

String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// R3-A (S-443): a Text that is just an amount ("₹1,23,456.50", "−$12", "+€4") is drawn with tabular
/// figures, so amounts line up in lists and totals (planning/06-design-system.md §3: `amount`, `amountHero`).
const AccessibilityGuideline tabularAmountsGuideline = _TabularAmounts();

final _amountText = RegExp(r'^[+\-−]?\s?[A-Z]{0,2}[₹$€£¥][\s ]?\d[\d,]*(\.\d+)?$');

class _TabularAmounts extends AccessibilityGuideline {
  const _TabularAmounts();

  @override
  String get description => 'Standalone amounts use tabular figures';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    var result = const Evaluation.pass();
    void visit(RenderObject node) {
      if (node is RenderParagraph) {
        final text = node.text.toPlainText().trim();
        if (_amountText.hasMatch(text)) {
          var tabular = false;
          void walk(InlineSpan span, TextStyle? parent) {
            final style = parent == null ? span.style : parent.merge(span.style);
            if (span is TextSpan && (span.text ?? '').contains(RegExp(r'\d'))) {
              tabular |= style?.fontFeatures?.contains(const FontFeature.tabularFigures()) ?? false;
            }
            for (final c in (span is TextSpan ? span.children : null) ?? const <InlineSpan>[]) {
              walk(c, style);
            }
          }

          walk(node.text, null);
          if (!tabular) {
            final where = node.debugCreator is DebugCreator
                ? (node.debugCreator! as DebugCreator).element.debugGetCreatorChain(6)
                : '';
            result += Evaluation.fail('"$text" is an amount without tabular figures ($where)');
          }
        }
        return;
      }
      node.visitChildren(visit);
    }

    for (final view in tester.binding.renderViews) {
      visit(view);
    }
    return result;
  }
}
