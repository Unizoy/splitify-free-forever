import 'package:drift/drift.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';

/// Everything a group's CSV export (#22) holds: the group, every member in fixed order (removed ones
/// too) and every expense and payment, deleted ones included (they are listed with `Deleted = yes`).
class ExportLedger {
  const ExportLedger({
    required this.group,
    required this.members,
    required this.expenses,
    required this.payments,
  });

  final LocalGroup group;
  final List<LocalMember> members;

  /// All expenses (IOUs too), oldest first.
  final List<LocalExpense> expenses;

  /// All payments, oldest first.
  final List<LocalPayment> payments;
}

/// Local reads for the CSV export (phase 17), kept beside [LedgerRepository].
extension ExportReads on LedgerRepository {
  /// The export rows of [groupId]; null while the group is not on this phone (or deleted).
  Future<ExportLedger?> loadExport(String groupId) async {
    final group = await (db.select(
      db.groups,
    )..where((g) => g.id.equals(groupId) & g.deletedAt.isNull())).getSingleOrNull();
    if (group == null) return null;
    final members =
        await (db.select(db.groupMembers)
              ..where((m) => m.groupId.equals(groupId))
              ..orderBy([(m) => OrderingTerm.asc(m.position), (m) => OrderingTerm.asc(m.id)]))
            .get();
    final expenses =
        await (db.select(db.expenses)
              ..where((e) => e.groupId.equals(groupId))
              ..orderBy([
                (e) => OrderingTerm.asc(e.date),
                (e) => OrderingTerm.asc(e.createdAt),
                (e) => OrderingTerm.asc(e.id),
              ]))
            .get();
    final payments =
        await (db.select(db.payments)
              ..where((p) => p.groupId.equals(groupId))
              ..orderBy([
                (p) => OrderingTerm.asc(p.date),
                (p) => OrderingTerm.asc(p.createdAt),
                (p) => OrderingTerm.asc(p.id),
              ]))
            .get();
    return ExportLedger(group: group, members: members, expenses: expenses, payments: payments);
  }
}

/// One group's rows in "Download my data" (D-034 WP-D): everything on this phone, deleted rows too.
class BackupGroupRows {
  const BackupGroupRows({
    required this.group,
    this.members = const [],
    this.expenses = const [],
    this.payments = const [],
    this.comments = const [],
    this.recurring = const [],
  });

  final LocalGroup group;

  /// Fixed order (position, then id), removed members too.
  final List<LocalMember> members;

  /// Oldest first (date, created, id); IOUs too.
  final List<LocalExpense> expenses;

  /// Oldest first (date, created, id).
  final List<LocalPayment> payments;

  /// Oldest first (created, id).
  final List<LocalComment> comments;

  /// By first date, then id.
  final List<LocalRecurring> recurring;
}

/// Counts shown on the Your data sheet: live groups, expenses and payments, and rows not synced yet.
typedef BackupCounts = ({int groups, int expenses, int payments, int pending});

/// Local reads for "Download my data" (D-034 WP-D).
extension BackupReads on LedgerRepository {
  /// Every group on this phone (deleted ones too, oldest first) with all its rows; [userId]'s profile.
  Future<({LocalProfile? me, List<BackupGroupRows> groups})> loadBackup(String? userId) async {
    final groups = await (db.select(
      db.groups,
    )..orderBy([(g) => OrderingTerm.asc(g.createdAt), (g) => OrderingTerm.asc(g.id)])).get();
    final members = await (db.select(
      db.groupMembers,
    )..orderBy([(m) => OrderingTerm.asc(m.position), (m) => OrderingTerm.asc(m.id)])).get();
    final expenses =
        await (db.select(db.expenses)..orderBy([
              (e) => OrderingTerm.asc(e.date),
              (e) => OrderingTerm.asc(e.createdAt),
              (e) => OrderingTerm.asc(e.id),
            ]))
            .get();
    final payments =
        await (db.select(db.payments)..orderBy([
              (p) => OrderingTerm.asc(p.date),
              (p) => OrderingTerm.asc(p.createdAt),
              (p) => OrderingTerm.asc(p.id),
            ]))
            .get();
    final comments = await (db.select(
      db.comments,
    )..orderBy([(c) => OrderingTerm.asc(c.createdAt), (c) => OrderingTerm.asc(c.id)])).get();
    final recurring = await (db.select(
      db.recurringTemplates,
    )..orderBy([(r) => OrderingTerm.asc(r.anchorDate), (r) => OrderingTerm.asc(r.id)])).get();
    Map<String, List<T>> by<T>(List<T> rows, String Function(T) group) {
      final out = <String, List<T>>{};
      for (final r in rows) {
        (out[group(r)] ??= []).add(r);
      }
      return out;
    }

    final m = by(members, (r) => r.groupId);
    final e = by(expenses, (r) => r.groupId);
    final p = by(payments, (r) => r.groupId);
    final c = by(comments, (r) => r.groupId);
    final t = by(recurring, (r) => r.groupId);
    final me = userId == null
        ? null
        : await (db.select(db.profiles)..where((x) => x.id.equals(userId))).getSingleOrNull();
    return (
      me: me,
      groups: [
        for (final g in groups)
          BackupGroupRows(
            group: g,
            members: m[g.id] ?? const [],
            expenses: e[g.id] ?? const [],
            payments: p[g.id] ?? const [],
            comments: c[g.id] ?? const [],
            recurring: t[g.id] ?? const [],
          ),
      ],
    );
  }

  /// Live counts for the Your data sheet (re-run on every change).
  Stream<BackupCounts> watchBackupCounts() => db
      .customSelect(
        'SELECT '
        '(SELECT COUNT(*) FROM "groups" WHERE deleted_at IS NULL) AS g, '
        '(SELECT COUNT(*) FROM expenses WHERE deleted_at IS NULL) AS e, '
        '(SELECT COUNT(*) FROM payments WHERE deleted_at IS NULL) AS p, '
        "((SELECT COUNT(*) FROM \"groups\" WHERE sync_state <> 'synced') "
        "+ (SELECT COUNT(*) FROM group_members WHERE sync_state <> 'synced') "
        "+ (SELECT COUNT(*) FROM expenses WHERE sync_state <> 'synced') "
        "+ (SELECT COUNT(*) FROM payments WHERE sync_state <> 'synced') "
        "+ (SELECT COUNT(*) FROM comments WHERE sync_state <> 'synced') "
        "+ (SELECT COUNT(*) FROM recurring_templates WHERE sync_state <> 'synced')) AS u",
        readsFrom: {
          db.groups,
          db.groupMembers,
          db.expenses,
          db.payments,
          db.comments,
          db.recurringTemplates,
        },
      )
      .watchSingle()
      .map(
        (r) => (
          groups: r.read<int>('g'),
          expenses: r.read<int>('e'),
          payments: r.read<int>('p'),
          pending: r.read<int>('u'),
        ),
      );
}
