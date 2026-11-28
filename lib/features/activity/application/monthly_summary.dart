import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/time/clock.dart' show LocalToday;
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/domain/group_totals.dart' show monthKeyOf;
import 'package:splitify/features/groups/application/groups_providers.dart'
    show currentUserIdProvider;
import 'package:splitify/features/insights/domain/aggregations.dart' show expenseKindIou;

final _log = Logger('monthly-summary');

/// The card at the top of Activity in the first days of a month (F14, W2-Y, S-434): what I spent last
/// month (my shares, per currency, IOUs left out) across how many groups, and my balances now. From the
/// phone's database, so it works offline; marked "not synced yet" while anything is pending (rule 3).
final class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.spent,
    required this.groups,
    required this.balances,
    this.unsynced = false,
  });

  /// The first day of the month it is about (last month).
  final DateTime month;

  /// Currency → my shares last month (minor units, > 0), never mixed (rule 4).
  final Map<String, int> spent;

  /// Groups where I had a share last month.
  final int groups;

  /// Currency → my net over every group now (positive = I'm owed); zero balances left out.
  final Map<String, int> balances;

  final bool unsynced;

  /// `YYYY-MM` of [month].
  String get key => monthKeyOf(month);
}

/// Days at the start of a month when the card shows.
const monthSummaryDays = 7;

/// Last month's summary on [today] (the phone's day), or null after the first [monthSummaryDays] days or when
/// I had no share in anything last month.
MonthSummary? monthSummaryOf({
  required List<GroupLedger> ledgers,
  required String? userId,
  required DateTime today,
  required MyBalances balances,
}) {
  if (today.day > monthSummaryDays) return null;
  final month = DateTime(today.year, today.month - 1);
  final key = monthKeyOf(month);
  final spent = <String, int>{};
  var groups = 0;
  for (final l in ledgers) {
    if (l.group.deletedAt != null) continue;
    final me = groupBalancesOf(l, userId).meId;
    if (me == null) continue;
    var any = false;
    for (final e in l.expenses) {
      if (e.kind == expenseKindIou || !e.date.startsWith(key)) continue;
      final share = decodeMinorMap(e.shares)[me] ?? 0;
      if (share <= 0) continue;
      final currency = e.currency.trim();
      spent[currency] = (spent[currency] ?? 0) + share;
      any = true;
    }
    if (any) groups++;
  }
  if (spent.isEmpty) return null;
  return MonthSummary(
    month: month,
    spent: spent,
    groups: groups,
    balances: {
      for (final e in balances.totals.entries)
        if (e.value != 0) e.key: e.value,
    },
    unsynced: balances.unsynced,
  );
}

/// The month whose card the person hid ("Hide until next month"), kept on this phone.
class HiddenMonthSummary extends Notifier<String?> {
  static const storageKey = 'w2y.monthSummaryHidden';

  @override
  String? build() {
    try {
      return ref.watch(sharedPreferencesProvider).getString(storageKey);
    } on Object catch (e) {
      // No preferences (widget tests, a broken store): the card simply shows.
      _log.fine('hidden month unavailable: ${e.runtimeType}');
      return null;
    }
  }

  Future<void> hide(String monthKey) async {
    state = monthKey;
    try {
      await ref.read(sharedPreferencesProvider).setString(storageKey, monthKey);
    } on Object catch (e) {
      _log.fine('hidden month not saved: ${e.runtimeType}');
    }
  }
}

final hiddenMonthSummaryProvider = NotifierProvider<HiddenMonthSummary, String?>(
  HiddenMonthSummary.new,
);

/// The card's data, or null when it doesn't show (later in the month, nothing spent, hidden).
final monthSummaryProvider = Provider.autoDispose<MonthSummary?>((ref) {
  final ledgers = ref.watch(allLedgersProvider).value;
  final balances = ref.watch(myBalancesProvider).value;
  if (ledgers == null || balances == null) return null;
  final summary = monthSummaryOf(
    ledgers: ledgers,
    userId: ref.watch(currentUserIdProvider),
    today: ref.watch(clockProvider).today(),
    balances: balances,
  );
  if (summary == null || ref.watch(hiddenMonthSummaryProvider) == summary.key) return null;
  return summary;
});
