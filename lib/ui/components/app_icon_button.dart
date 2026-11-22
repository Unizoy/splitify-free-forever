import 'package:flutter/material.dart';
import 'package:splitify/ui/components/pressable.dart';
import 'package:splitify/ui/theme/theme.dart';

/// [IconButton] with the shared press motion (S-261): its Material highlight plus a 0.9 press-in and spring
/// back. Use it for every app-bar and toolbar icon.
class AppIconButton extends StatefulWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.iconSize,
    super.key,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double? iconSize;

  /// Icon buttons are small: they shrink a little more than cards to read as pressed.
  static const double pressedScale = 0.9;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> with SingleTickerProviderStateMixin {
  final _states = WidgetStatesController();
  late final _press = PressMotion(this);

  @override
  void initState() {
    super.initState();
    _states.addListener(_onStates);
  }

  void _onStates() {
    if (!mounted) return;
    _press.set(context.motion, pressed: _states.value.contains(WidgetState.pressed));
  }

  @override
  void dispose() {
    _states
      ..removeListener(_onStates)
      ..dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const range = 1 - AppIconButton.pressedScale;
    return AnimatedBuilder(
      animation: _press.controller,
      builder: (context, child) => Transform.scale(scale: 1 - range * _press.value, child: child),
      child: IconButton(
        icon: widget.icon,
        onPressed: widget.onPressed,
        tooltip: widget.tooltip,
        color: widget.color,
        iconSize: widget.iconSize,
        statesController: _states,
      ),
    );
  }
}
