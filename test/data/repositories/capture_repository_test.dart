// TC-X4-02 (app side): importing, dismissing and expiring "payments to add"; recent chips for the bubble.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/capture_repository.dart';

import '../../support/capture_fakes.dart';
import '../../support/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeCaptureBridge bridge;
  late FakeClock clock;
  late CaptureRepository repo;

  final now = DateTime.utc(2026, 11, 21, 10);

  setUp(() {
    db = testDb();
    bridge = FakeCaptureBridge();
    clock = FakeClock(now);
    repo = CaptureRepository(db, bridge, clock);
  });
  tearDown(() => db.close());

  Future<List<LocalPaymentCapture>> rows() => db.select(db.paymentCaptures).get();

  Map<String, Object?> raw(
    String id, {
    Duration ago = const Duration(hours: 1),
    int amount = 50000,
  }) => rawCapture(id: id, amount: amount, at: now.subtract(ago));

  group('importNow', () {
    // TC-X4-02
    test('stores valid records and acks them together with the invalid ids', () async {
      bridge.captures = [
        raw(captureId1, amount: 125050),
        {...raw(captureId2), 'amount': -5}, // invalid: not positive
        {...raw(captureId3), 'currency': 'USD'}, // invalid: not INR
        'garbage', // no id: nothing to ack
      ];
      final n = await repo.importNow();
      expect(n, 1);
      final stored = await rows();
      expect(stored.map((r) => r.id), [captureId1]);
      expect(stored.single.amount, 125050);
      expect(stored.single.ref, '612345678901');
      expect(bridge.acks, hasLength(1));
      expect(bridge.acks.single.captures, [captureId1, captureId2, captureId3]);
      expect(bridge.acks.single.dismissed, isEmpty);
    });

    // TC-X4-02
    test('nothing to import: no ack', () async {
      expect(await repo.importNow(), 0);
      expect(bridge.acks, isEmpty);
    });

    // TC-X4-02
    test('applies tombstones from the bubble: dismissed rows are deleted and acked', () async {
      bridge.captures = [raw(captureId1), raw(captureId2)];
      await repo.importNow();
      expect(await rows(), hasLength(2));

      bridge
        ..captures = const []
        ..dismissedByBubble = [captureId1];
      expect(await repo.importNow(), 0);
      expect((await rows()).map((r) => r.id), [captureId2]);
      expect(bridge.acks.last.dismissed, [captureId1]);
    });

    // TC-X4-02
    test('drops records older than 7 days and purges stored ones that expire', () async {
      bridge.captures = [
        raw(captureId1, ago: const Duration(days: 8)),
        raw(captureId2, ago: const Duration(days: 6)),
      ];
      await repo.importNow();
      expect((await rows()).map((r) => r.id), [captureId2]);
      // The old one was refused, so it is acked as bad and the phone forgets it.
      expect(bridge.acks.single.captures, [captureId2, captureId1]);

      clock.advance(const Duration(days: 2));
      bridge.captures = const [];
      await repo.importNow();
      expect(await rows(), isEmpty);
    });

    // TC-X4-02
    test('importing the same record twice keeps one row', () async {
      bridge.captures = [raw(captureId1)];
      await repo.importNow();
      await repo.importNow();
      expect(await rows(), hasLength(1));
    });

    // TC-X4-02
    test('concurrent calls share one run', () async {
      final gate = Completer<void>();
      bridge
        ..captures = [raw(captureId1)]
        ..exportGate = gate.future;
      final a = repo.importNow();
      final b = repo.importNow();
      gate.complete();
      expect(await a, 1);
      expect(await b, 1);
      expect(bridge.exports, 1);
      // A later call starts a new run.
      await repo.importNow();
      expect(bridge.exports, 2);
    });
  });

  group('watchPending / get / remove / dismiss', () {
    // TC-X4-02
    test('newest first, expired rows hidden', () async {
      bridge.captures = [
        raw(captureId1, ago: const Duration(hours: 5)),
        raw(captureId2, ago: const Duration(hours: 1)),
        raw(captureId3, ago: const Duration(days: 3)),
      ];
      await repo.importNow();
      expect((await repo.watchPending().first).map((c) => c.id), [
        captureId2,
        captureId1,
        captureId3,
      ]);

      // Still in the table but past 7 days: hidden before the next purge.
      clock.advance(const Duration(days: 5));
      expect((await repo.watchPending().first).map((c) => c.id), [captureId2, captureId1]);
    });

    // TC-X4-02
    test('get returns the parsed capture or null', () async {
      bridge.captures = [raw(captureId1, amount: 125050)];
      await repo.importNow();
      final c = await repo.get(captureId1);
      expect(c!.amount, 125050);
      expect(c.payee, 'Rahul');
      expect(c.appName, 'Google Pay');
      expect(c.capturedAt, now.subtract(const Duration(hours: 1)));
      expect(await repo.get(captureId2), isNull);
    });

    // TC-X4-02
    test('remove deletes only the row; dismiss also tells the bridge', () async {
      bridge.captures = [raw(captureId1), raw(captureId2)];
      await repo.importNow();

      await repo.remove(captureId1);
      expect((await rows()).map((r) => r.id), [captureId2]);
      expect(bridge.dismissed, isEmpty);

      await repo.dismiss(captureId2);
      expect(await rows(), isEmpty);
      expect(bridge.dismissed, [captureId2]);
    });
  });

  group('recentChips', () {
    Future<void> addGroup(
      String id,
      String name,
      String created, {
      String type = 'other',
      String? archived,
    }) => db.customStatement(
      'INSERT INTO "groups" (id, name, type, created_at, archived_at) VALUES (?, ?, ?, ?, ?)',
      [id, name, type, created, archived],
    );

    Future<void> addMember(
      String id,
      String groupId,
      String name, {
      String? userId,
      int position = 0,
    }) => db.customStatement(
      'INSERT INTO group_members (id, group_id, user_id, display_name, position) VALUES (?, ?, ?, ?, ?)',
      [id, groupId, userId, name, position],
    );

    Future<void> addExpense(String id, String groupId, String created, {String? deleted}) =>
        db.customStatement(
          'INSERT INTO expenses (id, group_id, description, date, currency, total, payers, shares, '
          "created_at, deleted_at) VALUES (?, ?, 'x', '2026-11-20', 'INR', 100, '{}', '{}', ?, ?)",
          [id, groupId, created, deleted],
        );

    // TC-X4-02
    test('orders by latest expense, names a direct group by the other member', () async {
      await addGroup('g-trip', 'Goa trip', '2026-11-01T00:00:00Z');
      await addGroup('g-flat', 'Flat 4B', '2026-11-02T00:00:00Z');
      await addGroup('g-asha', 'Asha and me', '2026-11-10T00:00:00Z', type: 'direct');
      await addGroup('g-old', 'Old trip', '2026-11-19T00:00:00Z', archived: '2026-11-20T00:00:00Z');
      await addMember('m1', 'g-asha', 'Mohit', userId: 'u1');
      await addMember('m2', 'g-asha', 'Asha', position: 1);
      await addExpense('e1', 'g-trip', '2026-11-20T08:00:00Z');
      await addExpense('e2', 'g-flat', '2026-11-12T08:00:00Z');
      // A deleted expense does not count as use.
      await addExpense('e3', 'g-flat', '2026-11-21T08:00:00Z', deleted: '2026-11-21T09:00:00Z');

      final chips = await repo.recentChips(myUserId: 'u1');
      expect(chips.map((c) => (c.id, c.name, c.friend)), [
        ('g-trip', 'Goa trip', false), // expense on 20 Nov
        ('g-flat', 'Flat 4B', false), // expense on 12 Nov
        ('g-asha', 'Asha', true), // created 10 Nov, named by the other member
      ]);
    });

    // TC-X4-02
    test('respects the limit and skips archived groups', () async {
      await addGroup('g-a', 'A', '2026-11-01T00:00:00Z');
      await addGroup('g-b', 'B', '2026-11-02T00:00:00Z');
      await addGroup('g-c', 'C', '2026-11-03T00:00:00Z');
      await addGroup('g-old', 'Old', '2026-11-09T00:00:00Z', archived: '2026-11-10T00:00:00Z');
      final chips = await repo.recentChips(myUserId: null, limit: 2);
      expect(chips.map((c) => c.id), ['g-c', 'g-b']);
    });

    // TC-X4-02
    test('leaves out a direct group with no other member to name', () async {
      await addGroup('g-dm', 'dm', '2026-11-03T00:00:00Z', type: 'direct');
      await addMember('m1', 'g-dm', 'Mohit', userId: 'u1');
      expect(await repo.recentChips(myUserId: 'u1'), isEmpty);
    });
  });
}
