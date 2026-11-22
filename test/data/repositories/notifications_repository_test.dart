import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/repositories/notifications_repository.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';

import '../../support/fakes.dart';

/// Hand-written server: rows by seq, settings, scripted failures and gates.
class FakeNotificationsRemote implements NotificationsRemote {
  final rows = <Map<String, Object?>>[];
  Map<String, Object?>? settingsRow;
  Exception? fail;

  /// Held until completed, when set (consumed once).
  Completer<void>? notificationsGate;
  Completer<void>? settingsGate;
  Completer<void>? saveGate;

  final fetches = <({int afterSeq, int limit, bool newest})>[];
  final markReads = <List<String>?>[];
  final saves = <({Map<String, Object?> kinds, List<String> muted})>[];
  var settingsCalls = 0;

  @override
  Future<List<Map<String, Object?>>> notifications({
    int afterSeq = 0,
    int limit = 200,
    bool newest = false,
  }) async {
    fetches.add((afterSeq: afterSeq, limit: limit, newest: newest));
    if (fail != null) throw fail!;
    final gate = notificationsGate;
    if (gate != null) {
      notificationsGate = null;
      await gate.future;
    }
    final matching = rows.where((r) => (r['seq']! as int) > afterSeq).toList()
      ..sort((a, b) => (a['seq']! as int).compareTo(b['seq']! as int));
    if (newest) return matching.reversed.take(limit).toList().reversed.toList();
    return matching.take(limit).toList();
  }

  @override
  Future<Map<String, Object?>?> settings() async {
    settingsCalls++;
    if (fail != null) throw fail!;
    final gate = settingsGate;
    if (gate != null) {
      settingsGate = null;
      await gate.future;
    }
    return settingsRow;
  }

  @override
  Future<int> markRead(List<String>? ids) async {
    if (fail != null) throw fail!;
    markReads.add(ids);
    return ids?.length ?? 0;
  }

  @override
  Future<Map<String, Object?>> saveSettings({
    required Map<String, Object?> kinds,
    required List<String> mutedGroupIds,
  }) async {
    if (fail != null) throw fail!;
    saves.add((kinds: kinds, muted: mutedGroupIds));
    final gate = saveGate;
    if (gate != null) {
      saveGate = null;
      await gate.future;
    }
    return settingsRow = {'kinds': kinds, 'muted_group_ids': mutedGroupIds};
  }

  @override
  Future<void> registerDevice(String token, {String? appVersion}) async {}

  @override
  Future<void> unregisterDevice(String token) async {}

  @override
  Future<ReminderSent> sendReminder(String groupId, String memberId) => throw UnimplementedError();
}

Map<String, Object?> row(
  int seq, {
  String? readAt,
  String? createdAt,
  String? id,
  String kind = 'expenses',
}) => {
  'id': id ?? 'n$seq',
  'group_id': 'g1',
  'kind': kind,
  'type': 'expense_added',
  'title': 'Trip',
  'body': 'Asha added item $seq',
  'data': {'target_type': 'expense', 'target_id': 'e$seq'},
  'read_at': readAt,
  'created_at': createdAt ?? DateTime.utc(2026, 11, 20, 10, 0, seq % 60).toIso8601String(),
  'seq': seq,
};

void main() {
  late AppDatabase db;
  late FakeNotificationsRemote remote;
  late FakeClock clock;
  late NotificationsRepository repo;

  setUp(() {
    db = testDb();
    remote = FakeNotificationsRemote();
    clock = FakeClock(DateTime.utc(2026, 11, 22, 9));
    repo = NotificationsRepository(db, remote, clock);
  });

  tearDown(() => db.close());

  Future<List<LocalNotification>> all() => repo.watchAll().first;
  Future<LocalNotification> one(String id) async => (await all()).firstWhere((n) => n.id == id);

  group('refresh: pulling the bell', () {
    test('the first refresh fetches the newest rows (limit 100)', () async {
      remote.rows.addAll([for (var i = 1; i <= 3; i++) row(i)]);
      await repo.refresh();
      expect(remote.fetches, [(afterSeq: 0, limit: 100, newest: true)]);
      expect((await all()).map((n) => n.seq), [3, 2, 1]);
      final n = await one('n1');
      expect(n.title, 'Trip');
      expect(n.data, contains('target_id'));
      expect(n.readPending, 0);
    });

    test(
      'later refreshes use the highest local seq as cursor and keep paging while full',
      () async {
        remote.rows.add(row(5));
        await repo.refresh();
        remote.fetches.clear();
        remote.rows.addAll([for (var i = 6; i < 6 + 200 + 50; i++) row(i)]);
        await repo.refresh();
        expect(remote.fetches, [
          (afterSeq: 5, limit: 200, newest: false),
          (afterSeq: 205, limit: 200, newest: false),
        ]);
        expect((await all()).length, 251);
      },
    );

    test('an empty page ends paging; nothing new keeps the cache', () async {
      remote.rows.add(row(1));
      await repo.refresh();
      remote.fetches.clear();
      await repo.refresh();
      expect(remote.fetches.length, 1);
      expect((await all()).length, 1);
    });

    test('stops after maxPages full pages', () async {
      remote.rows.add(row(1));
      await repo.refresh();
      remote.fetches.clear();
      remote.rows.addAll([for (var i = 2; i < 2 + 200 * 11; i++) row(i)]);
      await repo.refresh();
      expect(remote.fetches.length, NotificationsRepository.maxPages);
    });

    test('keeps only the newest 300 rows', () async {
      remote.rows.add(row(1));
      await repo.refresh();
      remote.rows.addAll([for (var i = 2; i <= 401; i++) row(i)]);
      await repo.refresh();
      final rows = await all();
      expect(rows.length, NotificationsRepository.keep);
      expect(rows.map((n) => n.seq).reduce((a, b) => a < b ? a : b), 102);
      expect(rows.map((n) => n.seq).reduce((a, b) => a > b ? a : b), 401);
    });

    test('rows missing from the server copy still load with defaults (no created_at)', () async {
      remote.rows.add({...row(1), 'created_at': null, 'data': null}..remove('data'));
      await repo.refresh();
      final n = await one('n1');
      expect(n.createdAt, isNull);
      expect(n.data, '{}');
    });

    test('watchAll orders by created_at then seq, newest first', () async {
      remote.rows.addAll([
        row(1, createdAt: '2026-11-20T10:00:00Z'),
        row(2, createdAt: '2026-11-21T10:00:00Z'),
        row(3, createdAt: '2026-11-21T10:00:00Z'),
        row(4, createdAt: '2026-11-19T10:00:00Z'),
      ]);
      await repo.refresh();
      expect((await all()).map((n) => n.seq), [3, 2, 1, 4]);
    });

    test('offline: the cache is untouched and the error is rethrown', () async {
      remote.rows.add(row(1));
      await repo.refresh();
      await repo.markRead('n1');
      remote.fail = const NetworkException('offline');
      await expectLater(repo.refresh(), throwsA(isA<NetworkException>()));
      final n = await one('n1');
      expect(n.readPending, 1);
      expect(n.readAt, isNotNull);
      expect((await all()).length, 1);
      // A later refresh works again (single flight cleared).
      remote.fail = null;
      await repo.refresh();
      expect((await one('n1')).readPending, 0);
    });

    test(
      'single flight: a second refresh during a run joins it and runs the loop once more',
      () async {
        remote.rows.add(row(1));
        final gate = remote.notificationsGate = Completer<void>();
        final first = repo.refresh();
        final second = repo.refresh();
        expect(identical(first, second), isTrue);
        // Let the first run reach the gate, then add a row for the repeat run.
        await Future<void>.delayed(Duration.zero);
        remote.rows.add(row(2));
        gate.complete();
        await Future.wait([first, second]);
        expect(remote.settingsCalls, 2);
        expect(remote.fetches.length, 2);
        expect((await all()).length, 2);
      },
    );
  });

  group('read marks', () {
    setUp(() async {
      remote.rows.addAll([row(1), row(2), row(3)]);
      await repo.refresh();
    });

    test('watchUnreadCount follows reads', () async {
      expect(await repo.watchUnreadCount().first, 3);
      await repo.markRead('n1');
      expect(await repo.watchUnreadCount().first, 2);
      await repo.markAllRead();
      expect(await repo.watchUnreadCount().first, 0);
    });

    test(
      'markRead sets read_at and read_pending; refresh sends the ids and clears pending',
      () async {
        await repo.markRead('n2');
        final n = await one('n2');
        expect(n.readAt, '2026-11-22T09:00:00.000Z');
        expect(n.readPending, 1);
        expect((await one('n1')).readPending, 0);
        await repo.refresh();
        expect(remote.markReads, [
          ['n2'],
        ]);
        expect((await one('n2')).readPending, 0);
        expect((await one('n2')).readAt, '2026-11-22T09:00:00.000Z');
      },
    );

    test('markRead keeps the first read time when already read', () async {
      await repo.markRead('n1');
      clock.advance(const Duration(hours: 1));
      await repo.markRead('n1');
      expect((await one('n1')).readAt, '2026-11-22T09:00:00.000Z');
    });

    test('markAllRead marks every unread row, refresh sends them all', () async {
      await repo.markRead('n1');
      await repo.refresh();
      remote.markReads.clear();
      await repo.markAllRead();
      await repo.refresh();
      expect(remote.markReads.single!.toSet(), {'n2', 'n3'});
      for (final n in await all()) {
        expect(n.readAt, isNotNull);
        expect(n.readPending, 0);
      }
    });

    test('read marks are sent in chunks of 200', () async {
      remote.rows.addAll([for (var i = 4; i < 4 + 250; i++) row(i)]);
      await repo.refresh();
      await repo.markAllRead();
      remote.markReads.clear();
      await repo.refresh();
      expect(remote.markReads.map((c) => c!.length), [200, 53]);
    });

    test('a pending local read mark survives a pulled copy with read_at null', () async {
      final gate = remote.notificationsGate = Completer<void>();
      final running = repo.refresh();
      await Future<void>.delayed(Duration.zero);
      // Mark read while the pull is in flight; the server copy (unread, newer seq) arrives afterwards.
      await repo.markRead('n3');
      remote.rows.add({...row(9, id: 'n3')});
      gate.complete();
      await running;
      final n = await one('n3');
      expect(n.readAt, '2026-11-22T09:00:00.000Z');
      expect(n.readPending, 1);
      expect(n.seq, 9);
      // The next refresh tells the server.
      await repo.refresh();
      expect(remote.markReads.last, ['n3']);
      expect((await one('n3')).readPending, 0);
    });

    test('a server copy that is read replaces the local row and clears pending', () async {
      remote.rows.add(row(7, id: 'n1', readAt: '2026-11-21T00:00:00Z'));
      await repo.refresh();
      final n = await one('n1');
      expect(n.readAt, '2026-11-21T00:00:00Z');
      expect(n.readPending, 0);
    });
  });

  group('settings', () {
    test('watchPrefs defaults when nothing is stored; pending is false', () async {
      expect(await repo.watchPrefs().first, const NotificationPrefs());
      expect(await repo.watchPrefsPending().first, isFalse);
    });

    test(
      'savePrefs is pending locally; refresh sends it and stores the answer as synced',
      () async {
        final prefs = const NotificationPrefs()
            .withKind(NotificationKind.comments, NotificationChannel.push, on: false)
            .withMuted('g1', muted: true);
        await repo.savePrefs(prefs);
        expect(await repo.watchPrefs().first, prefs);
        expect(await repo.watchPrefsPending().first, isTrue);
        await repo.refresh();
        expect(remote.saves.single.kinds, prefs.kindsJson());
        expect(remote.saves.single.muted, ['g1']);
        expect(await repo.watchPrefsPending().first, isFalse);
        expect(await repo.watchPrefs().first, prefs);
      },
    );

    test('a change made while saveSettings is in flight stays pending and is sent again', () async {
      await repo.savePrefs(const NotificationPrefs().withMuted('g1', muted: true));
      final gate = remote.saveGate = Completer<void>();
      final running = repo.refresh();
      await Future<void>.delayed(Duration.zero);
      final newer = const NotificationPrefs()
          .withMuted('g1', muted: true)
          .withMuted('g2', muted: true);
      await repo.savePrefs(newer);
      gate.complete();
      await running;
      expect(remote.saves.length, 2);
      expect(remote.saves.last.muted, ['g1', 'g2']);
      expect(await repo.watchPrefs().first, newer);
      expect(await repo.watchPrefsPending().first, isFalse);
    });

    test('the pull does not overwrite prefs saved while it was in flight', () async {
      remote.settingsRow = {
        'kinds': <String, Object?>{},
        'muted_group_ids': ['server'],
      };
      final gate = remote.settingsGate = Completer<void>();
      final running = repo.refresh();
      await Future<void>.delayed(Duration.zero);
      final local = const NotificationPrefs().withMuted('mine', muted: true);
      await repo.savePrefs(local);
      gate.complete();
      await running;
      // The pending local change was not replaced by the older server answer; the next run sends it.
      expect(remote.saves, isEmpty);
      expect(await repo.watchPrefsPending().first, isTrue);
      expect(await repo.watchPrefs().first, local);
      await repo.refresh();
      expect(remote.saves.single.muted, ['mine']);
      expect(await repo.watchPrefsPending().first, isFalse);
    });

    test('with nothing pending the pull stores the server prefs as synced', () async {
      remote.settingsRow = {
        'kinds': {
          'payments': {'inapp': false},
        },
        'muted_group_ids': ['g9'],
      };
      await repo.refresh();
      final p = await repo.watchPrefs().first;
      expect(p.isOn(NotificationKind.payments, NotificationChannel.inapp), isFalse);
      expect(p.isMuted('g9'), isTrue);
      expect(await repo.watchPrefsPending().first, isFalse);
      expect(remote.saves, isEmpty);
    });

    test('a null server answer stores the defaults as synced', () async {
      await repo.refresh();
      final rowCount = await db
          .customSelect('SELECT COUNT(*) AS c FROM notification_settings')
          .getSingle();
      expect(rowCount.read<int>('c'), 1);
      expect(await repo.watchPrefs().first, const NotificationPrefs());
      expect(await repo.watchPrefsPending().first, isFalse);
    });

    test('offline refresh leaves pending prefs pending', () async {
      await repo.savePrefs(const NotificationPrefs().withMuted('g1', muted: true));
      remote.fail = const NetworkException('offline');
      await expectLater(repo.refresh(), throwsA(isA<NetworkException>()));
      expect(await repo.watchPrefsPending().first, isTrue);
    });
  });
}
