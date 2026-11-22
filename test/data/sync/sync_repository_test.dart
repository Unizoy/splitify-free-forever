// Phase 06 T5: sync status providers' data source (04 §9) + sign-out flush/wipe (04 §7).
import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
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

  group('phase 15', () {
    Future<void> upload(String id, {int attempts = 0, String record = 'r1'}) => db
        .into(db.pendingUploads)
        .insert(
          PendingUploadsCompanion.insert(
            id: id,
            bucket: 'receipts',
            localPath: 'p/$id.jpg',
            remotePath: 'g/$id.jpg',
            recordId: record,
            attempts: Value(attempts),
          ),
        );

    // TC-SYNC-OWNER: the local database belongs to one account.
    test('adoptOwner: first owner is set, same owner keeps data, another owner wipes', () async {
      expect(await repo.adoptOwner('u1'), isFalse);
      expect(await db.select(db.groups).get(), isNotEmpty);
      expect(await repo.adoptOwner('u1'), isFalse);
      expect(await db.select(db.groups).get(), isNotEmpty);
      expect(await engine.dao.meta(SyncRepository.ownerKey), 'u1');

      expect(await repo.adoptOwner('u2'), isTrue);
      expect(await db.select(db.groups).get(), isEmpty);
      expect(await db.select(db.groupMembers).get(), isEmpty);
      expect(await engine.dao.meta(SyncRepository.ownerKey), 'u2');
      expect(await repo.adoptOwner('u2'), isFalse);
    });

    // TC-SYNC-WAITING: only work that can still go up counts.
    test('hasWaiting: queued or retryable photo yes; failed or skipped only no', () async {
      expect(await repo.hasWaiting(), isFalse);
      await expenses.save(gid, data('A'));
      expect(await repo.hasWaiting(), isTrue);
      remote.applyScript.add(rejectAll);
      await repo.syncNow();
      expect((await repo.watchIssues().first), hasLength(1));
      expect(await repo.hasWaiting(), isFalse);

      await upload('u-skipped', attempts: 8);
      expect(await repo.hasWaiting(), isFalse);
      await upload('u-retrying', attempts: 7);
      expect(await repo.hasWaiting(), isTrue);
    });

    test('hasWaiting: a fresh pending photo alone is waiting', () async {
      await upload('u-new');
      expect(await repo.hasWaiting(), isTrue);
    });

    // TC-SYNC-UPLOADS: skipped first, then by id.
    test('watchUploads: skipped photos first, flag follows attempts', () async {
      await upload('a', attempts: 1);
      await upload('b', attempts: 8);
      await upload('c');
      final list = await repo.watchUploads().first;
      expect(list.map((u) => u.id), ['b', 'a', 'c']);
      expect(list.map((u) => u.skipped), [true, false, false]);
      expect(list.first.bucket, 'receipts');
      expect(list.first.recordId, 'r1');
      expect(list.first, list.first);
      expect(list.first.hashCode, list.first.hashCode);
    });

    test('retryUpload gives a skipped photo a fresh set of tries and syncs', () async {
      await upload('b', attempts: 8);
      final pulls = remote.pulls.length;
      await repo.retryUpload('b');
      final row = (await db.select(db.pendingUploads).get()).single;
      expect(row.attempts, 0);
      expect((await repo.watchUploads().first).single.skipped, isFalse);
      expect(remote.pulls.length, greaterThan(pulls));
    });

    // TC-SYNC-GROUP-MARKER: one query for every group card.
    test('watchUnsyncedGroupIds: groups with a not-synced row', () async {
      expect(await repo.watchUnsyncedGroupIds().first, isEmpty);
      await expenses.save(gid, data('A'));
      expect(await repo.watchUnsyncedGroupIds().first, {gid});
    });

    test('issue targets come from the comment payload; bad payload gives none', () async {
      await engine.queue.enqueue(
        entity: SyncEntity.comment,
        op: SyncOp.upsert,
        recordId: 'c1',
        groupId: gid,
        data: {'target_type': 'payment', 'target_id': 'p9', 'body': 'hi'},
        clientUpdatedAt: '2026-11-21T10:00:00Z',
        createdAt: '2026-11-21T10:00:00Z',
      );
      await engine.queue.enqueue(
        entity: SyncEntity.comment,
        op: SyncOp.upsert,
        recordId: 'c2',
        groupId: gid,
        data: {'body': 'x'},
        clientUpdatedAt: '2026-11-21T10:00:01Z',
        createdAt: '2026-11-21T10:00:01Z',
      );
      remote.applyScript.add(rejectAll);
      await repo.syncNow();
      await db.customStatement("UPDATE outbox SET payload = 'not json' WHERE record_id = 'c2'");
      final issues = await repo.watchIssues().first;
      final c1 = issues.firstWhere((i) => i.recordId == 'c1');
      final c2 = issues.firstWhere((i) => i.recordId == 'c2');
      expect((c1.entity, c1.targetType, c1.targetId), (SyncEntity.comment, 'payment', 'p9'));
      expect((c2.targetType, c2.targetId), (null, null));
    });
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
