import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/app_info.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/platform/system_settings.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/data/remote/push_messaging.dart';
import 'package:splitify/data/repositories/notifications_repository.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';

final _log = Logger('notifications');

/// Server side of the bell, settings, device token and reminders. Bootstrap overrides it with
/// `RemoteServices.notifications`; without settings and in widget tests every call fails like being offline.
final notificationsRemoteProvider = Provider<NotificationsRemote>(
  (ref) => const UnconfiguredNotificationsRemote(),
);

/// The phone's push channel. Bootstrap overrides it with `initPush()`'s answer; disabled by default (D-020).
final pushMessagingProvider = Provider<PushMessaging>((ref) => const DisabledPushMessaging());

/// Android's settings screens: the blocked-push banner's "Open phone settings".
final systemSettingsProvider = Provider<SystemSettings>((ref) => const ChannelSystemSettings());

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(notificationsRemoteProvider),
    ref.watch(clockProvider),
  ),
);

/// One bell row, ready for the screen.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    required this.unread,
    this.groupId,
    this.actorName = '',
    this.actorSeed = '',
    this.route,
  });

  factory NotificationItem.fromRow(LocalNotification n) {
    final data = _json(n.data);
    return NotificationItem(
      id: n.id,
      kind: NotificationKind.tryParse(n.kind) ?? NotificationKind.expenses,
      title: n.title,
      body: n.body,
      at:
          (n.createdAt == null ? null : DateTime.tryParse(n.createdAt!))?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      unread: n.readAt == null,
      groupId: n.groupId,
      actorName: (data['actor_name'] as String?) ?? '',
      actorSeed: (data['actor_member_id'] as String?) ?? (data['actor_name'] as String?) ?? n.id,
      route: notificationRoute(data),
    );
  }

  final String id;
  final NotificationKind kind;

  /// Group name (or the friend's name for friend expenses).
  final String title;

  /// The sentence, written by the server from this person's side ("Asha added “Dinner” · ₹1,200").
  final String body;
  final DateTime at;
  final bool unread;
  final String? groupId;
  final String actorName;
  final String actorSeed;

  /// Where a tap goes, or null.
  final String? route;
}

Map<String, Object?> _json(String? s) {
  if (s == null || s.isEmpty) return const {};
  try {
    final v = jsonDecode(s);
    return v is Map ? v.cast<String, Object?>() : const {};
  } on FormatException {
    return const {};
  }
}

/// App route for a notification's `data` (`target_type`, `target_id`, `group_id`; push data has the same
/// keys): the expense, the payment, the group's Balances tab (reminders) or the group.
String? notificationRoute(Map<String, Object?> data) {
  String? s(String k) {
    final v = data[k];
    return v is String && v.isNotEmpty ? v : null;
  }

  final id = s('target_id');
  final group = s('group_id');
  return switch (s('target_type')) {
    'expense' when id != null => '/expense/$id',
    'payment' when id != null => '/payment/$id',
    'balances' when group != null => '/groups/$group?tab=balances',
    _ when group != null => '/groups/$group',
    _ => null,
  };
}

/// The bell list, newest first (in-app rows only).
final notificationItemsProvider = StreamProvider.autoDispose<List<NotificationItem>>(
  (ref) => ref
      .watch(notificationsRepositoryProvider)
      .watchAll()
      .map((rows) => [for (final r in rows) NotificationItem.fromRow(r)]),
);

/// Unread count for the bell badge.
final unreadNotificationsProvider = StreamProvider<int>(
  (ref) => ref.watch(notificationsRepositoryProvider).watchUnreadCount(),
);

final notificationPrefsProvider = StreamProvider<NotificationPrefs>(
  (ref) => ref.watch(notificationsRepositoryProvider).watchPrefs(),
);

/// True while a settings change is not on the server yet ("not synced yet" marker).
final notificationPrefsPendingProvider = StreamProvider<bool>(
  (ref) => ref.watch(notificationsRepositoryProvider).watchPrefsPending(),
);

/// Android permission + whether push exists in this build (settings banner, pre-prompt).
final pushStateProvider = FutureProvider.autoDispose<({bool available, PushPermission permission})>(
  (ref) async {
    final push = ref.watch(pushMessagingProvider);
    if (!push.available) return (available: false, permission: PushPermission.denied);
    return (available: true, permission: await push.permission());
  },
);

/// Bell actions; every write lands on the phone first, then a best-effort refresh tells the server.
class NotificationActions {
  NotificationActions(this._ref);

  final Ref _ref;

  NotificationsRepository get _repo => _ref.read(notificationsRepositoryProvider);

  /// Fetches what is new; false when the server could not be reached (the list stays as it was).
  Future<bool> refresh() async {
    try {
      await _repo.refresh();
      return true;
    } on Exception catch (e) {
      _log.fine('notifications refresh failed: $e');
      return false;
    } on StateError catch (e) {
      // The database closed under a refresh in flight (sign-out wipe, app torn down): nothing to keep.
      _log.fine('notifications refresh stopped: $e');
      return false;
    }
  }

  /// Marks [id] read and syncs: what it points at is usually new on the server (B's expense), so the screen
  /// it opens fills in as soon as the pull lands.
  Future<void> open(String id) async {
    await _repo.markRead(id);
    unawaited(refresh());
    unawaited(_ref.read(syncRepositoryProvider).syncNow());
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    unawaited(refresh());
  }

  Future<void> setKind(NotificationKind kind, NotificationChannel channel, {required bool on}) =>
      _save((p) => p.withKind(kind, channel, on: on));

  Future<void> setMuted(String groupId, {required bool muted}) =>
      _save((p) => p.withMuted(groupId, muted: muted));

  Future<void> _save(NotificationPrefs Function(NotificationPrefs) change) async {
    final current = await _repo.watchPrefs().first;
    await _repo.savePrefs(change(current));
    unawaited(refresh());
  }
}

final notificationActionsProvider = Provider<NotificationActions>(NotificationActions.new);

/// This phone's FCM token on the server (rule 10): registered when signed in with permission, re-registered
/// on refresh, removed on sign-out. Does nothing without push (D-020).
class PushRegistration {
  PushRegistration({required this.push, required this.remote, required this.prefs});

  final PushMessaging push;
  final NotificationsRemote remote;
  final SharedPreferences prefs;

  static const tokenKey = 'push_token';
  StreamSubscription<String>? _refresh;

  /// Registers the current token (permission granted only) and follows token refreshes.
  Future<void> register() async {
    if (!push.available) return;
    if (await push.permission() != PushPermission.granted) return;
    final token = await push.token();
    if (token != null) await _send(token);
    _refresh ??= push.tokenRefresh.listen((t) => unawaited(_send(t)));
  }

  Future<void> _send(String token) async {
    try {
      await remote.registerDevice(token, appVersion: appVersion);
      await prefs.setString(tokenKey, token);
    } on Exception catch (e) {
      _log.info('register device failed: $e');
    }
  }

  /// Sign-out (04 §7): remove the token on the server (best effort) and on the phone.
  Future<void> unregister() async {
    await _refresh?.cancel();
    _refresh = null;
    final token = prefs.getString(tokenKey) ?? (push.available ? await push.token() : null);
    if (token != null) {
      try {
        await remote.unregisterDevice(token).timeout(const Duration(seconds: 5));
      } on Object catch (e) {
        _log.info('unregister device failed: $e');
      }
    }
    try {
      await push.deleteToken();
    } on Object catch (e) {
      _log.info('delete token failed: $e');
    }
    await prefs.remove(tokenKey);
  }

  Future<void> dispose() async => _refresh?.cancel();
}

final pushRegistrationProvider = Provider<PushRegistration>((ref) {
  final r = PushRegistration(
    push: ref.watch(pushMessagingProvider),
    remote: ref.watch(notificationsRemoteProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
  ref.onDispose(r.dispose);
  return r;
});

/// Refreshes the bell after every successful sync (the sync engine's `idle` after `syncing`).
final notificationsAutoRefreshProvider = Provider<void>((ref) {
  final engine = ref.watch(syncEngineProvider);
  final actions = ref.watch(notificationActionsProvider);
  var last = engine.phase;
  final sub = engine.phases.listen((p) {
    if (p == SyncPhase.idle && last == SyncPhase.syncing) unawaited(actions.refresh());
    last = p;
  });
  ref.onDispose(sub.cancel);
});

/// Pre-prompt (08 #19): once per install, after the first group create/join, when push exists and Android
/// has not been asked yet.
class PushPrePrompt {
  PushPrePrompt({required this.push, required this.prefs});

  final PushMessaging push;
  final SharedPreferences prefs;

  static const shownKey = 'push_preprompt_shown';

  Future<bool> shouldShow() async {
    if (!push.available || (prefs.getBool(shownKey) ?? false)) return false;
    return await push.permission() == PushPermission.notAsked;
  }

  Future<void> markShown() => prefs.setBool(shownKey, true);

  /// Shows Android's dialog; returns true when allowed.
  Future<bool> allow() async => await push.requestPermission() == PushPermission.granted;
}

final pushPrePromptProvider = Provider<PushPrePrompt>(
  (ref) => PushPrePrompt(
    push: ref.watch(pushMessagingProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  ),
);

/// Asks the signed-in shell to show the push pre-prompt (after a group create/join; the screen that asked is
/// usually gone by then). The value only counts requests.
class PushPrePromptRequests extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final pushPrePromptRequestsProvider = NotifierProvider<PushPrePromptRequests, int>(
  PushPrePromptRequests.new,
);
