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
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return DecoratedBox(
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
  }
}
