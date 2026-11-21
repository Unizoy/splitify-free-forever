import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/domain/balance_check.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';

import '../../../data/sync/sync_fakes.dart' show FakeRemoteApi;
import '../../../support/fakes.dart';
import '../../../support/ledger_seed.dart';

/// Scripted [BalancesRemote]; records the calls.
class FakeBalancesRemote implements BalancesRemote {
  ServerGroupBalances Function(String groupId)? group;
  ServerOverview Function()? overview;
  Exception? error;
  final calls = <String>[];

  @override
  Future<ServerGroupBalances> groupBalances(String groupId) async {
    calls.add('group:$groupId');
    if (error != null) throw error!;
    return group!(groupId);
  }

  @override
  Future<ServerOverview> myOverview() async {
    calls.add('overview');
    if (error != null) throw error!;
    return overview!();
  }
}

/// m1 (user u1) paid 300.00, split equally with m2: m2 owes m1 150.00.
const _order = ['m1', 'm2'];
final _flow = ExpenseFlow(
  currency: 'INR',
  paid: const {'m1': 30000},
  shares: const {'m1': 15000, 'm2': 15000},
);

ServerGroupBalances _serverGroup({int off = 0}) {
  final b = Balances.compute(_order, [_flow], const []);
  return ServerGroupBalances(
    groupId: 'g1',
    mainCurrency: 'INR',
    simplify: false,
    currencies: {
      'INR': Balances(
        nets: {for (final e in b.nets.entries) e.key: e.value + (e.key == 'm1' ? off : -off)},
        pairs: [for (final t in b.pairs) Transfer(t.from, t.to, t.amount + off)],
        simplified: [for (final t in b.simplified) Transfer(t.from, t.to, t.amount + off)],
      ),
    },
  );
}

ServerOverview _serverOverview({int mine = 15000}) => ServerOverview(
  totals: {'INR': mine},
  groups: [
    (groupId: 'g1', memberId: 'm1', balances: {'INR': mine}),
  ],
  people: [
    (userId: 'u2', memberId: 'm2', groupId: 'g1', name: 'Asha (server)', balances: {'INR': mine}),
    (userId: null, memberId: 'm7', groupId: 'g1', name: 'Zero', balances: {'INR': 0}),
  ],
);

void main() {
  late AppDatabase db;
  late FakeBalancesRemote remote;
  late ProviderContainer c;
  late List<LogRecord> logs;
  late StreamSubscription<LogRecord> logSub;
  late Level oldLevel;

  setUp(() {
    db = testDb();
    remote = FakeBalancesRemote();
    logs = [];
    oldLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    logSub = Logger.root.onRecord.listen(logs.add);
  });

  tearDown(() async {
    await logSub.cancel();
    Logger.root.level = oldLevel;
    c.dispose();
    await db.close();
  });

  Future<void> seedGoa({String expenseState = SyncState.synced}) => db.seed(
    groups: [seedGroup()],
    members: [
      seedMember('m1', userId: 'u1', name: 'Mohit'),
      seedMember('m2', name: 'Asha'),
    ],
    expenses: [
      seedExpense(
        'e1',
        total: 30000,
        payers: {'m1': 30000},
        shares: {'m1': 15000, 'm2': 15000},
        syncState: expenseState,
      ),
    ],
  );

  void open({DateTime? lastSync, List<Override> extra = const []}) {
    c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        remoteApiProvider.overrideWithValue(FakeRemoteApi()),
        balancesRemoteProvider.overrideWithValue(remote),
        currentUserIdProvider.overrideWithValue('u1'),
        lastSyncProvider.overrideWithValue(lastSync),
        clockProvider.overrideWithValue(FakeClock(DateTime(2026, 11, 22, 10))),
        ...extra,
      ],
    );
  }

  /// First data value of [p] that satisfies [ok] (the provider is kept alive meanwhile).
  Future<T> until<T>(ProviderListenable<AsyncValue<T>> p, bool Function(T v) ok) {
    final done = Completer<T>();
    late final ProviderSubscription<AsyncValue<T>> sub;
    void look(AsyncValue<T> v) {
      if (done.isCompleted) return;
      if (v.hasError && !v.hasValue) {
        done.completeError(v.error!);
      } else if (v.hasValue && ok(v.requireValue)) {
        done.complete(v.requireValue);
      }
    }

    sub = c.listen(p, (_, n) => look(n), fireImmediately: true);
    return done.future.whenComplete(sub.close);
  }

  final syncedAt = DateTime(2026, 11, 22, 9);

  List<LogRecord> warnings() => [
    for (final r in logs)
      if (r.loggerName == 'balances' && r.level == Level.WARNING) r,
  ];

  group('BalanceChecker.checkGroup', () {
    // TC-15-04
    test('TC-15-04 the same records give the same checksum and no warning', () async {
      await seedGoa();
      open();
      remote.group = (_) => _serverGroup();
      final check = (await c.read(balanceCheckerProvider).checkGroup('g1'))!;
      expect(check.matches, isTrue);
      expect(check.localChecksum, check.serverChecksum);
      expect(check.localChecksum, isNonZero);
      expect(remote.calls, ['group:g1']);
      expect(warnings(), isEmpty);
      expect(
        logs.any((r) => r.level == Level.FINE && r.message.contains('balances match')),
        isTrue,
      );
    });

    // TC-15-04
    test('TC-15-04 a difference is logged as a warning on the balances logger', () async {
      await seedGoa();
      open();
      remote.group = (_) => _serverGroup(off: 1);
      final check = (await c.read(balanceCheckerProvider).checkGroup('g1'))!;
      expect(check.matches, isFalse);
      expect(check.localChecksum, isNot(check.serverChecksum));
      final w = warnings().single;
      expect(w.message, contains('group g1: balances differ'));
      expect(w.message, contains(checksumText(check.localChecksum)));
      expect(w.message, contains(checksumText(check.serverChecksum)));
    });

    test('is skipped while the group has rows not on the server', () async {
      await seedGoa(expenseState: SyncState.pending);
      open();
      remote.group = (_) => _serverGroup();
      expect(await c.read(balanceCheckerProvider).checkGroup('g1'), isNull);
      expect(remote.calls, isEmpty);
    });

    test('is null for a group this phone does not have', () async {
      open();
      expect(await c.read(balanceCheckerProvider).checkGroup('nope'), isNull);
      expect(remote.calls, isEmpty);
    });

    test('is null (not an error) when the server cannot be reached', () async {
      await seedGoa();
      open();
      remote.error = const NetworkException();
      expect(await c.read(balanceCheckerProvider).checkGroup('g1'), isNull);
      expect(warnings(), isEmpty);
    });
  });

  group('BalanceChecker.checkOverview', () {
    test('matching overview: no differences, no warning', () async {
      await seedGoa();
      open();
      remote.overview = _serverOverview;
      final check = (await c.read(balanceCheckerProvider).checkOverview())!;
      expect(check.matches, isTrue);
      expect(check.differences, isEmpty);
      expect(warnings(), isEmpty);
    });

    // TC-15-04
    test('TC-15-04 a differing group is listed and logged', () async {
      await seedGoa();
      open();
      remote.overview = () => _serverOverview(mine: 14999);
      final check = (await c.read(balanceCheckerProvider).checkOverview())!;
      expect(check.matches, isFalse);
      expect(check.differences, ['g1']);
      expect(warnings().single.message, contains('overview: groups g1 differ'));
    });

    test('is skipped while anything is unsynced', () async {
      await seedGoa(expenseState: SyncState.pending);
      open();
      remote.overview = _serverOverview;
      expect(await c.read(balanceCheckerProvider).checkOverview(), isNull);
      expect(remote.calls, isEmpty);
    });

    test('is skipped while the outbox has changes', () async {
      await seedGoa();
      await db.seed(outbox: [seedOutbox(1, 'group', 'upsert', 'g1')]);
      open();
      remote.overview = _serverOverview;
      expect(await c.read(balanceCheckerProvider).checkOverview(), isNull);
    });

    test('is null when the server cannot be reached', () async {
      await seedGoa();
      open();
      remote.error = const RemoteException('X');
      expect(await c.read(balanceCheckerProvider).checkOverview(), isNull);
    });
  });

  group('check providers', () {
    test('return null before the first sync without calling the server', () async {
      await seedGoa();
      open();
      c.listen(groupCheckProvider('g1'), (_, _) {});
      c.listen(overviewCheckProvider, (_, _) {});
      expect(await c.read(groupCheckProvider('g1').future), isNull);
      expect(await c.read(overviewCheckProvider.future), isNull);
      expect(remote.calls, isEmpty);
    });

    test('run the checks once a sync has finished', () async {
      await seedGoa();
      open(lastSync: syncedAt);
      remote.group = (_) => _serverGroup();
      remote.overview = _serverOverview;
      c.listen(groupCheckProvider('g1'), (_, _) {});
      c.listen(overviewCheckProvider, (_, _) {});
      expect((await c.read(groupCheckProvider('g1').future))!.matches, isTrue);
      expect((await c.read(overviewCheckProvider.future))!.matches, isTrue);
    });
  });

  group('groupBalancesProvider', () {
    test('shows local balances and no server mark when they match', () async {
      await seedGoa();
      open(lastSync: syncedAt);
      remote.group = (_) => _serverGroup();
      c.listen(groupCheckProvider('g1'), (_, _) {});
      await c.read(groupCheckProvider('g1').future);
      final b = (await until(groupBalancesProvider('g1'), (v) => v != null))!;
      expect(b.fromServer, isFalse);
      expect(b.unsynced, isFalse);
      expect(b.meId, 'm1');
      expect(b.myNets, {'INR': 15000});
      expect(b.owed('m2', 'm1', 'INR'), 15000);
    });

    // TC-15-04
    test('TC-15-04 a mismatch shows the server numbers', () async {
      await seedGoa();
      open(lastSync: syncedAt);
      remote.group = (_) => _serverGroup(off: 1);
      final b = (await until(groupBalancesProvider('g1'), (v) => v?.fromServer ?? false))!;
      expect(b.fromServer, isTrue);
      expect(b.owed('m2', 'm1', 'INR'), 15001);
      expect(b.myNets, {'INR': 15001});
      expect(b.members, hasLength(2));
      expect(warnings(), isNotEmpty);
    });

    test(
      'is marked unsynced while the group has pending rows, and the server is not asked',
      () async {
        await seedGoa(expenseState: SyncState.pending);
        open(lastSync: syncedAt);
        remote.group = (_) => _serverGroup(off: 5);
        final b = (await until(groupBalancesProvider('g1'), (v) => v?.unsynced ?? false))!;
        expect(b.fromServer, isFalse);
        expect(b.owed('m2', 'm1', 'INR'), 15000);
        expect(remote.calls, isEmpty);
      },
    );

    test('is data(null) for a group that is not on the phone', () async {
      open();
      expect(await until(groupBalancesProvider('nope'), (v) => v == null), isNull);
    });

    test('starts loading, and passes a ledger error through', () async {
      await seedGoa();
      open(
        extra: [groupLedgerProvider('bad').overrideWith((ref) => Stream.error(StateError('boom')))],
      );
      c.listen(groupBalancesProvider('g1'), (_, _) {});
      expect(c.read(groupBalancesProvider('g1')).isLoading, isTrue);
      await expectLater(until(groupBalancesProvider('bad'), (v) => true), throwsStateError);
    });
  });

  group('allGroupBalancesProvider', () {
    test('computes every live group', () async {
      await seedGoa();
      await db.seed(
        groups: [seedGroup(id: 'g2', name: 'Flat', createdAt: '2026-11-02T10:00:00Z')],
      );
      open();
      final all = await until(allGroupBalancesProvider, (v) => v.length == 2);
      expect([for (final g in all) g.groupId], ['g1', 'g2']);
      expect(all[1].hasRecords, isFalse);
      expect(all[1].allSettled, isTrue);
    });

    test('a ledger error comes through', () async {
      open(extra: [allLedgersProvider.overrideWith((ref) => Stream.error(StateError('boom')))]);
      await expectLater(until(allGroupBalancesProvider, (v) => true), throwsStateError);
    });
  });

  group('myBalancesProvider', () {
    test('local overall balances when everything matches', () async {
      await seedGoa();
      open(lastSync: syncedAt);
      remote.overview = _serverOverview;
      c.listen(overviewCheckProvider, (_, _) {});
      await c.read(overviewCheckProvider.future);
      final m = await until(myBalancesProvider, (v) => v.totals.isNotEmpty);
      expect(m.totals, {'INR': 15000});
      expect(m.byGroup, {
        'g1': {'INR': 15000},
      });
      expect(m.fromServer, isFalse);
      expect(m.unsynced, isFalse);
      expect([for (final p in m.people) p.name], ['Asha']);
      expect(m.peopleOwingMe, 1);
      expect(m.peopleIOwe, 0);
      expect(m.status, BalanceStatus.owed);
    });

    // TC-15-04
    test('TC-15-04 a mismatch shows the server numbers', () async {
      await seedGoa();
      open(lastSync: syncedAt);
      remote.overview = () => _serverOverview(mine: 14999);
      final m = await until(myBalancesProvider, (v) => v.fromServer);
      expect(m.totals, {'INR': 14999});
      expect(m.byGroup, {
        'g1': {'INR': 14999},
      });
      // The all-zero person is dropped; linked people key by user id.
      expect(
        [for (final p in m.people) (p.key, p.name, p.seed)],
        [('u:u2', 'Asha (server)', 'm2')],
      );
    });

    test('is marked unsynced while anything is pending', () async {
      await seedGoa(expenseState: SyncState.pending);
      open(lastSync: syncedAt);
      remote.overview = () => _serverOverview(mine: 1);
      final m = await until(myBalancesProvider, (v) => v.unsynced);
      expect(m.fromServer, isFalse);
      expect(m.totals, {'INR': 15000});
      expect(remote.calls, isEmpty);
    });

    test('a ledger error comes through', () async {
      open(extra: [allLedgersProvider.overrideWith((ref) => Stream.error(StateError('boom')))]);
      await expectLater(until(myBalancesProvider, (v) => true), throwsStateError);
    });
  });
}
