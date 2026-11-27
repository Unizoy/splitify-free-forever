import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/features/balances/application/balances_providers.dart'
    show allLedgersProvider;
import 'package:splitify/features/insights/application/insights_providers.dart'
    show insightInputsOf;
import 'package:splitify/features/insights/domain/aggregations.dart';

/// One expense page's category trend (D-034 A6): the group's spending on the expense's top-level
/// category over the last three months, in the group's main currency (saved conversions only, rule 4).
typedef CategoryTrend = ({
  String currency,
  String category,
  String groupName,
  List<MonthSpend> months,
});

/// Which trend: the group and the expense's category key.
typedef CategoryTrendQuery = ({String groupId, String category});

/// The trend for [q] from the [ledgers] on this phone, ending with [today]'s month; null when the group
/// is not there or nothing was spent on the category in those months.
CategoryTrend? categoryTrendOf(List<GroupLedger> ledgers, CategoryTrendQuery q, DateTime today) {
  final ledger = ledgers.where((l) => l.group.id == q.groupId).firstOrNull;
  if (ledger == null) return null;
  final parent = ExpenseCategories.parentOf(q.category);
  final currency = ledger.group.mainCurrency.trim();
  final inputs = [
    for (final e in insightInputsOf(ledger))
      if (ExpenseCategories.parentOf(e.category) == parent) e,
  ];
  final spending = spendingInMainCurrency(
    inputs,
    const GroupScope(),
    currency,
    categoryOf: ExpenseCategories.parentOf,
  );
  final months = spending.summary.lastMonths(year: today.year, month: today.month, count: 3);
  if (months.every((m) => m.minor == 0)) return null;
  return (currency: currency, category: parent, groupName: ledger.group.name, months: months);
}

/// Read-only from the ledgers Insights uses (works offline).
final categoryTrendProvider = Provider.autoDispose.family<CategoryTrend?, CategoryTrendQuery>((
  ref,
  q,
) {
  final ledgers = ref.watch(allLedgersProvider).value;
  if (ledgers == null) return null;
  final today = ref.watch(clockProvider).now().toLocal();
  return categoryTrendOf(ledgers, q, today);
});
