import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/core/money/scaled_input.dart';
import 'package:splitify/data/local/app_database.dart';

/// Keeps the offline search table `expense_search` (FTS5, #34) in step with `expenses`: one row per live
/// expense with its description, notes, the names of everyone in it (member name and linked profile name)
/// and the amount as plain and grouped text (`1200 1,200`). Call inside the transaction that wrote the rows.
abstract final class SearchIndex {
  /// Re-indexes the expenses [ids] (deleted or missing ones just leave the index).
  static Future<void> expenses(AppDatabase db, Iterable<String> ids) async {
    final list = ids.toSet().toList();
    for (var i = 0; i < list.length; i += 500) {
      final chunk = list.sublist(i, i + 500 > list.length ? list.length : i + 500);
      await _drop(db, 'expense_id', chunk);
      final rows = await (db.select(db.expenses)..where((e) => e.id.isIn(chunk))).get();
      await _insert(db, rows);
    }
  }

  /// Re-indexes every expense of [groupIds] (member names changed).
  static Future<void> groups(AppDatabase db, Iterable<String> groupIds) async {
    final ids = groupIds.toSet().toList();
    if (ids.isEmpty) return;
    await _drop(db, 'group_id', ids);
    final rows = await (db.select(db.expenses)..where((e) => e.groupId.isIn(ids))).get();
    await _insert(db, rows);
  }

  /// Re-indexes everything (schema upgrade).
  static Future<void> all(AppDatabase db) async {
    await db.customUpdate(
      'DELETE FROM expense_search',
      updates: {db.expenseSearch},
      updateKind: UpdateKind.delete,
    );
    await _insert(db, await db.select(db.expenses).get());
  }

  /// Search text of an amount: plain and Indian-grouped, without a zero fraction (`1200 1,200`,
  /// `1200.5 1,200.50`).
  static String amountText(int minor, String currency) {
    final plain = ScaledInput.format(minor, Currencies.exponentOf(currency));
    final grouped = const MoneyFormatter(
      hideZeroFraction: true,
      unit: MoneyUnit.none,
    ).format(minor, currency);
    return plain == grouped ? plain : '$plain $grouped';
  }

  static Future<void> _drop(AppDatabase db, String column, List<String> ids) => db.customUpdate(
    'DELETE FROM expense_search WHERE $column IN (${List.filled(ids.length, '?').join(', ')})',
    variables: [for (final id in ids) Variable<String>(id)],
    updates: {db.expenseSearch},
    updateKind: UpdateKind.delete,
  );

  static Future<void> _insert(AppDatabase db, List<LocalExpense> rows) async {
    final live = [
      for (final e in rows)
        if (e.deletedAt == null) e,
    ];
    if (live.isEmpty) return;
    final names = await _names(db, {for (final e in live) e.groupId});
    for (final e in live) {
      final people = {..._keys(e.payers), ..._keys(e.shares)};
      final text = [for (final m in people) ...?names[m]].toSet().join(' ');
      await db.customInsert(
        'INSERT INTO expense_search (expense_id, group_id, description, notes, member_names, amount_text) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        variables: [
          Variable<String>(e.id),
          Variable<String>(e.groupId),
          Variable<String>(e.description),
          Variable<String>(e.notes ?? ''),
          Variable<String>(text),
          Variable<String>(amountText(e.total, e.currency.trim())),
        ],
        updates: {db.expenseSearch},
      );
    }
  }

  /// Names per member id of [groupIds]: the member's own name and the linked account's name.
  static Future<Map<String, List<String>>> _names(AppDatabase db, Set<String> groupIds) async {
    final ids = groupIds.toList();
    final rows = await db
        .customSelect(
          'SELECT m.id AS id, m.display_name AS name, p.display_name AS profile '
          'FROM group_members m LEFT JOIN profiles p ON p.id = m.user_id '
          'WHERE m.group_id IN (${List.filled(ids.length, '?').join(', ')})',
          variables: [for (final id in ids) Variable<String>(id)],
          readsFrom: {db.groupMembers, db.profiles},
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('id'): [
          r.read<String>('name'),
          if (r.readNullable<String>('profile') case final p? when p.trim().isNotEmpty) p,
        ],
    };
  }

  static Iterable<String> _keys(String? json) {
    if (json == null) return const [];
    final m = jsonDecode(json);
    return m is Map<String, Object?> ? m.keys : const [];
  }
}
