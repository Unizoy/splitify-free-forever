import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/domain/rules/group_rules.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' show profileProvider;
import 'package:splitify/features/balances/application/balance_views.dart' show decodeMinorMap;
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/insights/domain/aggregations.dart';

/// Whose spending Insights shows (#33): a whole group, or my shares.
enum InsightsMode { group, me }

/// What the Insights screen asks for. [groupId] null means: Group mode → the default group, Me mode →
/// every group and friend.
typedef InsightsQuery = ({InsightsMode mode, String? groupId});

/// A group in the Insights picker.
class InsightsGroup {
  const InsightsGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.mainCurrency,
    this.archived = false,
  });

  final String id;
  final String name;
  final String type;
  final String mainCurrency;
  final bool archived;
}

/// Everything the Insights screen draws for one [InsightsQuery].
class InsightsView {
  const InsightsView({
    required this.mode,
    required this.groups,
    required this.currency,
    required this.spending,
    required this.months,
    required this.currentMonth,
    this.group,
    this.categoryTrends = const {},
    this.whoPaid = const [],
    this.memberNames = const {},
    this.meMemberId,
  });

  final InsightsMode mode;

  /// The group shown; null in Me mode across everything (or when there are no groups).
  final InsightsGroup? group;

  /// Groups to pick from (friend groups left out), open ones first, then by name.
  final List<InsightsGroup> groups;

  /// The main currency everything is shown in (rule 4: others only via saved conversions).
  final String currency;

  /// All-time spending in [currency] by top-level category, plus the left-out count.
  final MainCurrencySpending spending;

  /// The last 12 months, oldest first, ending with [currentMonth].
  final List<MonthSpend> months;

  /// `YYYY-MM` of today.
  final String currentMonth;

  /// Each top-level category's last 12 months in [currency] (D-034 "Category over time"), oldest first.
  final Map<String, List<MonthSpend>> categoryTrends;

  /// Group mode: each member's paid against share over the last 12 months (D-034 "Who paid"), in fixed
  /// member order; empty in Me mode.
  final List<MemberTrend> whoPaid;

  /// Member names of the group shown (removed members too).
  final Map<String, String> memberNames;

  /// My member id in the group shown, if any.
  final String? meMemberId;

  SpendingSummary get summary => spending.summary;

  /// Expenses in another currency without a saved conversion to [currency].
  int get unconverted => spending.unconvertedCount;

  /// Nothing to draw: no spending in [currency] at all.
  bool get isEmpty => summary.count == 0;
}

/// [InsightExpense]s of a ledger's live expenses (IOUs included; the aggregation drops them).
List<InsightExpense> insightInputsOf(GroupLedger ledger) => [
  for (final e in ledger.expenses) insightExpenseOf(e),
];

/// One live expense row as Insights sees it: owed parts from `shares`, the saved conversion from
/// `fx_currency` / `fx_total` / `fx_shares` (never recomputed, rule 4).
InsightExpense insightExpenseOf(LocalExpense e) => InsightExpense(
  id: e.id,
  kind: e.kind,
  category: e.category,
  date: e.date.length > 10 ? e.date.substring(0, 10) : e.date,
  currency: e.currency.trim(),
  total: e.total,
  owed: decodeMinorMap(e.shares),
  paid: decodeMinorMap(e.payers),
  deleted: e.deletedAt != null,
  fxCurrency: e.fxCurrency?.trim(),
  fxTotal: e.fxTotal,
  fxOwed: e.fxShares == null ? null : decodeMinorMap(e.fxShares!),
  fxPaid: e.fxPayers == null ? null : decodeMinorMap(e.fxPayers!),
);

/// My member id in [ledger] (linked to [userId], not removed), or null.
String? myMemberIdIn(GroupLedger ledger, String? userId) => userId == null
    ? null
    : ledger.members.where((m) => m.userId == userId && m.deletedAt == null).firstOrNull?.id;

/// Pickable groups of [ledgers]: friend groups left out, open first, then by name.
List<InsightsGroup> insightsGroupsOf(List<GroupLedger> ledgers) {
  final out = [
    for (final l in ledgers)
      if (!GroupRules.isHidden(l.group.type))
        InsightsGroup(
          id: l.group.id,
          name: l.group.name,
          type: l.group.type,
          mainCurrency: l.group.mainCurrency.trim(),
          archived: l.group.archivedAt != null,
        ),
  ];
  return out..sort((a, b) {
    if (a.archived != b.archived) return a.archived ? 1 : -1;
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });
}

/// The group Group mode opens on: [wanted] when it is pickable, else the open group with the newest
/// expense, else the first one.
InsightsGroup? defaultInsightsGroup(
  List<GroupLedger> ledgers,
  List<InsightsGroup> groups,
  String? wanted,
) {
  if (groups.isEmpty) return null;
  final match = groups.where((g) => g.id == wanted).firstOrNull;
  if (match != null) return match;
  String newest(String id) {
    final l = ledgers.firstWhere((l) => l.group.id == id);
    return l.expenses.isEmpty ? '' : l.expenses.map((e) => e.date).reduce(_max);
  }

  final open = groups.where((g) => !g.archived).toList();
  final pool = open.isEmpty ? groups : open;
  var best = pool.first;
  var bestDate = newest(best.id);
  for (final g in pool.skip(1)) {
    final d = newest(g.id);
    if (d.compareTo(bestDate) > 0) {
      best = g;
      bestDate = d;
    }
  }
  return best;
}

String _max(String a, String b) => a.compareTo(b) >= 0 ? a : b;

/// The Insights numbers for [query] (#33): Group mode = the group's totals in its main currency;
/// Me mode = my shares, in the picked group's main currency, or across every group and friend in
/// [defaultCurrency]. Categories are top-level (`food`, `travel`, …); IOUs, payments and deleted
/// expenses are not spending.
InsightsView insightsViewOf(
  List<GroupLedger> ledgers,
  InsightsQuery query, {
  required String? userId,
  required String defaultCurrency,
  required DateTime today,
}) {
  final groups = insightsGroupsOf(ledgers);
  final InsightsGroup? group;
  if (query.mode == InsightsMode.group) {
    group = defaultInsightsGroup(ledgers, groups, query.groupId);
  } else {
    group = groups.where((g) => g.id == query.groupId).firstOrNull;
  }
  final picked = group == null
      ? (query.mode == InsightsMode.group ? const <GroupLedger>[] : ledgers)
      : ledgers.where((l) => l.group.id == group!.id).toList();
  final currency = group?.mainCurrency ?? defaultCurrency;
  final InsightScope scope = query.mode == InsightsMode.group
      ? const GroupScope()
      : MeScope({
          for (final l in picked)
            if (myMemberIdIn(l, userId) case final id?) id,
        });
  final inputs = [for (final l in picked) ...insightInputsOf(l)];
  final spending = spendingInMainCurrency(
    inputs,
    scope,
    currency,
    categoryOf: ExpenseCategories.parentOf,
  );
  final groupLedger = group == null || query.mode != InsightsMode.group ? null : picked.firstOrNull;
  return InsightsView(
    mode: query.mode,
    group: group,
    groups: groups,
    currency: currency,
    spending: spending,
    months: spending.summary.lastMonths(year: today.year, month: today.month),
    currentMonth: monthKey(today.year, today.month),
    categoryTrends: categoryTrends(
      inputs,
      scope,
      currency,
      categoryOf: ExpenseCategories.parentOf,
      year: today.year,
      month: today.month,
    ),
    whoPaid: groupLedger == null
        ? const []
        : paidShareMonths(
            inputs,
            currency,
            order: [for (final m in groupLedger.members) m.id],
            year: today.year,
            month: today.month,
          ),
    memberNames: {
      for (final l in picked)
        for (final m in l.members) m.id: m.displayName,
    },
    meMemberId: groupLedger == null ? null : myMemberIdIn(groupLedger, userId),
  );
}

/// The Insights screen's data from the phone's database (works offline; rule 3).
final insightsProvider = Provider.autoDispose.family<AsyncValue<InsightsView>, InsightsQuery>((
  ref,
  query,
) {
  final uid = ref.watch(currentUserIdProvider);
  // Expense dates are local calendar dates, so the current month is the local one.
  final today = ref.watch(clockProvider).now().toLocal();
  final currency = ref.watch(profileProvider).value?.defaultCurrency ?? 'INR';
  return ref
      .watch(allLedgersProvider)
      .whenData(
        (ls) => insightsViewOf(ls, query, userId: uid, defaultCurrency: currency, today: today),
      );
});
