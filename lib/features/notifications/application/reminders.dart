import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';

/// One reminder pair: [fromMember] (me) reminds [toMember] in [groupId].
typedef ReminderPair = ({String groupId, String fromMember, String toMember});

/// The 24 h throttle of `send_reminder` (08 #23).
const reminderThrottle = Duration(hours: 24);

/// When [ReminderPair.fromMember] last reminded [ReminderPair.toMember] in the group, from the activity log on
/// this phone (`reminder_sent` rows), or null.
final StreamProviderFamily<DateTime?, ReminderPair>
lastReminderProvider = StreamProvider.family<DateTime?, ReminderPair>((ref, p) {
  final db = ref.watch(appDatabaseProvider);
  return db
      .customSelect(
        "SELECT MAX(created_at) AS at FROM activity WHERE group_id = ? AND type = 'reminder_sent' "
        "AND actor_member_id = ? AND json_extract(data, '\$.to_member') = ?",
        variables: [
          Variable<String>(p.groupId),
          Variable<String>(p.fromMember),
          Variable<String>(p.toMember),
        ],
        readsFrom: {db.activity},
      )
      .watchSingle()
      .map((r) {
        final at = r.read<String?>('at');
        return at == null ? null : DateTime.tryParse(at)?.toUtc();
      });
});

/// Reminders sent from this phone in this run (the activity row arrives with the next sync): pair key → when
/// the next one is allowed.
class SentReminders extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => const {};

  static String keyOf(ReminderPair p) => '${p.groupId}|${p.fromMember}|${p.toMember}';

  void record(ReminderPair p, DateTime retryAt) => state = {...state, keyOf(p): retryAt};
}

final sentRemindersProvider = NotifierProvider<SentReminders, Map<String, DateTime>>(
  SentReminders.new,
);

/// When [p] may remind again, or null when it may now ([now] in UTC).
DateTime? reminderRetryAt({
  required DateTime? lastSent,
  required DateTime? sentHere,
  required DateTime now,
}) {
  final fromLog = lastSent?.add(reminderThrottle);
  final next = switch ((fromLog, sentHere)) {
    (final a?, final b?) => a.isAfter(b) ? a : b,
    (final a?, null) => a,
    (null, final b?) => b,
    _ => null,
  };
  return next != null && next.isAfter(now) ? next : null;
}

/// Sends a reminder (online only, 08 #23) and syncs so the activity row reaches the phone. Throws
/// [ReminderFailure]; a throttle answer is remembered like a sent reminder.
class ReminderActions {
  ReminderActions(this._ref);

  final Ref _ref;

  Future<ReminderSent> send(ReminderPair p) async {
    final clock = _ref.read(clockProvider);
    try {
      final sent = await _ref.read(notificationsRemoteProvider).sendReminder(p.groupId, p.toMember);
      _ref
          .read(sentRemindersProvider.notifier)
          .record(p, sent.retryAt ?? clock.now().toUtc().add(reminderThrottle));
      unawaited(_ref.read(syncRepositoryProvider).syncNow());
      return sent;
    } on ReminderFailure catch (e) {
      final retry = e.retryAt;
      if (e.code == ReminderFailureCode.throttled && retry != null) {
        _ref.read(sentRemindersProvider.notifier).record(p, retry);
      }
      rethrow;
    }
  }
}

final reminderActionsProvider = Provider<ReminderActions>(ReminderActions.new);
