import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart' as fcm;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';

final _log = Logger('push');

/// Android 13+ notification permission as the app sees it.
enum PushPermission { granted, denied, notAsked }

/// One push as the app needs it: what a tap opens (`target_type`, `target_id`, `group_id`, from the
/// `notifications.data` the server sent) plus the shown text.
class PushMessage {
  const PushMessage({required this.data, this.title, this.body});

  final Map<String, String> data;
  final String? title;
  final String? body;

  String? get notificationId => data['notification_id'];
  NotificationKind? get kind => NotificationKind.tryParse(data['kind']);
}

/// The phone's push channel (rule 10). [available] is false when Firebase is not set up in this build
/// (no `google-services.json`, D-020 dummy mode): the bell still works, nothing is registered.
abstract class PushMessaging {
  bool get available;

  Future<PushPermission> permission();

  /// Shows Android's permission dialog (Android 13+); returns the answer.
  Future<PushPermission> requestPermission();

  /// This phone's FCM token, or null.
  Future<String?> token();
  Stream<String> get tokenRefresh;

  /// Forgets the token (sign-out), so the next account gets a fresh one.
  Future<void> deleteToken();

  /// Pushes that arrive while the app is open (shown as a local notification).
  Stream<PushMessage> get foreground;

  /// Taps on a push or on a local notification.
  Stream<PushMessage> get opened;

  /// The push whose tap started the app, if any.
  Future<PushMessage?> launchMessage();

  /// Shows [m] as a local notification on its kind's channel (foreground pushes).
  Future<void> show(PushMessage m);
}

/// Push is not set up (D-020) or in tests: nothing is shown or registered.
class DisabledPushMessaging implements PushMessaging {
  const DisabledPushMessaging();

  @override
  bool get available => false;

  @override
  Future<PushPermission> permission() async => PushPermission.denied;

  @override
  Future<PushPermission> requestPermission() async => PushPermission.denied;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefresh => const Stream.empty();

  @override
  Future<void> deleteToken() async {}

  @override
  Stream<PushMessage> get foreground => const Stream.empty();

  @override
  Stream<PushMessage> get opened => const Stream.empty();

  @override
  Future<PushMessage?> launchMessage() async => null;

  @override
  Future<void> show(PushMessage m) async {}
}

/// Channel names on Android's notification settings (one channel per kind, phase 13 T1). English, like the
/// rest of the app (D-009); the server's `android.notification.channel_id` is the kind name.
const channelNames = {
  NotificationKind.expenses: ('Expenses', 'Added, edited, deleted and restored expenses'),
  NotificationKind.payments: ('Payments', 'Payments recorded with you'),
  NotificationKind.reminders: ('Reminders', 'Someone reminded you to settle up'),
  NotificationKind.comments: ('Comments', 'Comments on expenses and payments you are in'),
  NotificationKind.groups: ('Groups', 'People joining or leaving, group settings'),
  NotificationKind.summary: ('Monthly summary', 'What you spent last month, on the 1st'),
};

/// Starts Firebase when this build has it (google-services.json applied by Gradle). Any failure means
/// "not set up": the app runs with [DisabledPushMessaging].
Future<PushMessaging> initPush() async {
  try {
    await Firebase.initializeApp();
  } on Object catch (e) {
    _log.info('push disabled (Firebase not set up): ${e.runtimeType}');
    return const DisabledPushMessaging();
  }
  final push = FirebasePushMessaging(
    fcm.FirebaseMessaging.instance,
    FlutterLocalNotificationsPlugin(),
  );
  try {
    await push.init();
  } on Object catch (e) {
    _log.warning('push init failed: $e');
    return const DisabledPushMessaging();
  }
  return push;
}

/// [PushMessaging] over firebase_messaging + flutter_local_notifications (device glue, not unit tested).
class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._messaging, this._local);

  final fcm.FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;
  final _taps = StreamController<PushMessage>.broadcast();

  Future<void> init() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_splitify'),
      ),
      onDidReceiveNotificationResponse: (r) {
        final m = _decode(r.payload);
        if (m != null) _taps.add(m);
      },
    );
    final android = _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final e in channelNames.entries) {
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          e.key.name,
          e.value.$1,
          description: e.value.$2,
          importance: Importance.high,
        ),
      );
    }
    fcm.FirebaseMessaging.onMessageOpenedApp.listen((m) => _taps.add(_fromRemote(m)));
  }

  @override
  bool get available => true;

  static PushPermission _map(fcm.AuthorizationStatus s) => switch (s) {
    fcm.AuthorizationStatus.authorized ||
    fcm.AuthorizationStatus.provisional => PushPermission.granted,
    fcm.AuthorizationStatus.denied ||
    fcm.AuthorizationStatus.deniedPermanently => PushPermission.denied,
    fcm.AuthorizationStatus.notDetermined => PushPermission.notAsked,
  };

  @override
  Future<PushPermission> permission() async =>
      _map((await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      _map((await _messaging.requestPermission()).authorizationStatus);

  @override
  Future<String?> token() => _messaging.getToken();

  @override
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<PushMessage> get foreground => fcm.FirebaseMessaging.onMessage.map(_fromRemote);

  @override
  Stream<PushMessage> get opened => _taps.stream;

  @override
  Future<PushMessage?> launchMessage() async {
    final m = await _messaging.getInitialMessage();
    if (m != null) return _fromRemote(m);
    final details = await _local.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return _decode(details?.notificationResponse?.payload);
    }
    return null;
  }

  @override
  Future<void> show(PushMessage m) async {
    final kind = m.kind ?? NotificationKind.expenses;
    final names = channelNames[kind]!;
    await _local.show(
      id: (m.notificationId ?? '${m.title}${m.body}').hashCode & 0x7fffffff,
      title: m.title,
      body: m.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          kind.name,
          names.$1,
          channelDescription: names.$2,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(m.data),
    );
  }

  static PushMessage _fromRemote(fcm.RemoteMessage m) => PushMessage(
    data: {for (final e in m.data.entries) e.key: '${e.value}'},
    title: m.notification?.title,
    body: m.notification?.body,
  );

  static PushMessage? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final j = jsonDecode(payload);
      if (j is! Map) return null;
      return PushMessage(data: {for (final e in j.entries) '${e.key}': '${e.value}'});
    } on FormatException {
      return null;
    }
  }
}
