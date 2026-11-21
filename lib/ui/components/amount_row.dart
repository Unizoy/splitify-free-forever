import 'package:flutter/material.dart';
import 'package:splitify/ui/components/money_tone.dart';
import 'package:splitify/ui/components/sync_marker.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Money list row (646): title and caption on the left, signed amount on the
/// right ("+ ₹15" green, "− ₹15" red), divider below. Unsynced rows show the
/// [SyncMarker] under the caption.
class AmountRow extends StatelessWidget {
  const AmountRow({
    required this.title,
    required this.amountText,
    this.tone = MoneyTone.settled,
    this.caption,
    this.amountCaption,
    this.leading,
    this.unsynced = false,
    this.onTap,
    this.showDivider = true,
    super.key,
  });

  final String title;

  /// Formatted amount without a sign ("₹1,200"); the sign comes from [tone].
  final String amountText;
  final MoneyTone tone;
  final String? caption;

  /// Small line under the amount ("you lent").
  final String? amountCaption;
  final Widget? leading;
  final bool unsynced;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = tone.textColor(c);
    final sign = tone.sign;
    final signed = sign.isEmpty ? amountText : '$sign $amountText';
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.title.w(500)),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(caption!, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
        ],
        if (unsynced) ...[const SizedBox(height: AppSpacing.s1), const SyncMarker()],
      ],
    );
    final right = Column(
      crossAxisAlignment: large ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(signed, style: context.text.title.w(700).copyWith(color: color)),
        if (amountCaption != null)
          Text(amountCaption!, style: context.text.caption.copyWith(color: color)),
      ],
    );

    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.s3)],
                  Expanded(
                    child: large
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              left,
                              const SizedBox(height: AppSpacing.s1),
                              right,
                            ],
                          )
                        : left,
                  ),
                  if (!large) ...[const SizedBox(width: AppSpacing.s3), right],
                ],
              ),
            ),
            if (showDivider) Divider(height: 1, thickness: 1, color: c.divider),
          ],
        ),
      ),
    );
  }
}
