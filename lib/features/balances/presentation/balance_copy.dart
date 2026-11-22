import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';

/// List-style amount (`₹1,200`, `$35.50`).
String listMoney(int minor, String currency) => MoneyFormatter.list.format(minor, currency);

/// Signed list amount (`+₹500`, `−$20`) for mixed balances.
String signedMoney(int minor, String currency) {
  final text = const MoneyFormatter(
    hideZeroFraction: true,
    sign: MoneySign.always,
  ).format(minor, currency);
  // A word joiner keeps the sign on the amount's line ("-$20" never splits after the sign, S-240).
  final signed =
      text.startsWith(MoneyFormatter.plusSign) || text.startsWith(MoneyFormatter.minusSign);
  return signed ? '${text[0]}\u2060${text.substring(1)}' : text;
}

/// Per-currency amounts joined with ` · ` ([nets] already ordered). Absolute values, unless the
/// signs differ (then each carries its sign, rule 4: never one total over currencies).
String amountsText(Map<String, int> nets) {
  final mixed = balanceStatusOf(nets.values) == BalanceStatus.mixed;
  return [
    for (final e in nets.entries)
      mixed ? signedMoney(e.value, e.key) : listMoney(e.value.abs(), e.key),
  ].join('\u00A0· ');
}

/// Green when owed, red when owing, neutral otherwise.
MoneyTone toneOf(BalanceStatus s) => switch (s) {
  BalanceStatus.owed => MoneyTone.owed,
  BalanceStatus.owe => MoneyTone.owe,
  _ => MoneyTone.settled,
};

MoneyTone toneOfNet(int net) => net > 0
    ? MoneyTone.owed
    : net < 0
    ? MoneyTone.owe
    : MoneyTone.settled;

/// "You are owed" / "You owe" / "Settled" / "Owed and owing" (card and glass labels).
String statusText(AppLocalizations l, BalanceStatus s) => switch (s) {
  BalanceStatus.owed => l.youAreOwed,
  BalanceStatus.owe => l.youOwe,
  BalanceStatus.settled => l.settled,
  BalanceStatus.mixed => l.statusOwedAndOwe,
};

/// A member's name in a sentence: "You" at the start, "you" inside, else the display name.
String personName(AppLocalizations l, GroupBalances b, String id, {bool start = true}) {
  if (id == b.meId) return start ? l.you : l.youLower;
  final n = b.nameOf(id);
  return n.isEmpty ? l.someone : n;
}
