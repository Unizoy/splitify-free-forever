import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/ui/theme/theme.dart';

/// One choice in a [SegmentedPill].
class SegmentedPillItem<T> {
  const SegmentedPillItem({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Segmented control (534 Fixed/Flexible): `surfaceMuted` track, the selected
/// segment is a white pill with a soft shadow that slides between choices.
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    required this.items,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<SegmentedPillItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final index = items.indexWhere((i) => i.value == value).clamp(0, items.length - 1);
    final x = items.length == 1 ? 0.0 : -1 + 2 * index / (items.length - 1);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s1),
      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.allPill),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              alignment: Alignment(x, 0),
              duration: context.motion.base,
              curve: AppMotion.standard,
              child: FractionallySizedBox(
                widthFactor: 1 / items.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.isDark ? c.chip : c.surface,
                    borderRadius: AppRadii.allPill,
                    boxShadow: AppShadows.card(c, dark: context.isDark),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final item in items)
                Expanded(
                  child: _Segment(
                    item: item,
                    selected: item.value == value,
                    onTap: () {
                      if (item.value == value) return;
                      HapticFeedback.selectionClick();
                      onChanged(item.value);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({required this.item, required this.selected, required this.onTap});

  final SegmentedPillItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.textPrimary : c.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.allPill,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 18, color: color),
                  const SizedBox(width: AppSpacing.s2),
                ],
                Flexible(
                  child: Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: context.text.body.w(selected ? 600 : 500).copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
