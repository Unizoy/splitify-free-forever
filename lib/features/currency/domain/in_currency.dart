/// "Show in INR" on the Home overall card and a friend's page (W2-X P-9, S-427; rule 4).
///
/// A record counts in the chosen currency only as it is (already in it) or through the conversion saved with it
/// (rate, date, source; never recalculated, nothing fetched). Everything else stays in its own currency and is
/// shown next to the total as "not converted": currencies are never added together silently.
library;

import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/money/money_error.dart' show MoneyError;
import 'package:splitify/features/currency/domain/conversion.dart' show fullOrder;
import 'package:splitify/features/currency/domain/converted_balances.dart';

/// An amount in [currency] plus what could not be counted in it, per currency.
final class InCurrency {
  const InCurrency({
    required this.currency,
    this.amount = 0,
    this.notConverted = const {},
    this.counted = false,
  });

  /// The currency everything possible is shown in.
  final String currency;

  /// Minor units of [currency] (positive = owed to me).
  final int amount;

  /// Other currencies whose records have no saved conversion to [currency]: currency → minor units, 0s left out.
  final Map<String, int> notConverted;

  /// At least one record counted in [currency] (as it is or converted).
  final bool counted;

  /// Nothing to show in [currency]: no record counts in it.
  bool get empty => !counted;

  InCurrency operator +(InCurrency o) {
    final left = {...notConverted};
    o.notConverted.forEach((c, v) => left[c] = (left[c] ?? 0) + v);
    left.removeWhere((_, v) => v == 0);
    return InCurrency(
      currency: currency,
      amount: amount + o.amount,
      notConverted: left,
      counted: counted || o.counted,
    );
  }
}

int _part(Map<String, int>? m, String id) => m?[id] ?? 0;

/// My net in [target] from one group's [records] ([me] = my member id): paid minus share for expenses, and
/// payments I made (+) or got (-), each through its saved conversion when it is in another currency.
InCurrency myNetIn(String target, String me, List<FxRecord> records) {
  var amount = 0;
  var counted = false;
  final left = <String, int>{};
  for (final r in records) {
    final native = r.currency == target;
    final use = native || r.countsIn(target);
    final int v;
    if (r.isPayment) {
      final a = native ? r.amount : (use ? r.fxAmount! : r.amount);
      v = r.from == r.to ? 0 : (r.from == me ? a : (r.to == me ? -a : 0));
    } else {
      final paid = native || !use ? r.paid : r.fxPaid;
      final shares = native || !use ? r.shares : r.fxShares;
      v = _part(paid, me) - _part(shares, me);
    }
    if (use) {
      counted = true;
      amount += v;
    } else if (v != 0) {
      left[r.currency] = (left[r.currency] ?? 0) + v;
    }
  }
  left.removeWhere((_, v) => v == 0);
  return InCurrency(currency: target, amount: amount, notConverted: left, counted: counted);
}

/// What [friend] owes [me] (positive) or I owe them (negative) in [target] in one group, as its screen shows it.
/// Original debts (simplify off) add up record by record, each through its saved conversion. With simplify on,
/// the group's simplified transfers are only redone in [target] when every record counts in it (like "Simplify in
/// INR" on the group's Balances tab); otherwise the group stays as it is: [shown] (currency → what its screen
/// shows between us) goes to "not converted" unchanged.
InCurrency pairIn(
  String target, {
  required String me,
  required String friend,
  required List<String> order,
  required List<FxRecord> records,
  required bool simplify,
  required Map<String, int> shown,
}) {
  if (simplify) {
    final cb = convertedBalances(target, order, records);
    final b = cb.balances;
    if (!cb.complete || b == null) {
      final left = {...shown}..removeWhere((_, v) => v == 0);
      final inTarget = left.remove(target) ?? 0;
      return InCurrency(
        currency: target,
        amount: inTarget,
        notConverted: left,
        counted: inTarget != 0 || shown.containsKey(target),
      );
    }
    var amount = 0;
    for (final t in b.simplified) {
      if (t.from == friend && t.to == me) amount += t.amount;
      if (t.from == me && t.to == friend) amount -= t.amount;
    }
    return InCurrency(currency: target, amount: amount, counted: true);
  }
  var amount = 0;
  var counted = false;
  final left = <String, int>{};
  for (final r in records) {
    final native = r.currency == target;
    final use = native || r.countsIn(target);
    var v = 0;
    if (r.isPayment) {
      final a = native || !use ? r.amount : r.fxAmount!;
      if (r.from == me && r.to == friend) v = a;
      if (r.from == friend && r.to == me) v = -a;
    } else {
      final paid = (native || !use ? r.paid : r.fxPaid)!;
      final shares = (native || !use ? r.shares : r.fxShares)!;
      final ids = [...paid.keys, ...shares.keys];
      try {
        for (final t in expensePairs(fullOrder(order, ids), paid, shares)) {
          if (t.from == friend && t.to == me) v += t.amount;
          if (t.from == me && t.to == friend) v -= t.amount;
        }
      } on MoneyError {
        v = 0;
      }
    }
    if (use) {
      counted = true;
      amount += v;
    } else if (v != 0) {
      left[r.currency] = (left[r.currency] ?? 0) + v;
    }
  }
  left.removeWhere((_, v) => v == 0);
  return InCurrency(currency: target, amount: amount, notConverted: left, counted: counted);
}
