/// Saved conversions of expenses and payments (planning/05-money-engine.md §6, phase 14 T5).
///
/// A conversion is saved with the record: rate, rate date, source, target currency and the converted
/// amounts (total + parts re-allocated by the money engine, so they still sum). Saved rates are never
/// recalculated: an edit that keeps the currency keeps the rate and re-converts the new amounts with it; a new
/// currency drops the conversion (S-151).
library;

import 'package:splitify/core/money/fx.dart';
import 'package:splitify/core/money/money.dart' show checkAmount;
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/domain/rules/recurrence.dart' show formatIsoDate, parseIsoDate;
import 'package:splitify/features/currency/domain/fx_service.dart';

/// The fx columns of a record as stored (`fx_rate`, `fx_rate_date`, `fx_source`, `fx_currency` and
/// `fx_total` / `fx_amount`).
final class SavedFx {
  const SavedFx({
    required this.rate,
    required this.rateDate,
    required this.source,
    required this.currency,
    required this.total,
  });

  /// Null unless every column is set and readable (a half-saved conversion counts as none).
  static SavedFx? tryRead({
    required String? rate,
    required String? rateDate,
    required String? source,
    required String? currency,
    required int? total,
  }) {
    if (rate == null || rateDate == null || source == null || currency == null || total == null) {
      return null;
    }
    final DateTime date;
    try {
      parseRate(rate);
      date = parseIsoDate(rateDate.length > 10 ? rateDate.substring(0, 10) : rateDate);
    } on Exception {
      return null;
    }
    return SavedFx(
      rate: rate,
      rateDate: date,
      source: source == FxSource.manual.code ? FxSource.manual : FxSource.frankfurter,
      currency: currency.trim(),
      total: total,
    );
  }

  /// Major units of [currency] per major unit of the record's currency.
  final String rate;

  /// Date-only UTC.
  final DateTime rateDate;
  final FxSource source;

  /// The target currency.
  final String currency;

  /// Converted total (expense) or amount (payment), minor units of [currency].
  final int total;

  /// The same rate as an [FxRate] for a record in [from].
  FxRate asRate(String from) => FxRate(
    from: from,
    to: currency,
    rate: rate,
    effectiveDate: rateDate,
    source: source,
    isFallback: false,
  );
}

/// Columns that remove an expense's conversion.
const Map<String, Object?> clearedExpenseFx = {
  'fx_rate': null,
  'fx_rate_date': null,
  'fx_source': null,
  'fx_currency': null,
  'fx_total': null,
  'fx_payers': null,
  'fx_shares': null,
};

/// Columns that remove a payment's conversion.
const Map<String, Object?> clearedPaymentFx = {
  'fx_rate': null,
  'fx_rate_date': null,
  'fx_source': null,
  'fx_currency': null,
  'fx_amount': null,
};

/// fx columns of an expense converted at [rate] (`rate.from` must be the expense currency): the total
/// with `convert`, payers and shares re-allocated by [convertExpense] in fixed [order]. Throws the money
/// engine's errors ([AmountTooLarge] when the converted total does not fit, [InvalidRate], …).
Map<String, Object?> expenseFxColumns({
  required int total,
  required Map<String, int> paid,
  required Map<String, int> shares,
  required List<String> order,
  required FxRate rate,
}) {
  final c = convertExpense(
    total: total,
    from: rate.from,
    to: rate.to,
    rate: rate.rate,
    paid: paid,
    shares: shares,
    order: fullOrder(order, [...paid.keys, ...shares.keys]),
  );
  return {
    'fx_rate': rate.rate,
    'fx_rate_date': formatIsoDate(rate.effectiveDate),
    'fx_source': rate.source.code,
    'fx_currency': rate.to,
    'fx_total': c.total,
    'fx_payers': c.paid,
    'fx_shares': c.shares,
  };
}

/// fx columns of a payment of [amount] converted at [rate]. Throws [AmountTooLarge] when the converted
/// amount is out of bounds, [InvalidRate].
Map<String, Object?> paymentFxColumns({required int amount, required FxRate rate}) {
  final converted = convert(amount, rate.from, rate.to, rate.rate);
  checkAmount(converted);
  return {
    'fx_rate': rate.rate,
    'fx_rate_date': formatIsoDate(rate.effectiveDate),
    'fx_source': rate.source.code,
    'fx_currency': rate.to,
    'fx_amount': converted,
  };
}

/// fx columns to save with an edited expense (S-151): none when it had no conversion; cleared when the
/// currency changed (or became the target currency) or the new amounts can't be converted; otherwise the
/// saved rate applied to the new total and parts.
Map<String, Object?> expenseFxAfterEdit({
  required SavedFx? saved,
  required String oldCurrency,
  required String currency,
  required int total,
  required Map<String, int> paid,
  required Map<String, int> shares,
  required List<String> order,
}) {
  if (saved == null) return const {};
  if (currency != oldCurrency || currency == saved.currency) return clearedExpenseFx;
  try {
    return expenseFxColumns(
      total: total,
      paid: paid,
      shares: shares,
      order: order,
      rate: saved.asRate(currency),
    );
  } on MoneyError {
    return clearedExpenseFx;
  }
}

/// fx columns to save with an edited payment (same rules as [expenseFxAfterEdit]).
Map<String, Object?> paymentFxAfterEdit({
  required SavedFx? saved,
  required String oldCurrency,
  required String currency,
  required int amount,
}) {
  if (saved == null) return const {};
  if (currency != oldCurrency || currency == saved.currency) return clearedPaymentFx;
  try {
    return paymentFxColumns(amount: amount, rate: saved.asRate(currency));
  } on MoneyError {
    return clearedPaymentFx;
  }
}

/// [order] followed by any of [ids] it lacks (sorted), so every member of a record has a fixed place.
List<String> fullOrder(List<String> order, Iterable<String> ids) {
  final known = order.toSet();
  final extra = {
    for (final id in ids)
      if (!known.contains(id)) id,
  }.toList()..sort();
  return [...order, ...extra];
}
