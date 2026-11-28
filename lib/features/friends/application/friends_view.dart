import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/money/money_error.dart' show MoneyError;
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/friends/application/friend_identity.dart';

/// One group I share with a friend (a normal group or our `direct` friend group, #2).
class FriendLink {
  const FriendLink({required this.ledger, required this.balances, required this.friendMemberId});

  final GroupLedger ledger;
  final GroupBalances balances;

  /// The friend's member id in this group (members are not accounts, rule 8).
  final String friendMemberId;

  LocalGroup get group => ledger.group;

  bool get isDirect => group.type == 'direct';

  /// A several-friends group (W2-X F11): hidden from the Groups grid, shown here.
  bool get isAdhoc => group.type == 'adhoc';

  /// My member id here (links exist only where I am an active member).
  String get meId => balances.meId!;

  /// What this group's screen shows between us, per currency (positive = they owe me), 0s left out.
  Map<String, int> get amounts => friendTotals([_friendGroup]);

  FriendGroup get _friendGroup => FriendGroup(
    me: meId,
    friend: friendMemberId,
    balances: balances.byCurrency,
    simplify: balances.simplify,
  );

  /// The friend owes me something here (as the group shows it): Remind is offered.
  bool get owesMe =>
      transfers.any((t) => t.transfer.from == friendMemberId && t.transfer.to == meId);

  /// The transfers between us this group's Balances tab shows (simplified when it has simplify on).
  List<({String currency, Transfer transfer})> get transfers => [
    for (final c in balances.currencies)
      for (final t in balances.shown(c))
        if ((t.from == meId && t.to == friendMemberId) ||
            (t.from == friendMemberId && t.to == meId))
          (currency: c, transfer: t),
  ];
}

/// Someone I share a group with (Friends tab, #2/#16): linked people once per account (key `u:<user id>`),
/// name-only people once per member (key `m:<member id>`).
class Friend {
  const Friend({
    required this.key,
    required this.name,
    required this.seed,
    required this.links,
    required this.balances,
    this.userId,
    this.tint,
  });

  final String key;
  final String name;

  /// Avatar colour seed (the first member id).
  final String seed;
  final int? tint;
  final String? userId;

  /// Shared groups, oldest first.
  final List<FriendLink> links;

  /// Total with this friend per currency (#16, 05 §5): Σ of what each shared group shows between us,
  /// positive = they owe me. Settled currencies are left out; keys alphabetical.
  final Map<String, int> balances;

  bool get nameOnly => userId == null;

  /// Our direct friend group, if there is one.
  String? get directGroupId => links.where((l) => l.isDirect).firstOrNull?.group.id;

  /// Shared normal groups (not the direct one, not several-friends groups).
  List<FriendLink> get sharedGroups => [...links.where((l) => !l.isDirect && !l.isAdhoc)];

  /// The member id a new several-friends group derives this friend's id from (S-421): the person's own
  /// member for name-only friends; for an account, an active member in a live group, our direct group first.
  String get originMemberId {
    if (userId == null) return key.substring(2);
    bool active(FriendLink l) {
      final m = l.ledger.members.where((m) => m.id == l.friendMemberId).firstOrNull;
      return m != null && m.status == 'active' && m.deletedAt == null && l.group.deletedAt == null;
    }

    final live = links.where(active).toList();
    final pick =
        live.where((l) => l.isDirect).firstOrNull ??
        live.where((l) => !l.isAdhoc).firstOrNull ??
        live.firstOrNull ??
        links.first;
    return pick.friendMemberId;
  }

  BalanceStatus get status => balanceStatusOf(balances.values);

  /// Every transfer between us across groups (settle up from the friend page).
  List<({FriendLink link, String currency, Transfer transfer})> get transfers => [
    for (final l in links)
      for (final t in l.transfers) (link: l, currency: t.currency, transfer: t.transfer),
  ];
}

/// The key of [member] as a friend.
String friendKeyOf(LocalMember member) =>
    member.userId != null ? 'u:${member.userId}' : 'm:${member.id}';

/// Everyone I share a live group with, by name. [profileNames] (account id → profile name) wins over
/// the member's name (03 §2: "name shown = profile name if linked"). A person shows up when they are an
/// active member of a group where I am one, or still have a balance with me there.
List<Friend> friendsOf(
  List<GroupLedger> ledgers,
  String? userId, {
  Map<String, String> profileNames = const {},
}) {
  if (userId == null) return const [];
  final found = <String, ({LocalMember first, List<FriendLink> links})>{};
  final byId = membersById([for (final l in ledgers) l.members]);
  for (final ledger in ledgers) {
    final b = groupBalancesOf(ledger, userId);
    final me = b.meId;
    if (me == null) continue;
    final withMe = <String>{
      for (final c in b.currencies)
        for (final t in b.shown(c))
          if (t.from == me) t.to else if (t.to == me) t.from,
    };
    for (final m in ledger.members) {
      if (m.id == me || (m.userId != null && m.userId == userId)) continue;
      final active = m.deletedAt == null && m.status == 'active';
      if (!active && !withMe.contains(m.id)) continue;
      final key = friendKeyIn(m, byId);
      // A name-only person is named and coloured by the member they were first added as (S-421).
      final root = key.startsWith('m:') ? byId[key.substring(2)] : null;
      final entry = found.putIfAbsent(key, () => (first: root ?? m, links: <FriendLink>[]));
      entry.links.add(FriendLink(ledger: ledger, balances: b, friendMemberId: m.id));
    }
  }
  final friends = [
    for (final e in found.entries)
      Friend(
        key: e.key,
        name: profileNames[e.value.first.userId] ?? e.value.first.displayName,
        seed: e.value.first.id,
        tint: e.value.first.tint,
        userId: e.value.first.userId,
        links: e.value.links,
        balances: friendTotals([for (final l in e.value.links) l._friendGroup]),
      ),
  ];
  friends.sort((a, b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.key.compareTo(b.key);
  });
  return friends;
}

/// [friends] whose name contains [query] (any case); all of them for an empty query.
List<Friend> searchFriends(List<Friend> friends, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return friends;
  return [...friends.where((f) => f.name.toLowerCase().contains(q))];
}

/// One expense or payment that involves both of us (friend page list).
class FriendItem {
  const FriendItem({required this.link, required this.amount, this.expense, this.payment});

  final FriendLink link;
  final LocalExpense? expense;
  final LocalPayment? payment;

  /// Between us in this record (positive = they owe me / I lent, negative = I borrowed).
  final int amount;

  String get date => expense?.date ?? payment!.date;
  String get id => expense?.id ?? payment!.id;
  String get currency => (expense?.currency ?? payment!.currency).trim();
}

/// Expenses where both of us paid or owe something, and payments between us, across our groups;
/// newest first. An expense's amount is what it adds to "who owes whom" between us
/// ([expensePairs], 05 §5), so the items of a group add up to its original debts.
List<FriendItem> friendItems(Friend friend) {
  final items = <FriendItem>[];
  for (final l in friend.links) {
    final me = l.meId;
    final them = l.friendMemberId;
    final order = [for (final m in l.ledger.members) m.id];
    for (final e in l.ledger.expenses) {
      final paid = decodeMinorMap(e.payers);
      final shares = decodeMinorMap(e.shares);
      bool involved(String id) => (paid[id] ?? 0) != 0 || (shares[id] ?? 0) != 0;
      if (!involved(me) || !involved(them)) continue;
      final extra = {...paid.keys, ...shares.keys}.difference(order.toSet()).toList()..sort();
      var amount = 0;
      try {
        for (final t in expensePairs([...order, ...extra], paid, shares)) {
          if (t.from == them && t.to == me) amount += t.amount;
          if (t.from == me && t.to == them) amount -= t.amount;
        }
      } on MoneyError {
        amount = 0;
      }
      items.add(FriendItem(link: l, expense: e, amount: amount));
    }
    for (final p in l.ledger.payments) {
      final between =
          (p.fromMember == me && p.toMember == them) || (p.fromMember == them && p.toMember == me);
      if (!between) continue;
      items.add(FriendItem(link: l, payment: p, amount: p.fromMember == me ? p.amount : -p.amount));
    }
  }
  items.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  });
  return items;
}

/// How many of [items] (newest first, [friendItems]) are settled history (D-034 B5): when we are settled in
/// every currency, everything up to the last full settle-up — the newest point where what each item adds up to
/// is zero in every currency — hides behind "Show settled items". 0 while a balance is open.
int settledHistoryCount(Friend friend, List<FriendItem> items) {
  if (friend.status != BalanceStatus.settled || items.isEmpty) return 0;
  final totals = <String, int>{};
  var lastZero = -1;
  for (var i = items.length - 1; i >= 0; i--) {
    final item = items[i];
    totals[item.currency] = (totals[item.currency] ?? 0) + item.amount;
    if (totals.values.every((v) => v == 0)) lastZero = items.length - 1 - i;
  }
  // Settled as the groups show it but the records do not add up to zero (simplify debts moved who owes whom):
  // all of it is history.
  return lastZero < 0 ? items.length : lastZero + 1;
}
