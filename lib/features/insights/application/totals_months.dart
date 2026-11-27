import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/application/totals_providers.dart' show totalsInputs;
import 'package:splitify/features/balances/domain/group_totals.dart';

/// A group's totals for any month (D-034 WP-D, F13): the Totals tab's ‹ › month view.
final class TotalsMonths {
  TotalsMonths(List<TotalsExpense> inputs)
    : _inputs = List.unmodifiable(inputs),
      months = List.unmodifiable(
        {
          for (final e in inputs)
            if (e.isSpending && e.date.length >= 7) e.date.substring(0, 7),
        }.toList()..sort(),
      );

  final List<TotalsExpense> _inputs;

  /// Months (`YYYY-MM`) with spending, oldest first.
  final List<String> months;

  final _cache = <String, Map<String, CurrencyTotals>>{};

  /// Totals per currency of [month] (the same numbers as the tab's "This month" for today's month).
  Map<String, CurrencyTotals> of(String month) =>
      _cache.putIfAbsent(month, () => groupTotals(_inputs, month: month));
}

/// [TotalsMonths] of a group from the phone's database; null while the group is not on this phone.
final totalsMonthsProvider = Provider.autoDispose.family<AsyncValue<TotalsMonths?>, String>(
  (ref, groupId) => ref
      .watch(groupLedgerProvider(groupId))
      .whenData((l) => l == null ? null : TotalsMonths(totalsInputs(l))),
);
