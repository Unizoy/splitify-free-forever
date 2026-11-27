import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/time/clock.dart' show LocalToday;
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' show profileProvider;
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/domain/group_totals.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/insights/domain/aggregations.dart' show expenseKindIou;

/// The Account tab's cards ("Your spending", "Your stats"), from the phone's database.
class AccountStats {
  const AccountStats({
    required this.currency,
    required this.spentThisMonth,
    required this.groups,
    required this.people,
    required this.expenses,
  });

  /// The person's default currency; other currencies are not added in (rule 4).
  final String currency;

  /// My shares of this month's spending in [currency] (IOUs left out).
  final int spentThisMonth;

  /// Open (not archived) groups I am in, friend groups left out.
  final int groups;

  /// Other people I share a group with (linked accounts counted once).
  final int people;

  /// Live expenses I added.
  final int expenses;
}

AccountStats accountStatsOf(
  List<GroupLedger> ledgers,
  String? userId,
  DateTime today,
  String currency,
) {
  final month = monthKeyOf(today);
  var spent = 0;
  var groups = 0;
  var expenses = 0;
  final people = <String>{};
  for (final l in ledgers) {
    final me = groupBalancesOf(l, userId).meId;
    if (me == null) continue;
    if (l.group.archivedAt == null && l.group.type != 'direct') groups++;
    for (final m in l.members) {
      if (m.id == me || m.deletedAt != null || m.status != 'active') continue;
      people.add(m.userId != null ? 'u:${m.userId}' : 'm:${m.id}');
    }
    for (final e in l.expenses) {
      if (e.createdBy == userId || (e.createdBy == null && e.seq == 0)) expenses++;
      if (e.kind == expenseKindIou || e.currency.trim() != currency) continue;
      if (!e.date.startsWith(month)) continue;
      spent += decodeMinorMap(e.shares)[me] ?? 0;
    }
  }
  return AccountStats(
    currency: currency,
    spentThisMonth: spent,
    groups: groups,
    people: people.length,
    expenses: expenses,
  );
}

final accountStatsProvider = Provider.autoDispose<AsyncValue<AccountStats>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final today = ref.watch(clockProvider).today(); // this month = the phone's month (S-413)
  final currency = ref.watch(profileProvider).value?.defaultCurrency ?? 'INR';
  return ref.watch(allLedgersProvider).whenData((ls) => accountStatsOf(ls, uid, today, currency));
});
