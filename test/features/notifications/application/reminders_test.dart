import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/features/notifications/application/reminders.dart';

import '../../../support/fakes.dart';

class _Remote extends UnconfiguredNotificationsRemote {
  _Remote();

  ReminderSent? answer;
  ReminderFailure? failure;
  final sent = <(String, String)>[];

  @override
  Future<ReminderSent> sendReminder(String groupId, String memberId) async {
    sent.add((groupId, memberId));
    if (failure != null) throw failure!;
    return answer!;
  }
}

const pair = (groupId: 'g1', fromMember: 'me', toMember: 'bob');

void main() {
  final now = DateTime.utc(2026, 11, 22, 9);

  group('reminderRetryAt', () {
    test('null when nothing was sent', () {
      expect(reminderRetryAt(lastSent: null, sentHere: null, now: now), isNull);
    });

    test('last sent in the log blocks for 24 h', () {
      final last = now.subtract(const Duration(hours: 2));
      expect(
        reminderRetryAt(lastSent: last, sentHere: null, now: now),
        last.add(const Duration(hours: 24)),
      );
    });

    test('a log entry older than 24 h allows reminding now', () {
      expect(
        reminderRetryAt(
          lastSent: now.subtract(const Duration(hours: 24)),
          sentHere: null,
          now: now,
        ),
        isNull,
      );
      expect(
        reminderRetryAt(
          lastSent: now.subtract(const Duration(hours: 30)),
          sentHere: null,
          now: now,
        ),
        isNull,
      );
    });

    test('a reminder sent from this phone blocks until its retry time', () {
      final at = now.add(const Duration(hours: 3));
      expect(reminderRetryAt(lastSent: null, sentHere: at, now: now), at);
      expect(
        reminderRetryAt(
          lastSent: null,
          sentHere: now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        isNull,
      );
      expect(reminderRetryAt(lastSent: null, sentHere: now, now: now), isNull);
    });

    test('with both, the later time wins', () {
      final logged = now.subtract(const Duration(hours: 1)); // retry at now + 23 h
      final later = now.add(const Duration(hours: 30));
      final earlier = now.add(const Duration(hours: 5));
      expect(reminderRetryAt(lastSent: logged, sentHere: later, now: now), later);
      expect(
        reminderRetryAt(lastSent: logged, sentHere: earlier, now: now),
        logged.add(reminderThrottle),
      );
    });
  });

  group('SentReminders', () {
    test('records per pair and keeps other pairs', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(sentRemindersProvider), isEmpty);
      final n = c.read(sentRemindersProvider.notifier);
      n.record(pair, DateTime.utc(2026, 11, 23));
      n.record((groupId: 'g1', fromMember: 'me', toMember: 'carol'), DateTime.utc(2026, 11, 24));
      n.record(pair, DateTime.utc(2026, 11, 25));
      final s = c.read(sentRemindersProvider);
      expect(s, {
        'g1|me|bob': DateTime.utc(2026, 11, 25),
        'g1|me|carol': DateTime.utc(2026, 11, 24),
      });
      expect(SentReminders.keyOf(pair), 'g1|me|bob');
    });
  });

  group('lastReminderProvider', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = testDb();
      container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<void> insert(
      String id, {
      String group = 'g1',
      String? actor = 'me',
      String type = 'reminder_sent',
      String data = '{"to_member":"bob"}',
      String? at,
    }) => db.customInsert(
      'INSERT INTO activity (id, group_id, actor_member_id, type, data, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        Variable<String>(id),
        Variable<String>(group),
        Variable<String>(actor),
        Variable<String>(type),
        Variable<String>(data),
        Variable<String>(at),
      ],
      updates: {db.activity},
    );

    test('null when there is no reminder row', () async {
      final sub = container.listen(lastReminderProvider(pair), (_, _) {});
      addTearDown(sub.close);
      expect(await container.read(lastReminderProvider(pair).future), isNull);
    });

    test('is the newest created_at for that pair only and follows new rows', () async {
      await insert('a1', at: '2026-11-20T08:00:00Z');
      await insert('a2', at: '2026-11-21T08:00:00Z');
      // Not this pair or not a reminder.
      await insert('b1', at: '2026-11-22T08:00:00Z', data: '{"to_member":"carol"}');
      await insert('b2', at: '2026-11-22T08:00:00Z', actor: 'someone');
      await insert('b3', at: '2026-11-22T08:00:00Z', group: 'g2');
      await insert('b4', at: '2026-11-22T08:00:00Z', type: 'expense_added');
      final seen = <DateTime?>[];
      final sub = container.listen(
        lastReminderProvider(pair),
        (_, next) => seen.add(next.value),
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await pumpEventQueue();
      expect(seen.last, DateTime.utc(2026, 11, 21, 8));
      await insert('a3', at: '2026-11-22T07:30:00+00:00');
      await pumpEventQueue();
      expect(seen.last, DateTime.utc(2026, 11, 22, 7, 30));
    });

    test('rows without a time or with an unreadable time give null', () async {
      await insert('c1');
      await insert('c2', at: 'garbage');
      final sub = container.listen(lastReminderProvider(pair), (_, _) {});
      addTearDown(sub.close);
      expect(await container.read(lastReminderProvider(pair).future), isNull);
    });
  });

  group('ReminderActions.send', () {
    late _Remote remote;
    late FakeSyncRepository sync;
    late FakeClock clock;
    late ProviderContainer container;

    setUp(() {
      remote = _Remote();
      sync = FakeSyncRepository();
      clock = FakeClock(DateTime.utc(2026, 11, 22, 9));
      container = ProviderContainer(
        overrides: [
          notificationsRemoteProvider.overrideWithValue(remote),
          syncRepositoryProvider.overrideWithValue(sync),
          clockProvider.overrideWithValue(clock),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('records the server retry time and syncs', () async {
      final retry = DateTime.utc(2026, 11, 23, 9, 5);
      remote.answer = ReminderSent(amounts: const {'INR': 500}, retryAt: retry);
      final sent = await container.read(reminderActionsProvider).send(pair);
      expect(sent.amounts, {'INR': 500});
      expect(remote.sent, [('g1', 'bob')]);
      expect(container.read(sentRemindersProvider), {'g1|me|bob': retry});
      await pumpEventQueue();
      expect(sync.calls, ['sync']);
    });

    test('falls back to now + 24 h when the server gives no retry time', () async {
      remote.answer = const ReminderSent(amounts: {}, retryAt: null);
      await container.read(reminderActionsProvider).send(pair);
      expect(container.read(sentRemindersProvider)['g1|me|bob'], DateTime.utc(2026, 11, 23, 9));
    });

    test('a throttled failure with a retry time is recorded and rethrown', () async {
      final retry = DateTime.utc(2026, 11, 23, 4);
      remote.failure = ReminderFailure(ReminderFailureCode.throttled, retryAt: retry);
      await expectLater(
        container.read(reminderActionsProvider).send(pair),
        throwsA(
          isA<ReminderFailure>().having((e) => e.code, 'code', ReminderFailureCode.throttled),
        ),
      );
      expect(container.read(sentRemindersProvider), {'g1|me|bob': retry});
      expect(sync.calls, isEmpty);
    });

    test(
      'throttled without a retry time and other failures are rethrown, nothing recorded',
      () async {
        for (final f in [
          const ReminderFailure(ReminderFailureCode.throttled),
          const ReminderFailure(ReminderFailureCode.offline),
          ReminderFailure(ReminderFailureCode.nameOnly, retryAt: DateTime.utc(2030)),
          const ReminderFailure(ReminderFailureCode.nothingOwed),
        ]) {
          remote.failure = f;
          await expectLater(container.read(reminderActionsProvider).send(pair), throwsA(same(f)));
        }
        expect(container.read(sentRemindersProvider), isEmpty);
        expect(sync.calls, isEmpty);
      },
    );
  });
}
