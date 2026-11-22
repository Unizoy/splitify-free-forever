// TC-29-01 (afterPush hook: photo uploads run after push, before pull; never fail the sync).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/sync_engine.dart';
import 'package:splitify/data/sync/sync_types.dart';

import 'sync_fakes.dart';

void main() {
  late AppDatabase db;
  late FakeRemoteApi remote;
  late FakeClock clock;
  late SyncEngine engine;
  late ExpensesRepository expenses;
  late List<String> order;
  late Future<void> Function() hook;

  setUp(() async {
    db = memoryDb();
    remote = FakeRemoteApi();
    clock = FakeClock(DateTime.utc(2026, 11, 21, 10));
    order = [];
    hook = () async => order.add('after');
    engine = SyncEngine(
      db: db,
      remote: remote,
      clock: clock,
      timer: ManualTimers().call,
      random: Random(1),
      afterPush: () => hook(),
    );
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
    remote.pullScript.add((c, s) {
      order.add('pull');
      return PullPage(serverTime: remote.serverTime, rows: const {}, nextCursors: c, userSeq: s);
    });
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  Future<void> queueOne() => expenses.save(gid, {
    'description': 'Tea',
    'date': '2026-11-21',
    'currency': 'INR',
    'total': 1000,
    'payers': {m1: 1000},
    'shares': {m1: 500, m2: 500},
  });

  // TC-29-01
  test('afterPush runs after a successful push and before the pull', () async {
    await queueOne();
    await engine.sync();
    expect(order, ['after', 'pull']);
    expect(remote.applied, hasLength(1));
    expect(engine.phase, SyncPhase.idle);
  });

  // TC-29-01
  test('an exception from afterPush is logged; the sync still pulls and ends idle', () async {
    hook = () async {
      order.add('after');
      throw Exception('upload broke');
    };
    await queueOne();
    await engine.sync();
    expect(order, ['after', 'pull']);
    expect(engine.phase, SyncPhase.idle);
    expect(engine.failures, 0);
  });

  // TC-29-01
  test('afterPush is not called when the push fails', () async {
    await queueOne();
    remote.applyScript.add((_) => const NetworkException('offline'));
    await engine.sync();
    expect(order, isEmpty);
    expect(engine.phase, SyncPhase.offline);
  });
}
