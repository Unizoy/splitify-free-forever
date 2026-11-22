// TC-2-03 (friends list and friend page data), TC-16-01 (friend total = sum of what each shared group
// shows between us), TC-17-02 (simplify changes only what a group shows, per group).
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/balances.dart' show Transfer;
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/friends/application/friends_view.dart';

import '../../../support/ledger_seed.dart';
import '../friend_fixtures.dart';

List<GroupLedger> _main({bool priyaSettled = false, bool goaSimplify = false}) => [
  goaLedger(simplify: goaSimplify),
  flatLedger(priyaSettled: priyaSettled),
  directLedger(),
  othersLedger(),
  leftLedger(),
];

List<Friend> _friends(List<GroupLedger> l, {Map<String, String> names = const {}}) =>
    friendsOf(l, 'u1', profileNames: names);

Friend _by(List<Friend> all, String key) => all.firstWhere((f) => f.key == key);

/// What every group of [ledgers] shows between me and [friend] (re-derived from the group balances).
Map<String, int> _expectedTotals(List<GroupLedger> ledgers, Friend friend) {
  final out = <String, int>{};
  for (final ledger in ledgers) {
    final b = groupBalancesOf(ledger, 'u1');
    final me = b.meId;
    if (me == null) continue;
    for (final m in ledger.members) {
      final theirs = m.userId != null ? 'u:${m.userId}' : 'm:${m.id}';
      if (theirs != friend.key) continue;
      for (final c in b.byCurrency.keys) {
        final shown = b.simplify ? b.byCurrency[c]!.simplified : b.byCurrency[c]!.pairs;
        for (final t in shown) {
          if (t.from == m.id && t.to == me) out[c] = (out[c] ?? 0) + t.amount;
          if (t.from == me && t.to == m.id) out[c] = (out[c] ?? 0) - t.amount;
        }
      }
    }
  }
  out.removeWhere((_, v) => v == 0);
  return out;
}

void main() {
  group('friendsOf', () {
    // TC-2-03
    test('lists linked people once per account and name-only people once per member', () {
      final all = _friends(_main(), names: profileNames);
      expect([for (final f in all) f.key], ['u:u2', 'u:u3', 'm:b3', 'm:a3']);
      final asha = _by(all, 'u:u2');
      expect(asha.userId, 'u2');
      expect(asha.nameOnly, isFalse);
      expect([for (final l in asha.links) l.group.id], ['g1', 'g2', 'g3']);
      expect([for (final l in asha.links) l.friendMemberId], ['a2', 'b2', 'c2']);
      expect(_by(all, 'm:a3').nameOnly, isTrue);
      expect(_by(all, 'm:a3').userId, isNull);
    });

    // TC-2-03
    test('leaves me out, and groups where I am not an active member', () {
      final all = _friends(_main(), names: profileNames);
      expect(all.map((f) => f.key), isNot(contains('u:u1')));
      // Bob (u9, u5), Zed: only in groups I am not part of.
      expect(all.map((f) => f.key), isNot(contains('u:u9')));
      expect(all.map((f) => f.key), isNot(contains('u:u5')));
      expect(all.map((f) => f.key), isNot(contains('m:x3')));
      // Asha has no link to the group of two other people.
      expect(_by(all, 'u:u2').links.map((l) => l.group.id), isNot(contains('g4')));
    });

    // TC-2-03
    test('no signed-in user means no friends', () {
      expect(friendsOf(_main(), null), isEmpty);
    });

    // TC-2-03
    test('a removed member is listed only while they have a balance with me', () {
      final owing = _friends(_main());
      expect(owing.map((f) => f.key), contains('m:b3'));
      expect(owing.map((f) => f.key), isNot(contains('m:b4')));
      expect(_by(owing, 'm:b3').balances, {'INR': 500});

      final paidBack = _friends(_main(priyaSettled: true));
      expect(paidBack.map((f) => f.key), isNot(contains('m:b3')));
    });

    // TC-2-03
    test('profile names win over member names; others keep the member name', () {
      final named = _friends(_main(), names: profileNames);
      expect(_by(named, 'u:u2').name, 'Asha Rao');
      expect(_by(named, 'm:a3').name, 'Rahul Mehta');
      final plain = _friends(_main());
      expect(_by(plain, 'u:u2').name, 'Asha');
    });

    // TC-2-03
    test('sorts by name ignoring case', () {
      final ledger = ledgerOf(goaLedger().group, [
        goaLedger().members.first,
        goaLedger().members[1].copyWith(displayName: 'zoya'),
        goaLedger().members[2].copyWith(displayName: 'Bela'),
        goaLedger().members[3].copyWith(displayName: 'amit'),
      ]);
      expect(
        [
          for (final f in _friends([ledger])) f.name,
        ],
        ['amit', 'Bela', 'zoya'],
      );
    });

    // TC-2-03
    test('a friend with no records yet is listed as settled', () {
      final dev = _by(_friends(_main()), 'u:u3');
      expect(dev.balances, isEmpty);
      expect(dev.status, BalanceStatus.settled);
    });
  });

  group('Friend balances', () {
    // TC-16-01
    test('the total merges every shared group, the direct one included', () {
      final asha = _by(_friends(_main(), names: profileNames), 'u:u2');
      // +60.00 in Goa, -100.00 in Flat 4B, +25.00 in our direct group.
      expect(asha.balances, {'INR': -1500});
      expect(asha.status, BalanceStatus.owe);
      expect(
        [for (final l in asha.links) l.amounts],
        [
          {'INR': 6000},
          {'INR': -10000},
          {'INR': 2500},
        ],
      );
    });

    // TC-16-01
    test('name-only people carry only their own member', () {
      final all = _friends(_main());
      expect(_by(all, 'm:a3').balances, {'INR': 7000});
      expect(_by(all, 'm:a3').status, BalanceStatus.owed);
    });

    // TC-16-01
    test('two currencies are listed apart, never summed', () {
      final asha = _by(_friends([twoCurrencyLedger()]), 'u:u2');
      expect(asha.balances, {'INR': 1000, 'USD': 2000});
      expect(asha.status, BalanceStatus.owed);
      final mixed = _by(_friends([twoCurrencyLedger(), flatLedger()]), 'u:u2');
      // Flat 4B: -100.00 INR; Abroad: +10.00 INR and +20.00 USD.
      expect(mixed.balances, {'INR': -9000, 'USD': 2000});
      expect(mixed.status, BalanceStatus.mixed);
    });

    // TC-16-01
    test('a currency that nets to zero is left out', () {
      // Abroad: +10.00 INR; Flat... Asha owes me 10.00 here and I owe her 10.00 there.
      final ledger = ledgerOf(
        flatLedger().group,
        flatLedger().members,
        expenses: [
          flatLedger().expenses.first.copyWith(
            total: 1000,
            payers: '{"b2":1000}',
            shares: '{"b1":1000}',
          ),
        ],
      );
      final f = _by(_friends([ledger, twoCurrencyLedger()]), 'u:u2');
      expect(f.balances, {'USD': 2000});
    });

    // TC-16-01
    test(
      'the 3-person cycle: original debts show the pairs, simplified shows nothing (TC-17-02)',
      () {
        final off = _friends([cycleLedger()]);
        expect(_by(off, 'u:u2').balances, {'INR': -1000}); // I owe Asha 10.00
        expect(_by(off, 'u:u7').balances, {'INR': 1000}); // Kabir owes me 10.00
        final on = _friends([cycleLedger(simplify: true)]);
        expect(_by(on, 'u:u2').balances, isEmpty);
        expect(_by(on, 'u:u7').balances, isEmpty);
        expect(_by(on, 'u:u2').status, BalanceStatus.settled);
        // Simplify is per group: another group of the same friend keeps showing its own pairs.
        final mixedSetting = _friends([cycleLedger(simplify: true), cycleLedger(id: 'g8')]);
        expect(_by(mixedSetting, 'u:u2').balances, {'INR': -1000});
      },
    );

    // TC-16-01
    test('friend total equals the sum of what each shared group shows between us', () {
      final fixtures = <String, List<GroupLedger>>{
        'main': _main(),
        'main, goa simplified': _main(goaSimplify: true),
        'main, priya settled': _main(priyaSettled: true),
        'cycle off': [cycleLedger()],
        'cycle on': [cycleLedger(simplify: true)],
        'cycle on + off + direct': [
          cycleLedger(simplify: true),
          cycleLedger(id: 'g8'),
          directLedger(),
        ],
        'two currencies': [twoCurrencyLedger(), twoCurrencyLedger(simplify: true, id: 'g9')],
        'everything': [
          ..._main(),
          cycleLedger(),
          cycleLedger(simplify: true, id: 'g8'),
          twoCurrencyLedger(),
        ],
      };
      for (final entry in fixtures.entries) {
        final friends = _friends(entry.value, names: profileNames);
        expect(friends, isNotEmpty, reason: entry.key);
        for (final f in friends) {
          expect(f.balances, _expectedTotals(entry.value, f), reason: '${entry.key}: ${f.key}');
          // The groups' own lines add up to the same total.
          final byLinks = <String, int>{};
          for (final l in f.links) {
            l.amounts.forEach((c, v) => byLinks[c] = (byLinks[c] ?? 0) + v);
          }
          byLinks.removeWhere((_, v) => v == 0);
          expect(f.balances, byLinks, reason: '${entry.key}: ${f.key} by group');
        }
      }
    });

    // TC-16-01
    test('Friend.status follows the signs', () {
      final all = _friends(_main());
      expect(_by(all, 'u:u2').status, BalanceStatus.owe);
      expect(_by(all, 'm:a3').status, BalanceStatus.owed);
      expect(_by(all, 'u:u3').status, BalanceStatus.settled);
    });
  });

  group('Friend links', () {
    // TC-2-03
    test('directGroupId and sharedGroups tell our friend group from normal groups', () {
      final all = _friends(_main());
      final asha = _by(all, 'u:u2');
      expect(asha.directGroupId, 'g3');
      expect([for (final l in asha.sharedGroups) l.group.id], ['g1', 'g2']);
      final rahul = _by(all, 'm:a3');
      expect(rahul.directGroupId, isNull);
      expect(rahul.sharedGroups.single.group.id, 'g1');
      expect(asha.links.last.isDirect, isTrue);
      expect(asha.links.first.isDirect, isFalse);
    });

    // TC-2-03
    test('a friend I only have a direct group with has no shared groups', () {
      final only = _by(_friends([directLedger()]), 'u:u2');
      expect(only.sharedGroups, isEmpty);
      expect(only.directGroupId, 'g3');
    });

    // TC-2-03
    test('transfers are what each group shows between us, one entry per currency', () {
      final asha = _by(_friends(_main()), 'u:u2');
      expect(
        [for (final t in asha.transfers) (t.link.group.id, t.currency, t.transfer)],
        [
          ('g1', 'INR', const Transfer('a2', 'a1', 6000)),
          ('g2', 'INR', const Transfer('b1', 'b2', 10000)),
          ('g3', 'INR', const Transfer('c2', 'c1', 2500)),
        ],
      );
      // Rahul has one in Goa; Dev none (nothing between us).
      expect(
        _by(_friends(_main()), 'm:a3').transfers.single.transfer,
        const Transfer('a3', 'a1', 7000),
      );
      expect(_by(_friends(_main()), 'u:u3').transfers, isEmpty);
    });

    // TC-17-02
    test('transfers follow the group\'s simplify setting', () {
      final off = _by(_friends([cycleLedger()]), 'u:u2');
      expect(off.transfers.single.transfer, const Transfer('k1', 'k2', 1000));
      final on = _by(_friends([cycleLedger(simplify: true)]), 'u:u2');
      expect(on.transfers, isEmpty);
    });

    // TC-2-03
    test('a link knows who I am in its group', () {
      final asha = _by(_friends(_main()), 'u:u2');
      expect([for (final l in asha.links) l.meId], ['a1', 'b1', 'c1']);
    });
  });

  group('searchFriends', () {
    final all = _friends(_main(), names: profileNames);

    // TC-2-03
    test('matches part of a name in any case, and keeps the order', () {
      expect(
        [for (final f in searchFriends(all, 'a')) f.name],
        ['Asha Rao', 'Dev Shah', 'Priya Nair', 'Rahul Mehta'],
      );
      expect([for (final f in searchFriends(all, 'ASHA')) f.key], ['u:u2']);
      expect([for (final f in searchFriends(all, '  mEh ')) f.key], ['m:a3']);
    });

    // TC-2-03
    test('an empty or blank query returns everyone; no match returns nobody', () {
      expect(searchFriends(all, ''), all);
      expect(searchFriends(all, '   '), all);
      expect(searchFriends(all, 'zzz'), isEmpty);
    });
  });

  group('friendItems', () {
    List<FriendItem> itemsOf(String key, {List<GroupLedger>? ledgers}) =>
        friendItems(_by(_friends(ledgers ?? _main()), key));

    // TC-2-03
    test('only expenses where both of us are involved, plus payments between us, newest first', () {
      final items = itemsOf('u:u2');
      // Movie (direct, 22 Nov), payment (21 Nov), Rent and Dinner (20 Nov, higher id first).
      expect([for (final i in items) i.id], ['e5', 'p1', 'e3', 'e1']);
      // The Cab (Asha not in it), Rahul's payment to Dev and Priya's Milk are not on Asha's page.
      expect(items.map((i) => i.id), isNot(contains('e2')));
      expect(items.map((i) => i.id), isNot(contains('p2')));
    });

    // TC-2-03
    test('an expense amount is what it adds to who owes whom between us (+ = I lent)', () {
      final byId = {for (final i in itemsOf('u:u2')) i.id: i};
      expect(byId['e1']!.amount, 10000); // I paid the dinner: Asha owes me her share
      expect(byId['e3']!.amount, -10000); // Asha paid the rent: I owe her my share
      expect(byId['e5']!.amount, 2500);
      expect(byId['e1']!.expense!.description, 'Dinner');
      expect(byId['e1']!.payment, isNull);
      expect(byId['e1']!.currency, 'INR');
    });

    // TC-2-03
    test('a payment between us is signed: I paid = +, they paid = -', () {
      final theyPaid = itemsOf('u:u2').firstWhere((i) => i.id == 'p1');
      expect(theyPaid.amount, -4000);
      expect(theyPaid.payment!.fromMember, 'a2');
      expect(theyPaid.expense, isNull);
      expect(theyPaid.date, '2026-11-21');
      final iPaid = ledgerOf(
        goaLedger().group,
        goaLedger().members,
        payments: [
          seedPayment('p8', groupId: 'g1', from: 'a1', to: 'a2', amount: 2500),
          seedPayment('p9', groupId: 'g1', from: 'a3', to: 'a4', amount: 100),
        ],
      );
      final items = itemsOf('u:u2', ledgers: [iPaid]);
      expect(items.single.amount, 2500);
    });

    // TC-2-03
    test('an expense I am not in is left out', () {
      final ledger = ledgerOf(
        goaLedger().group,
        goaLedger().members,
        expenses: [
          // Asha and Rahul only.
          seedExpense(
            'x1',
            groupId: 'g1',
            total: 1000,
            payers: {'a2': 1000},
            shares: {'a2': 500, 'a3': 500},
          ),
        ],
      );
      expect(itemsOf('u:u2', ledgers: [ledger]), isEmpty);
    });

    // TC-2-03
    test('a friend with a group but no records has nothing shared', () {
      expect(itemsOf('u:u3'), isEmpty);
    });

    // TC-2-03
    test('a name-only friend sees only the records of their group', () {
      expect([for (final i in itemsOf('m:a3')) i.id], ['e1', 'e2']);
      expect(itemsOf('m:a3').last.amount, -3000); // Rahul paid the cab: I owe my 30.00
    });
  });
}
