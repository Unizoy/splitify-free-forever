import 'package:drift/drift.dart';
import 'package:splitify/data/local/app_database.dart';

/// Local reads for the currency picker (#14).
class CurrencyReads {
  CurrencyReads(this.db);

  final AppDatabase db;

  /// Currencies of this phone's live expenses and payments, most recently used first (at most [limit]).
  Stream<List<String>> watchRecent({int limit = 5}) => db
      .customSelect(
        'SELECT TRIM(currency) AS code, MAX(at) AS last FROM ('
        '  SELECT currency, COALESCE(created_at, date) AS at FROM expenses WHERE deleted_at IS NULL'
        '  UNION ALL'
        '  SELECT currency, COALESCE(created_at, date) AS at FROM payments WHERE deleted_at IS NULL'
        ') GROUP BY TRIM(currency) ORDER BY last DESC, code ASC LIMIT ?',
        variables: [Variable<int>(limit)],
        readsFrom: {db.expenses, db.payments},
      )
      .map((r) => r.read<String>('code'))
      .watch();
}
