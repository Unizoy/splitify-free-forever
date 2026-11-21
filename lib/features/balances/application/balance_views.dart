import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/money/money_error.dart' show MoneyError;
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';

final _log = Logger('balances');

/// Which way a set of nets points for the viewer.
enum BalanceStatus { owed, owe, settled, mixed }

/// Status of [nets] (one per currency): all ≥ 0 with some > 0 = owed, all ≤ 0 with some < 0 = owe,
/// all 0 = settled, both signs = mixed (currencies are never added together).
BalanceStatus balanceStatusOf(Iterable<int> nets) {
  final pos = nets.any((v) => v > 0);
  final neg = nets.any((v) => v < 0);
  if (pos && neg) return BalanceStatus.mixed;
  if (pos) return BalanceStatus.owed;
  if (neg) return BalanceStatus.owe;
  return BalanceStatus.settled;
}

/// [codes] with [first] in front (when present), the rest alphabetical.
List<String> orderCurrencies(Iterable<String> codes, String first) {
  final rest = codes.where((c) => c != first).toSet().toList()..sort();
  return [if (codes.contains(first)) first, ...rest];
}

/// `{"member": minor}` JSON of an expense's payers/shares.
Map<String, int> decodeMinorMap(String json) {
  final m = jsonDecode(json) as Map<String, Object?>;
  return {for (final e in m.entries) e.key: (e.value! as num).toInt()};
}

/// One group's balances as the screens show them (05 §5): per currency nets, original pairs and
/// simplified transfers, plus who "me" is and whether the numbers include unsynced rows.
class GroupBalances {
  const GroupBalances({
    required this.groupId,
    required this.groupName,
    required this.mainCurrency,
    required this.members,
    required this.byCurrency,
    this.simplify = false,
    this.meId,
    this.hasRecords = false,
    this.unsynced = false,
    this.fromServer = false,
  });

  final String groupId;
  final String groupName;
  final String mainCurrency;

  /// Every member in fixed order (removed ones too).
  final List<LocalMember> members;

  /// Balances per currency code.
  final Map<String, Balances> byCurrency;

  /// The group shows simplified transfers (#17, rule 12).
  final bool simplify;

  /// The viewer's member id here, if they are an active member.
  final String? meId;

  /// The group has at least one live expense or payment.
  final bool hasRecords;

  /// Computed from rows not on the server yet ("not synced yet").
  final bool unsynced;

  /// The server's answer replaced the local one (they differed: the server wins, rule 3).
  final bool fromServer;

  /// Currencies with records: the group's main currency first, then alphabetical.
  List<String> get currencies => orderCurrencies(byCurrency.keys, mainCurrency);

  LocalMember? member(String id) => members.where((m) => m.id == id).firstOrNull;

  String nameOf(String id) => member(id)?.displayName ?? '';

  /// Transfers the screen shows in [currency]: simplified when simplify is on, else the pairs.
  List<Transfer> shown(String currency, {bool? simplified}) =>
      byCurrency[currency]?.shown(simplify: simplified ?? simplify) ?? const [];

  /// My non-zero net per currency, main currency first.
  Map<String, int> get myNets {
    final me = meId;
    if (me == null) return const {};
    return {
      for (final c in currencies)
        if ((byCurrency[c]!.nets[me] ?? 0) != 0) c: byCurrency[c]!.nets[me]!,
    };
  }

  /// Every net is 0 in every currency.
  bool get allSettled => byCurrency.values.every((b) => b.nets.values.every((v) => v == 0));

  /// What [from] owes [to] in [currency] as the screen shows it (0 when nothing).
  int owed(String from, String to, String currency) =>
      shown(currency).where((t) => t.from == from && t.to == to).fold(0, (a, t) => a + t.amount);

  GroupBalances copyWith({bool? unsynced}) => GroupBalances(
    groupId: groupId,
    groupName: groupName,
    mainCurrency: mainCurrency,
    members: members,
    byCurrency: byCurrency,
    simplify: simplify,
    meId: meId,
    hasRecords: hasRecords,
    unsynced: unsynced ?? this.unsynced,
    fromServer: fromServer,
  );

  /// The same view with the server's numbers.
  GroupBalances withServer(ServerGroupBalances s) => GroupBalances(
    groupId: groupId,
    groupName: groupName,
    mainCurrency: mainCurrency,
    members: members,
    byCurrency: s.currencies,
    simplify: simplify,
    meId: meId,
    hasRecords: hasRecords || s.currencies.isNotEmpty,
    unsynced: unsynced,
    fromServer: true,
  );
}

/// Local balances of [ledger] (rule 3: instant and offline; the server check confirms them). Rows
/// naming a member this phone does not have yet put that id after everyone else.
GroupBalances groupBalancesOf(GroupLedger ledger, String? userId) {
  final order = [for (final m in ledger.members) m.id];
  final flows = [
    for (final e in ledger.expenses)
      ExpenseFlow(
        currency: e.currency,
        paid: decodeMinorMap(e.payers),
        shares: decodeMinorMap(e.shares),
      ),
  ];
  final payments = [
    for (final p in ledger.payments)
      if (p.fromMember != p.toMember && p.amount > 0)
        Payment(currency: p.currency, from: p.fromMember, to: p.toMember, amount: p.amount),
  ];
  final known = order.toSet();
  final extra = {
    for (final f in flows) ...[...f.paid.keys, ...f.shares.keys],
    for (final p in payments) ...[p.from, p.to],
  }.difference(known).toList()..sort();
  var byCurrency = const <String, Balances>{};
  try {
    byCurrency = balancesByCurrency([...order, ...extra], flows, payments);
  } on MoneyError catch (e) {
    _log.warning('group ${ledger.group.id}: local balances failed: ${e.runtimeType}');
  }
  final meId = ledger.members
      .where(
        (m) => userId != null && m.userId == userId && m.status == 'active' && m.deletedAt == null,
      )
      .map((m) => m.id)
      .firstOrNull;
  return GroupBalances(
    groupId: ledger.group.id,
    groupName: ledger.group.name,
    mainCurrency: ledger.group.mainCurrency.trim(),
    members: ledger.members,
    byCurrency: byCurrency,
    simplify: ledger.group.simplifyDebts,
    meId: meId,
    hasRecords: ledger.expenses.isNotEmpty || ledger.payments.isNotEmpty,
  );
}

/// One person I share money with, across groups (key `u:<user id>` or `m:<member id>` for name-only).
class PersonBalance {
  const PersonBalance({
    required this.key,
    required this.name,
    required this.seed,
    required this.balances,
  });

  final String key;
  final String name;

  /// Avatar seed (member or user id).
  final String seed;

  /// Currency → minor units; positive = they owe me.
  final Map<String, int> balances;
}

/// My overall balance (Groups home glass card, Account wallet): per currency, per group, per person.
class MyBalances {
  const MyBalances({
    required this.totals,
    required this.byGroup,
    required this.people,
    this.unsynced = false,
    this.fromServer = false,
  });

  /// Currency → my non-zero net over every group.
  final Map<String, int> totals;

  /// Group id → currency → my non-zero net there.
  final Map<String, Map<String, int>> byGroup;

  final List<PersonBalance> people;

  /// Includes rows not on the server yet.
  final bool unsynced;

  /// The server's answer replaced the local one.
  final bool fromServer;

  BalanceStatus get status => balanceStatusOf(totals.values);

  /// People who owe me something / whom I owe something.
  int get peopleOwingMe => people.where((p) => p.balances.values.any((v) => v > 0)).length;
  int get peopleIOwe => people.where((p) => p.balances.values.any((v) => v < 0)).length;

  MyBalances copyWith({bool? unsynced}) => MyBalances(
    totals: totals,
    byGroup: byGroup,
    people: people,
    unsynced: unsynced ?? this.unsynced,
    fromServer: fromServer,
  );

  /// From `my_overview` (rule 3).
  factory MyBalances.fromServer(ServerOverview s) => MyBalances(
    totals: {
      for (final e in s.totals.entries)
        if (e.value != 0) e.key: e.value,
    },
    byGroup: {
      for (final g in s.groups)
        g.groupId: {
          for (final e in g.balances.entries)
            if (e.value != 0) e.key: e.value,
        },
    },
    people: [
      for (final p in s.people)
        if (p.balances.values.any((v) => v != 0))
          PersonBalance(
            key: p.userId != null ? 'u:${p.userId}' : 'm:${p.memberId}',
            name: p.name,
            seed: p.memberId ?? p.userId ?? p.name,
            balances: {
              for (final e in p.balances.entries)
                if (e.value != 0) e.key: e.value,
            },
          ),
    ],
    fromServer: true,
  );
}

/// My overall balances from local group balances (groups where I am an active member): totals are
/// the sum of my per-group nets (rule 3 invariant), people come from what each group screen shows
/// between me and them (05 §5 "Total with a friend").
MyBalances myBalancesOf(List<GroupBalances> groups) {
  final totals = <String, int>{};
  final byGroup = <String, Map<String, int>>{};
  final people = <String, ({String name, String seed, Map<String, int> balances})>{};
  for (final g in groups) {
    final me = g.meId;
    if (me == null) continue;
    final mine = g.myNets;
    if (mine.isNotEmpty) byGroup[g.groupId] = mine;
    mine.forEach((c, v) => totals[c] = (totals[c] ?? 0) + v);
    for (final c in g.currencies) {
      for (final t in g.shown(c)) {
        final String other;
        final int signed;
        if (t.from == me) {
          other = t.to;
          signed = -t.amount;
        } else if (t.to == me) {
          other = t.from;
          signed = t.amount;
        } else {
          continue;
        }
        final m = g.member(other);
        final key = m?.userId != null ? 'u:${m!.userId}' : 'm:$other';
        final p = people.putIfAbsent(
          key,
          () => (name: g.nameOf(other), seed: other, balances: <String, int>{}),
        );
        p.balances[c] = (p.balances[c] ?? 0) + signed;
      }
    }
  }
  final keys = people.keys.toList()..sort();
  return MyBalances(
    totals: {
      for (final c in totals.keys.toList()..sort())
        if (totals[c] != 0) c: totals[c]!,
    },
    byGroup: byGroup,
    people: [
      for (final k in keys)
        if (people[k]!.balances.values.any((v) => v != 0))
          PersonBalance(
            key: k,
            name: people[k]!.name,
            seed: people[k]!.seed,
            balances: {
              for (final e in people[k]!.balances.entries)
                if (e.value != 0) e.key: e.value,
            },
          ),
    ],
  );
}
