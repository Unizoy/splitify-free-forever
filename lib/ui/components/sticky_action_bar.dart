import 'package:flutter/material.dart';
import 'package:splitify/ui/components/content_width.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Bottom action bar (712): page-coloured bar with a top divider, a summary
/// line and the amber CTA (plus an optional secondary action beside it).
/// Respects the bottom safe area.
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({required this.primary, this.summary, this.secondary, super.key});

  /// Summary text or row shown above the buttons.
  final Widget? summary;
  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    // Side by side the primary gets two thirds of the bar: stacked when that would wrap its label — large
    // text, or a narrow phone (320 dp at 1.0, 393 dp at 1.3) where "Add expense" broke mid-word (S-446).
    const margins = 2 * AppSpacing.screen;
    final content =
        MediaQuery.sizeOf(context).width.clamp(margins, AppSpacing.maxContent + margins) - margins;
    final large = scale > 1.4 || content / scale < 320;
    // On a short phone the pinned bar keeps its text at 1.5x at most, so at 200 % it no longer covers half
    // the screen (320 x 568: about 290 of 568 dp; R3-A, S-446). The page above scales fully.
    final short = MediaQuery.sizeOf(context).height < 700;
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.s3),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s4,
            AppSpacing.screen,
            AppSpacing.s1,
          ),
          // On tablets the bar spans the screen and its buttons line up with the content (S-444).
          child: ContentWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (summary != null) ...[
                  DefaultTextStyle(
                    style: context.text.body.w(600).copyWith(color: c.textSecondary),
                    child: summary!,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                ],
                if (secondary == null)
                  primary
                else if (large)
                  Column(
                    children: [
                      primary,
                      const SizedBox(height: AppSpacing.s2),
                      secondary!,
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(child: secondary!),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(flex: 2, child: primary),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return short ? MediaQuery.withClampedTextScaling(maxScaleFactor: 1.5, child: bar) : bar;
  }
}
