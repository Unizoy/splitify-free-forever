// W2-X F11: several friends without a group. A person picked into a several-friends (ad-hoc) group keeps being
// the same friend (member id = origin XOR group id, S-421): one friend row, totals over both groups, the same
// people reuse one ad-hoc group. Vectors + glados properties (the ad-hoc split adds up; per-group amounts add up
// to the friend's total; my per-group nets add up to my overall balance, rule 3).
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glados/glados.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/friends/application/friend_identity.dart';
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/friend_widgets.dart';
import 'package:splitify/l10n/app_localizations.dart';

import '../../../support/ledger_seed.dart';
import '../friend_fixtures.dart' show ledgerOf;

const _trip = '00000000-0000-4000-8000-0000000000f1';
const _adhoc = 'c2820000-0000-4000-8000-000000000001';
const _me = '00000000-0000-4000-8000-0000000000a1';
const _asha = '00000000-0000-4000-8000-0000000000a2';
const _rahul = '00000000-0000-4000-8000-0000000000a3';
const _meAdhoc = 'c2820000-0000-4000-8000-0000000000e1';

String _d(String origin) => derivedMemberId(origin, _adhoc);

/// Goa trip: me, Asha (u2) and Rahul (name only); Rahul owes me 100.00 there.
GroupLedger _tripLedger() => ledgerOf(
  seedGroup(id: _trip, name: 'Goa trip'),
  [
    seedMember(_me, groupId: _trip, name: 'Mohit', userId: 'u1'),
    seedMember(_asha, groupId: _trip, name: 'Asha', userId: 'u2', position: 1),
    seedMember(_rahul, groupId: _trip, name: 'Rahul Mehta', position: 2),
  ],
  expenses: [
    seedExpense(
      'e1',
      groupId: _trip,
      total: 20000,
      payers: {_me: 20000},
      shares: {_me: 10000, _rahul: 10000},
    ),
  ],
);

/// "With you and" Asha + Rahul: me paid 900.00 split three ways. Asha's row has no account locally yet
/// ([ashaLinked] false: as written offline before the pull).
GroupLedger _adhocLedger({bool ashaLinked = true, String id = _adhoc, bool archived = false}) =>
    ledgerOf(
      seedGroup(
        id: id,
        name: 'Mohit, Asha & Rahul',
        type: 'adhoc',
        archivedAt: archived ? '2026-11-27T10:00:00Z' : null,
      ),
      [
        seedMember(_meAdhoc, groupId: id, name: 'Mohit', userId: 'u1'),
        seedMember(
          derivedMemberId(_asha, id),
          groupId: id,
          name: 'Asha',
          userId: ashaLinked ? 'u2' : null,
          position: 1,
        ),
        seedMember(derivedMemberId(_rahul, id), groupId: id, name: 'Rahul', position: 2),
      ],
      expenses: [
        seedExpense(
          'e2',
          groupId: id,
          total: 90000,
          payers: {_meAdhoc: 90000},
          shares: {
            _meAdhoc: 30000,
            derivedMemberId(_asha, id): 30000,
            derivedMemberId(_rahul, id): 30000,
          },
        ),
      ],
    );

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  group('uuidXor (same as 0028 private.uuid_xor)', () {
    test('vector and inverse', () {
      expect(
        uuidXor('00000000-0000-4000-8000-000000000001', 'ffffffff-ffff-ffff-ffff-fffffffffffe'),
        'ffffffff-ffff-bfff-7fff-ffffffffffff',
      );
      expect(uuidXor(uuidXor(_rahul, _adhoc), _adhoc), _rahul);
      expect(uuidXor(_rahul.toUpperCase(), _adhoc), uuidXor(_rahul, _adhoc));
    });

    test('non-uuid ids are no origin', () {
      expect(() => uuidXor('m1', _adhoc), throwsFormatException);
      final m = seedMember('m1', groupId: 'g1');
      expect(originOf(m, {'m1': m}), isNull);
      expect(friendKeyIn(m, {'m1': m}), 'm:m1');
    });
  });

  group('one person, one friend', () {
    test('a name-only person picked into an ad-hoc group is the same friend, totals over both', () {
      final friends = friendsOf([_tripLedger(), _adhocLedger()], 'u1');
      expect([for (final f in friends) f.key], ['u:u2', 'm:$_rahul']);
      final rahul = friends.last;
      expect(rahul.name, 'Rahul Mehta', reason: 'named by the member he was first added as');
      expect(rahul.seed, _rahul);
      expect(rahul.links.length, 2);
      expect(rahul.balances, {'INR': 40000});
      expect(rahul.sharedGroups.map((s) => s.group.id), [_trip]);
      expect(rahul.links.where((x) => x.isAdhoc).single.friendMemberId, _d(_rahul));
      expect(rahul.originMemberId, _rahul);
    });

    test(
      'a friend with an account written offline (no account on the row yet) is still that friend',
      () {
        final friends = friendsOf([_tripLedger(), _adhocLedger(ashaLinked: false)], 'u1');
        final asha = friends.firstWhere((f) => f.key == 'u:u2');
        expect(asha.links.length, 2);
        expect(asha.balances, {'INR': 30000});
        expect(asha.originMemberId, _asha, reason: 'an active member in a live normal group');
      },
    );

    test('the Home caption counts each person once', () {
      final mine = myBalancesOf([
        for (final g in [_tripLedger(), _adhocLedger(ashaLinked: false)]) groupBalancesOf(g, 'u1'),
      ]);
      expect(mine.peopleOwingMe, 2);
      expect(mine.totals, {'INR': 70000});
    });

    test('an ad-hoc link is labelled with its people, not its name', () {
      final f = friendsOf([_tripLedger(), _adhocLedger()], 'u1').last;
      final link = f.links.firstWhere((x) => x.isAdhoc);
      expect(friendLinkLabel(l, link), 'You, Asha & Rahul');
      expect(joinNames(l, ['A']), 'A');
      expect(joinNames(l, ['A', 'B']), 'A & B');
    });

    test('groupFriendsProvider: the people of an ad-hoc group as friends, in member order', () {
      final c = ProviderContainer(
        overrides: [
          friendsProvider.overrideWithValue(
            AsyncData(friendsOf([_tripLedger(), _adhocLedger()], 'u1')),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect([for (final f in c.read(groupFriendsProvider(_adhoc))) f.key], ['u:u2', 'm:$_rahul']);
      expect(c.read(groupFriendsProvider(_trip)), isEmpty, reason: 'a normal group has no chips');
    });
  });

  group('the same people reuse their ad-hoc group', () {
    final ledgers = [_tripLedger(), _adhocLedger()];

    test('exactly these people', () {
      expect(existingAdhocGroup(ledgers, 'u1', {'u:u2', 'm:$_rahul'}), _adhoc);
      expect(existingAdhocGroup(ledgers, 'u1', {'m:$_rahul', 'u:u2'}), _adhoc);
    });

    test('not fewer, not more, not archived, not a stranger', () {
      expect(existingAdhocGroup(ledgers, 'u1', {'u:u2'}), isNull);
      expect(existingAdhocGroup(ledgers, 'u1', {'u:u2', 'm:$_rahul', 'u:u9'}), isNull);
      expect(
        existingAdhocGroup(
          [_tripLedger(), _adhocLedger(archived: true)],
          'u1',
          {'u:u2', 'm:$_rahul'},
        ),
        isNull,
      );
      expect(existingAdhocGroup(ledgers, null, {'u:u2', 'm:$_rahul'}), isNull);
      expect(existingAdhocGroup(ledgers, 'u9', {'u:u2', 'm:$_rahul'}), isNull);
      // Asha's phone finds the same group for the same people.
      expect(existingAdhocGroup(ledgers, 'u2', {'u:u1', 'm:$_rahul'}), _adhoc);
    });
  });

  group('the ad-hoc group name', () {
    String more(int n) => l.w2xMorePeople(n);

    test('everyone, me first', () {
      expect(adhocGroupName('Mohit', ['Asha', 'Rahul'], more: more), 'Mohit, Asha & Rahul');
      expect(adhocGroupName('', ['Asha', 'Rahul'], more: more), 'Asha & Rahul');
    });

    test('long lists end with "N more" within 60 characters', () {
      final names = [for (var i = 0; i < 9; i++) 'Person number $i'];
      final name = adhocGroupName('Mohit', names, more: more);
      expect(name.length, lessThanOrEqualTo(60));
      expect(name, startsWith('Mohit, Person number 0'));
      expect(name, endsWith('more'));
    });
  });

  group('properties', () {
    final explore = ExploreConfig(numRuns: 300);
    Generator<T> gen<T>(T Function(Random r) f) =>
        any.simple(generate: (r, _) => f(r), shrink: (_) => const []);

    Glados(
      gen((r) => (total: 1 + r.nextInt(5000000), n: 2 + r.nextInt(9), seed: r.nextInt(1 << 30))),
      explore,
    ).test('an equal ad-hoc split adds up to the total and differs by at most one unit', (c) {
      final order = [for (var i = 0; i < c.n; i++) 'p$i'];
      final shares = split(c.total, SplitKind.equal, order, const {});
      expect(shares.values.fold(0, (a, b) => a + b), c.total);
      final hi = shares.values.reduce((a, b) => a > b ? a : b);
      final lo = shares.values.reduce((a, b) => a < b ? a : b);
      expect(hi - lo, lessThanOrEqualTo(1));
    });

    Glados(
      gen(
        (r) => [
          for (var i = 0, k = 1 + r.nextInt(6); i < k; i++) (r.nextInt(3), 1 + r.nextInt(900000)),
        ],
      ),
      explore,
    ).test('per-group amounts add up to each friend\'s total; my per-group nets to my overall', (
      bills,
    ) {
      // Random bills in the ad-hoc group (payer: me / Asha / Rahul), split equally between the three.
      final ids = [_meAdhoc, _d(_asha), _d(_rahul)];
      final expenses = [
        for (var i = 0; i < bills.length; i++)
          seedExpense(
            'x$i',
            groupId: _adhoc,
            total: bills[i].$2,
            payers: {ids[bills[i].$1]: bills[i].$2},
            shares: split(bills[i].$2, SplitKind.equal, ids, const {}),
          ),
      ];
      final base = _adhocLedger();
      final adhoc = ledgerOf(base.group, base.members, expenses: expenses);
      final ledgers = [_tripLedger(), adhoc];
      for (final f in friendsOf(ledgers, 'u1')) {
        final sum = <String, int>{};
        for (final link in f.links) {
          link.amounts.forEach((c, v) => sum[c] = (sum[c] ?? 0) + v);
        }
        sum.removeWhere((_, v) => v == 0);
        expect(f.balances, sum, reason: f.key);
      }
      final groups = [for (final g in ledgers) groupBalancesOf(g, 'u1')];
      final mine = myBalancesOf(groups);
      final byGroup = <String, int>{};
      for (final g in mine.byGroup.values) {
        g.forEach((c, v) => byGroup[c] = (byGroup[c] ?? 0) + v);
      }
      byGroup.removeWhere((_, v) => v == 0);
      expect(mine.totals, byGroup);
    });
  });
}
