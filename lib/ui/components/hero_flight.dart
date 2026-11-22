import 'package:flutter/material.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Hero tags shared by a list item and the page it opens (S-263).
abstract final class AppHeroTags {
  /// Group card cover → group page hero.
  static String group(String id) => 'group-cover-$id';

  /// Expense row icon → expense detail icon.
  static String expense(String id) => 'expense-icon-$id';
}

/// Container transform for a group card flying into a page hero: the page's background grows out of the
/// card while the card's own face fades out early, and the corners open from 28 dp to square. Covers paint
/// directly while in flight (no cache entry per frame).
Widget coverHeroShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final from = (fromHeroContext.widget as Hero).child;
  final to = (toHeroContext.widget as Hero).child;
  final push = direction == HeroFlightDirection.push;
  final card = push ? from : to;
  final page = push ? to : from;
  return CoverCacheOff(
    child: Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.r28 * (1 - t)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                page,
                Opacity(opacity: (1 - t / 0.4).clamp(0.0, 1.0), child: card),
              ],
            ),
          );
        },
      ),
    ),
  );
}
