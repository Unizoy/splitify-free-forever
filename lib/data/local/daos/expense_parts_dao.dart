import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:splitify/data/local/app_database.dart';

/// Keeps `expense_parts` in step with `expenses` (04 §2); call inside the transaction that wrote the expense.
/// Deleted expenses have no parts, so balance sums skip tombstones.
Future<void> rebuildExpenseParts(AppDatabase db, String expenseId) async {
  await (db.delete(db.expenseParts)..where((p) => p.expenseId.equals(expenseId))).go();
  final e = await (db.select(db.expenses)..where((x) => x.id.equals(expenseId))).getSingleOrNull();
  if (e == null || e.deletedAt != null) return;
  final paid = _parts(e.payers);
  final owed = _parts(e.shares);
  final fxPaid = _parts(e.fxPayers);
  final fxOwed = _parts(e.fxShares);
  final fx = e.fxCurrency != null;
  for (final m in {...paid.keys, ...owed.keys}) {
    await db
        .into(db.expenseParts)
        .insert(
          ExpensePartsCompanion.insert(
            expenseId: e.id,
            groupId: e.groupId,
            memberId: m,
            currency: e.currency,
            paid: Value(paid[m] ?? 0),
            owed: Value(owed[m] ?? 0),
            fxCurrency: Value(e.fxCurrency),
            fxPaid: Value(fx ? fxPaid[m] ?? 0 : null),
            fxOwed: Value(fx ? fxOwed[m] ?? 0 : null),
          ),
        );
  }
}

Map<String, int> _parts(String? json) {
  if (json == null) return const {};
  final m = jsonDecode(json) as Map<String, Object?>;
  return {for (final e in m.entries) e.key: e.value! as int};
}
