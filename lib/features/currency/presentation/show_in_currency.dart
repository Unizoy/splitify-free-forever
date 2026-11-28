import 'package:flutter/material.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/currency/domain/in_currency.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Show in INR" / "By currency" on a hero (W2-X P-9): one switch for the Home card and friend pages.
class ShowInCurrencyChip extends StatelessWidget {
  const ShowInCurrencyChip({
    required this.currency,
    required this.on,
    required this.onChanged,
    super.key,
  });

  final String currency;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      toggled: on,
      child: IconChip(
        key: const Key('show-in-currency'),
        label: on ? l.w2xShowByCurrency : l.w2xShowIn(currency),
        icon: AppIcons.swap,
        onDark: true,
        onTap: () => onChanged(!on),
      ),
    );
  }
}

/// The "not converted" amounts next to a converted total, signed when they point another way than [main].
String notConvertedText(Map<String, int> left, int main) {
  final mainSign = main.sign;
  final signed =
      left.values.any((v) => mainSign != 0 && v.sign != mainSign) ||
      balanceStatusOf(left.values) == BalanceStatus.mixed;
  final codes = left.keys.toList()..sort();
  return [for (final c in codes) signed ? signedMoney(left[c]!, c) : listMoney(left[c]!.abs(), c)]
      .join(' · ');
}

/// The lines under a converted total on a hero: "In INR · saved rates", and what stays in its own currency.
class InCurrencyNote extends StatelessWidget {
  const InCurrencyNote({required this.value, this.center = false, super.key});

  final InCurrency value;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final style = context.text.bodySmall.copyWith(color: c.onHero.withValues(alpha: 0.78));
    final align = center ? TextAlign.center : TextAlign.start;
    final v = value;
    return Column(
      key: const Key('in-currency-note'),
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          v.counted ? l.w2xInSavedRates(v.currency) : l.w2xNothingConverted(v.currency),
          key: const Key('in-currency-label'),
          textAlign: align,
          style: style,
        ),
        if (v.counted && v.notConverted.isNotEmpty)
          Text(
            l.w2xNotConverted(notConvertedText(v.notConverted, v.amount)),
            key: const Key('in-currency-left'),
            textAlign: align,
            style: style.w(600),
          ),
      ],
    );
  }
}
