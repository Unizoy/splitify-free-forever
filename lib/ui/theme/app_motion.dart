import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Motion tokens (planning/06-design-system.md §5).
///
/// Read through `context.motion` so "remove animations" turns every duration
/// into zero.
@immutable
class AppMotion {
  const AppMotion({required this.reduced});

  /// Motion for [context]: reduced when the platform asks to disable animations.
  factory AppMotion.of(BuildContext context) =>
      AppMotion(reduced: MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// True when the user asked the system to remove animations.
  final bool reduced;

  static const _fast = Duration(milliseconds: 150);
  static const _base = Duration(milliseconds: 250);
  static const _slow = Duration(milliseconds: 400);
  static const _showcase = Duration(milliseconds: 800);

  /// Standard curve for base/slow transitions.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Presses and toggles.
  Duration get fast => reduced ? Duration.zero : _fast;

  /// Most transitions and accordions.
  Duration get base => reduced ? Duration.zero : _base;

  /// Sheets and the hero/sheet reveal.
  Duration get slow => reduced ? Duration.zero : _slow;

  /// Nav pill morph, stacked-card shuffle, celebration.
  Duration get showcase => reduced ? Duration.zero : _showcase;

  /// Curve for presses and toggles.
  Curve get fastCurve => Curves.easeOut;

  /// Spring (stiffness 300, damping 26) for showcase motion.
  Curve get spring => const SpringCurve();
}

/// A curve that follows a damped spring (stiffness 300, damping 26, mass 1)
/// over the showcase duration, with a small overshoot.
class SpringCurve extends Curve {
  const SpringCurve();

  static final _sim = SpringSimulation(
    const SpringDescription(mass: 1, stiffness: 300, damping: 26),
    0,
    1,
    0,
  );

  @override
  double transformInternal(double t) => _sim.x(t * 0.8);
}
