import 'dart:async';

import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Which tick a [Pressable] plays on tap (§5 haptics).
enum PressHaptic {
  none,

  /// Toggles, chips, tabs.
  selection,

  /// Primary actions and FABs.
  light,
}

/// The one tap primitive (S-261): every card, row, chip, tile and button presses in to
/// [AppMotion.pressScale] in ~90 ms with a faint highlight, then springs back in ~160 ms. The tap fires on
/// finger up straight away — the release plays while the next screen comes in, so nothing waits on it.
///
/// Keyboard/switch access (focus + activate) and the tap semantics action come with it, like [InkWell],
/// without needing a [Material] ancestor. With [onTap] and [onLongPress] null it is inert.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.circle = false,
    this.scale = AppMotion.pressScale,
    this.haptic = PressHaptic.none,
    this.highlight = true,
    this.highlightColor,
    this.behavior = HitTestBehavior.opaque,
    this.focusNode,
    this.autofocus = false,
    this.excludeFromSemantics = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Shape of the press highlight; square corners when null.
  final BorderRadius? borderRadius;

  /// Round highlight (icon buttons, the amber add button).
  final bool circle;

  /// Pressed scale; 1 turns the shrink off (full-width rows keep the highlight only).
  final double scale;
  final PressHaptic haptic;

  /// Faint overlay while pressed.
  final bool highlight;

  /// Overlay colour; defaults to the text colour at low alpha (white on dark heroes when given).
  final Color? highlightColor;
  final HitTestBehavior behavior;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool excludeFromSemantics;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final _press = PressMotion(this);
  bool _focused = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _tap() {
    switch (widget.haptic) {
      case PressHaptic.none:
        break;
      case PressHaptic.selection:
        AppHaptics.selection();
      case PressHaptic.light:
        AppHaptics.light();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final c = context.colors;
    final overlay = widget.highlightColor ?? c.textPrimary;
    final shape = widget.circle ? BoxShape.circle : BoxShape.rectangle;
    Widget body = widget.child;
    if (widget.highlight) {
      body = AnimatedBuilder(
        animation: _press.controller,
        builder: (context, child) {
          final t = _focused ? 1.0 : _press.value;
          // Same widget at every t, so the child keeps its state; no colour = nothing painted at rest.
          return DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              shape: shape,
              borderRadius: widget.circle ? null : widget.borderRadius,
              color: t == 0 ? null : overlay.withValues(alpha: 0.07 * t),
            ),
            child: child,
          );
        },
        child: body,
      );
    }
    if (widget.scale != 1) {
      final range = 1 - widget.scale;
      body = AnimatedBuilder(
        animation: _press.controller,
        builder: (context, child) => Transform.scale(scale: 1 - range * _press.value, child: child),
        child: body,
      );
    }
    return FocusableActionDetector(
      enabled: enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        if (widget.onTap != null)
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _tap()),
      },
      child: GestureDetector(
        behavior: widget.behavior,
        excludeFromSemantics: widget.excludeFromSemantics,
        onTapDown: enabled ? (_) => _press.down(context.motion) : null,
        onTapUp: enabled ? (_) => _press.up(context.motion) : null,
        onTapCancel: enabled ? () => _press.up(context.motion) : null,
        onTap: widget.onTap == null ? null : _tap,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                Feedback.forLongPress(context);
                widget.onLongPress!();
              },
        child: body,
      ),
    );
  }
}

/// The press-in / spring-back timing shared by [Pressable], [PillButton] and the icon buttons. A quick tap
/// still shows the whole press: the release starts once the press-in is done.
class PressMotion {
  PressMotion(TickerProvider vsync) : controller = AnimationController(vsync: vsync);

  /// 0 at rest, 1 fully pressed (the release overshoots a little below 0).
  final AnimationController controller;
  bool _down = false;

  double get value => controller.value;

  /// Finger down.
  void down(AppMotion motion) {
    _down = true;
    if (motion.reduced) {
      controller.value = 1;
      return;
    }
    controller.animateTo(1, duration: motion.press, curve: Curves.easeOut).then((_) {
      if (!_down) _release(motion);
    }, onError: (Object _) {});
  }

  /// Finger up or cancelled.
  void up(AppMotion motion) {
    _down = false;
    if (!controller.isAnimating) _release(motion);
  }

  /// [down] or [up] from a pressed flag (icon buttons report a pressed state).
  void set(AppMotion motion, {required bool pressed}) => pressed ? down(motion) : up(motion);

  void _release(AppMotion motion) {
    if (motion.reduced) {
      controller.value = 0;
      return;
    }
    unawaited(controller.animateBack(0, duration: motion.release, curve: motion.spring));
  }

  void dispose() => controller.dispose();
}
