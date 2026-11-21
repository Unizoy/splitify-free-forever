/// Group totals (#21): what a group spent, per currency, and what each person paid and owes of it.
///
/// Pure Dart, integer minor units. IOUs (loans) and payments are not spending, so they never count
/// (TC-21-01); payments live in their own table and are simply not passed in. Currencies are never
/// added together (rule 4).
library;

import 'package:splitify/features/insights/domain/aggregations.dart' show expenseKindIou;

/// One live expense as the totals see it.
final class TotalsExpense {
  const TotalsExpense({
    required this.currency,
    required this.total,
    required this.date,
    this.paid = const {},
    this.shares = const {},
    this.kind = 'expense',
  });

  final String currency;
  final int total;

  /// ISO date `YYYY-MM-DD`.
  final String date;

  /// Member id → minor units paid / owed.
  final Map<String, int> paid;
  final Map<String, int> shares;

  /// `expense` or `iou`.
  final String kind;

  bool get isSpending => kind != expenseKindIou;
}

/// Totals of one currency.
final class CurrencyTotals {
  const CurrencyTotals({
    required this.currency,
    required this.spent,
    required this.count,
    required this.paid,
    required this.shares,
  });

  final String currency;

  /// Σ expense totals (minor units).
  final int spent;

  /// Number of expenses counted.
  final int count;

  /// Member id → Σ paid / Σ share; members with neither are left out.
  final Map<String, int> paid;
  final Map<String, int> shares;
}

/// Totals per currency (keys in alphabetical order) of the spending in [expenses]; with [month]
/// (`YYYY-MM`) only expenses dated in that month count.
Map<String, CurrencyTotals> groupTotals(List<TotalsExpense> expenses, {String? month}) {
  final spent = <String, int>{};
  final count = <String, int>{};
  final paid = <String, Map<String, int>>{};
  final shares = <String, Map<String, int>>{};
  for (final e in expenses) {
    if (!e.isSpending) continue;
    if (month != null && !e.date.startsWith(month)) continue;
    final c = e.currency;
    spent[c] = (spent[c] ?? 0) + e.total;
    count[c] = (count[c] ?? 0) + 1;
    final p = paid.putIfAbsent(c, () => {});
    final s = shares.putIfAbsent(c, () => {});
    e.paid.forEach((m, v) {
      if (v != 0) p[m] = (p[m] ?? 0) + v;
    });
    e.shares.forEach((m, v) {
      if (v != 0) s[m] = (s[m] ?? 0) + v;
    });
  }
  final codes = spent.keys.toList()..sort();
  return {
    for (final c in codes)
      c: CurrencyTotals(
        currency: c,
        spent: spent[c]!,
        count: count[c]!,
        paid: Map.unmodifiable(paid[c]!),
        shares: Map.unmodifiable(shares[c]!),
      ),
  };
}

/// `YYYY-MM` of a local date.
String monthKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
