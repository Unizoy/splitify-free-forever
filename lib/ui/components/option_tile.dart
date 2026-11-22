import 'package:flutter/material.dart';
import 'package:splitify/ui/components/pressable.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Outlined indigo choice (532 "Before Dec 24"): radius 16, at least 56 dp
/// tall, centred primary text. Selected = filled `primaryContainer`.
class OptionTile extends StatelessWidget {
  const OptionTile({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.leading,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  /// Optional widget before the label (avatar, icon).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadii.all16,
        haptic: PressHaptic.selection,
        child: AnimatedContainer(
          duration: context.motion.fast,
          curve: context.motion.fastCurve,
          decoration: BoxDecoration(
            color: selected ? c.primaryContainer : AppPalette.clear,
            borderRadius: AppRadii.all16,
            border: Border.all(color: c.primary, width: 1.5),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.buttonLarge),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s5,
                vertical: AppSpacing.s3,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.s3)],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: context.text.button
                          .w(700)
                          .copyWith(color: selected ? c.onPrimaryContainer : c.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
