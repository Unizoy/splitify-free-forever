import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Centres [child] and keeps it at most [maxWidth] wide (R3-A, S-444): on phones it changes nothing; on
/// tablets and open foldables forms, lists and cards keep their phone proportions instead of stretching,
/// while the page background behind them still fills the screen.
class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.child, this.maxWidth = AppSpacing.maxContent, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// [ContentWidth] for a sliver: pads [sliver] on both sides so its content is at most [maxWidth] wide
/// and centred.
class SliverContentWidth extends StatelessWidget {
  const SliverContentWidth({
    required this.sliver,
    this.maxWidth = AppSpacing.maxContent,
    super.key,
  });

  final Widget sliver;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final side = math.max(0, (constraints.crossAxisExtent - maxWidth) / 2).toDouble();
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: side),
        sliver: sliver,
      );
    },
  );
}

/// Side padding for a page whose content should be at most [maxWidth] wide: the screen margin on phones,
/// more on wide screens so the content is centred (for scroll views that take a padding).
double pageSidePadding(BuildContext context, {double maxWidth = AppSpacing.maxContent}) {
  final width = MediaQuery.sizeOf(context).width;
  return math.max(AppSpacing.screen, (width - maxWidth) / 2);
}

/// A page body (a scroll view or column that brings its own 20 dp side margins) at most
/// [AppSpacing.maxPage] wide, centred, full height (R3-A, S-444): forms and lists keep phone proportions on
/// tablets and open foldables. On phones it changes nothing.
class PageBody extends StatelessWidget {
  const PageBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSpacing.maxPage),
      child: child,
    ),
  );
}
