import 'package:flutter/material.dart';
import 'package:splitify/ui/components/dashed_divider.dart';
import 'package:splitify/ui/components/pressable.dart';
import 'package:splitify/ui/components/word_fit_text.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Settings-style row (614): icon, label, optional value and chevron, with a
/// dashed divider below.
class DashedListRow extends StatelessWidget {
  const DashedListRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueColor,
    this.onTap,
    this.showDivider = true,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool showDivider;

  /// Red label and icon (Delete account).
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = destructive ? c.oweText : c.textPrimary;
    final stacked = value != null && context.stackRows;
    final valueText = value == null
        ? null
        : Text(
            value!,
            textAlign: TextAlign.end,
            style: context.text.amount.copyWith(color: valueColor ?? c.primary),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: onTap != null,
          child: Pressable(
            onTap: onTap,
            scale: AppMotion.rowPressScale,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                child: Row(
                  children: [
                    Icon(icon, size: 24, color: fg),
                    const SizedBox(width: AppSpacing.s4),
                    Expanded(
                      child: stacked
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                WordFitText(
                                  label,
                                  style: context.text.body.w(600).copyWith(color: fg),
                                ),
                                const SizedBox(height: 2),
                                valueText!,
                              ],
                            )
                          : WordFitText(label, style: context.text.body.w(600).copyWith(color: fg)),
                    ),
                    if (valueText != null && !stacked) ...[
                      const SizedBox(width: AppSpacing.s3),
                      // A long value wraps (right-aligned) instead of running off a 320 dp phone (S-446).
                      Flexible(child: valueText),
                    ],
                    if (onTap != null) ...[
                      const SizedBox(width: AppSpacing.s3),
                      Icon(AppIcons.chevronRight, size: 18, color: fg),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showDivider) const DashedDivider(),
      ],
    );
  }
}
