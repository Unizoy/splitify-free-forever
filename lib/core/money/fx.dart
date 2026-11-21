/// Currency conversion (planning/05-money-engine.md §6, rules 4–5).
///
/// Rates are decimal strings (> 0, at most 10 decimal places) handled with
/// `package:decimal`; results are rounded half away from zero, written out
/// explicitly as sign × ⌊|v| + ½⌋ in exact integer arithmetic so Dart and SQL
/// can't differ.
library;

import 'package:decimal/decimal.dart';
import 'package:splitify/core/money/allocation.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_error.dart';

/// Decimal places a stored rate may have (`numeric(24,10)`).
const int rateDecimals = 10;

final BigInt _rateScale = BigInt.from(10).pow(rateDecimals);

/// Parses an exchange rate. Throws [InvalidRate] unless [rate] is a decimal
/// number > 0 with at most [rateDecimals] decimal places (trailing zeros don't count).
Decimal parseRate(String rate) {
  final r = Decimal.tryParse(rate.trim());
  if (r == null || r <= Decimal.zero || r.scale > rateDecimals) throw const InvalidRate();
  return r;
}

/// Converts [amount] minor units of [from] into minor units of [to] at
/// [rate] (major units of [to] per major unit of [from]):
/// `round_half_away_from_zero(amount × rate × 10^(exp(to) − exp(from)))`.
///
/// Any sign of [amount] is allowed. Throws [InvalidRate], or [AmountTooLarge]
/// when the result does not fit a 64-bit int.
int convert(int amount, String from, String to, String rate) {
  final r = parseRate(rate);
  final shift = Currencies.exponentOf(to) - Currencies.exponentOf(from);
  final v = (Decimal.fromInt(amount) * r).shift(shift).toRational();
  final result = _roundHalfAway(v.numerator, v.denominator);
  if (!result.isValidInt) throw const AmountTooLarge();
  return result.toInt();
}

/// An expense converted into another currency; parts still sum to [total].
final class ConvertedExpense {
  const ConvertedExpense({
    required this.currency,
    required this.total,
    required this.paid,
    required this.shares,
  });

  /// The target currency.
  final String currency;
  final int total;

  /// Paid per member, in fixed order.
  final Map<String, int> paid;

  /// Share per member, in fixed order.
  final Map<String, int> shares;
}

/// Converts an expense: the total with [convert], then payers and shares
/// re-allocated by their original amounts with [allocateRatio] (largest
/// remainder, fixed-order ties), so the parts still sum to the new total.
///
/// Throws [AmountNotPositive] / [AmountTooLarge] when [total] or the converted
/// total is out of bounds, [InvalidRate], [InvalidWeights] (all payers or all
/// shares 0, or one negative), [UnknownMember], [DuplicateMember].
ConvertedExpense convertExpense({
  required int total,
  required String from,
  required String to,
  required String rate,
  required Map<String, int> paid,
  required Map<String, int> shares,
  required List<String> order,
}) {
  checkAmount(total);
  final index = fixedOrderIndex(order);
  checkKnownMembers(index, paid.keys);
  checkKnownMembers(index, shares.keys);
  final t = convert(total, from, to, rate);
  checkAmount(t);
  return ConvertedExpense(
    currency: to,
    total: t,
    paid: _reallocate(t, paid, order),
    shares: _reallocate(t, shares, order),
  );
}

/// Cross rate `from → to` from EUR-based rates (Frankfurter):
/// `eur[to] / eur[from]` rounded half away from zero to 10 decimals, as a
/// fixed-point string with exactly 10 decimals (`"89.6437142330"`). EUR itself
/// is 1. Throws [RateNotFound] for a missing currency, [InvalidRate] for a bad
/// stored rate.
String crossRate(Map<String, String> eurRates, String from, String to) {
  final a = _eurRate(eurRates, from);
  final b = _eurRate(eurRates, to);
  final q = b / a;
  final scaled = _roundHalfAway(q.numerator * _rateScale, q.denominator);
  final fraction = (scaled % _rateScale).toString().padLeft(rateDecimals, '0');
  return '${scaled ~/ _rateScale}.$fraction';
}

Decimal _eurRate(Map<String, String> eurRates, String code) {
  if (code == 'EUR') return Decimal.one;
  final rate = eurRates[code];
  if (rate == null) throw RateNotFound(code);
  return parseRate(rate);
}

Map<String, int> _reallocate(int total, Map<String, int> amounts, List<String> order) {
  final ids = [
    for (final m in order)
      if (amounts.containsKey(m)) m,
  ];
  final parts = allocateRatio(total, [for (final m in ids) amounts[m]!]);
  return Map.unmodifiable({for (var i = 0; i < ids.length; i++) ids[i]: parts[i]});
}

/// sign(n / d) × ⌊|n / d| + ½⌋ for d > 0, exactly: ⌊(2|n| + d) / 2d⌋ with the sign of n.
BigInt _roundHalfAway(BigInt numerator, BigInt denominator) {
  final two = BigInt.two;
  final magnitude = (numerator.abs() * two + denominator) ~/ (denominator * two);
  return numerator.isNegative ? -magnitude : magnitude;
}
