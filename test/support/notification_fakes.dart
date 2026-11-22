// Fakes and sample rows for the phase 13 notification screens (widget tests + goldens).
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/data/remote/push_messaging.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/repositories/notifications_repository.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';

import 'fakes.dart';

/// Scripted [PushMessaging]: permission answers, token, and what the app did with it.
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

  @override
  Future<PushPermission> permission() async => permissionState;

  @override
  Future<PushPermission> requestPermission() async {
    requested++;
    permissionState = requestAnswer;
    return requestAnswer;
  }

  @override
  Future<String?> token() async => tokenValue;

  @override
  Stream<String> get tokenRefresh => refreshes.stream;

  @override
  Future<void> deleteToken() async => deleted++;

  @override
  Stream<PushMessage> get foreground => foregroundMessages.stream;

  @override
  Stream<PushMessage> get opened => taps.stream;

  @override
  Future<PushMessage?> launchMessage() async => launch;

  @override
  Future<void> show(PushMessage m) async => shown.add(m);
}

/// [NotificationsRemote] that records calls; [sendReminder] answers [reminderError] or [reminderSent].
class FakeNotificationsRemote implements NotificationsRemote {
  final registered = <(String, String?)>[];
  final reminders = <(String, String)>[];
  ReminderFailure? reminderError;
  ReminderSent reminderSent = const ReminderSent(amounts: {'INR': 120000}, retryAt: null);

  @override
  Future<List<Map<String, Object?>>> notifications({
    int afterSeq = 0,
    int limit = 200,
    bool newest = false,
  }) async => const [];

  @override
  Future<Map<String, Object?>?> settings() async => null;

  @override
  Future<int> markRead(List<String>? ids) async => 0;

  @override
  Future<Map<String, Object?>> saveSettings({
    required Map<String, Object?> kinds,
    required List<String> mutedGroupIds,
  }) async => {'kinds': kinds, 'muted_group_ids': mutedGroupIds};

  @override
  Future<void> registerDevice(String token, {String? appVersion}) async =>
      registered.add((token, appVersion));

  @override
  Future<void> unregisterDevice(String token) async {}

  @override
  Future<ReminderSent> sendReminder(String groupId, String memberId) async {
    reminders.add((groupId, memberId));
    final e = reminderError;
    if (e != null) throw e;
    return reminderSent;
  }
}

/// A stored bell row. [data] is the server's JSON (`target_type`, `target_id`, `group_id`, `actor_name`).
LocalNotification notifRow(
  String id, {
  String kind = 'expenses',
  String title = 'Goa trip',
  String body = 'Asha added “Dinner” · ₹1,200',
  String createdAt = '2026-11-21T08:30:00Z',
  bool read = false,
  Map<String, Object?>? data,
  String? groupId = 'g-goa',
  int seq = 1,
}) => LocalNotification(
  id: id,
  groupId: groupId,
  kind: kind,
  type: 'expense_added',
  title: title,
  body: body,
  data: jsonEncode(
    data ??
        {
          'target_type': 'expense',
          'target_id': 'e-$id',
          'group_id': groupId,
          'actor_name': 'Asha Rao',
        },
  ),
  readAt: read ? '2026-11-21T09:00:00Z' : null,
  createdAt: createdAt,
  seq: seq,
  readPending: 0,
);

/// Never queried (the fake overrides every method), so one lazy database serves all fakes.
final _unusedDb = testDb();

/// In-memory [NotificationsRepository] (no database): rows, prefs and the pending flag live in fields and
/// stream out on every change, so screens and the real `NotificationActions` run against it.
class FakeNotificationsRepository extends NotificationsRepository {
  FakeNotificationsRepository({
    List<LocalNotification> rows = const [],
    this.prefs = const NotificationPrefs(),
    this.prefsPending = false,
  }) : rows = [...rows],
       super(
         _unusedDb,
         const UnconfiguredNotificationsRemote(),
         FakeClock(DateTime.utc(2026, 11, 21)),
       );

  List<LocalNotification> rows;
  NotificationPrefs prefs;
  bool prefsPending;

  /// When set, [refresh] throws it (offline).
  Object? refreshError;
  var refreshCalls = 0;
  final readIds = <String>[];
  var markedAll = 0;

  final _changes = StreamController<void>.broadcast();

  Stream<T> _stream<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  /// Replaces the rows (a refresh that brought news).
  void setRows(List<LocalNotification> next) {
    rows = [...next];
    _changes.add(null);
  }

  @override
  Stream<List<LocalNotification>> watchAll() => _stream(() => [...rows]);

  @override
  Stream<int> watchUnreadCount() => _stream(() => rows.where((r) => r.readAt == null).length);

  @override
  Stream<NotificationPrefs> watchPrefs() => _stream(() => prefs);

  @override
  Stream<bool> watchPrefsPending() => _stream(() => prefsPending);

  @override
  Future<void> markRead(String id) async {
    readIds.add(id);
    rows = [for (final r in rows) r.id == id && r.readAt == null ? _read(r) : r];
    _changes.add(null);
  }

  @override
  Future<void> markAllRead() async {
    markedAll++;
    rows = [for (final r in rows) r.readAt == null ? _read(r) : r];
    _changes.add(null);
  }

  static LocalNotification _read(LocalNotification r) =>
      r.copyWith(readAt: const Value('2026-11-21T10:00:00Z'));

  @override
  Future<void> savePrefs(NotificationPrefs next) async {
    prefs = next;
    prefsPending = true;
    _changes.add(null);
  }

  @override
  Future<void> refresh() async {
    refreshCalls++;
    final e = refreshError;
    if (e != null) throw e;
  }
}

/// An offline failure like the real remote throws.
const offlineError = NetworkException('offline');

/// All five kinds over two days (clock: 21 Nov 2026): three unread, two read, newest first.
List<LocalNotification> sampleNotifRows() => [
  notifRow('n1', seq: 5),
  notifRow(
    'n2',
    kind: 'payments',
    body: 'Rahul paid you ₹300',
    createdAt: '2026-11-21T07:10:00Z',
    seq: 4,
    data: const {
      'target_type': 'payment',
      'target_id': 'p1',
      'group_id': 'g-goa',
      'actor_name': 'Rahul Mehta',
    },
  ),
  notifRow(
    'n3',
    kind: 'reminders',
    body: 'Asha reminded you to settle up · ₹1,200',
    createdAt: '2026-11-21T06:00:00Z',
    read: true,
    seq: 3,
    data: const {'target_type': 'balances', 'group_id': 'g-goa', 'actor_name': 'Asha Rao'},
  ),
  notifRow(
    'n4',
    kind: 'comments',
    title: 'Flat 4B',
    body: 'Dev commented on “Wifi bill”: “Paid it today”',
    createdAt: '2026-11-20T18:20:00Z',
    groupId: 'g-flat',
    seq: 2,
    data: const {
      'target_type': 'expense',
      'target_id': 'e-wifi',
      'group_id': 'g-flat',
      'actor_name': 'Dev Shah',
    },
  ),
  notifRow(
    'n5',
    kind: 'groups',
    body: 'Priya joined the group',
    createdAt: '2026-11-20T09:00:00Z',
    read: true,
    seq: 1,
    data: const {'target_type': 'member', 'group_id': 'g-goa', 'actor_name': 'Priya Nair'},
  ),
];
