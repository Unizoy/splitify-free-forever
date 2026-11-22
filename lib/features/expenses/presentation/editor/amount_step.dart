import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/keypad_input.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/currency/presentation/currency_picker_sheet.dart'
    show CurrencyChip;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Step 1 (07 §2): huge centred amount with the currency chip, the description underline field
/// and the custom keypad (digits, `.`, ⌫, `+ − × ÷`).
class AmountStep extends StatelessWidget {
  const AmountStep({
    required this.draft,
    required this.description,
    required this.onAmountText,
    required this.onDescription,
    required this.showErrors,
    this.onPickCurrency,
    super.key,
  });

  final ExpenseDraft draft;
  final TextEditingController description;
  final ValueChanged<String> onAmountText;
  final ValueChanged<String> onDescription;

  /// Show "required" problems (after a Save or Next attempt).
  final bool showErrors;

  /// Opens the currency picker (phase 14).
  final VoidCallback? onPickCurrency;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final text = draft.amountText;
    final result = draft.amount;
    final error = l.amountError(result, draft.currency);
    final total = draft.total;
    final symbol = Currencies.of(draft.currency).symbol;
    final amountStyle = context.text.amountHero.copyWith(
      color: text.isEmpty ? c.textTertiary : c.textPrimary,
    );
    final descriptionError = showErrors ? l.descriptionError(draft.descriptionProblem) : null;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.s6,
              AppSpacing.screen,
              AppSpacing.s4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l.expAmountQuestion,
                    textAlign: TextAlign.center,
                    style: context.text.headline,
                  ),
                ),
                const SizedBox(height: AppSpacing.s5),
                Center(
                  child: CurrencyChip(code: draft.currency, onTap: onPickCurrency),
                ),
                const SizedBox(height: AppSpacing.s3),
                Semantics(
                  label: l.expAmountLabel,
                  value: total == null ? text : MoneyFormatter.detail.format(total, draft.currency),
                  liveRegion: true,
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$symbol${text.isEmpty ? '0' : KeypadInput.display(text)}',
                      key: const Key('amount-display'),
                      maxLines: 1,
                      style: amountStyle,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(22),
                  child: Center(
                    child: error != null
                        ? Text(
                            error,
                            key: const Key('amount-error'),
                            style: context.text.bodySmall.w(600).copyWith(color: c.oweText),
                          )
                        : (total != null && KeypadInput.hasOperator(text))
                        ? Text(
                            l.expAmountEquals(MoneyFormatter.list.format(total, draft.currency)),
                            style: context.text.bodySmall.w(600).copyWith(color: c.primary),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.s5),
                UnderlineField(
                  key: const Key('expense-description'),
                  label: l.expDescriptionLabel,
                  hint: l.expDescriptionHint,
                  required: true,
                  controller: description,
                  errorText: descriptionError,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [LengthLimitingTextInputFormatter(maxDescription + 20)],
                  onChanged: onDescription,
                ),
              ],
            ),
          ),
        ),
        if (!keyboardOpen)
          AmountKeypad(
            onKey: (k) {
              FocusManager.instance.primaryFocus?.unfocus();
              onAmountText(KeypadInput.apply(text, k, Currencies.exponentOf(draft.currency)));
            },
            onClear: () => onAmountText(''),
            allowDot: Currencies.exponentOf(draft.currency) > 0,
          ),
      ],
    );
  }
}

/// 4 × 4 amount keypad: digits on the page, operators on muted keys, ⌫ (long press clears).
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
      child: Material(
        color: op ? c.surfaceMuted : c.surface,
        borderRadius: AppRadii.all16,
        child: InkWell(
          key: Key('key-${keyValue.name}'),
          borderRadius: AppRadii.all16,
          onTap: enabled ? tap : null,
          onLongPress: onLongPress,
          child: SizedBox(height: 52, child: Center(child: face)),
        ),
      ),
    );
  }
}
