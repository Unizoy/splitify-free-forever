/// Group CSV export writer (planning/08-feature-specs.md #22, phase 17 T3).
///
/// UTF-8 with BOM, `\r\n` line ends, RFC 4180 quoting. Columns: Date, Description, Category,
/// Currency, Amount, Paid by, Split type, one column per member (net of the row, Splitwise
/// style: paid − owed), Notes, Added by, Deleted. Payments are rows with category `Payment`.
/// One footer "Total balance" row per currency sums the member nets of rows that are not
/// deleted. Amounts are plain decimals via [MoneyFormatter.plain] (`1250.50`), never grouped.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:splitify/core/money/money_formatter.dart';

/// Byte order mark that starts the file so spreadsheet apps read it as UTF-8.
const String csvBom = '﻿';

/// Fixed columns before the member columns.
const List<String> csvLeadingColumns = [
  'Date',
  'Description',
  'Category',
  'Currency',
  'Amount',
  'Paid by',
  'Split type',
];

/// Fixed columns after the member columns.
const List<String> csvTrailingColumns = ['Notes', 'Added by', 'Deleted'];

/// Category cell of payment rows.
const String csvPaymentCategory = 'Payment';

/// Description cell of the per-currency footer rows.
const String csvTotalLabel = 'Total balance';

/// A group member column; pass members in fixed order (position, then id), removed ones too.
final class CsvMember {
  const CsvMember(this.id, this.name);

  final String id;
  final String name;
}

/// One expense (or IOU) row.
final class CsvExpense {
  const CsvExpense({
    required this.date,
    required this.description,
    required this.category,
    required this.currency,
    required this.total,
    required this.splitType,
    this.paid = const {},
    this.owed = const {},
    this.notes,
    this.addedBy,
    this.deleted = false,
  });

  /// ISO date `YYYY-MM-DD`.
  final String date;
  final String description;

  /// Category shown (key or label, as the caller chooses).
  final String category;
  final String currency;

  /// Total in minor units of [currency].
  final int total;

  /// `split_kind` (`equal`, `exact`, …).
  final String splitType;

  /// Member id → paid minor units.
  final Map<String, int> paid;

  /// Member id → owed minor units.
  final Map<String, int> owed;
  final String? notes;

  /// Display name of who added it.
  final String? addedBy;
  final bool deleted;
}

/// One payment row: [fromId] paid [toId].
final class CsvPayment {
  const CsvPayment({
    required this.date,
    required this.fromId,
    required this.toId,
    required this.currency,
    required this.amount,
    this.method = 'cash',
    this.note,
    this.addedBy,
    this.deleted = false,
  });

  final String date;
  final String fromId;
  final String toId;
  final String currency;

  /// Amount in minor units of [currency].
  final int amount;

  /// `cash`, `upi`, `bank` or `other`.
  final String method;
  final String? note;
  final String? addedBy;
  final bool deleted;
}

/// Builds the CSV text, BOM first. Rows are ordered by date, then input order (expenses before
/// payments on the same date).
String buildGroupCsv({
  required List<CsvMember> members,
  List<CsvExpense> expenses = const [],
  List<CsvPayment> payments = const [],
}) {
  final names = {for (final m in members) m.id: m.name};
  String nameOf(String id) => names[id] ?? id;

  final rows = <_Row>[
    for (final e in expenses)
      _Row(
        date: e.date,
        currency: e.currency,
        deleted: e.deleted,
        nets: {for (final m in members) m.id: (e.paid[m.id] ?? 0) - (e.owed[m.id] ?? 0)},
        cells: [
          e.date,
          _text(e.description),
          _text(e.category),
          e.currency,
          MoneyFormatter.plain(e.total, e.currency),
          _text(
            [
              for (final m in members)
                if ((e.paid[m.id] ?? 0) != 0) m.name,
            ].join(', '),
          ),
          _text(e.splitType),
        ],
        tail: [_text(e.notes ?? ''), _text(e.addedBy ?? '')],
      ),
    for (final p in payments)
      _Row(
        date: p.date,
        currency: p.currency,
        deleted: p.deleted,
        nets: {
          for (final m in members)
            m.id: (m.id == p.fromId ? p.amount : 0) - (m.id == p.toId ? p.amount : 0),
        },
        cells: [
          p.date,
          _text('${nameOf(p.fromId)} paid ${nameOf(p.toId)}'),
          csvPaymentCategory,
          p.currency,
          MoneyFormatter.plain(p.amount, p.currency),
          _text(nameOf(p.fromId)),
          _text('payment (${p.method})'),
        ],
        tail: [_text(p.note ?? ''), _text(p.addedBy ?? '')],
      ),
  ];
  final order = List<int>.generate(rows.length, (i) => i)
    ..sort((a, b) {
      final byDate = rows[a].date.compareTo(rows[b].date);
      return byDate != 0 ? byDate : a.compareTo(b);
    });

  final totals = <String, Map<String, int>>{};
  final out = StringBuffer(csvBom)
    ..write(
      _line([...csvLeadingColumns, for (final m in members) _text(m.name), ...csvTrailingColumns]),
    );
  for (final i in order) {
    final row = rows[i];
    if (!row.deleted) {
      final sums = totals.putIfAbsent(row.currency, () => {});
      row.nets.forEach((id, net) => sums[id] = (sums[id] ?? 0) + net);
    }
    out.write(
      _line([
        ...row.cells,
        for (final m in members) MoneyFormatter.plain(row.nets[m.id]!, row.currency),
        ...row.tail,
        row.deleted ? 'yes' : 'no',
      ]),
    );
  }
  for (final currency in totals.keys.toList()..sort()) {
    final sums = totals[currency]!;
    out.write(
      _line([
        '',
        csvTotalLabel,
        '',
        currency,
        '',
        '',
        '',
        for (final m in members) MoneyFormatter.plain(sums[m.id] ?? 0, currency),
        '',
        '',
        '',
      ]),
    );
  }
  return out.toString();
}

/// [buildGroupCsv] encoded as UTF-8 bytes (starting `EF BB BF`), ready for the share sheet.
Uint8List buildGroupCsvBytes({
  required List<CsvMember> members,
  List<CsvExpense> expenses = const [],
  List<CsvPayment> payments = const [],
}) => utf8.encode(buildGroupCsv(members: members, expenses: expenses, payments: payments));

/// Quotes [cell] when it holds a comma, quote or line break; quotes inside are repeated.
String csvEscape(String cell) {
  if (!cell.contains(RegExp('[",\r\n]'))) return cell;
  return '"${cell.replaceAll('"', '""')}"';
}

/// User text: a leading `=`, `+`, `-`, `@`, tab or CR gets an apostrophe so spreadsheet apps
/// show it as text instead of running it as a formula (CSV injection). Text that already starts with
/// apostrophes before such a character gets one more, so the importer's undo (strip one) gives it back
/// unchanged (R4, S-475: `'=x` came back as `=x`).
String _text(String value) => value.startsWith(RegExp("'*[=+\\-@\t\r]")) ? "'$value" : value;

String _line(List<String> cells) => '${cells.map(csvEscape).join(',')}\r\n';

final class _Row {
  _Row({
    required this.date,
    required this.currency,
    required this.deleted,
    required this.nets,
    required this.cells,
    required this.tail,
  });

  final String date;
  final String currency;
  final bool deleted;
  final Map<String, int> nets;
  final List<String> cells;
  final List<String> tail;
}
