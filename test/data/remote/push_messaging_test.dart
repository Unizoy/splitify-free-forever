import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart' as fcm;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:splitify/data/remote/push_messaging.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';

class _MockMessaging extends Mock implements fcm.FirebaseMessaging {}

class _MockLocal extends Mock implements FlutterLocalNotificationsPlugin {}

class _FakeSettings extends Fake implements fcm.NotificationSettings {
  _FakeSettings(this.authorizationStatus);

  @override
  final fcm.AuthorizationStatus authorizationStatus;
}

class _FakeInit extends Fake implements InitializationSettings {}

class _FakeDetails extends Fake implements NotificationDetails {}

class _FakeChannel extends Fake implements AndroidNotificationChannel {}

class _FakeLaunch extends Fake implements NotificationAppLaunchDetails {
  _FakeLaunch({required this.didNotificationLaunchApp, this.notificationResponse});

  @override
  final bool didNotificationLaunchApp;

  @override
  final NotificationResponse? notificationResponse;
}

class _FakeResponse extends Fake implements NotificationResponse {
  _FakeResponse(this.payload);

  @override
  final String? payload;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeInit());
    registerFallbackValue(_FakeDetails());
    registerFallbackValue(_FakeChannel());
  });

  group('PushMessage', () {
    test('exposes the notification id and parsed kind from data', () {
      const m = PushMessage(data: {'notification_id': 'n1', 'kind': 'payments'});
      expect(m.notificationId, 'n1');
      expect(m.kind, NotificationKind.payments);
      const none = PushMessage(data: {});
      expect(none.notificationId, isNull);
      expect(none.kind, isNull);
      expect(const PushMessage(data: {'kind': 'zzz'}).kind, isNull);
    });
  });

  group('DisabledPushMessaging', () {
    test('is unavailable and does nothing', () async {
      const p = DisabledPushMessaging();
      expect(p.available, isFalse);
      expect(await p.permission(), PushPermission.denied);
      expect(await p.requestPermission(), PushPermission.denied);
      expect(await p.token(), isNull);
      expect(await p.launchMessage(), isNull);
      await p.deleteToken();
      await p.show(const PushMessage(data: {}));
      expect(await p.tokenRefresh.isEmpty, isTrue);
      expect(await p.foreground.isEmpty, isTrue);
      expect(await p.opened.isEmpty, isTrue);
    });
  });

  test('channelNames has one entry per kind', () {
    expect(channelNames.keys.toSet(), NotificationKind.values.toSet());
    for (final v in channelNames.values) {
      expect(v.$1, isNotEmpty);
      expect(v.$2, isNotEmpty);
    }
  });

  group('FirebasePushMessaging', () {
    late _MockMessaging messaging;
    late _MockLocal local;
    late FirebasePushMessaging push;

    setUp(() {
      messaging = _MockMessaging();
      local = _MockLocal();
      push = FirebasePushMessaging(messaging, local);
    });

    test('is available', () => expect(push.available, isTrue));

    test('permission and requestPermission map authorization statuses', () async {
      const mapping = {
        fcm.AuthorizationStatus.authorized: PushPermission.granted,
        fcm.AuthorizationStatus.provisional: PushPermission.granted,
        fcm.AuthorizationStatus.denied: PushPermission.denied,
        fcm.AuthorizationStatus.deniedPermanently: PushPermission.denied,
        fcm.AuthorizationStatus.notDetermined: PushPermission.notAsked,
      };
      for (final e in mapping.entries) {
        when(() => messaging.getNotificationSettings())
            .thenAnswer((_) async => _FakeSettings(e.key));
        when(() => messaging.requestPermission()).thenAnswer((_) async => _FakeSettings(e.key));
        expect(await push.permission(), e.value, reason: '${e.key}');
        expect(await push.requestPermission(), e.value, reason: '${e.key}');
      }
    });

    test('token, tokenRefresh and deleteToken go to FirebaseMessaging', () async {
      when(() => messaging.getToken()).thenAnswer((_) async => 'tok');
      when(() => messaging.onTokenRefresh).thenAnswer((_) => Stream.value('tok2'));
      when(() => messaging.deleteToken()).thenAnswer((_) async {});
      expect(await push.token(), 'tok');
      expect(await push.tokenRefresh.first, 'tok2');
      await push.deleteToken();
      verify(() => messaging.deleteToken()).called(1);
    });

    test('opened is a (broadcast) stream of taps', () {
      expect(push.opened.isBroadcast, isTrue);
    });

    test('show builds a local notification on the kind channel with the data as payload', () async {
      when(
        () => local.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});
      const m = PushMessage(
        data: {'notification_id': 'n1', 'kind': 'reminders', 'group_id': 'g'},
        title: 'Trip',
        body: 'Asha reminded you',
      );
      await push.show(m);
      final captured = verify(
        () => local.show(
          id: captureAny(named: 'id'),
          title: 'Trip',
          body: 'Asha reminded you',
          notificationDetails: captureAny(named: 'notificationDetails'),
          payload: captureAny(named: 'payload'),
        ),
      ).captured;
      expect(captured[0], 'n1'.hashCode & 0x7fffffff);
      final android = (captured[1] as NotificationDetails).android!;
      expect(android.channelId, 'reminders');
      expect(android.channelName, 'Reminders');
      expect(jsonDecode(captured[2] as String), m.data);
    });

    test('show falls back to the expenses channel and a text-based id', () async {
      when(
        () => local.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          notificationDetails: any(named: 'notificationDetails'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});
      await push.show(const PushMessage(data: {}, title: 'A', body: 'B'));
      final captured = verify(
        () => local.show(
          id: captureAny(named: 'id'),
          title: 'A',
          body: 'B',
          notificationDetails: captureAny(named: 'notificationDetails'),
          payload: '{}',
        ),
      ).captured;
      expect(captured[0], 'AB'.hashCode & 0x7fffffff);
      expect((captured[1] as NotificationDetails).android!.channelId, 'expenses');
    });

    test('launchMessage reads the local launch payload when FCM has none', () async {
      when(() => messaging.getInitialMessage()).thenAnswer((_) async => null);
      when(() => local.getNotificationAppLaunchDetails()).thenAnswer(
        (_) async => _FakeLaunch(
          didNotificationLaunchApp: true,
          notificationResponse: _FakeResponse('{"group_id":"g1","n":3}'),
        ),
      );
      final m = await push.launchMessage();
      expect(m!.data, {'group_id': 'g1', 'n': '3'});
    });

    test('launchMessage is null when nothing launched the app or the payload is bad', () async {
      when(() => messaging.getInitialMessage()).thenAnswer((_) async => null);
      when(() => local.getNotificationAppLaunchDetails()).thenAnswer((_) async => null);
      expect(await push.launchMessage(), isNull);
      for (final payload in <String?>['not json', '[1]', '', null]) {
        when(() => local.getNotificationAppLaunchDetails()).thenAnswer(
          (_) async => _FakeLaunch(
            didNotificationLaunchApp: true,
            notificationResponse: _FakeResponse(payload),
          ),
        );
        expect(await push.launchMessage(), isNull, reason: '$payload');
      }
      when(() => local.getNotificationAppLaunchDetails())
          .thenAnswer((_) async => _FakeLaunch(didNotificationLaunchApp: false));
      expect(await push.launchMessage(), isNull);
    });

    test('launchMessage maps the FCM initial message', () async {
      when(() => messaging.getInitialMessage()).thenAnswer(
        (_) async => const fcm.RemoteMessage(
          data: {'group_id': 'g9', 'count': 2},
          notification: fcm.RemoteNotification(title: 'T', body: 'B'),
        ),
      );
      final m = await push.launchMessage();
      expect(m!.data, {'group_id': 'g9', 'count': '2'});
      expect(m.title, 'T');
      expect(m.body, 'B');
    });

    test('init registers the tap callback; taps with a payload reach opened', () async {
      DidReceiveNotificationResponseCallback? onTap;
      when(
        () => local.initialize(
          settings: any(named: 'settings'),
          onDidReceiveNotificationResponse: any(named: 'onDidReceiveNotificationResponse'),
          onDidReceiveBackgroundNotificationResponse: any(
            named: 'onDidReceiveBackgroundNotificationResponse',
          ),
        ),
      ).thenAnswer((i) async {
        onTap =
            i.namedArguments[#onDidReceiveNotificationResponse]
                as DidReceiveNotificationResponseCallback?;
        return true;
      });
      // The Firebase static streams (onMessageOpenedApp) need a Firebase app, so init ends in an error
      // here; everything before that line has run.
      try {
        await push.init();
      } on Object {
        // expected under flutter_test
      }
      expect(onTap, isNotNull);
      final taps = <PushMessage>[];
      final sub = push.opened.listen(taps.add);
      onTap!(_FakeResponse('{"group_id":"g1"}'));
      onTap!(_FakeResponse('bad'));
      await pumpEventQueue();
      await sub.cancel();
      expect(taps.map((m) => m.data), [
        {'group_id': 'g1'},
      ]);
    });
  });
}
