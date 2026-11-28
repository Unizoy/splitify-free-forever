import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/pressable.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Outlined − / + circles (36 dp, 48 dp touch area) with the value between
/// (712). Used for shares.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.semanticLabel,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  /// What is being counted ("Rahul's shares").
  final String? semanticLabel;

  void _set(int v) {
    AppHaptics.selection();
    onChanged(v.clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canDec = value > min;
    final canInc = value < max;
    return Semantics(
      label: semanticLabel,
      value: '$value',
      increasedValue: canInc ? '${value + 1}' : null,
      decreasedValue: canDec ? '${value - 1}' : null,
      onIncrease: canInc ? () => _set(value + 1) : null,
      onDecrease: canDec ? () => _set(value - 1) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Circle(
            icon: AppIcons.minus,
            tooltip: l.decrease,
            onTap: canDec ? () => _set(value - 1) : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40),
            child: ExcludeSemantics(
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: context.text.title
                    .w(600)
                    .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
          _Circle(
            icon: AppIcons.plus,
            tooltip: l.increase,
            onTap: canInc ? () => _set(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = onTap == null ? c.textTertiary : c.textSecondary;
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: tooltip,
        child: Pressable(
          onTap: onTap,
          circle: true,
          scale: 0.88,
          child: SizedBox.square(
            dimension: AppSpacing.minTouch,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
