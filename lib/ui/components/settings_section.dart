import 'package:flutter/widgets.dart';
import 'package:splitify/ui/theme/theme.dart';

/// A settings group (D-033, Splitwise-like lists): an optional caps heading and a surface card holding its
/// rows ([DashedListRow], [ToggleRow]); an optional [footer] note under the card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({required this.children, this.title, this.footer, super.key});

  final String? title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.s1, bottom: AppSpacing.s3),
            child: Semantics(
              header: true,
              child: Text(
                title!.toUpperCase(),
                style: context.text.labelCaps.copyWith(color: c.textSecondary),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadii.all24,
            border: Border.all(color: c.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s1),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s1, AppSpacing.s2, AppSpacing.s1, 0),
            child: Text(footer!, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
          ),
      ],
    );
  }
}
