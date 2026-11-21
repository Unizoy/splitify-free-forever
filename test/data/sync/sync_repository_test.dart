// Phase 06 T5: sync status providers' data source (04 §9) + sign-out flush/wipe (04 §7).
import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/sync_engine.dart';
import 'package:splitify/data/sync/sync_types.dart';

import 'sync_fakes.dart';

void main() {
  late AppDatabase db;
  late FakeRemoteApi remote;
  late FakeClock clock;
  late SyncEngine engine;
  late SyncRepository repo;
  late ExpensesRepository expenses;

  setUp(() async {
    db = memoryDb();
    remote = FakeRemoteApi();
    clock = FakeClock(DateTime.utc(2026, 11, 21, 10));
    engine = SyncEngine(
      db: db,
      remote: remote,
      clock: clock,
      timer: ManualTimers().call,
      random: Random(1),
    );
    repo = SyncRepository(engine);
    expenses = ExpensesRepository(db, LocalWriter(db, clock, engine.serverClock));
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

  Map<String, Object?> data(String d) => {
    'description': d,
    'date': '2026-11-21',
    'currency': 'INR',
    'total': 1000,
    'payers': {m1: 1000},
    'shares': {m1: 500, m2: 500},
  };

  ApplyResponse rejectAll(List<Map<String, Object?>> batch) => ApplyResponse(remote.serverTime, [
    for (final m in batch)
      MutationResult(m['mutation_id']! as String, MutationStatus.rejected, code: 'NOT_MEMBER'),
  ]);

  test('status: never synced and empty, then waiting, offline, synced', () async {
    final seen = <SyncStatus>[];
    final sub = repo.watchStatus().listen(seen.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(seen.last, const SyncStatus(phase: SyncPhase.idle));
    expect(seen.last.allSynced, isTrue);

    await expenses.save(gid, data('Tea'));
    await pumpEventQueue();
    expect(seen.last.waiting, 1);
    expect(seen.last.allSynced, isFalse);

    remote.applyScript.add((_) => const NetworkException('offline'));
    await repo.syncNow();
    await pumpEventQueue();
    expect(seen.map((s) => s.phase), contains(SyncPhase.syncing));
    expect(seen.last.phase, SyncPhase.offline);
    expect(seen.last.lastError, 'offline');
    expect(seen.last.waiting, 1);

    await repo.syncNow();
    await pumpEventQueue();
    expect(seen.last.phase, SyncPhase.idle);
    expect(seen.last.waiting, 0);
    expect(seen.last.lastSync, clock.time);
    expect(seen.last.hashCode, seen.last.hashCode);
  });

  test('issues: refused changes listed, retry re-sends, discard drops the change', () async {
    final a = await expenses.save(gid, data('A'));
    final b = await expenses.save(gid, data('B'));
    remote.applyScript.add(rejectAll);
    await repo.syncNow();
    final issues = await repo.watchIssues().first;
    expect(issues.map((i) => i.recordId), [a, b]);
    final first = issues.first;
    expect(first.entity, SyncEntity.expense);
    expect(first.op, SyncOp.upsert);
    expect(first.groupId, gid);
    expect(first.code, 'NOT_MEMBER');
    expect(first.attempts, 1);
    expect(first.createdAt, isNotNull);
    expect((await repo.watchStatus().first).failed, 2);

    await repo.retry(first.seq);
    expect((await repo.watchIssues().first).map((i) => i.recordId), [b]);
    expect(remote.applied.last.single['id'], a);

    await repo.discard(issues.last.seq);
    expect(await repo.watchIssues().first, isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('unsynced markers: any row or outbox item, and per group', () async {
    expect(await repo.watchAnyUnsynced().first, isFalse);
    expect(await repo.watchGroupUnsynced(gid).first, isFalse);
    await expenses.save(gid, data('A'));
    expect(await repo.watchAnyUnsynced().first, isTrue);
    expect(await repo.watchGroupUnsynced(gid).first, isTrue);
  });

  test('sign-out push: sends the outbox; offline or slow → false within the timeout', () async {
    await expenses.save(gid, data('A'));
    expect(await repo.pushBeforeSignOut(), isTrue);
    expect(remote.applied, hasLength(1));

    await expenses.save(gid, data('B'));
    remote.applyScript.add((_) => const NetworkException('offline'));
    expect(await repo.pushBeforeSignOut(), isFalse);

    final never = Completer<ApplyResponse>();
    final slow = SyncRepository(
      SyncEngine(db: db, remote: _SlowRemote(never.future), clock: clock),
    );
    expect(await slow.pushBeforeSignOut(timeout: const Duration(milliseconds: 20)), isFalse);
  });

  test('wipeLocal deletes every row', () async {
    await expenses.save(gid, data('A'));
    await repo.wipeLocal();
    expect(await db.select(db.expenses).get(), isEmpty);
    expect(await db.select(db.groups).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  test('unconfigured remote behaves like offline', () async {
    const r = UnconfiguredRemoteApi();
    await expectLater(r.applyMutations(const []), throwsA(isA<NetworkException>()));
    await expectLater(
      r.pullChanges(cursors: const {}, userSeq: 0),
      throwsA(isA<NetworkException>()),
    );
    await expectLater(r.refreshSession(), throwsA(isA<AuthExpiredException>()));
  });
}

class _SlowRemote extends FakeRemoteApi {
  _SlowRemote(this.reply);

  final Future<ApplyResponse> reply;

  @override
  Future<ApplyResponse> applyMutations(List<Map<String, Object?>> batch) => reply;
}
