import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/ui/components/dashed_divider.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Settings row with an on/off pill (notification settings, phase 13): optional tinted icon circle, title,
/// one-line hint and the switch. The whole row toggles; 48 dp touch, screen readers hear the state.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.leading,
    this.showDivider = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;

  /// Null disables the row.
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  /// Replaces the icon circle (a group's avatar).
  final Widget? leading;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;
    final lead =
        leading ??
        (icon == null
            ? null
            : Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: c.onPrimaryContainer),
              ));
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              }
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.minTouch + AppSpacing.s4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                child: Row(
                  children: [
                    if (lead != null) ...[lead, const SizedBox(width: AppSpacing.s3)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: context.text.title
                                .w(500)
                                .copyWith(color: enabled ? c.textPrimary : c.textTertiary),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: context.text.bodySmall.copyWith(color: c.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    PillSwitch(value: value, enabled: enabled),
                  ],
                ),
              ),
            ),
            if (showDivider) const DashedDivider(),
          ],
        ),
      ),
    );
  }
}

/// The switch itself (52×32): indigo track with the knob on the right when on, a quiet outlined track when
/// off. Display only; [ToggleRow] handles taps and semantics.
class PillSwitch extends StatelessWidget {
  const PillSwitch({required this.value, this.enabled = true, super.key});

  final bool value;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final duration = context.motion.fast;
    final track = !enabled
        ? c.surfaceMuted
        : value
        ? c.primary
        : c.chip;
    return AnimatedContainer(
      duration: duration,
      curve: AppMotion.standard,
      width: 52,
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: track,
        borderRadius: AppRadii.allPill,
        border: Border.all(color: value && enabled ? c.primary : c.border),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: AppMotion.standard,
        alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: value && enabled ? c.surface : c.textTertiary,
            shape: BoxShape.circle,
          ),
          child: value && enabled ? Icon(AppIcons.check, size: 13, color: c.primary) : null,
        ),
      ),
    );
  }
}
