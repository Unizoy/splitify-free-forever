import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/domain/entities/profile.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/balances/application/account_stats.dart';
import 'package:splitify/features/balances/application/totals_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';

import '../../../support/fakes.dart';
import '../../../support/ledger_seed.dart';

class _FixedProfile extends ProfileController {
  _FixedProfile(this.currency);
  final String? currency;

  @override
  Future<Profile?> build() async =>
      currency == null ? null : Profile(id: 'u1', displayName: 'Mohit', defaultCurrency: currency!);
}

final _today = DateTime(2026, 11, 22, 10);

GroupLedger _goa() => GroupLedger(
  group: seedGroup(mainCurrency: 'INR '),
  members: [
    seedMember('m1', userId: 'u1', name: 'Mohit'),
    seedMember('m2', userId: 'u2', name: 'Asha', position: 1),
    seedMember('m3', name: 'Ravi', position: 2),
  ],
  expenses: [
    seedExpense(
      'e1',
      date: '2026-11-05',
      total: 30000,
      payers: {'m1': 30000},
      shares: {'m1': 10000, 'm2': 10000, 'm3': 10000},
    ),
    seedExpense(
      'loan',
      date: '2026-11-06',
      kind: 'iou',
      total: 50000,
      payers: {'m1': 50000},
      shares: {'m2': 50000},
    ),
    seedExpense(
      'e3',
      date: '2026-10-30',
      total: 9000,
      payers: {'m2': 9000},
      shares: {'m1': 3000, 'm2': 3000, 'm3': 3000},
    ),
    seedExpense(
      'usd',
      date: '2026-11-07',
      currency: 'USD',
      total: 1000,
      payers: {'m2': 1000},
      shares: {'m1': 500, 'm2': 500},
    ),
  ],
  payments: [seedPayment('p1', from: 'm2', to: 'm1', amount: 5000)],
);

void main() {
  group('groupTotalsOf', () {
    test('TC-21-01 month and all-time totals leave IOUs and payments out', () {
      final v = groupTotalsOf(_goa(), 'u1', _today);
      expect(v.mainCurrency, 'INR');
      expect(v.meId, 'm1');
      expect(v.nameOf('m2'), 'Asha');
      expect(v.nameOf('nobody'), '');
      expect(v.month.keys, ['INR', 'USD']);
      expect(v.month['INR']!.spent, 30000);
      expect(v.month['INR']!.count, 1);
      expect(v.month['USD']!.spent, 1000);
      expect(v.allTime['INR']!.spent, 39000);
      expect(v.allTime['INR']!.count, 2);
      expect(v.allTime['INR']!.paid, {'m1': 30000, 'm2': 9000});
      expect(v.allTime['INR']!.shares, {'m1': 13000, 'm2': 13000, 'm3': 13000});
    });

    test('without an account there is no me', () {
      expect(groupTotalsOf(_goa(), null, _today).meId, isNull);
    });

    test('totalsInputs reads the stored JSON and trims the currency', () {
      final l = GroupLedger(
        group: seedGroup(),
        members: const [],
        expenses: [
          seedExpense('e', currency: 'INR ', total: 5, payers: {'a': 5}, shares: {'b': 5}),
        ],
        payments: const [],
      );
      final i = totalsInputs(l).single;
      expect((i.currency, i.total, i.kind, i.date), ('INR', 5, 'expense', '2026-11-20'));
      expect(i.paid, {'a': 5});
      expect(i.shares, {'b': 5});
    });
  });

  group('accountStatsOf', () {
    final flat = GroupLedger(
      group: seedGroup(id: 'g2', name: 'Flat', archivedAt: '2026-11-01T00:00:00Z'),
      members: [
        seedMember('n1', groupId: 'g2', userId: 'u1'),
        seedMember('n2', groupId: 'g2', userId: 'u2', position: 1),
      ],
      expenses: [
        seedExpense(
          'e6',
          groupId: 'g2',
          date: '2026-11-10',
          total: 400,
          payers: {'n2': 400},
          shares: {'n1': 200, 'n2': 200},
          createdBy: 'u1',
        ),
      ],
      payments: const [],
    );
    final friend = GroupLedger(
      group: seedGroup(id: 'g3', name: 'Friend', type: 'direct'),
      members: [
        seedMember('d1', groupId: 'g3', userId: 'u1'),
        seedMember('d2', groupId: 'g3', position: 1, name: 'Dev'),
        seedMember('d3', groupId: 'g3', position: 2, name: 'Gone', deletedAt: '2026-11-01'),
        seedMember('d4', groupId: 'g3', position: 3, name: 'Left', status: 'left'),
      ],
      expenses: const [],
      payments: const [],
    );
    final strangers = GroupLedger(
      group: seedGroup(id: 'g4'),
      members: [seedMember('z1', groupId: 'g4', userId: 'u9')],
      expenses: [
        seedExpense(
          'e9',
          groupId: 'g4',
          total: 100,
          payers: {'z1': 100},
          shares: {'z1': 100},
          createdBy: 'u1',
        ),
      ],
      payments: const [],
    );

    GroupLedger goaWith(List<LocalExpense> more) {
      final g = _goa();
      return GroupLedger(
        group: g.group,
        members: g.members,
        expenses: [...g.expenses, ...more],
        payments: g.payments,
      );
    }

    test('spent this month = my shares in the default currency, IOUs and other months out', () {
      final s = accountStatsOf([_goa(), flat], 'u1', _today, 'INR');
      expect(s.currency, 'INR');
      // e1 10000 + flat e6 200; loan, October and USD do not count.
      expect(s.spentThisMonth, 10200);
      expect(accountStatsOf([_goa()], 'u1', _today, 'USD').spentThisMonth, 500);
      expect(accountStatsOf([_goa()], 'u1', DateTime(2026, 10, 3), 'INR').spentThisMonth, 3000);
    });

    test('groups: open, non-direct groups I am an active member of', () {
      expect(accountStatsOf([_goa(), flat, friend, strangers], 'u1', _today, 'INR').groups, 1);
      expect(accountStatsOf([_goa(), _goa()], 'u1', _today, 'INR').groups, 2);
    });

    test('people: distinct others, linked accounts once, removed members out', () {
      final s = accountStatsOf([_goa(), flat, friend, strangers], 'u1', _today, 'INR');
      // u:u2 (twice), m:m3 (name-only), m:d2 (friend group).
      expect(s.people, 3);
    });

    test('expenses: created by me or not yet synced (no creator and seq 0)', () {
      final unsynced = seedExpense('u0', total: 1, payers: {'m1': 1}, shares: {'m1': 1}, seq: 0);
      final byOther = seedExpense(
        'o1',
        total: 1,
        payers: {'m1': 1},
        shares: {'m1': 1},
        createdBy: 'u2',
      );
      final noCreatorSynced = seedExpense('s1', total: 1, payers: {'m1': 1}, shares: {'m1': 1});
      final mine = seedExpense(
        'mine',
        total: 1,
        payers: {'m1': 1},
        shares: {'m1': 1},
        createdBy: 'u1',
      );
      final s = accountStatsOf(
        [
          goaWith([unsynced, byOther, noCreatorSynced, mine]),
          flat,
          strangers,
        ],
        'u1',
        _today,
        'INR',
      );
      // goa: unsynced + mine; flat: e6; strangers: nobody is me there.
      expect(s.expenses, 3);
    });

    test('without an account nothing is mine', () {
      final s = accountStatsOf([_goa(), flat], null, _today, 'INR');
      expect((s.spentThisMonth, s.groups, s.people), (0, 0, 0));
      expect(s.expenses, 0);
    });

    test('no groups at all', () {
      final s = accountStatsOf(const [], 'u1', _today, 'INR');
      expect((s.spentThisMonth, s.groups, s.people, s.expenses), (0, 0, 0, 0));
    });
  });

  group('providers', () {
    late AppDatabase db;
    late ProviderContainer c;

    Future<T> data<T>(ProviderListenable<AsyncValue<T>> p) {
      final done = Completer<T>();
      late final ProviderSubscription<AsyncValue<T>> sub;
      sub = c.listen(p, (_, n) {
        if (done.isCompleted) return;
        if (n.hasValue) {
          done.complete(n.requireValue);
        } else if (n.hasError) {
          done.completeError(n.error!);
        }
      }, fireImmediately: true);
      return done.future.whenComplete(sub.close);
    }

    void open({String? currency, DateTime? now}) {
      c = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('u1'),
          clockProvider.overrideWithValue(FakeClock(now ?? _today)),
          profileProvider.overrideWith(() => _FixedProfile(currency)),
        ],
      );
    }

    setUp(() async {
      db = testDb();
      final g = _goa();
      await db.seed(
        groups: [g.group],
        members: g.members,
        expenses: g.expenses,
        payments: g.payments,
      );
    });

    tearDown(() async {
      c.dispose();
      await db.close();
    });

    test('TC-21-01 groupTotalsProvider reads the ledger from the database', () async {
      open();
      final v = (await data(groupTotalsProvider('g1')))!;
      expect(v.month['INR']!.spent, 30000);
      expect(v.allTime['INR']!.spent, 39000);
      expect(v.meId, 'm1');
    });

    test('groupTotalsProvider is null for an unknown group', () async {
      open();
      expect(await data(groupTotalsProvider('nope')), isNull);
    });

    test('accountStatsProvider uses the profile default currency', () async {
      open(currency: 'USD');
      final s = await data(accountStatsProvider);
      expect(s.currency, 'USD');
      expect(s.spentThisMonth, 500);
      expect(s.groups, 1);
      expect(s.people, 2);
    });

    // Final QA (S-413): "this month" is the phone's month; on the 1st before 05:30 in India the UTC month
    // is still the previous one.
    test('this month follows the phone, not UTC', () async {
      final instant = DateTime.utc(2026, 11, 30, 19); // 00:30 on 1 Dec in India
      final november = instant.toLocal().month == 11;
      open(now: instant);
      final v = (await data(groupTotalsProvider('g1')))!;
      expect(v.month['INR']?.spent ?? 0, november ? 30000 : 0);
      final s = await data(accountStatsProvider);
      expect(s.spentThisMonth, november ? 10000 : 0);
    });

    test('accountStatsProvider falls back to INR without a profile', () async {
      open();
      final s = await data(accountStatsProvider);
      expect(s.currency, 'INR');
      expect(s.spentThisMonth, 10000);
    });
  });
}
