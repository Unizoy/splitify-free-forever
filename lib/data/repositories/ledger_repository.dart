import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/stream_ext.dart';

/// Everything the balances and totals of one group are computed from (05 §5, rule 3): the group, all of
/// its members in fixed order (removed ones too: old records still name them), its live expenses and its
/// live payments.
class GroupLedger {
  const GroupLedger({
    required this.group,
    required this.members,
    required this.expenses,
    required this.payments,
  });

  final LocalGroup group;

  /// Every member of the group in fixed order (`position`, then id).
  final List<LocalMember> members;

  /// Live (not deleted) expenses, newest first.
  final List<LocalExpense> expenses;

  /// Live (not deleted) payments, newest first.
  final List<LocalPayment> payments;

  // Value equality, so a re-run that read the same rows doesn't recompute balances (S-455).
  @override
  bool operator ==(Object other) =>
      other is GroupLedger &&
      other.group == group &&
      listEquals(other.members, members) &&
      listEquals(other.expenses, expenses) &&
      listEquals(other.payments, payments);

  @override
  int get hashCode => Object.hash(group, members.length, expenses.length, payments.length);
}

/// Local reads for balances, totals and payments (phase 09). Streams re-run whenever one of the tables
/// they read changes, so pulls and local writes show at once.
class LedgerRepository {
  LedgerRepository(this.db);

  final AppDatabase db;

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables => {
    db.groups,
    db.groupMembers,
    db.expenses,
    db.payments,
  };

  /// Re-runs [load] after every change to [tables] (first value at once). Changes that land while a load
  /// runs (a sync's pull pages) collapse into one more load (S-455).
  Stream<T> _watch<T>(
    Set<ResultSetImplementation<dynamic, dynamic>> tables,
    Future<T> Function() load,
  ) => db.customSelect('SELECT 1', readsFrom: tables).watch().asyncMapLatest((_) => load());

  /// The ledger of [groupId]; null while the group is not on this phone (or deleted). A write to another
  /// group re-reads it but sends nothing new (S-455).
  Stream<GroupLedger?> watchGroup(String groupId) =>
      _watch(_tables, () => loadGroup(groupId)).distinct();

  /// Ledgers of every live group (archived and friend groups too), oldest first.
  Stream<List<GroupLedger>> watchAll() => _watch(_tables, loadAll).distinctRows();

  Future<GroupLedger?> loadGroup(String groupId) async {
    final group = await (db.select(
      db.groups,
    )..where((g) => g.id.equals(groupId) & g.deletedAt.isNull())).getSingleOrNull();
    if (group == null) return null;
    final all = await _load(groupId: groupId);
    return GroupLedger(
      group: group,
      members: all.members[groupId] ?? const [],
      expenses: all.expenses[groupId] ?? const [],
      payments: all.payments[groupId] ?? const [],
    );
  }

  Future<List<GroupLedger>> loadAll() async {
    final groups =
        await (db.select(db.groups)
              ..where((g) => g.deletedAt.isNull())
              ..orderBy([(g) => OrderingTerm.asc(g.createdAt), (g) => OrderingTerm.asc(g.id)]))
            .get();
    final all = await _load();
    return [
      for (final g in groups)
        GroupLedger(
          group: g,
          members: all.members[g.id] ?? const [],
          expenses: all.expenses[g.id] ?? const [],
          payments: all.payments[g.id] ?? const [],
        ),
    ];
  }

  Future<
    ({
      Map<String, List<LocalMember>> members,
      Map<String, List<LocalExpense>> expenses,
      Map<String, List<LocalPayment>> payments,
    })
  >
  _load({String? groupId}) async {
    final members =
        await (db.select(db.groupMembers)
              ..where((m) => groupId == null ? const Constant(true) : m.groupId.equals(groupId))
              ..orderBy([(m) => OrderingTerm.asc(m.position), (m) => OrderingTerm.asc(m.id)]))
            .get();
    final expenses =
        await (db.select(db.expenses)
              ..where(
                (e) =>
                    e.deletedAt.isNull() &
                    (groupId == null ? const Constant(true) : e.groupId.equals(groupId)),
              )
              ..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.desc(e.id)]))
            .get();
    final payments =
        await (db.select(db.payments)
              ..where(
                (p) =>
                    p.deletedAt.isNull() &
                    (groupId == null ? const Constant(true) : p.groupId.equals(groupId)),
              )
              ..orderBy([(p) => OrderingTerm.desc(p.date), (p) => OrderingTerm.desc(p.id)]))
            .get();
    Map<String, List<T>> by<T>(List<T> rows, String Function(T) key) {
      final out = <String, List<T>>{};
      for (final r in rows) {
        (out[key(r)] ??= []).add(r);
      }
      return out;
    }

    return (
      members: by(members, (m) => m.groupId),
      expenses: by(expenses, (e) => e.groupId),
      payments: by(payments, (p) => p.groupId),
    );
  }

  /// One payment (deleted ones too, so the detail screen can say it is gone).
  Stream<LocalPayment?> watchPayment(String id) =>
      (db.select(db.payments)..where((p) => p.id.equals(id))).watchSingleOrNull().distinct();
}
