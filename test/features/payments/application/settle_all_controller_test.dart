// D-034 B1: settle everything with one friend — the options on the friend's sheet (per currency, two or more
// groups), the batch form (prefilled total, part, over, currencies kept apart, archived groups left out) and the
// save (one payment per group through the outbox, biggest first, both nets reach 0).
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/groups/application/groups_providers.dart' as groups;
import 'package:splitify/features/payments/application/settle_all_controller.dart';
import 'package:splitify/features/payments/application/settle_controller.dart' show SettleNotFound;

import '../../../data/sync/sync_fakes.dart';
import '../../../support/ledger_seed.dart';

const _asha = 'u:u2';

/// Goa (g1): Asha owes me ₹200. Our friend group (g3): Asha owes me ₹255. Flat (g2, archived on request):
/// Asha owes me ₹50. Optionally a USD balance in Goa.
Future<void> _seed(
  AppDatabase db, {
  bool archivedFlat = false,
  bool usd = false,
  bool iOweInFlat = false,
}) => db.seed(
  groups: [
    seedGroup(id: 'g1', name: 'Goa trip'),
    seedGroup(
      id: 'g2',
      name: 'Flat 4B',
      type: 'home',
      createdAt: '2026-11-02T10:00:00Z',
      archivedAt: archivedFlat ? '2026-11-20T10:00:00Z' : null,
    ),
    seedGroup(id: 'g3', name: 'Me & Asha', type: 'direct', createdAt: '2026-11-03T10:00:00Z'),
  ],
  members: [
    seedMember('a1', groupId: 'g1', name: 'Mohit', userId: 'u1'),
    seedMember('a2', groupId: 'g1', name: 'Asha', userId: 'u2', position: 1),
    seedMember('b1', groupId: 'g2', name: 'Mohit', userId: 'u1'),
    seedMember('b2', groupId: 'g2', name: 'Asha', userId: 'u2', position: 1),
    seedMember('c1', groupId: 'g3', name: 'Mohit', userId: 'u1'),
    seedMember('c2', groupId: 'g3', name: 'Asha', userId: 'u2', position: 1),
  ],
  expenses: [
    seedExpense(
      'e1',
      groupId: 'g1',
      total: 40000,
      payers: {'a1': 40000},
      shares: {'a1': 20000, 'a2': 20000},
    ),
    seedExpense(
      'e2',
      groupId: 'g3',
      total: 51000,
      payers: {'c1': 51000},
      shares: {'c1': 25500, 'c2': 25500},
    ),
    if (iOweInFlat)
      seedExpense(
        'e3',
        groupId: 'g2',
        total: 20000,
        payers: {'b2': 20000},
        shares: {'b1': 10000, 'b2': 10000},
      )
    else
      seedExpense(
        'e3',
        groupId: 'g2',
        total: 10000,
        payers: {'b1': 10000},
        shares: {'b1': 5000, 'b2': 5000},
      ),
    if (usd)
      seedExpense(
        'e4',
        groupId: 'g1',
        currency: 'USD',
        total: 2000,
        payers: {'a1': 2000},
        shares: {'a1': 1000, 'a2': 1000},
      ),
  ],
);

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = memoryDb();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        remoteApiProvider.overrideWithValue(FakeRemoteApi()),
        clockProvider.overrideWithValue(FakeClock(DateTime(2026, 11, 27, 10))),
        groups.currentUserIdProvider.overrideWithValue('u1'),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    unawaited(db.close());
  });

  Future<Friend> asha() async {
    final ledgers = await container.read(ledgerRepositoryProvider).loadAll();
    return friendsOf(ledgers, 'u1').firstWhere((f) => f.key == _asha);
  }

  SettleAllArgs args([String currency = 'INR']) => (friendKey: _asha, currency: currency);

  Future<SettleAllDraft> open([String currency = 'INR']) {
    container.listen(settleAllProvider(args(currency)), (_, _) {});
    return container.read(settleAllProvider(args(currency)).future);
  }

  SettleAllController ctl([String currency = 'INR']) =>
      container.read(settleAllProvider(args(currency)).notifier);

  SettleAllDraft draft([String currency = 'INR']) =>
      container.read(settleAllProvider(args(currency))).requireValue;

  Future<List<Map<String, Object?>>> paymentsQueued() async => [
    for (final o in await db.select(db.outbox).get())
      if (o.entity == 'payment')
        {'group': o.groupId, ...jsonDecode(o.payload) as Map<String, Object?>},
  ];

  group('options on the friend sheet', () {
    test('one "Everything" per currency with balances in two or more groups', () async {
      await _seed(db, usd: true);
      final options = settleAllOptions(await asha());
      // INR in three groups (Goa 200, Flat 50, direct 255); USD only in Goa: no batch for it.
      expect(options, [(currency: 'INR', net: 50500, groups: 3)]);
    });

    test('archived groups stay out (read-only on the server)', () async {
      await _seed(db, archivedFlat: true);
      expect(settleAllOptions(await asha()), [(currency: 'INR', net: 45500, groups: 2)]);
      expect([for (final g in settleAllGroups(await asha(), 'INR')) g.groupId], ['g1', 'g3']);
    });

    test('a balance the other way is part of the batch: the net is what changes hands', () async {
      await _seed(db, iOweInFlat: true);
      final groupsInr = settleAllGroups(await asha(), 'INR');
      expect(
        [for (final g in groupsInr) (g.groupId, g.owed)],
        [('g1', 20000), ('g2', -10000), ('g3', 25500)],
      );
      expect(settleAllOptions(await asha()), [(currency: 'INR', net: 35500, groups: 3)]);
    });
  });

  group('the batch form', () {
    test('prefilled with the whole balance; Asha pays me; nothing else stays open', () async {
      await _seed(db, archivedFlat: true);
      final d = await open();
      expect((d.friendName, d.currency, d.total, d.friendPays), ('Asha', 'INR', 45500, true));
      expect(d.amountText, '455');
      expect((d.me.id, d.friend.id), ('a1', 'a2'));
      expect(d.othersOpen, isTrue, reason: 'the archived Flat still holds ₹50');
      expect(d.settlesEverything, isFalse);
    });

    test('settles everything when no other currency or group is left', () async {
      await _seed(db);
      final d = await open();
      expect((d.total, d.othersOpen, d.settlesEverything), (50500, false, true));
    });

    test('part of it: biggest group first (₹300 = our group ₹255 + Goa ₹45)', () async {
      await _seed(db, archivedFlat: true);
      await open();
      ctl().setAmountText('300');
      expect([for (final p in draft().parts) (p.groupId, p.amount)], [('g3', 25500), ('g1', 4500)]);
      expect((draft().partIn('g1'), draft().partIn('g3')), (4500, 25500));
      expect(draft().settlesEverything, isFalse);
    });

    test('more than the whole balance is blocked inline', () async {
      await _seed(db, archivedFlat: true);
      await open();
      ctl().setAmountText('456');
      expect((draft().over, draft().canSave), (true, false));
      expect(draft().parts, isEmpty);
      expect(await ctl().save(), isNull);
      expect(await paymentsQueued(), isEmpty);
      ctl().useTotal();
      expect((draft().amountText, draft().canSave), ('455', true));
    });

    test('a long note blocks saving', () async {
      await _seed(db);
      await open();
      ctl().setNote('x' * 201);
      expect(draft().canSave, isFalse);
    });

    test('another currency is its own batch (rule 4)', () async {
      await _seed(db, usd: true);
      final inr = await open();
      expect((inr.total, inr.othersOpen), (50500, true), reason: 'USD stays open');
      final usd = await open('USD');
      expect([for (final g in usd.groups) (g.groupId, g.owed)], [('g1', 1000)]);
      expect((usd.currency, usd.total, usd.amountText), ('USD', 1000, '10'));
    });

    test('an unknown friend is not found', () async {
      await _seed(db);
      container.listen(settleAllProvider((friendKey: 'u:nobody', currency: 'INR')), (_, _) {});
      await expectLater(
        container.read(settleAllProvider((friendKey: 'u:nobody', currency: 'INR')).future),
        throwsA(isA<SettleNotFound>()),
      );
    });
  });

  group('saving', () {
    test('everything: one payment per group in one go, through the outbox, nets reach 0', () async {
      await _seed(db, archivedFlat: true);
      await open();
      ctl()
        ..setMethod('bank')
        ..setNote('Goa + dinners');
      final ids = await ctl().save();
      expect(ids, hasLength(2));
      final queued = await paymentsQueued();
      expect(
        [for (final q in queued) (q['group'], q['from_member'], q['to_member'], q['amount'])],
        [('g3', 'c2', 'c1', 25500), ('g1', 'a2', 'a1', 20000)],
      );
      for (final q in queued) {
        expect(
          (q['currency'], q['method'], q['note'], q['date']),
          ('INR', 'bank', 'Goa + dinners', '2026-11-27'),
        );
      }
      final rows = await db.select(db.payments).get();
      expect(
        rows.every((p) => p.syncState == 'pending'),
        isTrue,
        reason: '"not synced yet" until pushed',
      );
      final after = await asha();
      expect(settleAllGroups(after, 'INR'), isEmpty);
      expect(after.links.firstWhere((l) => l.group.id == 'g2').amounts, {'INR': 5000});
    });

    test('I owe on balance: the payments go from me', () async {
      await db.seed(
        groups: [
          seedGroup(id: 'g1'),
          seedGroup(id: 'g3', type: 'direct'),
        ],
        members: [
          seedMember('a1', groupId: 'g1', userId: 'u1'),
          seedMember('a2', groupId: 'g1', name: 'Asha', userId: 'u2', position: 1),
          seedMember('c1', groupId: 'g3', userId: 'u1'),
          seedMember('c2', groupId: 'g3', name: 'Asha', userId: 'u2', position: 1),
        ],
        expenses: [
          seedExpense(
            'e1',
            groupId: 'g1',
            total: 1000,
            payers: {'a2': 1000},
            shares: {'a1': 500, 'a2': 500},
          ),
          seedExpense(
            'e2',
            groupId: 'g3',
            total: 3000,
            payers: {'c2': 3000},
            shares: {'c1': 1500, 'c2': 1500},
          ),
        ],
      );
      final d = await open();
      expect((d.friendPays, d.total), (false, 2000));
      await ctl().save();
      expect(
        [for (final q in await paymentsQueued()) (q['from_member'], q['to_member'], q['amount'])],
        [('c1', 'c2', 1500), ('a1', 'a2', 500)],
      );
    });

    test('a balance the other way is cleared too: exactly the net changes hands', () async {
      await _seed(db, iOweInFlat: true);
      await open();
      await ctl().save();
      final queued = await paymentsQueued();
      expect(
        [for (final q in queued) (q['group'], q['from_member'], q['to_member'], q['amount'])],
        [('g3', 'c2', 'c1', 25500), ('g1', 'a2', 'a1', 20000), ('g2', 'b1', 'b2', 10000)],
      );
      expect((await asha()).balances, isEmpty);
    });
  });
}
