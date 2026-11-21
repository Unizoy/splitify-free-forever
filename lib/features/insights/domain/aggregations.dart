/// Spending aggregations for Insights (planning/08-feature-specs.md #33, phase 17 T1).
///
/// Pure Dart, integer minor units only. Spending is grouped per currency and never mixed
/// (money rule 4); the main-currency view uses only the conversion saved on each expense and
/// reports how many expenses had none. IOUs, payments and deleted expenses are not spending.
library;

import 'dart:collection';

/// `expenses.kind` of a loan (IOU); never counted as spending.
const String expenseKindIou = 'iou';

/// One expense as Insights sees it, built from the local expense row and its parts.
final class InsightExpense {
  const InsightExpense({
    required this.id,
    required this.category,
    required this.date,
    required this.currency,
    required this.total,
    this.kind = 'expense',
    this.owed = const {},
    this.deleted = false,
    this.fxCurrency,
    this.fxTotal,
    this.fxOwed,
  });

  final String id;

  /// `expense` or [expenseKindIou].
  final String kind;

  /// Category key, e.g. `food.dining`.
  final String category;

  /// ISO date `YYYY-MM-DD` (the `date` column).
  final String date;

  /// ISO 4217 code of [total] and [owed].
  final String currency;

  /// Expense total in minor units of [currency].
  final int total;

  /// Member id → owed minor units (`expense_parts.owed`).
  final Map<String, int> owed;

  /// `deleted_at` is set.
  final bool deleted;

  /// Saved conversion target (`fx_currency`), if any.
  final String? fxCurrency;

  /// Saved converted total (`fx_total`) in minor units of [fxCurrency].
  final int? fxTotal;

  /// Saved converted owed parts (`expense_parts.fx_owed`) by member id.
  final Map<String, int>? fxOwed;

  /// `YYYY-MM` of [date].
  String get monthKey => date.substring(0, 7);

  /// Counts as spending: not deleted and not an IOU.
  bool get isSpending => !deleted && kind != expenseKindIou;
}

/// Whose spending is counted.
sealed class InsightScope {
  const InsightScope();
}

/// The whole group: each expense counts with its total.
final class GroupScope extends InsightScope {
  const GroupScope();
}

/// "Me": only my shares. [myMemberIds] holds my member id in every group in the input.
final class MeScope extends InsightScope {
  const MeScope(this.myMemberIds);

  final Set<String> myMemberIds;
}

/// Spending of one category.
final class CategorySpend {
  const CategorySpend(this.category, this.minor);

  final String category;
  final int minor;

  @override
  bool operator ==(Object other) =>
      other is CategorySpend && other.category == category && other.minor == minor;

  @override
  int get hashCode => Object.hash(category, minor);

  @override
  String toString() => 'CategorySpend($category, $minor)';
}

/// Spending of one month (`YYYY-MM`).
final class MonthSpend {
  const MonthSpend(this.month, this.minor);

  final String month;
  final int minor;

  @override
  bool operator ==(Object other) =>
      other is MonthSpend && other.month == month && other.minor == minor;

  @override
  int get hashCode => Object.hash(month, minor);

  @override
  String toString() => 'MonthSpend($month, $minor)';
}

/// Spending in one currency.
final class SpendingSummary {
  const SpendingSummary({
    required this.currency,
    required this.total,
    required this.count,
    required this.byCategory,
    required this.byMonth,
  });

  final String currency;

  /// Sum of all included amounts.
  final int total;

  /// Number of expenses included.
  final int count;

  /// Largest first; ties by category key.
  final List<CategorySpend> byCategory;

  /// Months that have spending, oldest first.
  final List<MonthSpend> byMonth;

  /// The [count] months ending at [year]-[month], oldest first, with zero for months without
  /// spending (the month bars).
  List<MonthSpend> lastMonths({required int year, required int month, int count = 12}) {
    final known = {for (final m in byMonth) m.month: m.minor};
    final out = <MonthSpend>[];
    for (var i = count - 1; i >= 0; i--) {
      final index = year * 12 + (month - 1) - i;
      final key = monthKey(index ~/ 12, index % 12 + 1);
      out.add(MonthSpend(key, known[key] ?? 0));
    }
    return out;
  }
}

/// Spending in the main currency plus how many expenses could not be shown in it.
final class MainCurrencySpending {
  const MainCurrencySpending(this.summary, this.unconvertedCount);

  final SpendingSummary summary;

  /// Spending expenses in another currency without a saved conversion to the main currency.
  final int unconvertedCount;
}

/// `YYYY-MM` for [year] and [month] (1–12).
String monthKey(int year, int month) =>
    '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

/// Spending per currency, keyed and ordered by currency code. [categoryOf] maps a category key
/// to the bucket shown (default: the key itself, e.g. pass a parent lookup for top-level groups).
Map<String, SpendingSummary> spendingPerCurrency(
  Iterable<InsightExpense> expenses,
  InsightScope scope, {
  String Function(String category)? categoryOf,
}) {
  final builders = SplayTreeMap<String, _Builder>();
  for (final e in expenses) {
    if (!e.isSpending) continue;
    final minor = _amount(scope, e.total, e.owed);
    if (minor == 0) continue;
    builders.putIfAbsent(e.currency, () => _Builder(e.currency)).add(e, minor, categoryOf);
  }
  return {for (final entry in builders.entries) entry.key: entry.value.build()};
}

/// Spending in [mainCurrency]: expenses in it count as they are; others count with their saved
/// conversion to it (never recomputed); the rest are left out and counted.
MainCurrencySpending spendingInMainCurrency(
  Iterable<InsightExpense> expenses,
  InsightScope scope,
  String mainCurrency, {
  String Function(String category)? categoryOf,
}) {
  final builder = _Builder(mainCurrency);
  var unconverted = 0;
  for (final e in expenses) {
    if (!e.isSpending) continue;
    final minor = e.currency == mainCurrency
        ? _amount(scope, e.total, e.owed)
        : _converted(e, scope, mainCurrency);
    if (minor == null) {
      // Only expenses that would have counted are reported as left out.
      if (_amount(scope, e.total, e.owed) != 0) unconverted++;
    } else if (minor != 0) {
      builder.add(e, minor, categoryOf);
    }
  }
  return MainCurrencySpending(builder.build(), unconverted);
}

/// The saved conversion of [e] to [mainCurrency] for [scope], or null when there is none.
int? _converted(InsightExpense e, InsightScope scope, String mainCurrency) {
  final fxTotal = e.fxTotal;
  final fxOwed = e.fxOwed;
  if (e.fxCurrency != mainCurrency || fxTotal == null) return null;
  return switch (scope) {
    GroupScope() => fxTotal,
    MeScope() => fxOwed == null ? null : _amount(scope, fxTotal, fxOwed),
  };
}

int _amount(InsightScope scope, int total, Map<String, int> owed) => switch (scope) {
  GroupScope() => total,
  MeScope(:final myMemberIds) => myMemberIds.fold(0, (sum, id) => sum + (owed[id] ?? 0)),
};

final class _Builder {
  _Builder(this.currency);

  final String currency;
  final Map<String, int> _categories = {};
  final SplayTreeMap<String, int> _months = SplayTreeMap();
  int _total = 0;
  int _count = 0;

  void add(InsightExpense e, int minor, String Function(String)? categoryOf) {
    final category = categoryOf == null ? e.category : categoryOf(e.category);
    _categories[category] = (_categories[category] ?? 0) + minor;
    _months[e.monthKey] = (_months[e.monthKey] ?? 0) + minor;
    _total += minor;
    _count++;
  }

  SpendingSummary build() {
    final categories = [for (final c in _categories.entries) CategorySpend(c.key, c.value)]
      ..sort((a, b) {
        final byAmount = b.minor.compareTo(a.minor);
        return byAmount != 0 ? byAmount : a.category.compareTo(b.category);
      });
    return SpendingSummary(
      currency: currency,
      total: _total,
      count: _count,
      byCategory: List.unmodifiable(categories),
      byMonth: List.unmodifiable([for (final m in _months.entries) MonthSpend(m.key, m.value)]),
    );
  }
}
