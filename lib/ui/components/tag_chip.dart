import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Tiny letter-spaced caps tag beside a row title ("LOAN"): `primaryContainer` pill, never wraps.
class TagChip extends StatelessWidget {
  const TagChip({required this.label, this.icon, super.key});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 2),
      decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadii.allPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c.onPrimaryContainer),
            const SizedBox(width: AppSpacing.s1),
          ],
          Text(
            label.toUpperCase(),
            maxLines: 1,
            // 11 sp at least (R3-A, S-442): the old 10 sp tag was the smallest text in the app.
            style: context.text.labelCaps.copyWith(color: c.onPrimaryContainer, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
