import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Text that wraps between words but never inside one: when the longest word is wider than the space,
/// the whole text shrinks (from the reader's text scale) until that word fits ("ANNIVERSARY" on a
/// narrow card at 200 % text, a one-word segment label).
class WordFitText extends StatelessWidget {
  const WordFitText(
    this.text, {
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Text scaler that makes the longest word of [text] fit [maxWidth] (never larger than [base]).
  static TextScaler fitScaler({
    required String text,
    required TextStyle style,
    required TextScaler base,
    required double maxWidth,
    required TextDirection direction,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) return base;
    var widest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: direction,
        textScaler: base,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    if (widest <= maxWidth) return base;
    final size = style.fontSize ?? 14;
    final factor = base.scale(size) / size * (maxWidth / widest) * 0.98;
    return TextScaler.linear(math.max(factor, 0.5));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: style,
      textScaler: fitScaler(
        text: text,
        style: style,
        base: MediaQuery.textScalerOf(context),
        maxWidth: constraints.maxWidth,
        direction: Directionality.of(context),
      ),
    ),
  );
}

/// One text scale for a row of labels (tabs, segments): the reader's scale, shrunk just enough for the
/// widest label to fit [maxWidth] on one line, so every label in the row has the same size (S-242).
TextScaler sharedLabelScaler(
  BuildContext context, {
  required List<String> labels,
  required TextStyle style,
  required double maxWidth,
  double minFactor = 0.8,
}) {
  final base = MediaQuery.textScalerOf(context);
  if (!maxWidth.isFinite || maxWidth <= 0) return base;
  var widest = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: base,
      maxLines: 1,
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  if (widest <= maxWidth) return base;
  final size = style.fontSize ?? 14;
  final factor = base.scale(size) / size * (maxWidth / widest) * 0.98;
  return TextScaler.linear(math.max(factor, minFactor));
}
