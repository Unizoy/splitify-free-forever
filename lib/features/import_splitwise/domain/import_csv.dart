/// One entry point for the importer (X1): a Splitwise export or Splitify's own group export
/// (planning/08-feature-specs.md #22, `csv_export.dart`; TC-22-02 round trip), detected from the
/// header row. Both become the same [SplitwiseCsv] model, so reconstruction and checks are shared.
library;

import 'package:csv/csv.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/features/export/domain/csv_export.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_csv_parser.dart';

/// Which app wrote a file.
enum ImportFormat { splitwise, splitify }

/// A parsed file and the app that wrote it.
typedef ImportCsv = ({ImportFormat format, SplitwiseCsv file});

final _currency = RegExp(r'^[A-Z]{3}$');
final _formulaGuard = RegExp('^\'[=+\\-@\t\r]');

/// Parses [text] in either format. Throws a [SplitwiseCsvError] ([BadHeader] when the header is
/// neither format's). [categoryKeys] maps a lower-case category label, as Splitify's export writes
/// it ("dining out"), to its D-016 key (S-184); unknown labels go through the Splitwise mapping.
ImportCsv parseImportCsv(
  String text, {
  String paymentCategory = splitwisePaymentCategory,
  Map<String, String> categoryKeys = const {},
}) {
  final input = text.startsWith('﻿') ? text.substring(1) : text;
  final cells = _cells(input);
  if (cells.every(_isBlank)) throw const EmptyFile();
  if (_isSplitifyHeader(cells.first)) {
    return (format: ImportFormat.splitify, file: _readSplitify(cells, categoryKeys));
  }
  return (
    format: ImportFormat.splitwise,
    file: parseSplitwiseCsv(input, paymentCategory: paymentCategory),
  );
}

List<List<String>> _cells(String input) => [
  for (final r in const CsvDecoder(fieldDelimiter: ',', skipEmptyLines: false).convert(input))
    [for (final c in r) '$c'.trim()],
];

bool _isBlank(List<String> cells) => cells.every((c) => c.isEmpty);

bool _same(String a, String b) => a.toLowerCase() == b.toLowerCase();

bool _isSplitifyHeader(List<String> h) {
  final lead = csvLeadingColumns.length;
  final tail = csvTrailingColumns.length;
  if (h.length < lead + tail) return false;
  for (var i = 0; i < lead; i++) {
    if (!_same(h[i], csvLeadingColumns[i])) return false;
  }
  for (var i = 0; i < tail; i++) {
    if (!_same(h[h.length - tail + i], csvTrailingColumns[i])) return false;
  }
  return true;
}

/// The export guards user text that looks like a formula with a leading apostrophe; undo that.
String _text(String cell) => _formulaGuard.hasMatch(cell) ? cell.substring(1) : cell;

SplitwiseCsv _readSplitify(List<List<String>> cells, Map<String, String> categoryKeys) {
  final header = cells.first;
  final lead = csvLeadingColumns.length;
  final tail = csvTrailingColumns.length;
  final members = [for (final m in header.sublist(lead, header.length - tail)) _text(m)];
  if (members.isEmpty ||
      members.any((m) => m.isEmpty) ||
      members.toSet().length != members.length) {
    throw const BadHeader();
  }
  final notesAt = header.length - tail;
  final deletedAt = header.length - 1;
  final rows = <SplitwiseRow>[];
  final sums = <String, Map<String, int>>{};
  final totals = <String, Map<String, int>>{};
  for (var i = 1; i < cells.length; i++) {
    final cell = cells[i];
    final row = i + 1;
    if (_isBlank(cell)) continue;
    if (cell.length != header.length) {
      throw WrongColumnCount(row, expected: header.length, actual: cell.length);
    }
    final currency = cell[3].toUpperCase();
    if (!_currency.hasMatch(currency)) throw InvalidCurrency(row, cell[3]);
    final exponent = Currencies.exponentOf(currency);
    final nets = <String, int>{
      for (var m = 0; m < members.length; m++)
        members[m]: parseMinorCell(cell[lead + m], exponent, row, members[m]),
    };
    final description = _text(cell[1]);
    if (cell[0].isEmpty && _same(description, csvTotalLabel)) {
      if (totals.containsKey(currency)) throw DuplicateTotals(row, currency);
      totals[currency] = nets;
      continue;
    }
    // Deleted rows are in the export for the record only; they don't count in its totals.
    if (_same(cell[deletedAt], 'yes')) continue;
    final remaining = nets.values.fold(0, (a, b) => a + b);
    if (remaining != 0) throw RowNotBalanced(row, remaining);
    final sum = sums.putIfAbsent(currency, () => {for (final m in members) m: 0});
    nets.forEach((m, v) => sum[m] = sum[m]! + v);
    final label = _text(cell[2]);
    final category = categoryKeys[label.toLowerCase()] ?? label;
    final notes = _text(cell[notesAt]);
    rows.add(
      SplitwiseRow(
        row: row,
        date: parseCsvDate(cell[0], row),
        description: description,
        category: category,
        isPayment: _same(label, csvPaymentCategory),
        currency: currency,
        cost: parseMinorCell(cell[4], exponent, row, csvLeadingColumns[4], allowEmpty: false),
        nets: nets,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }
  return SplitwiseCsv(members: members, rows: rows, columnSums: sums, totals: totals);
}
