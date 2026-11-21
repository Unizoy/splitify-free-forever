import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Empty state (636): 64 dp light-blue icon bubble, title, secondary message
/// and optional actions. No illustrations.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.actions = const [],
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Buttons under the text, laid out side by side (stacked at large text).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.infoContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: c.info),
          ),
          const SizedBox(height: AppSpacing.s4),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.title.copyWith(color: c.textPrimary),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: context.text.body.copyWith(color: c.textSecondary),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s6),
            if (large || actions.length == 1)
              Column(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.s3),
                    actions[i],
                  ],
                ],
              )
            else
              Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.s3),
                    Expanded(child: actions[i]),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }
}
