import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/data/sync/row_codec.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';

/// The bell and notification settings (08 #19, S-142). Offline-first for the person's own notification
/// data: reads come from Drift, writes (read marks, settings) land on this phone first with a pending flag
/// and [refresh] sends them before it fetches what is new (seq cursor). Group data stays with the outbox;
/// these rows are per user and written by their own RPCs, so they never go through `apply_mutations`.
class NotificationsRepository {
  NotificationsRepository(this.db, this.remote, this.clock);

  final AppDatabase db;
  final NotificationsRemote remote;
  final Clock clock;

  /// First fetch on a phone: only the newest rows.
  static const firstPage = 100;
  static const page = 200;
  static const maxPages = 10;

  /// Rows kept on the phone (newest by seq).
  static const keep = 300;
  static const _me = 'me';

  Future<void>? _running;
  bool _again = false;

  /// The bell list, newest first.
  Stream<List<LocalNotification>> watchAll() => (db.select(
    db.notifications,
  )..orderBy([(n) => OrderingTerm.desc(n.createdAt), (n) => OrderingTerm.desc(n.seq)])).watch();

  /// How many are unread (the bell badge).
  Stream<int> watchUnreadCount() {
    final count = db.notifications.id.count();
    return (db.selectOnly(db.notifications)
          ..addColumns([count])
          ..where(db.notifications.readAt.isNull()))
        .map((r) => r.read(count) ?? 0)
        .watchSingle();
  }

  /// Saved settings (defaults until the server or the person says otherwise).
  Stream<NotificationPrefs> watchPrefs() => (db.select(
    db.notificationSettings,
  )..where((s) => s.key.equals(_me))).watchSingleOrNull().map(_prefsOf);

  /// True while a settings change is not on the server yet.
  Stream<bool> watchPrefsPending() => (db.select(
    db.notificationSettings,
  )..where((s) => s.key.equals(_me))).watchSingleOrNull().map((r) => r?.syncState == 'pending');

  static NotificationPrefs _prefsOf(LocalNotificationSettings? r) {
    if (r == null) return const NotificationPrefs();
    return NotificationPrefs.fromJson({
      'kinds': jsonDecode(r.kinds),
      'muted_group_ids': jsonDecode(r.mutedGroupIds),
    });
  }

  String get _now => clock.now().toUtc().toIso8601String();

  /// Marks one notification read on this phone; [refresh] tells the server.
  Future<void> markRead(String id) =>
      (db.update(db.notifications)..where((n) => n.id.equals(id) & n.readAt.isNull())).write(
        NotificationsCompanion(readAt: Value(_now), readPending: const Value(1)),
      );

  /// Marks everything read on this phone; [refresh] tells the server.
  Future<void> markAllRead() => (db.update(db.notifications)..where((n) => n.readAt.isNull()))
      .write(NotificationsCompanion(readAt: Value(_now), readPending: const Value(1)));

  /// Saves [prefs] on this phone (pending); [refresh] sends them.
  Future<void> savePrefs(NotificationPrefs prefs) => db
      .into(db.notificationSettings)
      .insertOnConflictUpdate(
        NotificationSettingsCompanion.insert(
          key: _me,
          kinds: Value(jsonEncode(prefs.kindsJson())),
          mutedGroupIds: Value(jsonEncode(prefs.mutedJson())),
          syncState: const Value('pending'),
        ),
      );

  /// Sends pending read marks and settings, then fetches new notifications and the saved settings. One run at
  /// a time (a call during a run makes it run once more). Throws the remote's exceptions (offline →
  /// `NetworkException`); whatever was stored before the failure stays.
  Future<void> refresh() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    do {
      _again = false;
      await _pushReads();
      await _pushPrefs();
      await _pullNotifications();
      await _pullPrefs();
    } while (_again);
  }

  Future<void> _pushReads() async {
    final ids =
        await (db.selectOnly(db.notifications)
              ..addColumns([db.notifications.id])
              ..where(db.notifications.readPending.equals(1)))
            .map((r) => r.read(db.notifications.id)!)
            .get();
    for (var i = 0; i < ids.length; i += page) {
      final chunk = ids.sublist(i, i + page > ids.length ? ids.length : i + page);
      await remote.markRead(chunk);
      await (db.update(
        db.notifications,
      )..where((n) => n.id.isIn(chunk))).write(const NotificationsCompanion(readPending: Value(0)));
    }
  }

  Future<LocalNotificationSettings?> _prefsRow() =>
      (db.select(db.notificationSettings)..where((s) => s.key.equals(_me))).getSingleOrNull();

  Future<void> _pushPrefs() async {
    final row = await _prefsRow();
    if (row == null || row.syncState != 'pending') return;
    final prefs = _prefsOf(row);
    final saved = await remote.saveSettings(
      kinds: prefs.kindsJson(),
      mutedGroupIds: prefs.mutedJson(),
    );
    // A change made while the call ran stays pending for the next run.
    final now = await _prefsRow();
    if (now == null || now.kinds != row.kinds || now.mutedGroupIds != row.mutedGroupIds) {
      _again = true;
      return;
    }
    await _storePrefs(NotificationPrefs.fromJson(saved));
  }

  Future<void> _pullPrefs() async {
    final row = await _prefsRow();
    if (row?.syncState == 'pending') return;
    final saved = await remote.settings();
    if ((await _prefsRow())?.syncState == 'pending') return;
    await _storePrefs(
      saved == null ? const NotificationPrefs() : NotificationPrefs.fromJson(saved),
    );
  }

  Future<void> _storePrefs(NotificationPrefs p) => db
      .into(db.notificationSettings)
      .insertOnConflictUpdate(
        NotificationSettingsCompanion.insert(
          key: _me,
          kinds: Value(jsonEncode(p.kindsJson())),
          mutedGroupIds: Value(jsonEncode(p.mutedJson())),
          syncState: const Value('synced'),
        ),
      );

  Future<void> _pullNotifications() async {
    final max = db.notifications.seq.max();
    var cursor =
        (await (db.selectOnly(db.notifications)..addColumns([max])).getSingle()).read(max) ?? 0;
    if (cursor == 0) {
      await _store(await remote.notifications(limit: firstPage, newest: true));
      return;
    }
    for (var i = 0; i < maxPages; i++) {
      final rows = await remote.notifications(afterSeq: cursor, limit: page);
      if (rows.isEmpty) return;
      await _store(rows);
      cursor = rows.map((r) => (r['seq']! as num).toInt()).reduce((a, b) => a > b ? a : b);
      if (rows.length < page) return;
    }
  }

  /// Upserts server rows; a read mark made on this phone and not sent yet survives an older server copy.
  Future<void> _store(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    await db.transaction(() async {
      final pending = {
        for (final n in await (db.select(
          db.notifications,
        )..where((n) => n.readPending.equals(1))).get())
          n.id: n.readAt,
      };
      for (final r in rows) {
        final id = r['id']! as String;
        final values = columnValues(db.notifications, r);
        if (pending.containsKey(id) && r['read_at'] == null) {
          values['read_at'] = Variable<Object>(pending[id]);
          values['read_pending'] = const Variable<Object>(1);
        } else {
          values['read_pending'] = const Variable<Object>(0);
        }
        await insertRaw(db, db.notifications, values, replace: true);
      }
      // Keep the newest [keep] rows.
      await db.customUpdate(
        'DELETE FROM notifications WHERE id NOT IN '
        '(SELECT id FROM notifications ORDER BY seq DESC LIMIT ?) AND read_pending = 0',
        variables: [Variable<int>(keep)],
        updates: {db.notifications},
        updateKind: UpdateKind.delete,
      );
    });
  }
}
