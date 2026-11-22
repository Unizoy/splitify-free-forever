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
