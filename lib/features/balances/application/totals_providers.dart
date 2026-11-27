import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/time/clock.dart' show LocalToday;
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/domain/group_totals.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';

/// The Totals tab (#21): this month's and all-time totals per currency, with the names to show.
class GroupTotalsView {
  const GroupTotalsView({
    required this.mainCurrency,
    required this.members,
    required this.month,
    required this.allTime,
    this.meId,
  });

  final String mainCurrency;

  /// Every member in fixed order.
  final List<LocalMember> members;
  final String? meId;

  /// Totals per currency: the current calendar month / all time.
  final Map<String, CurrencyTotals> month;
  final Map<String, CurrencyTotals> allTime;

  String nameOf(String id) => members.where((m) => m.id == id).firstOrNull?.displayName ?? '';
}

/// Totals inputs of a ledger's live expenses.
List<TotalsExpense> totalsInputs(GroupLedger l) => [
  for (final e in l.expenses)
    TotalsExpense(
      currency: e.currency.trim(),
      total: e.total,
      date: e.date,
      kind: e.kind,
      paid: decodeMinorMap(e.payers),
      shares: decodeMinorMap(e.shares),
    ),
];

GroupTotalsView groupTotalsOf(GroupLedger l, String? userId, DateTime today) {
  final inputs = totalsInputs(l);
  return GroupTotalsView(
    mainCurrency: l.group.mainCurrency.trim(),
    members: l.members,
    meId: groupBalancesOf(l, userId).meId,
    month: groupTotals(inputs, month: monthKeyOf(today)),
    allTime: groupTotals(inputs),
  );
}

final groupTotalsProvider = Provider.autoDispose.family<AsyncValue<GroupTotalsView?>, String>((
  ref,
  groupId,
) {
  final uid = ref.watch(currentUserIdProvider);
  final today = ref.watch(clockProvider).today(); // this month = the phone's month (S-413)
  return ref
      .watch(groupLedgerProvider(groupId))
      .whenData((l) => l == null ? null : groupTotalsOf(l, uid, today));
});
