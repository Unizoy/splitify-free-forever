import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/app_motion.dart';

/// Push routes slide along a shared horizontal axis (S-262): the new page comes in 24 dp from the end
/// edge while it fades in, the old one drifts 24 dp the other way and fades into the page colour; a pop
/// runs it backwards. 280 ms in, 240 ms back — crisp, never a full-width slide. Instant when the user
/// removed animations.
class SharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const SharedAxisPageTransitionsBuilder();

  /// How far pages travel.
  static const double shift = 24;

  @override
  Duration get transitionDuration => const AppMotion(reduced: false).route;

  @override
  Duration get reverseTransitionDuration => const AppMotion(reduced: false).routeBack;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.of(context).reduced) return child;
    return SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// The shared-axis move for one page: [animation] brings it in (fade + slide from the end side) and takes it
/// out on pop; [secondaryAnimation] shifts it toward the start side while a new page fades in over it. Only
/// the top page fades, so the two always cross-fade over real content — never over an empty window.
class SharedAxisTransition extends StatelessWidget {
  const SharedAxisTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    super.key,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  static const _fadeIn = Interval(0, 0.55, curve: Curves.easeOut);
  static const _fadeOut = Interval(0.45, 1, curve: Curves.easeIn);

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    const shift = SharedAxisPageTransitionsBuilder.shift;
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      builder: (context, child) {
        final a = animation.value;
        final s = secondaryAnimation.value;
        final popping = animation.status == AnimationStatus.reverse;
        final opacity = (popping ? _fadeOut : _fadeIn).transform(a);
        final x =
            dir * shift * (1 - AppMotion.emphasized.transform(a)) -
            dir * shift * AppMotion.standard.transform(s);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(offset: Offset(x, 0), child: child),
        );
      },
      child: child,
    );
  }
}
