import 'dart:async';
import 'dart:convert';

import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// What `send_reminder` answered (08 #23).
class ReminderSent {
  const ReminderSent({required this.amounts, required this.retryAt});

  factory ReminderSent.fromJson(Map<String, Object?> j) => ReminderSent(
    amounts: {
      for (final e in ((j['amounts'] as Map?) ?? const {}).entries)
        if (e.value is num) e.key as String: (e.value as num).toInt(),
    },
    retryAt: DateTime.tryParse((j['retry_at'] as String?) ?? '')?.toUtc(),
  );

  /// What the reminded person owes, minor units per currency.
  final Map<String, int> amounts;

  /// When this pair may remind again.
  final DateTime? retryAt;
}

/// Why a reminder was not sent (codes from `0016_notifications.sql`).
enum ReminderFailureCode { offline, throttled, nameOnly, nothingOwed, notMember, unknown }

class ReminderFailure implements Exception {
  const ReminderFailure(this.code, {this.retryAt});

  static ReminderFailureCode fromServer(String? code) => switch (code) {
    'REMINDER_THROTTLED' => ReminderFailureCode.throttled,
    'NAME_ONLY_MEMBER' => ReminderFailureCode.nameOnly,
    'NOTHING_OWED' => ReminderFailureCode.nothingOwed,
    'NOT_MEMBER' || 'MEMBER_NOT_FOUND' || 'CANNOT_REMIND_SELF' => ReminderFailureCode.notMember,
    _ => ReminderFailureCode.unknown,
  };

  final ReminderFailureCode code;

  /// For [ReminderFailureCode.throttled]: when the next reminder is allowed.
  final DateTime? retryAt;

  @override
  String toString() => 'ReminderFailure(${code.name})';
}

/// The signed-in person's notification data (03 §4/§5, S-142): bell rows by seq, settings, read marks, this
/// phone's push token and reminders. Read calls throw [NetworkException] offline, [AuthExpiredException] or
/// [RemoteException] otherwise; [sendReminder] throws [ReminderFailure].
abstract class NotificationsRemote {
  /// In-app notifications with `seq > afterSeq`, oldest first (at most [limit]); with [newest] the newest
  /// [limit] rows instead (first fetch on a phone).
  Future<List<Map<String, Object?>>> notifications({
    int afterSeq = 0,
    int limit = 200,
    bool newest = false,
  });

  /// The saved settings row, or null when the person never changed anything.
  Future<Map<String, Object?>?> settings();

  /// `mark_notifications_read(ids)`; null ids = all.
  Future<int> markRead(List<String>? ids);

  /// `upsert_notification_settings`; returns the saved settings.
  Future<Map<String, Object?>> saveSettings({
    required Map<String, Object?> kinds,
    required List<String> mutedGroupIds,
  });

  Future<void> registerDevice(String token, {String? appVersion});
  Future<void> unregisterDevice(String token);

  Future<ReminderSent> sendReminder(String groupId, String memberId);
}

/// No server configured (D-020 builds, widget tests): fails like being offline.
class UnconfiguredNotificationsRemote implements NotificationsRemote {
  const UnconfiguredNotificationsRemote();

  static Future<T> _offline<T>() =>
      Future.error(const NetworkException(UnconfiguredRemoteApi.code));

  @override
  Future<List<Map<String, Object?>>> notifications({
    int afterSeq = 0,
    int limit = 200,
    bool newest = false,
  }) => _offline();

  @override
  Future<Map<String, Object?>?> settings() => _offline();

  @override
  Future<int> markRead(List<String>? ids) => _offline();

  @override
  Future<Map<String, Object?>> saveSettings({
    required Map<String, Object?> kinds,
    required List<String> mutedGroupIds,
  }) => _offline();

  @override
  Future<void> registerDevice(String token, {String? appVersion}) => _offline();

  @override
  Future<void> unregisterDevice(String token) => _offline();

  @override
  Future<ReminderSent> sendReminder(String groupId, String memberId) =>
      Future.error(const ReminderFailure(ReminderFailureCode.offline));
}

typedef NotificationsQuery = Future<List<Object?>> Function(int afterSeq, int limit, bool newest);
typedef SettingsQuery = Future<Object?> Function();
typedef NotificationsRpc = Future<Object?> Function(String name, Map<String, Object?> params);

/// [NotificationsRemote] over PostgREST (RLS returns only the caller's rows).
class SupabaseNotificationsRemote implements NotificationsRemote {
  SupabaseNotificationsRemote({
    required this.query,
    required this.settingsQuery,
    required this.rpc,
  });

  /// Wires the real client (thin glue, exercised on the device).
  factory SupabaseNotificationsRemote.fromClient(sb.SupabaseClient c) =>
      SupabaseNotificationsRemote(
        query: (afterSeq, limit, newest) => c
            .from('notifications')
            .select(columns)
            .eq('inapp', true)
            .gt('seq', afterSeq)
            .order('seq', ascending: !newest)
            .limit(limit),
        settingsQuery: () =>
            c.from('notification_settings').select('kinds, muted_group_ids').maybeSingle(),
        rpc: (name, params) => c.rpc<Object?>(name, params: params),
      );

  static const columns =
      'id, group_id, activity_id, kind, type, title, body, data, read_at, created_at, seq';

  final NotificationsQuery query;
  final SettingsQuery settingsQuery;
  final NotificationsRpc rpc;

  @override
  Future<List<Map<String, Object?>>> notifications({
    int afterSeq = 0,
    int limit = 200,
    bool newest = false,
  }) => _guard(() async {
    final rows = await query(afterSeq, limit, newest);
    return [for (final r in rows) (r! as Map).cast<String, Object?>()];
  });

  @override
  Future<Map<String, Object?>?> settings() => _guard(() async {
    final r = await settingsQuery();
    return r == null ? null : (r as Map).cast<String, Object?>();
  });

  @override
  Future<int> markRead(List<String>? ids) => _guard(
    () async => ((await rpc('mark_notifications_read', {'ids': ids})) as num?)?.toInt() ?? 0,
  );

  @override
  Future<Map<String, Object?>> saveSettings({
    required Map<String, Object?> kinds,
    required List<String> mutedGroupIds,
  }) => _guard(() async {
    final r = await rpc('upsert_notification_settings', {
      'kinds': kinds,
      'muted_group_ids': mutedGroupIds,
    });
    return (r! as Map).cast<String, Object?>();
  });

  @override
  Future<void> registerDevice(String token, {String? appVersion}) => _guard(
    () =>
        rpc('register_device', {'token': token, 'app_version': appVersion, 'platform': 'android'}),
  );

  @override
  Future<void> unregisterDevice(String token) =>
      _guard(() => rpc('unregister_device', {'token': token}));

  @override
  Future<ReminderSent> sendReminder(String groupId, String memberId) async {
    try {
      final r = await _guard(() async {
        try {
          return await rpc('send_reminder', {'group_id': groupId, 'to_member_id': memberId});
        } on sb.PostgrestException catch (e) {
          // Raised codes (`private.fail`, P0001) come as the message, the detail JSON carries retry_at.
          if (e.code != 'P0001') rethrow;
          throw ReminderFailure(
            ReminderFailure.fromServer(e.message),
            retryAt: _retryAt(e.details),
          );
        }
      });
      return ReminderSent.fromJson((r! as Map).cast<String, Object?>());
    } on NetworkException {
      throw const ReminderFailure(ReminderFailureCode.offline);
    } on RemoteException {
      throw const ReminderFailure(ReminderFailureCode.unknown);
    } on AuthExpiredException {
      throw const ReminderFailure(ReminderFailureCode.unknown);
    }
  }

  static DateTime? _retryAt(Object? details) {
    if (details is! String || details.isEmpty) return null;
    try {
      final j = jsonDecode(details);
      return j is Map ? DateTime.tryParse((j['retry_at'] as String?) ?? '')?.toUtc() : null;
    } on FormatException {
      return null;
    }
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body().timeout(const Duration(seconds: 20));
    } on sb.PostgrestException catch (e) {
      throw SupabaseRemoteApi.mapPostgrest(e);
    } on sb.AuthException {
      throw const AuthExpiredException();
    } on TimeoutException {
      throw const NetworkException('timeout');
    } on Exception catch (e) {
      if (e is ReminderFailure ||
          e is NetworkException ||
          e is RemoteException ||
          e is AuthExpiredException) {
        rethrow;
      }
      // Socket, HTTP client and TLS failures: treat as offline (the bell keeps its cache).
      throw NetworkException(e.runtimeType.toString());
    }
  }
}
