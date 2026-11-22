/// Group balances "in the main currency" (planning/05-money-engine.md §6, #32, phase 14 T5/T6).
///
/// Every record in another currency counts only through its saved conversion to the main currency (rule 4:
/// saved rates, never recalculated). While any such record has no saved conversion the view has no balances,
/// just the list of records to convert. Simplify "after converting" runs on these converted nets.
library;

import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/money/money_error.dart' show MoneyError;
import 'package:splitify/features/currency/domain/conversion.dart' show fullOrder;

/// One live expense or payment of a group, as the converted view needs it (no Drift types, S-090 style).
final class FxRecord {
  /// An expense: [paid]/[shares] in [currency], and its saved conversion if any.
  const FxRecord.expense({
    required this.id,
    required this.date,
    required this.currency,
    required this.amount,
    required Map<String, int> this.paid,
    required Map<String, int> this.shares,
    this.description = '',
    this.fxCurrency,
    this.fxAmount,
    Map<String, int>? this.fxPaid,
    Map<String, int>? this.fxShares,
  }) : from = null,
       to = null;

  /// A payment [from] → [to] of [amount], and its saved conversion if any.
  const FxRecord.payment({
    required this.id,
    required this.date,
    required this.currency,
    required this.amount,
    required String this.from,
    required String this.to,
    this.fxCurrency,
    this.fxAmount,
  }) : paid = null,
       shares = null,
       fxPaid = null,
       fxShares = null,
       description = '';

  final String id;

  /// `YYYY-MM-DD`.
  final String date;
  final String currency;

  /// Expense total or payment amount (minor units of [currency]).
  final int amount;
  final String description;

  final Map<String, int>? paid;
  final Map<String, int>? shares;
  final String? from;
  final String? to;

  /// Saved conversion: target currency and converted total/amount (+ parts for expenses).
  final String? fxCurrency;
  final int? fxAmount;
  final Map<String, int>? fxPaid;
  final Map<String, int>? fxShares;

  bool get isPayment => from != null;

  /// True when this record counts in [main] as it is or through a saved conversion to [main].
  bool countsIn(String main) =>
      currency == main ||
      (fxCurrency == main &&
          fxAmount != null &&
          (isPayment || (fxPaid != null && fxShares != null)));
}

/// The converted view of one group.
final class ConvertedBalances {
  const ConvertedBalances({required this.currency, required this.missing, this.balances});

  /// The main currency everything is shown in.
  final String currency;

  /// Records in another currency without a saved conversion to [currency], newest first.
  final List<FxRecord> missing;

  /// Nets, pairs and simplified transfers in [currency]; null while [missing] is not empty (or the
  /// records could not be combined).
  final Balances? balances;

  bool get complete => missing.isEmpty && balances != null;
}

/// The group's balances in [main] from [records] (member fixed [order]; unknown ids are appended).
ConvertedBalances convertedBalances(String main, List<String> order, List<FxRecord> records) {
  final missing = [
    for (final r in records)
      if (!r.countsIn(main)) r,
  ]..sort((a, b) => b.date.compareTo(a.date));
  if (missing.isNotEmpty) return ConvertedBalances(currency: main, missing: missing);

  final flows = <ExpenseFlow>[];
  final payments = <Payment>[];
  for (final r in records) {
    final native = r.currency == main;
    if (r.isPayment) {
      final amount = native ? r.amount : r.fxAmount!;
      if (r.from != r.to && amount > 0) {
        payments.add(Payment(currency: main, from: r.from!, to: r.to!, amount: amount));
      }
    } else {
      flows.add(
        ExpenseFlow(
          currency: main,
          paid: native ? r.paid! : r.fxPaid!,
          shares: native ? r.shares! : r.fxShares!,
        ),
      );
    }
  }
  final ids = [
    for (final f in flows) ...[...f.paid.keys, ...f.shares.keys],
    for (final p in payments) ...[p.from, p.to],
  ];
  try {
    return ConvertedBalances(
      currency: main,
      missing: const [],
      balances: Balances.compute(fullOrder(order, ids), flows, payments),
    );
  } on MoneyError {
    return ConvertedBalances(currency: main, missing: const []);
  }
}
