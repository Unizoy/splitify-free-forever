import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/features/expenses/application/keypad_input.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// 4 × 4 amount keypad of the loan form (#11): digits on the page, operators on muted keys, ⌫ (long press
/// clears). The expense editor uses the phone's number keyboard instead (D-032).
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({required this.onKey, required this.onClear, this.allowDot = true, super.key});

  final ValueChanged<KeypadKey> onKey;
  final VoidCallback onClear;
  final bool allowDot;

  static const _rows = [
    [KeypadKey.d1, KeypadKey.d2, KeypadKey.d3, KeypadKey.divide],
    [KeypadKey.d4, KeypadKey.d5, KeypadKey.d6, KeypadKey.times],
    [KeypadKey.d7, KeypadKey.d8, KeypadKey.d9, KeypadKey.minus],
    [KeypadKey.dot, KeypadKey.d0, KeypadKey.delete, KeypadKey.plus],
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      // A hairline on top: content scrolling under the keypad reads as scrolled, not cut off.
      decoration: BoxDecoration(
        color: c.bgSubtle,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s3,
          AppSpacing.s3,
          AppSpacing.s3,
          AppSpacing.s2,
        ),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.4,
          child: Column(
            children: [
              for (final row in _rows)
                Row(
                  children: [
                    for (final k in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.s1),
                          child: _Key(
                            keyValue: k,
                            enabled: k != KeypadKey.dot || allowDot,
                            onTap: () => onKey(k),
                            onLongPress: k == KeypadKey.delete ? onClear : null,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.keyValue,
    required this.enabled,
    required this.onTap,
    this.onLongPress,
  });

  final KeypadKey keyValue;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final op = keyValue.isOperator;
    final label = switch (keyValue) {
      KeypadKey.delete => l.expKeyDelete,
      KeypadKey.plus => l.expKeyPlus,
      KeypadKey.minus => l.expKeyMinus,
      KeypadKey.times => l.expKeyTimes,
      KeypadKey.divide => l.expKeyDivide,
      KeypadKey.dot => l.expKeyDot,
      _ => keyValue.symbol,
    };
    final fg = !enabled ? c.textTertiary : (op ? c.primary : c.textPrimary);
    final Widget face = keyValue == KeypadKey.delete
        ? Icon(AppIcons.backspace, size: 26, color: fg)
        : Text(keyValue.symbol, style: context.text.headline.w(op ? 600 : 500).copyWith(color: fg));
    void tap() {
      HapticFeedback.selectionClick();
      onTap();
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? tap : null,
      child: Pressable(
        key: Key('key-${keyValue.name}'),
        onTap: enabled ? tap : null,
        onLongPress: onLongPress,
        borderRadius: AppRadii.all16,
        child: Material(
          color: op ? c.surfaceMuted : c.surface,
          borderRadius: AppRadii.all16,
          child: SizedBox(height: 52, child: Center(child: face)),
        ),
      ),
    );
  }
}
