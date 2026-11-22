import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Formats an amount in minor units for [AnimatedAmount].
typedef MinorFormatter = String Function(int minor);

/// A balance total that counts to its new value when it changes (S-264): integer minor units all the way
/// (rule 1), ≤ 350 ms, ease-out. The first build shows the value as is; a change of [currency] jumps
/// (never count across currencies). Screen readers get the final text only.
class AnimatedAmount extends StatefulWidget {
  const AnimatedAmount({
    required this.minor,
    required this.currency,
    required this.format,
    this.style,
    this.textAlign,
    this.maxLines,
    super.key,
  });

  final int minor;
  final String currency;
  final MinorFormatter format;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  State<AnimatedAmount> createState() => _AnimatedAmountState();
}

class _AnimatedAmountState extends State<AnimatedAmount> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this);
  late int _from = widget.minor;
  late int _to = widget.minor;

  int get _value {
    final t = Curves.easeOutCubic.transform(_c.value);
    // Integer interpolation (no floats reach the money layer): from + round((to - from) · t).
    return _from + ((_to - _from) * t).round();
  }

  @override
  void didUpdateWidget(AnimatedAmount old) {
    super.didUpdateWidget(old);
    if (old.currency != widget.currency) {
      _c.stop();
      _from = _to = widget.minor;
      return;
    }
    if (widget.minor == _to) return;
    final motion = context.motion;
    _from = _c.isAnimating ? _value : _to;
    _to = widget.minor;
    if (motion.reduced) {
      _c.value = 1;
      return;
    }
    _c
      ..duration = motion.count
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finalText = widget.format(_to);
    return Semantics(
      label: finalText,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Text(
          _c.isAnimating ? widget.format(_value) : finalText,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
        ),
      ),
    );
  }
}
