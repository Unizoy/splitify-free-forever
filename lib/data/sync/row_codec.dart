import 'dart:convert';

import 'package:drift/drift.dart';

/// Server/feature row (snake_case JSON) â†’ column values for [table]. Unknown keys are ignored; JSON objects
/// and lists become TEXT JSON; numbers sent for TEXT columns (numeric fx rates) keep their decimal text.
Map<String, Variable<Object>> columnValues(
  TableInfo<Table, Object?> table,
  Map<String, Object?> row,
) => {
  for (final c in table.$columns)
    if (row.containsKey(c.name)) c.name: Variable<Object>(_convert(c.type, row[c.name])),
};

Object? _convert(Object type, Object? v) {
  if (v == null) return null;
  if (type == DriftSqlType.string) {
    if (v is String) return v;
    if (v is Map || v is List) return jsonEncode(v);
    return '$v';
  }
  if (type == DriftSqlType.bool) return v is bool ? v : v == 1;
  if (type == DriftSqlType.int) return v is int ? v : int.parse('$v');
  return v;
}

/// Table of [db] called [name].
TableInfo<Table, Object?> tableNamed(GeneratedDatabase db, String name) =>
    db.allTables.firstWhere((t) => t.actualTableName == name);

/// `INSERT [OR REPLACE]` of raw column values (typed inserts need the row class; this works for any table)
/// and notifies stream queries on [table].
Future<void> insertRaw(
  GeneratedDatabase db,
  TableInfo<Table, Object?> table,
  Map<String, Variable<Object>> values, {
  bool replace = false,
}) {
  final cols = values.keys.toList();
  return db.customInsert(
    'INSERT ${replace ? 'OR REPLACE ' : ''}INTO "${table.actualTableName}" '
    '(${cols.map((c) => '"$c"').join(', ')}) VALUES (${List.filled(cols.length, '?').join(', ')})',
    variables: [for (final c in cols) values[c]!],
    updates: {table},
  );
}
