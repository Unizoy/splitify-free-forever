import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  late List<String> calls;
  late Map<String, Object?> lastParams;

  SupabaseNotificationsRemote remote({
    NotificationsQuery? query,
    SettingsQuery? settingsQuery,
    NotificationsRpc? rpc,
  }) => SupabaseNotificationsRemote(
    query: query ?? (_, _, _) async => const [],
    settingsQuery: settingsQuery ?? () async => null,
    rpc:
        rpc ??
        (name, params) async {
          calls.add(name);
          lastParams = params;
          return null;
        },
  );

  Future<T> boom<T>(Object e) => Future<T>.error(e);

  setUp(() {
    calls = [];
    lastParams = {};
  });

  group('ReminderSent / ReminderFailure', () {
    test('ReminderSent.fromJson keeps numeric amounts and parses retry_at as UTC', () {
      final s = ReminderSent.fromJson({
        'amounts': {'INR': 12050, 'USD': 3.0, 'bad': 'x'},
        'retry_at': '2026-11-23T10:00:00+05:30',
      });
      expect(s.amounts, {'INR': 12050, 'USD': 3});
      expect(s.retryAt, DateTime.utc(2026, 11, 23, 4, 30));
      final empty = ReminderSent.fromJson(const {});
      expect(empty.amounts, isEmpty);
      expect(empty.retryAt, isNull);
    });

    test('fromServer maps every code', () {
      expect(ReminderFailure.fromServer('REMINDER_THROTTLED'), ReminderFailureCode.throttled);
      expect(ReminderFailure.fromServer('NAME_ONLY_MEMBER'), ReminderFailureCode.nameOnly);
      expect(ReminderFailure.fromServer('NOTHING_OWED'), ReminderFailureCode.nothingOwed);
      for (final c in ['NOT_MEMBER', 'MEMBER_NOT_FOUND', 'CANNOT_REMIND_SELF']) {
        expect(ReminderFailure.fromServer(c), ReminderFailureCode.notMember);
      }
      expect(ReminderFailure.fromServer('X'), ReminderFailureCode.unknown);
      expect(ReminderFailure.fromServer(null), ReminderFailureCode.unknown);
      expect(
        ReminderFailure(ReminderFailureCode.throttled, retryAt: DateTime.utc(2026)).toString(),
        'ReminderFailure(throttled)',
      );
    });
  });

  group('UnconfiguredNotificationsRemote', () {
    test('every call fails like being offline', () async {
      const r = UnconfiguredNotificationsRemote();
      await expectLater(r.notifications(), throwsA(isA<NetworkException>()));
      await expectLater(r.settings(), throwsA(isA<NetworkException>()));
      await expectLater(r.markRead(null), throwsA(isA<NetworkException>()));
      await expectLater(
        r.saveSettings(kinds: const {}, mutedGroupIds: const []),
        throwsA(isA<NetworkException>()),
      );
      await expectLater(r.registerDevice('t'), throwsA(isA<NetworkException>()));
      await expectLater(r.unregisterDevice('t'), throwsA(isA<NetworkException>()));
      await expectLater(
        r.sendReminder('g', 'm'),
        throwsA(isA<ReminderFailure>().having((e) => e.code, 'code', ReminderFailureCode.offline)),
      );
    });
  });

  group('SupabaseNotificationsRemote', () {
    test('notifications passes the cursor args and maps rows to string-keyed maps', () async {
      int? a;
      int? l;
      bool? n;
      final r = remote(
        query: (after, limit, newest) async {
          a = after;
          l = limit;
          n = newest;
          return [
            <dynamic, dynamic>{'id': 'n1', 'seq': 4},
          ];
        },
      );
      final rows = await r.notifications(afterSeq: 3, limit: 50, newest: true);
      expect([a, l, n], [3, 50, true]);
      expect(rows, [
        {'id': 'n1', 'seq': 4},
      ]);
      expect(await remote().notifications(), isEmpty);
    });

    test('settings returns null or the row', () async {
      expect(await remote().settings(), isNull);
      final r = remote(settingsQuery: () async => <dynamic, dynamic>{'kinds': <String, Object?>{}});
      expect(await r.settings(), {'kinds': <String, Object?>{}});
    });

    test('markRead sends ids (or null = all) and returns the count', () async {
      final r = remote(
        rpc: (name, params) async {
          calls.add(name);
          lastParams = params;
          return 3;
        },
      );
      expect(await r.markRead(['a', 'b']), 3);
      expect(calls, ['mark_notifications_read']);
      expect(lastParams, {
        'ids': ['a', 'b'],
      });
      await r.markRead(null);
      expect(lastParams, {'ids': null});
      expect(await remote().markRead(null), 0);
    });

    test('saveSettings sends kinds and muted_group_ids and returns the saved row', () async {
      final r = remote(
        rpc: (name, params) async {
          calls.add(name);
          lastParams = params;
          return <dynamic, dynamic>{
            'kinds': <String, Object?>{},
            'muted_group_ids': ['g'],
          };
        },
      );
      final saved = await r.saveSettings(
        kinds: {
          'expenses': {'push': false},
        },
        mutedGroupIds: ['g'],
      );
      expect(calls, ['upsert_notification_settings']);
      expect(lastParams, {
        'kinds': {
          'expenses': {'push': false},
        },
        'muted_group_ids': ['g'],
      });
      expect(saved['muted_group_ids'], ['g']);
    });

    test('registerDevice and unregisterDevice call their rpcs with the token', () async {
      final r = remote();
      await r.registerDevice('tok', appVersion: '1.2.3');
      expect(calls, ['register_device']);
      expect(lastParams, {'token': 'tok', 'app_version': '1.2.3', 'platform': 'android'});
      await r.unregisterDevice('tok');
      expect(calls.last, 'unregister_device');
      expect(lastParams, {'token': 'tok'});
    });

    test('sendReminder sends the pair and maps the answer', () async {
      final r = remote(
        rpc: (name, params) async {
          calls.add(name);
          lastParams = params;
          return <dynamic, dynamic>{
            'amounts': {'INR': 500},
            'retry_at': '2026-11-23T10:00:00Z',
          };
        },
      );
      final sent = await r.sendReminder('g1', 'm1');
      expect(calls, ['send_reminder']);
      expect(lastParams, {'group_id': 'g1', 'to_member_id': 'm1'});
      expect(sent.amounts, {'INR': 500});
      expect(sent.retryAt, DateTime.utc(2026, 11, 23, 10));
    });

    Future<ReminderFailure> failure(Object error) async {
      final r = remote(rpc: (_, _) => boom(error));
      try {
        await r.sendReminder('g', 'm');
      } on ReminderFailure catch (e) {
        return e;
      }
      fail('expected a ReminderFailure');
    }

    test('sendReminder maps REMINDER_THROTTLED with retry_at details', () async {
      final e = await failure(
        const sb.PostgrestException(
          message: 'REMINDER_THROTTLED',
          code: 'P0001',
          details: '{"retry_at":"2026-11-23T10:00:00+00:00"}',
        ),
      );
      expect(e.code, ReminderFailureCode.throttled);
      expect(e.retryAt, DateTime.utc(2026, 11, 23, 10));
    });

    test('sendReminder maps other raised codes', () async {
      for (final (msg, code) in [
        ('NAME_ONLY_MEMBER', ReminderFailureCode.nameOnly),
        ('NOTHING_OWED', ReminderFailureCode.nothingOwed),
        ('NOT_MEMBER', ReminderFailureCode.notMember),
        ('SOMETHING', ReminderFailureCode.unknown),
      ]) {
        final e = await failure(sb.PostgrestException(message: msg, code: 'P0001'));
        expect(e.code, code);
        expect(e.retryAt, isNull);
      }
    });

    test('sendReminder tolerates bad or missing details', () async {
      for (final details in <Object?>['not json', '[1]', '', 42]) {
        final e = await failure(
          sb.PostgrestException(message: 'REMINDER_THROTTLED', code: 'P0001', details: details),
        );
        expect(e.code, ReminderFailureCode.throttled);
        expect(e.retryAt, isNull);
      }
    });

    test('sendReminder maps network failures to offline', () async {
      expect((await failure(const SocketException('down'))).code, ReminderFailureCode.offline);
      expect((await failure(TimeoutException('slow'))).code, ReminderFailureCode.offline);
    });

    test('sendReminder maps other server and auth failures to unknown', () async {
      expect(
        (await failure(const sb.PostgrestException(message: 'boom', code: '42501'))).code,
        ReminderFailureCode.unknown,
      );
      // 5xx counts as being unreachable.
      expect(
        (await failure(const sb.PostgrestException(message: 'boom', code: '500'))).code,
        ReminderFailureCode.offline,
      );
      expect((await failure(const sb.AuthException('expired'))).code, ReminderFailureCode.unknown);
    });

    test('read calls map socket, timeout, auth and server errors', () async {
      await expectLater(
        remote(settingsQuery: () => boom(const SocketException('x'))).settings(),
        throwsA(isA<NetworkException>()),
      );
      await expectLater(
        remote(rpc: (_, _) => boom(TimeoutException('t'))).markRead(null),
        throwsA(isA<NetworkException>()),
      );
      await expectLater(
        remote(rpc: (_, _) => boom(const sb.AuthException('a'))).unregisterDevice('t'),
        throwsA(isA<AuthExpiredException>()),
      );
      await expectLater(
        remote(
          query: (_, _, _) => boom(const sb.PostgrestException(message: 'm', code: '400')),
        ).notifications(),
        throwsA(isA<RemoteException>()),
      );
      await expectLater(
        remote(query: (_, _, _) => boom(const NetworkException('already'))).notifications(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('fromClient glue fails fast under flutter_test', () async {
      final r = SupabaseNotificationsRemote.fromClient(sb.SupabaseClient('https://x.example', 'k'));
      Future<void> fails(Future<Object?> f) => expectLater(
        f,
        throwsA(
          anyOf(isA<NetworkException>(), isA<RemoteException>(), isA<AuthExpiredException>()),
        ),
      );

      await fails(r.notifications(afterSeq: 1, limit: 5, newest: true));
      await fails(r.settings());
      await fails(r.markRead(['a']));
    });
  });
}
