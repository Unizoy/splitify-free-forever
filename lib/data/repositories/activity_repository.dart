import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';

/// What the activity feed is built from (#18): the server's activity rows (pulled), this phone's own
/// changes still in the outbox, and the names they refer to.
class ActivitySources {
  const ActivitySources({
    required this.activity,
    required this.pending,
    required this.groups,
    required this.members,
    required this.expenses,
    required this.payments,
    this.recurring = const {},
  });

  /// Server activity, newest first.
  final List<LocalActivity> activity;

  /// Own changes not on the server yet, newest first.
  final List<OutboxItem> pending;

  /// Groups by id (deleted ones too: old activity names them).
  final Map<String, LocalGroup> groups;

  /// Members by id (removed ones too).
  final Map<String, LocalMember> members;

  /// Expenses and payments the pending changes and comment rows point at, by id.
  final Map<String, LocalExpense> expenses;
  final Map<String, LocalPayment> payments;

  /// Repeating-expense templates the pending changes point at, by id (phase 16).
  final Map<String, LocalRecurring> recurring;
}

/// Local reads for the Activity tab and the group feed.
class ActivityRepository {
  ActivityRepository(this.db);

  final AppDatabase db;

  /// Newest activity rows shown at most.
  static const limit = 300;

  /// Feed sources of every group, or of [groupId] only; re-emits on every change.
  Stream<ActivitySources> watch({String? groupId}) => db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          db.activity,
          db.outbox,
          db.groups,
          db.groupMembers,
          db.expenses,
          db.payments,
          db.recurringTemplates,
        },
      )
      .watch()
      .asyncMap((_) => load(groupId: groupId));

  Future<ActivitySources> load({String? groupId}) async {
    final activity =
        await (db.select(db.activity)
              ..where((a) => groupId == null ? const Constant(true) : a.groupId.equals(groupId))
              ..orderBy([(a) => OrderingTerm.desc(a.createdAt), (a) => OrderingTerm.desc(a.seq)])
              ..limit(limit))
            .get();
    final pending =
        await (db.select(db.outbox)
              ..where((o) => groupId == null ? const Constant(true) : o.groupId.equals(groupId))
              ..orderBy([(o) => OrderingTerm.desc(o.seq)]))
            .get();
    final groups = await db.select(db.groups).get();
    final members = await db.select(db.groupMembers).get();
    final expenseIds = <String>{
      for (final o in pending)
        if (o.entity == SyncEntity.expense.wire) o.recordId,
      for (final a in activity) ?_commentTarget(a, 'expense'),
    };
    final paymentIds = <String>{
      for (final o in pending)
        if (o.entity == SyncEntity.payment.wire) o.recordId,
      for (final a in activity) ?_commentTarget(a, 'payment'),
    };
    final recurringIds = <String>{
      for (final o in pending)
        if (o.entity == SyncEntity.recurring.wire) o.recordId,
    };
    final recurring = recurringIds.isEmpty
        ? const <LocalRecurring>[]
        : await (db.select(db.recurringTemplates)..where((t) => t.id.isIn(recurringIds))).get();
    expenseIds.addAll([for (final t in recurring) ?t.expenseId]);
    final expenses = expenseIds.isEmpty
        ? const <LocalExpense>[]
        : await (db.select(db.expenses)..where((e) => e.id.isIn(expenseIds))).get();
    final payments = paymentIds.isEmpty
        ? const <LocalPayment>[]
        : await (db.select(db.payments)..where((p) => p.id.isIn(paymentIds))).get();
    return ActivitySources(
      activity: activity,
      pending: pending,
      groups: {for (final g in groups) g.id: g},
      members: {for (final m in members) m.id: m},
      expenses: {for (final e in expenses) e.id: e},
      payments: {for (final p in payments) p.id: p},
      recurring: {for (final t in recurring) t.id: t},
    );
  }

  static String? _commentTarget(LocalActivity a, String type) {
    if (!a.type.startsWith('comment_')) return null;
    final data = jsonDecode(a.data);
    if (data is! Map || data['target_type'] != type) return null;
    return data['target_id'] as String?;
  }
}
