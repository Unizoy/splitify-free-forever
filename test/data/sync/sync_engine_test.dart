// TC-27-01…10: sync engine suite (planning/04-sync-engine.md §10) with FakeRemoteApi + FakeClock + in-memory Drift.
import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/sync_engine.dart';
import 'package:splitify/data/sync/sync_triggers.dart';
import 'package:splitify/data/sync/sync_types.dart';

import 'sync_fakes.dart';

void main() {
  late AppDatabase db;
  late FakeRemoteApi remote;
  late FakeClock clock;
  late ManualTimers timers;
  late SyncEngine engine;
  late LocalWriter writer;
  late ExpensesRepository expenses;
  var signedOut = 0;

  SyncEngine buildEngine({int batchSize = 50, int pageSize = 500}) => SyncEngine(
    db: db,
    remote: remote,
    clock: clock,
    timer: timers.call,
    random: Random(1),
    batchSize: batchSize,
    pageSize: pageSize,
    onSignedOut: () async => signedOut++,
  );

  setUp(() async {
    db = memoryDb();
    remote = FakeRemoteApi();
    clock = FakeClock(DateTime.utc(2026, 11, 21, 10));
    timers = ManualTimers();
    signedOut = 0;
    engine = buildEngine();
    writer = LocalWriter(db, clock, engine.serverClock);
    expenses = ExpensesRepository(db, writer);
    // A synced group with two members.
    await engine.applier.apply(
      PullPage(
        serverTime: remote.serverTime,
        rows: {
          'groups': [serverGroup()],
          'group_members': [serverMember(m1, 0), serverMember(m2, 1)],
        },
        nextCursors: const {gid: 2},
        userSeq: 0,
      ),
    );
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  Map<String, Object?> expenseData(String description, {int total = 10000}) => {
    'description': description,
    'date': '2026-11-21',
    'currency': 'INR',
    'total': total,
    'payers': {m1: total},
    'shares': {m1: total - total ~/ 2, m2: total ~/ 2},
  };

  Future<List<OutboxItem>> outbox() => db.select(db.outbox).get();
  Future<LocalExpense> expense(String id) =>
      (db.select(db.expenses)..where((e) => e.id.equals(id))).getSingle();

  test('TC-27-01 mutations are pushed in local order, across batches', () async {
    engine = buildEngine(batchSize: 2);
    final a = await expenses.save(gid, expenseData('A'));
    await expenses.save(gid, expenseData('A2'), id: a);
    final b = await expenses.save(gid, expenseData('B'));
    await expenses.delete(b, gid);
    await engine.sync();
    final sent = [for (final batch in remote.applied) ...batch];
    expect(remote.applied.map((b) => b.length), [2, 2]);
    expect(sent.map((m) => (m['id'], m['op'])), [
      (a, 'upsert'),
      (a, 'upsert'),
      (b, 'upsert'),
      (b, 'delete'),
    ]);
    expect((sent[1]['data']! as Map)['description'], 'A2');
    expect(sent.first['entity'], 'expense');
    expect(sent.first['group_id'], gid);
    expect(await outbox(), isEmpty);
    // Applied rows stay pending until the pull brings their seq.
    expect((await expense(a)).syncState, SyncState.pending);
    expect(engine.phase, SyncPhase.idle);
    expect(await engine.dao.meta(SyncEngine.lastSyncKey), isNotNull);
  });

  test('TC-27-02 a network failure re-sends the same mutation ids; duplicates are done', () async {
    final a = await expenses.save(gid, expenseData('A'));
    remote.applyScript.add((_) => const NetworkException('offline'));
    await engine.sync();
    expect(engine.phase, SyncPhase.offline);
    expect(engine.failures, 1);
    expect(engine.lastError, 'offline');
    final item = (await outbox()).single;
    expect(item.status, OutboxStatus.queued);
    expect(item.attempts, 1);
    expect(timers.scheduled.last.$1.inMilliseconds, inInclusiveRange(1000, 2000));

    remote.applyScript.add(
      (batch) => appliedAll(batch, remote.serverTime, MutationStatus.duplicate),
    );
    timers.scheduled.last.$2();
    await pumpEventQueue();
    await engine.sync();
    expect(remote.applied[1].single['mutation_id'], remote.applied[0].single['mutation_id']);
    expect(await outbox(), isEmpty);
    expect(engine.failures, 0);
    expect((await expense(a)).description, 'A');
  });

  test(
    'TC-27-03 last write wins both ways: applied then synced; superseded then server copy',
    () async {
      final a = await expenses.save(gid, expenseData('Mine'));
      remote.pullScript.add(
        (c, u) => PullPage(
          serverTime: remote.serverTime,
          rows: {
            'expenses': [serverExpense(a, seq: 10, description: 'Mine')],
          },
          nextCursors: const {gid: 10},
          userSeq: 0,
        ),
      );
      await engine.sync();
      expect((await expense(a)).syncState, SyncState.synced);

      // Older local edit loses to a newer server edit.
      await expenses.save(gid, expenseData('Older edit'), id: a);
      final lost = <int>[];
      final sub = engine.superseded.listen(lost.add);
      remote.applyScript.add(
        (batch) => appliedAll(batch, remote.serverTime, MutationStatus.superseded),
      );
      remote.pullScript.add(
        (c, u) => PullPage(
          serverTime: remote.serverTime,
          rows: {
            'expenses': [serverExpense(a, seq: 11, description: 'Their newer edit')],
          },
          nextCursors: const {gid: 11},
          userSeq: 0,
        ),
      );
      await engine.sync();
      await pumpEventQueue();
      await sub.cancel();
      expect(lost, [1]);
      expect((await expense(a)).description, 'Their newer edit');
      expect((await expense(a)).syncState, SyncState.synced);
    },
  );

  test('TC-27-04 client_updated_at uses the server clock offset, not the phone clock', () async {
    remote.serverTime = clock.time.add(const Duration(minutes: 5));
    await engine.sync();
    expect(await engine.serverClock.offset(), const Duration(minutes: 5));
    await expenses.save(gid, expenseData('A'));
    expect((await outbox()).single.clientUpdatedAt, '2026-11-21T10:05:00.000Z');
    // The offset survives a restart (stored in sync_meta).
    final again = buildEngine();
    expect(await again.serverClock.offset(), const Duration(minutes: 5));
    await again.dispose();
  });

  test('TC-27-05 pages are pulled until has_more is false with advancing cursors', () async {
    engine = buildEngine(pageSize: 2);
    remote.pullScript
      ..add(
        (c, u) => PullPage(
          serverTime: remote.serverTime,
          rows: {
            'expenses': [serverExpense('e1', seq: 3), serverExpense('e2', seq: 4)],
          },
          nextCursors: const {gid: 4},
          userSeq: 0,
          hasMore: true,
        ),
      )
      ..add(
        (c, u) => PullPage(
          serverTime: remote.serverTime,
          rows: {
            'expenses': [serverExpense('e3', seq: 5)],
            'profiles': [
              {'id': 'u1', 'display_name': 'Asha', 'default_currency': 'INR', 'seq': 7},
            ],
          },
          nextCursors: const {gid: 5},
          userSeq: 7,
        ),
      );
    await engine.sync();
    expect(remote.pulls, [
      {gid: 2},
      {gid: 4},
    ]);
    expect(await db.select(db.expenses).get(), hasLength(3));
    expect(await engine.dao.groupCursors(), {gid: 5});
    expect(await engine.dao.userCursor(), 7);
    final parts = await db.select(db.expenseParts).get();
    expect(parts, hasLength(6));
    expect(parts.where((p) => p.memberId == m1).first.paid, 10000);
    expect(parts.where((p) => p.memberId == m2).first.owed, 5000);
  });

  test('TC-27-06 tombstones are stored but hidden, with no balance parts', () async {
    remote.pullScript.add(
      (c, u) => PullPage(
        serverTime: remote.serverTime,
        rows: {
          'expenses': [
            serverExpense('e1', seq: 3),
            serverExpense('e2', seq: 4, deletedAt: '2026-11-21T09:00:00Z', fxRate: 83.1234567891),
          ],
        },
        nextCursors: const {gid: 4},
        userSeq: 0,
      ),
    );
    await engine.sync();
    expect(await db.select(db.expenses).get(), hasLength(2));
    expect((await expenses.watchForGroup(gid).first).map((e) => e.id), ['e1']);
    expect((await expense('e2')).fxRate, '83.1234567891');
    expect((await expenses.watchParts(gid).first).map((p) => p.expenseId).toSet(), {'e1'});
  });

  test(
    'TC-27-07 a page that fails mid-way is rolled back and pulled again; in-flight items resume',
    () async {
      final bad = serverExpense('e2', seq: 4)..remove('description');
      remote.pullScript.add(
        (c, u) => PullPage(
          serverTime: remote.serverTime,
          rows: {
            'expenses': [serverExpense('e1', seq: 3), bad],
          },
          nextCursors: const {gid: 4},
          userSeq: 0,
        ),
      );
      await engine.sync();
      expect(engine.phase, SyncPhase.error);
      expect(engine.lastError, 'LOCAL_ERROR');
      expect(await db.select(db.expenses).get(), isEmpty);
      expect(await engine.dao.groupCursors(), {gid: 2});

      // Killed while a push was in flight: the item is queued again on the next run.
      await expenses.save(gid, expenseData('A'));
      await engine.queue.markInFlight(await outbox());
      await engine.sync();
      expect(remote.pulls.last, {gid: 2});
      expect(remote.applied, hasLength(1));
      expect(await outbox(), isEmpty);
    },
  );

  test(
    'TC-27-08 rejected mutations fail item and row, block only their record; retry and discard',
    () async {
      final a = await expenses.save(gid, expenseData('Bad'));
      final b = await expenses.save(gid, expenseData('Good'));
      remote.applyScript.add(
        (batch) => ApplyResponse(remote.serverTime, [
          MutationResult(
            batch[0]['mutation_id']! as String,
            MutationStatus.rejected,
            code: 'SPLIT_SUM_MISMATCH',
          ),
          MutationResult(batch[1]['mutation_id']! as String, MutationStatus.applied),
        ]),
      );
      await engine.sync();
      final failed = (await outbox()).single;
      expect(
        (failed.recordId, failed.status, failed.lastError),
        (a, OutboxStatus.failed, 'SPLIT_SUM_MISMATCH'),
      );
      expect((await expense(a)).syncState, SyncState.failed);
      expect(await engine.queue.watchCount(OutboxStatus.failed).first, 1);
      expect(await engine.queue.watchFailed().first, hasLength(1));

      // A later edit of the same record waits; other records still go.
      await expenses.save(gid, expenseData('Bad again'), id: a);
      final c = await expenses.save(gid, expenseData('Other'));
      await engine.sync();
      expect(remote.applied.last.map((m) => m['id']), [c]);
      expect(b, isNotNull);

      await engine.queue.retry(failed.seq);
      expect((await expense(a)).syncState, SyncState.pending);
      await engine.queue.retry(99999); // unknown: no-op
      remote.applyScript.add(
        (batch) => ApplyResponse(remote.serverTime, [
          for (final m in batch)
            MutationResult(m['mutation_id']! as String, MutationStatus.rejected),
        ]),
      );
      await engine.sync();
      expect((await outbox()).map((o) => o.lastError), ['REJECTED', 'REJECTED']);

      await engine.queue.discard((await outbox()).first.seq);
      await engine.queue.discard(99999);
      expect(await outbox(), isEmpty);
      expect(await db.select(db.expenses).get(), hasLength(2)); // never-synced local row removed
      expect(await engine.dao.groupCursors(), {gid: 0}); // group re-pulled
    },
  );

  test('TC-27-09 a 401 refreshes once; a second 401 signs out and keeps the outbox', () async {
    await expenses.save(gid, expenseData('A'));
    remote.applyScript.add((_) => const AuthExpiredException());
    await engine.sync();
    expect(remote.refreshes, 1);
    expect(await outbox(), isEmpty);
    expect(engine.phase, SyncPhase.idle);

    await expenses.save(gid, expenseData('B'));
    remote.applyScript.add((_) => const AuthExpiredException());
    remote.refreshError = const AuthExpiredException();
    await engine.sync();
    expect(engine.phase, SyncPhase.signedOut);
    expect(signedOut, 1);
    expect((await outbox()).single.status, OutboxStatus.queued);
    expect(await db.select(db.expenses).get(), hasLength(2));
  });

  test('TC-27-10 losing access to a group removes it locally', () async {
    await expenses.save(gid, expenseData('A'));
    remote.applyScript.add((_) => const NetworkException());
    await engine.sync();
    remote.pullScript.add(
      (c, u) => PullPage(
        serverTime: remote.serverTime,
        rows: const {},
        nextCursors: const {gid: 9},
        userSeq: 0,
        lostGroups: const [gid],
      ),
    );
    await engine.applier.apply(await remote.pullChanges(cursors: const {}, userSeq: 0));
    expect(await db.select(db.groups).get(), isEmpty);
    expect(await db.select(db.groupMembers).get(), isEmpty);
    expect(await db.select(db.expenses).get(), isEmpty);
    expect(await outbox(), isEmpty);
    expect(await engine.dao.groupCursors(), isEmpty);
  });

  group('engine details', () {
    test('pending local edits are not overwritten by a pull', () async {
      final a = await expenses.save(gid, expenseData('Local'));
      remote.applyScript.add((_) => const NetworkException());
      await engine.sync();
      await engine.applier.apply(
        PullPage(
          serverTime: remote.serverTime,
          rows: {
            'expenses': [serverExpense(a, seq: 20, description: 'Server')],
          },
          nextCursors: const {gid: 20},
          userSeq: 0,
        ),
      );
      expect((await expense(a)).description, 'Local');
    });

    test('backoff doubles from 2 s to a 5 min cap with jitter', () {
      for (final (n, max) in [(1, 2000), (2, 4000), (3, 8000), (9, 300000), (40, 300000)]) {
        final d = engine.backoff(n).inMilliseconds;
        expect(d, inInclusiveRange(max ~/ 2, max), reason: 'attempt $n');
      }
    });

    test('single flight: a sync requested while running runs once more', () async {
      final gate = Completer<void>();
      remote.pullScript.add((c, u) {
        return PullPage(serverTime: remote.serverTime, rows: const {}, nextCursors: c, userSeq: u);
      });
      final first = engine.sync();
      final second = engine.sync();
      expect(identical(first, second), isTrue);
      gate.complete();
      await first;
      expect(remote.pulls, hasLength(2));
    });

    test('server errors back off; requestSync is debounced', () async {
      remote.pullScript.add((c, u) => const RemoteException('PGRST100'));
      final phases = <SyncPhase>[];
      final sub = engine.phases.listen(phases.add);
      await engine.sync();
      await pumpEventQueue();
      await sub.cancel();
      expect(phases, [SyncPhase.syncing, SyncPhase.error]);
      expect(engine.lastError, 'PGRST100');
      engine
        ..requestSync()
        ..requestSync();
      expect(timers.scheduled.last.$1, const Duration(seconds: 1));
      timers.scheduled.last.$2();
      await pumpEventQueue();
      expect(engine.phase, SyncPhase.idle);
    });

    test('a batch without results stays queued', () async {
      await expenses.save(gid, expenseData('A'));
      remote.applyScript.add((_) => ApplyResponse(remote.serverTime, const []));
      await engine.sync();
      expect((await outbox()).single.lastError, 'NO_RESULT');
    });

    test('triggers sync on reconnect, nudge and resume', () async {
      final online = StreamController<bool>();
      final nudges = StreamController<void>();
      var runs = 0;
      final t = SyncTriggers(
        sync: () async => runs++,
        online: online.stream,
        nudges: nudges.stream,
      );
      online
        ..add(true)
        ..add(false)
        ..add(true);
      nudges.add(null);
      await pumpEventQueue();
      t.onResume();
      expect(runs, 3);
      await t.dispose();
    });
  });

  group('writes', () {
    test('a write updates the row and the outbox in one transaction', () async {
      final groups = GroupsRepository(db, writer);
      final id = await groups.create(name: 'Flat', ownerName: 'Me', type: 'home');
      expect((await groups.watchAll().first).map((g) => g.name), ['Flat', 'Goa']);
      final item = (await outbox()).single;
      expect((item.entity, item.op, item.recordId, item.groupId), ('group', 'upsert', id, id));
      expect(
        engine.queue.toWire(item)['data'],
        containsPair('owner_member', isA<Map<String, Object?>>()),
      );
      final members = MembersRepository(db, writer);
      expect((await members.watchForGroup(id).first).single.role, 'owner');
      await members.addNameOnly(id, 'Ravi');
      expect((await members.watchForGroup(id).first).map((m) => m.position), [0, 1]);
      await groups.update(id, {'name': 'Flat 2'});
      expect((await groups.watchOne(id).first)!.name, 'Flat 2');
      expect(await watchGroupUnsynced(db, id).first, isTrue);
      expect(await watchGroupUnsynced(db, gid).first, isFalse);
    });

    test('delete and restore are soft; payments and comments repos', () async {
      final a = await expenses.save(gid, expenseData('A'));
      await expenses.delete(a, gid);
      expect(await expenses.watchForGroup(gid).first, isEmpty);
      expect((await expense(a)).deletedAt, isNotNull);
      expect(await expenses.watchParts(gid).first, isEmpty);
      await expenses.restore(a, gid);
      expect(await expenses.watchOne(a).first, isNotNull);
      expect(await expenses.watchParts(gid).first, hasLength(2));

      final payments = PaymentsRepository(db, writer);
      await payments.save(gid, {
        'from_member': m2,
        'to_member': m1,
        'amount': 5000,
        'currency': 'INR',
        'date': '2026-11-21',
      });
      expect(await payments.watchForGroup(gid).first, hasLength(1));
      final comments = CommentsRepository(db, writer);
      final c = await comments.save(gid, {
        'target_type': 'expense',
        'target_id': a,
        'body': 'Nice',
      });
      expect(await comments.watchForTarget(a).first, hasLength(1));
      await comments.delete(c, gid);
      expect(await comments.watchForTarget(a).first, isEmpty);
      expect((await outbox()).map((o) => o.op), [
        'upsert',
        'delete',
        'restore',
        'upsert',
        'upsert',
        'delete',
      ]);
    });

    test('wipe empties every table', () async {
      await expenses.save(gid, expenseData('A'));
      await db.wipe();
      expect(await db.select(db.groups).get(), isEmpty);
      expect(await outbox(), isEmpty);
      final dao = SyncDao(db);
      await dao.setMeta('k', 'v');
      expect(await dao.watchMeta('k').first, 'v');
      expect(
        await db
            .customSelect('SELECT count(*) AS c FROM expense_search')
            .map((r) => r.read<int>('c'))
            .getSingle(),
        0,
      );
    });
  });
}
