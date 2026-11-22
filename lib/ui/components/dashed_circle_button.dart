import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/ui/components/pressable.dart';
import 'package:splitify/ui/painters/dashed.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Onboarding call to action (455 "Start / Now"): a 120 dp dashed circle that
/// turns slowly around a two-line label. Grows with the text size.
class DashedCircleButton extends StatefulWidget {
  const DashedCircleButton({required this.label, required this.onPressed, this.color, super.key});

  /// Two-line label ("Get\nstarted").
  final String label;
  final VoidCallback onPressed;

  /// Defaults to white (for heroes).
  final Color? color;

  @override
  State<DashedCircleButton> createState() => _DashedCircleButtonState();
}

class _DashedCircleButtonState extends State<DashedCircleButton>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.motion.reduced) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colors.onHero;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final diameter = 120 * (1 + (scale - 1) * 0.5);
    void tap() {
      HapticFeedback.selectionClick();
      widget.onPressed();
    }

    return Semantics(
      button: true,
      label: widget.label.replaceAll('\n', ' '),
      excludeSemantics: true,
      onTap: tap,
      child: Pressable(
        onTap: tap,
        circle: true,
        scale: 0.95,
        highlightColor: color,
        child: SizedBox.square(
          dimension: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: RotationTransition(
                  turns: _spin,
                  child: CustomPaint(
                    painter: DashedBorderPainter(color: color, circle: true, dash: 9, gap: 7),
                  ),
                ),
              ),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: context.text.button
                    .w(600)
                    .copyWith(color: color, fontSize: 20, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
