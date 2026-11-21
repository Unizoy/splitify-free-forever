import 'package:drift/drift.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/repositories.dart';

/// Extra reads for the expense screens (phase 08), kept beside [ExpensesRepository].
extension ExpenseReads on ExpensesRepository {
  /// Every member of [groupId], removed ones too (old expenses still name them), in fixed order
  /// (`position`, then id).
  Stream<List<LocalMember>> watchAllMembers(String groupId) =>
      (db.select(db.groupMembers)
            ..where((m) => m.groupId.equals(groupId))
            ..orderBy([(m) => OrderingTerm.asc(m.position), (m) => OrderingTerm.asc(m.id)]))
          .watch();

  /// Category of the group's newest live expense, suggested first for the next one (#13).
  Future<String?> lastCategory(String groupId) async {
    final row =
        await (db.select(db.expenses)
              ..where((e) => e.groupId.equals(groupId) & e.deletedAt.isNull())
              ..orderBy([(e) => OrderingTerm.desc(e.createdAt), (e) => OrderingTerm.desc(e.id)])
              ..limit(1))
            .getSingleOrNull();
    return row?.category;
  }

  /// Parts of one expense (paid/owed per member).
  Stream<List<ExpensePart>> watchPartsOf(String expenseId) =>
      (db.select(db.expenseParts)..where((p) => p.expenseId.equals(expenseId))).watch();
}
