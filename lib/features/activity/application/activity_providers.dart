import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/activity/application/settings_activity.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/activity_repository.dart';
import 'package:splitify/data/repositories/import_repository.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';

/// Filter chips of the feed (#18).
enum ActivityFilter { all, expenses, payments, comments, groups }

/// A person named in an activity sentence.
typedef ActivityPerson = ({String name, String seed, bool isMe});

/// One row of the activity feed: a server activity row, or one of my changes still in the outbox
/// ([pending], shown with the "not synced yet" marker).
class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.type,
    required this.groupId,
    required this.groupName,
    required this.at,
    required this.actor,
    this.member,
    this.from,
    this.to,
    this.description,
    this.amount,
    this.currency,
    this.targetType,
    this.targetId,
    this.pending = false,
  });

  final String id;

  /// Activity type (`expense_added`, …; 08 cross-cutting list).
  final String type;
  final String groupId;
  final String groupName;

  /// When it happened, local time.
  final DateTime at;
  final ActivityPerson actor;

  /// The member a `member_*` row is about.
  final ActivityPerson? member;

  /// Payer and receiver of a `payment_*` row.
  final ActivityPerson? from;
  final ActivityPerson? to;

  /// Expense description (`expense_*`), the commented expense (`comment_*`) or the group name.
  final String? description;

  /// Expense total or payment amount (minor units of [currency]).
  final int? amount;
  final String? currency;

  /// What a tap opens: `expense`, `payment` or `group` (+ id).
  final String? targetType;
  final String? targetId;
  final bool pending;

  ActivityFilter get filter => filterOf(type);

  static ActivityFilter filterOf(String type) {
    if (type.startsWith('expense_') ||
        type.startsWith('recurring_') ||
        type.startsWith('import_')) {
      return ActivityFilter.expenses;
    }
    if (type.startsWith('payment_') || type == 'reminder_sent') return ActivityFilter.payments;
    if (type.startsWith('comment_')) return ActivityFilter.comments;
    return ActivityFilter.groups;
  }
}

Map<String, Object?> _json(String? s) {
  if (s == null || s.isEmpty) return const {};
  final v = jsonDecode(s);
  return v is Map ? v.cast<String, Object?>() : const {};
}

DateTime _time(String? iso) =>
    (iso == null ? null : DateTime.tryParse(iso))?.toLocal() ??
    DateTime.fromMillisecondsSinceEpoch(0);

int? _int(Object? v) => v is num ? v.toInt() : null;

/// Builds the feed rows (newest first) from [s] for the signed-in [userId].
List<ActivityItem> buildActivityItems(ActivitySources s, String? userId) {
  ActivityPerson person(String? memberId, {String? fallback}) {
    final m = memberId == null ? null : s.members[memberId];
    return (
      name: m?.displayName ?? fallback ?? '',
      seed: memberId ?? fallback ?? '',
      isMe: m != null && userId != null && m.userId == userId,
    );
  }

  ActivityPerson actorOf(LocalActivity a) {
    if (a.actorMemberId != null && s.members.containsKey(a.actorMemberId)) {
      final p = person(a.actorMemberId);
      return (name: p.name, seed: p.seed, isMe: p.isMe || a.actorUserId == userId);
    }
    final byUser = s.members.values
        .where((m) => m.groupId == a.groupId && m.userId != null && m.userId == a.actorUserId)
        .firstOrNull;
    if (byUser != null) return person(byUser.id);
    return (
      name: '',
      seed: a.actorUserId ?? a.id,
      isMe: a.actorUserId != null && a.actorUserId == userId,
    );
  }

  final me = s.members.values.where((m) => userId != null && m.userId == userId);
  ActivityPerson meIn(String groupId) {
    final m = me.where((m) => m.groupId == groupId).firstOrNull;
    return (name: m?.displayName ?? '', seed: m?.id ?? userId ?? '', isMe: true);
  }

  String groupName(String id) => s.groups[id]?.name ?? '';

  final out = <ActivityItem>[];
  for (final a in s.activity) {
    final d = _json(a.data);
    final type = a.type == 'expense_added' && d['recurring'] == true
        ? 'expense_added_recurring'
        : refineActivityType(a.type, d);
    var targetType = a.targetType;
    var targetId = a.targetId;
    String? description;
    if (type.startsWith('comment_')) {
      targetType = d['target_type'] as String?;
      targetId = d['target_id'] as String?;
      description = targetType == 'expense' ? s.expenses[targetId]?.description : null;
    } else if (type.startsWith('expense_') || type.startsWith('recurring_')) {
      description = d['description'] as String?;
      if (type.startsWith('recurring_') && d['expense_id'] is String) {
        targetType = 'expense';
        targetId = d['expense_id']! as String;
      }
    } else if (type.startsWith('group_') || type.startsWith('settings_')) {
      description = (d['name'] as String?) ?? groupName(a.groupId);
    }
    if (type.endsWith('_deleted') && !type.startsWith('comment_')) {
      targetType = 'group';
      targetId = a.groupId;
    } else if (targetType != 'expense' && targetType != 'payment') {
      targetType = 'group';
      targetId = a.groupId;
    }
    out.add(
      ActivityItem(
        id: a.id,
        type: type,
        groupId: a.groupId,
        groupName: groupName(a.groupId),
        at: _time(a.createdAt),
        actor: actorOf(a),
        member: type.startsWith('member_')
            ? person(d['member_id'] as String?, fallback: d['name'] as String?)
            : null,
        from: type.startsWith('payment_') ? person(d['from_member'] as String?) : null,
        to: type.startsWith('payment_') ? person(d['to_member'] as String?) : null,
        description: description,
        amount: _int(d['total']) ?? _int(d['amount']),
        currency: (d['currency'] as String?)?.trim(),
        targetType: targetType,
        targetId: targetId,
      ),
    );
  }

  for (final o in s.pending) {
    final item = _pendingItem(o, s, meIn(o.groupId), person, groupName(o.groupId));
    if (item != null) out.add(item);
  }
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
}

ActivityItem? _pendingItem(
  OutboxItem o,
  ActivitySources s,
  ActivityPerson me,
  ActivityPerson Function(String? memberId, {String? fallback}) person,
  String groupName,
) {
  final op = o.op;
  final payload = _json(o.payload);
  String verb(String added, {required bool isNew}) => switch (op) {
    'delete' => 'deleted',
    'restore' => 'restored',
    _ => isNew ? added : 'edited',
  };
  final base = (id: 'pending-${o.seq}', at: _time(o.createdAt), groupId: o.groupId);
  // An import is one entry (0021): its summary / undo note stands for the batch, other rows are quiet.
  if (payload['source'] == 'import') {
    final values = payload['split_values'];
    final note = values is Map ? values : const <String, Object?>{};
    final String type;
    if (note[importUndoKey] != null) {
      type = 'import_undone';
    } else if (note[importSummaryKey] is Map) {
      type = (note[importSummaryKey] as Map)['source'] == 'splitify'
          ? 'import_completed_file'
          : 'import_completed';
    } else {
      return null;
    }
    return ActivityItem(
      id: base.id,
      type: type,
      groupId: base.groupId,
      groupName: groupName,
      at: base.at,
      actor: me,
      targetType: 'group',
      targetId: o.groupId,
      pending: true,
    );
  }
  switch (o.entity) {
    case 'expense':
      final e = s.expenses[o.recordId];
      final type = 'expense_${verb('added', isNew: e == null || e.seq == 0)}';
      return ActivityItem(
        id: base.id,
        type: type,
        groupId: base.groupId,
        groupName: groupName,
        at: base.at,
        actor: me,
        description: e?.description ?? payload['description'] as String?,
        amount: e?.total ?? _int(payload['total']),
        currency: e?.currency.trim() ?? (payload['currency'] as String?),
        targetType: op == 'delete' ? 'group' : 'expense',
        targetId: op == 'delete' ? o.groupId : o.recordId,
        pending: true,
      );
    case 'payment':
      final p = s.payments[o.recordId];
      final type = 'payment_${verb('added', isNew: p == null || p.seq == 0)}';
      return ActivityItem(
        id: base.id,
        type: type,
        groupId: base.groupId,
        groupName: groupName,
        at: base.at,
        actor: me,
        from: person(p?.fromMember ?? payload['from_member'] as String?),
        to: person(p?.toMember ?? payload['to_member'] as String?),
        amount: p?.amount ?? _int(payload['amount']),
        currency: p?.currency.trim() ?? (payload['currency'] as String?),
        targetType: op == 'delete' ? 'group' : 'payment',
        targetId: op == 'delete' ? o.groupId : o.recordId,
        pending: true,
      );
    case 'group':
      final g = s.groups[o.recordId];
      final isNew = g == null || g.seq == 0;
      final String type;
      if (op == 'upsert' && !isNew && payload.containsKey('archived_at')) {
        type = payload['archived_at'] == null ? 'group_unarchived' : 'group_archived';
      } else if (op == 'upsert' &&
          !isNew &&
          payload.containsKey('simplify_debts') &&
          payload.length == 1) {
        type = simplifyActivityType(on: payload['simplify_debts'] == true);
      } else {
        type = 'group_${verb('created', isNew: isNew).replaceFirst('edited', 'updated')}';
      }
      return ActivityItem(
        id: base.id,
        type: type,
        groupId: base.groupId,
        groupName: groupName,
        at: base.at,
        actor: me,
        description: g?.name ?? payload['name'] as String?,
        targetType: 'group',
        targetId: o.groupId,
        pending: true,
      );
    case 'member':
      final m = s.members[o.recordId];
      final isNew = m == null || m.seq == 0;
      return ActivityItem(
        id: base.id,
        type: switch (op) {
          'delete' => 'member_removed',
          _ => isNew ? 'member_added' : 'group_updated',
        },
        groupId: base.groupId,
        groupName: groupName,
        at: base.at,
        actor: me,
        member: person(o.recordId, fallback: payload['display_name'] as String?),
        description: groupName,
        targetType: 'group',
        targetId: o.groupId,
        pending: true,
      );
    case 'recurring':
      final t = s.recurring[o.recordId];
      final isNew = t == null || t.seq == 0;
      final template = payload['template'];
      return ActivityItem(
        id: base.id,
        type: isNew
            ? 'recurring_created'
            : (payload['active'] == false || op == 'delete'
                  ? 'recurring_stopped'
                  : 'recurring_updated'),
        groupId: base.groupId,
        groupName: groupName,
        at: base.at,
        actor: me,
        description: template is Map
            ? template['description'] as String?
            : s.expenses[t?.expenseId]?.description,
        targetType: t?.expenseId == null && payload['expense_id'] == null ? 'group' : 'expense',
        targetId: (t?.expenseId ?? payload['expense_id'] as String?) ?? o.groupId,
        pending: true,
      );
    case 'comment':
      return ActivityItem(
        id: base.id,
        type: op == 'delete' ? 'comment_deleted' : 'comment_added',
        groupId: base.groupId,
        groupName: groupName,
        at: base.at,
        actor: me,
        targetType: 'group',
        targetId: o.groupId,
        pending: true,
      );
  }
  return null;
}

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(appDatabaseProvider)),
);

/// Feed sources of every group (null) or of one group.
final activitySourcesProvider = StreamProvider.autoDispose.family<ActivitySources, String?>(
  (ref, groupId) => ref.watch(activityRepositoryProvider).watch(groupId: groupId),
);

/// The feed (newest first) of every group (null) or of one group.
final activityItemsProvider = Provider.autoDispose.family<AsyncValue<List<ActivityItem>>, String?>((
  ref,
  groupId,
) {
  final uid = ref.watch(currentUserIdProvider);
  return ref.watch(activitySourcesProvider(groupId)).whenData((s) => buildActivityItems(s, uid));
});

/// Rows of [items] that pass [filter].
List<ActivityItem> filterActivity(List<ActivityItem> items, ActivityFilter filter) =>
    filter == ActivityFilter.all
    ? items
    : [
        for (final i in items)
          if (i.filter == filter) i,
      ];
