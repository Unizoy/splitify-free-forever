import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/app_info.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/data/remote/push_messaging.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/sync/sync_engine.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';

import '../../../support/fakes.dart';

class FakePushMessaging implements PushMessaging {
  FakePushMessaging({
    this.available = true,
    this.permissionState = PushPermission.granted,
    this.tokenValue = 'tok-1',
  });

  @override
  bool available;
  PushPermission permissionState;
  PushPermission requestAnswer = PushPermission.granted;
  String? tokenValue;
  final refreshes = StreamController<String>.broadcast();
  final foregroundMessages = StreamController<PushMessage>.broadcast();
  final taps = StreamController<PushMessage>.broadcast();
  PushMessage? launch;
  final shown = <PushMessage>[];
  var deleted = 0;
  var requested = 0;
  Object? deleteError;

  @override
  Future<PushPermission> permission() async => permissionState;

  @override
  Future<PushPermission> requestPermission() async {
    requested++;
    return requestAnswer;
  }

  @override
  Future<String?> token() async => tokenValue;

  @override
  Stream<String> get tokenRefresh => refreshes.stream;

  @override
  Future<void> deleteToken() async {
    deleted++;
    if (deleteError != null) throw deleteError!;
  }

  @override
  Stream<PushMessage> get foreground => foregroundMessages.stream;

  @override
  Stream<PushMessage> get opened => taps.stream;

  @override
  Future<PushMessage?> launchMessage() async => launch;

  @override
  Future<void> show(PushMessage m) async => shown.add(m);
}

/// Records what the screens and push registration ask of the server.
class RecordingRemote implements NotificationsRemote {
  final registered = <(String, String?)>[];
  final unregistered = <String>[];
  final saved = <Map<String, Object?>>[];
  var refreshCalls = 0;
  Exception? registerError;
  Object? unregisterError;
  Exception? fetchError;
  Completer<void>? unregisterGate;

  @override
  Future<List<Map<String, Object?>>> notifications({
    int afterSeq = 0,
    int limit = 200,
    bool newest = false,
  }) async {
    refreshCalls++;
    if (fetchError != null) throw fetchError!;
    return const [];
  }

  @override
  Future<Map<String, Object?>?> settings() async => null;

  @override
  Future<int> markRead(List<String>? ids) async => 0;

  @override
  Future<Map<String, Object?>> saveSettings({
    required Map<String, Object?> kinds,
    required List<String> mutedGroupIds,
  }) async {
    final r = {'kinds': kinds, 'muted_group_ids': mutedGroupIds};
    saved.add(r);
    return r;
  }

  @override
  Future<void> registerDevice(String token, {String? appVersion}) async {
    if (registerError != null) throw registerError!;
    registered.add((token, appVersion));
  }

  @override
  Future<void> unregisterDevice(String token) async {
    await unregisterGate?.future;
    if (unregisterError != null) throw unregisterError!;
    unregistered.add(token);
  }

  @override
  Future<ReminderSent> sendReminder(String groupId, String memberId) => throw UnimplementedError();
}

class MockEngine extends Mock implements SyncEngine {}

Map<String, Object?> pushRow(
  int seq, {
  String? data,
  String? createdAt,
  String kind = 'payments',
}) => {
  'id': 'n$seq',
  'group_id': 'g1',
  'kind': kind,
  'type': 'payment_added',
  'title': 'Trip',
  'body': 'Body $seq',
  if (data != null) 'data': data,
  'created_at': createdAt ?? '2026-11-20T10:00:00Z',
  'seq': seq,
};

void main() {
  late AppDatabase db;
  late RecordingRemote remote;
  late FakePushMessaging push;
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = testDb();
    remote = RecordingRemote();
    push = FakePushMessaging();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationsRemoteProvider.overrideWithValue(remote),
        pushMessagingProvider.overrideWithValue(push),
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 22, 9))),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('notificationRoute', () {
    test('expense, payment, balances, group and none', () {
      expect(notificationRoute({'target_type': 'expense', 'target_id': 'e1'}), '/expense/e1');
      expect(notificationRoute({'target_type': 'payment', 'target_id': 'p1'}), '/payment/p1');
      expect(
        notificationRoute({'target_type': 'balances', 'group_id': 'g1'}),
        '/groups/g1?tab=balances',
      );
      expect(notificationRoute({'target_type': 'member', 'group_id': 'g1'}), '/groups/g1');
      expect(notificationRoute({'group_id': 'g1'}), '/groups/g1');
      expect(
        notificationRoute({'target_type': 'expense', 'target_id': '', 'group_id': 'g2'}),
        '/groups/g2',
      );
      expect(notificationRoute({'target_type': 'expense', 'group_id': 'g3'}), '/groups/g3');
      expect(notificationRoute({'target_type': 'balances'}), isNull);
      expect(notificationRoute({'target_type': 5, 'group_id': 7}), isNull);
      expect(notificationRoute(const {}), isNull);
    });
  });

  group('NotificationItem.fromRow', () {
    LocalNotification local({
      String data = '{}',
      String? createdAt,
      String? readAt,
      String kind = 'comments',
      String? groupId = 'g1',
    }) => LocalNotification(
      id: 'n1',
      groupId: groupId,
      kind: kind,
      type: 't',
      title: 'Trip',
      body: 'Body',
      data: data,
      readAt: readAt,
      createdAt: createdAt,
      seq: 1,
      readPending: 0,
    );

    test('maps a normal row', () {
      final item = NotificationItem.fromRow(
        local(
          data: '{"actor_name":"Asha","actor_member_id":"m1","target_type":"expense","target_id":"e1"}',
          createdAt: '2026-11-20T10:00:00Z',
        ),
      );
      expect(item.id, 'n1');
      expect(item.kind, NotificationKind.comments);
      expect(item.unread, isTrue);
      expect(item.actorName, 'Asha');
      expect(item.actorSeed, 'm1');
      expect(item.route, '/expense/e1');
      expect(item.groupId, 'g1');
      expect(item.at.toUtc(), DateTime.utc(2026, 11, 20, 10));
      expect(item.title, 'Trip');
      expect(item.body, 'Body');
    });

    test('bad JSON data, missing created_at, unknown kind and read rows', () {
      final item = NotificationItem.fromRow(
        local(data: 'not json', kind: 'future', readAt: '2026-11-21T00:00:00Z', groupId: null),
      );
      expect(item.kind, NotificationKind.expenses);
      expect(item.unread, isFalse);
      expect(item.actorName, '');
      expect(item.actorSeed, 'n1');
      expect(item.route, isNull);
      expect(item.at, DateTime.fromMillisecondsSinceEpoch(0));
      expect(NotificationItem.fromRow(local(data: '[1]')).route, isNull);
      expect(NotificationItem.fromRow(local(data: '')).actorName, '');
      expect(
        NotificationItem.fromRow(local(createdAt: 'garbage')).at,
        DateTime.fromMillisecondsSinceEpoch(0),
      );
    });

    test('actor seed falls back to the actor name', () {
      expect(NotificationItem.fromRow(local(data: '{"actor_name":"Asha"}')).actorSeed, 'Asha');
    });
  });

  group('providers over the repository', () {
    test('default remote and push providers are the unconfigured/disabled ones', () {
      final bare = ProviderContainer();
      addTearDown(bare.dispose);
      expect(bare.read(notificationsRemoteProvider), isA<UnconfiguredNotificationsRemote>());
      expect(bare.read(pushMessagingProvider), isA<DisabledPushMessaging>());
    });

    test('items, unread count, prefs and pending streams', () async {
      final actions = container.read(notificationActionsProvider);
      final items = container.listen(notificationItemsProvider, (_, _) {});
      final unread = container.listen(unreadNotificationsProvider, (_, _) {});
      final prefsSub = container.listen(notificationPrefsProvider, (_, _) {});
      final pending = container.listen(notificationPrefsPendingProvider, (_, _) {});
      addTearDown(() {
        items.close();
        unread.close();
        prefsSub.close();
        pending.close();
      });

      expect(await container.read(unreadNotificationsProvider.future), 0);
      expect(await container.read(notificationPrefsProvider.future), const NotificationPrefs());

      await actions.setKind(NotificationKind.payments, NotificationChannel.push, on: false);
      await actions.setMuted('g1', muted: true);
      final p = await container.read(notificationsRepositoryProvider).watchPrefs().first;
      expect(p.isOn(NotificationKind.payments, NotificationChannel.push), isFalse);
      expect(p.isMuted('g1'), isTrue);
      await pumpEventQueue();
      expect(remote.saved, isNotEmpty);
      expect(container.read(notificationItemsProvider).value, isEmpty);
    });

    test('items list maps rows after a refresh', () async {
      final repo = container.read(notificationsRepositoryProvider);
      await db.customInsert(
        "INSERT INTO notifications (id, group_id, kind, type, title, body, data, created_at, seq) "
        "VALUES ('n1','g1','payments','t','Trip','Body','{\"group_id\":\"g1\"}','2026-11-20T10:00:00Z',1)",
        updates: {db.notifications},
      );
      final sub = container.listen(notificationItemsProvider, (_, _) {});
      addTearDown(sub.close);
      final items = await container.read(notificationItemsProvider.future);
      expect(items.single.route, '/groups/g1');
      expect(await repo.watchUnreadCount().first, 1);
    });

    test('pushStateProvider reports availability and permission', () async {
      expect(await container.read(pushStateProvider.future), (
        available: true,
        permission: PushPermission.granted,
      ));
      container.invalidate(pushStateProvider);
      push.available = false;
      expect(await container.read(pushStateProvider.future), (
        available: false,
        permission: PushPermission.denied,
      ));
    });
  });

  group('NotificationActions', () {
    test('refresh returns true on success and false on an exception', () async {
      final actions = container.read(notificationActionsProvider);
      expect(await actions.refresh(), isTrue);
      remote.fetchError = const NetworkException('offline');
      expect(await actions.refresh(), isFalse);
    });

    test('open and markAllRead mark locally and then refresh in the background', () async {
      final repo = container.read(notificationsRepositoryProvider);
      for (final i in [1, 2]) {
        await db.customInsert(
          "INSERT INTO notifications (id, kind, type, title, body, seq) "
          "VALUES ('n$i','payments','t','T','B',$i)",
          updates: {db.notifications},
        );
      }
      final actions = container.read(notificationActionsProvider);
      await actions.open('n1');
      expect(await repo.watchUnreadCount().first, 1);
      await pumpEventQueue();
      await actions.markAllRead();
      expect(await repo.watchUnreadCount().first, 0);
      await pumpEventQueue();
      expect(remote.refreshCalls, greaterThanOrEqualTo(2));
    });
  });

  group('PushRegistration', () {
    PushRegistration registration() => container.read(pushRegistrationProvider);

    test('registers the token with the app version and remembers it', () async {
      await registration().register();
      expect(remote.registered, [('tok-1', appVersion)]);
      expect(prefs.getString(PushRegistration.tokenKey), 'tok-1');
    });

    test('does nothing without push, without permission, or without a token', () async {
      push.available = false;
      await registration().register();
      push.available = true;
      for (final perm in [PushPermission.denied, PushPermission.notAsked]) {
        push.permissionState = perm;
        await registration().register();
      }
      expect(remote.registered, isEmpty);
      push.permissionState = PushPermission.granted;
      push.tokenValue = null;
      await registration().register();
      expect(remote.registered, isEmpty);
    });

    test('follows token refreshes (subscribes once) and swallows remote errors', () async {
      await registration().register();
      await registration().register();
      push.refreshes.add('tok-2');
      await pumpEventQueue();
      expect(remote.registered.map((e) => e.$1), ['tok-1', 'tok-1', 'tok-2']);
      remote.registerError = const NetworkException('offline');
      push.refreshes.add('tok-3');
      await pumpEventQueue();
      expect(remote.registered.length, 3);
      expect(prefs.getString(PushRegistration.tokenKey), 'tok-2');
    });

    test('unregister removes the token on the server, the phone and the pref', () async {
      await registration().register();
      await registration().unregister();
      expect(remote.unregistered, ['tok-1']);
      expect(push.deleted, 1);
      expect(prefs.getString(PushRegistration.tokenKey), isNull);
      // Token refreshes are no longer followed.
      push.refreshes.add('tok-9');
      await pumpEventQueue();
      expect(remote.registered.length, 1);
    });

    test('unregister without a stored pref asks the push channel for its token', () async {
      await registration().unregister();
      expect(remote.unregistered, ['tok-1']);
      push.available = false;
      await registration().unregister();
      expect(remote.unregistered, ['tok-1']);
      expect(push.deleted, 2);
    });

    test('unregister swallows server and delete errors and still clears the pref', () async {
      await prefs.setString(PushRegistration.tokenKey, 'old');
      remote.unregisterError = const NetworkException('offline');
      push.deleteError = StateError('no firebase');
      await registration().unregister();
      expect(push.deleted, 1);
      expect(prefs.getString(PushRegistration.tokenKey), isNull);
    });

    testWidgets('unregister gives up on a hanging server after 5 s', (tester) async {
      await prefs.setString(PushRegistration.tokenKey, 'old');
      remote.unregisterGate = Completer<void>();
      var done = false;
      unawaited(container.read(pushRegistrationProvider).unregister().then((_) => done = true));
      await tester.pump(const Duration(seconds: 4));
      expect(done, isFalse);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(done, isTrue);
      expect(prefs.getString(PushRegistration.tokenKey), isNull);
    });
  });

  group('PushPrePrompt', () {
    PushPrePrompt pre() => container.read(pushPrePromptProvider);

    test('shows only when push exists, was not shown, and permission was not asked', () async {
      push.permissionState = PushPermission.notAsked;
      expect(await pre().shouldShow(), isTrue);
      push.permissionState = PushPermission.granted;
      expect(await pre().shouldShow(), isFalse);
      push.permissionState = PushPermission.denied;
      expect(await pre().shouldShow(), isFalse);
      push.permissionState = PushPermission.notAsked;
      push.available = false;
      expect(await pre().shouldShow(), isFalse);
      push.available = true;
      await pre().markShown();
      expect(prefs.getBool(PushPrePrompt.shownKey), isTrue);
      expect(await pre().shouldShow(), isFalse);
    });

    test('allow asks Android and reports whether it was granted', () async {
      expect(await pre().allow(), isTrue);
      push.requestAnswer = PushPermission.denied;
      expect(await pre().allow(), isFalse);
      expect(push.requested, 2);
    });
  });

  group('PushPrePromptRequests', () {
    test('counts requests', () {
      expect(container.read(pushPrePromptRequestsProvider), 0);
      container.read(pushPrePromptRequestsProvider.notifier).request();
      container.read(pushPrePromptRequestsProvider.notifier).request();
      expect(container.read(pushPrePromptRequestsProvider), 2);
    });
  });

  group('notificationsAutoRefreshProvider', () {
    test('refreshes once after the engine goes syncing then idle, not on other changes', () async {
      final engine = MockEngine();
      final phases = StreamController<SyncPhase>.broadcast();
      when(() => engine.phase).thenReturn(SyncPhase.idle);
      when(() => engine.phases).thenAnswer((_) => phases.stream);
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationsRemoteProvider.overrideWithValue(remote),
          sharedPreferencesProvider.overrideWithValue(prefs),
          syncEngineProvider.overrideWithValue(engine),
        ],
      );
      addTearDown(() async {
        c.dispose();
        await phases.close();
      });
      c.read(notificationsAutoRefreshProvider);

      phases.add(SyncPhase.idle);
      await pumpEventQueue();
      expect(remote.refreshCalls, 0);

      phases.add(SyncPhase.syncing);
      await pumpEventQueue();
      expect(remote.refreshCalls, 0);

      phases.add(SyncPhase.idle);
      await pumpEventQueue();
      expect(remote.refreshCalls, 1);

      phases.add(SyncPhase.syncing);
      phases.add(SyncPhase.offline);
      await pumpEventQueue();
      expect(remote.refreshCalls, 1);

      c.dispose();
      phases.add(SyncPhase.syncing);
      phases.add(SyncPhase.idle);
      await pumpEventQueue();
      expect(remote.refreshCalls, 1);
    });
  });
}
