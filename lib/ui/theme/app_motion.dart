import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Motion tokens (planning/06-design-system.md §5, retuned by S-260: crisp and springy, 90–320 ms).
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

  static const _press = Duration(milliseconds: 90);
  static const _release = Duration(milliseconds: 160);
  static const _fast = Duration(milliseconds: 150);
  static const _base = Duration(milliseconds: 240);
  static const _slow = Duration(milliseconds: 300);
  static const _showcase = Duration(milliseconds: 300);
  static const _route = Duration(milliseconds: 280);
  static const _routeBack = Duration(milliseconds: 240);
  static const _tab = Duration(milliseconds: 220);
  static const _count = Duration(milliseconds: 350);
  static const _entrance = Duration(milliseconds: 220);
  static const _stagger = Duration(milliseconds: 30);
  static const _shimmer = Duration(milliseconds: 1200);
  static const _intro = Duration(milliseconds: 350);
  static const _float = Duration(seconds: 4);
  static const _expand = Duration(milliseconds: 220);
  static const _insert = Duration(milliseconds: 240);
  static const _swap = Duration(milliseconds: 180);
  static const _success = Duration(milliseconds: 280);
  static const _successHold = Duration(milliseconds: 420);

  /// How far a pressed control shrinks (Pressable, PillButton, cards, chips).
  static const double pressScale = 0.97;

  /// Full-width list rows shrink less (a 0.97 row moves its edges ~5 dp).
  static const double rowPressScale = 0.985;

  /// Rows that get the staggered entrance on a list's first load.
  static const int entranceMax = 8;

  /// Standard curve for base/slow transitions.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Decelerating curve for things that arrive (entrances, routes).
  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1);

  /// Finger down on a control: quick ease to [pressScale].
  Duration get press => reduced ? Duration.zero : _press;

  /// Finger up: spring back to rest.
  Duration get release => reduced ? Duration.zero : _release;

  /// Presses and toggles.
  Duration get fast => reduced ? Duration.zero : _fast;

  /// Most transitions and accordions.
  Duration get base => reduced ? Duration.zero : _base;

  /// Sheets and the hero/sheet reveal (≤ 320 ms).
  Duration get slow => reduced ? Duration.zero : _slow;

  /// Nav pill morph and other spring moves.
  Duration get showcase => reduced ? Duration.zero : _showcase;

  /// Push route (shared axis); [routeBack] for the pop.
  Duration get route => reduced ? Duration.zero : _route;
  Duration get routeBack => reduced ? Duration.zero : _routeBack;

  /// Fade-through between bottom-nav tabs and in-page tabs.
  Duration get tab => reduced ? Duration.zero : _tab;

  /// Balance totals counting to a new value.
  Duration get count => reduced ? Duration.zero : _count;

  /// One list row's entrance; rows start [stagger] apart.
  Duration get entrance => reduced ? Duration.zero : _entrance;
  Duration get stagger => reduced ? Duration.zero : _stagger;

  /// One sweep of the loading skeleton's shimmer (loops; static when reduced).
  Duration get shimmer => _shimmer;

  /// A showpiece's staggered entrance, every part included (the welcome preview's cards, S-281).
  Duration get intro => reduced ? Duration.zero : _intro;

  /// One loop of an idle float (±3–4 dp; the welcome preview, S-281). Callers never start it when reduced.
  Duration get float => _float;

  /// A section opening or closing in place (settled history, who owes whom, filters, the monthly card), S-451.
  Duration get expand => reduced ? Duration.zero : _expand;

  /// A row that arrives while its list is on screen (a saved expense, a new comment, a chip), S-451.
  Duration get insert => reduced ? Duration.zero : _insert;

  /// A value that changes in place (Show in INR, simplified / original, a split mode's body), S-451.
  Duration get swap => reduced ? Duration.zero : _swap;

  /// The success check drawing itself (saved, paid), S-452.
  Duration get success => reduced ? Duration.zero : _success;

  /// How long the editor's saved check stays before the page closes (was 700 ms, S-452).
  Duration get successHold => reduced ? Duration.zero : _successHold;

  /// Chips and pills changing between their resting and selected looks.
  Duration get select => fast;

  /// Bottom sheets rising (closing takes [fast]); never over 350 ms.
  Duration get sheet => slow;

  /// Curve for presses and toggles.
  Curve get fastCurve => Curves.easeOut;

  /// Spring (stiffness 300, damping 26) for showcase motion and the press release.
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

/// Haptics (§5, S-453): one helper for every tick, never heavy.
///
/// * [selection]: toggles, steps, tab switches, chips.
/// * [light]: primary buttons and the + button.
/// * [success]: a save or a payment went through (Android 11+ CONFIRM; a firmer tick before).
/// * [error]: Save found a problem (Android 11+ REJECT; two quick ticks before).
///
/// [success] and [error] go through `splitify/haptics` (MainActivity) so phones older than Android 11 still
/// feel them; without that channel (tests, other platforms) Flutter's notification haptics play.
abstract final class AppHaptics {
  static const channel = MethodChannel('splitify/haptics');

  static void selection() => unawaited(HapticFeedback.selectionClick());

  static void light() => unawaited(HapticFeedback.lightImpact());

  static void success() => unawaited(_notify('success', HapticFeedback.successNotification));

  static void error() => unawaited(_notify('error', HapticFeedback.errorNotification));

  static Future<void> _notify(String kind, Future<void> Function() fallback) async {
    try {
      await channel.invokeMethod<void>(kind);
    } on MissingPluginException {
      await fallback();
    } on PlatformException {
      await fallback();
    }
  }
}
