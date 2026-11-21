/// Splitwise "Export as spreadsheet" CSV parser (X1, planning/08-feature-specs.md;
/// format in planning/research/01-product-research.md §4).
///
/// Pure Dart: text in, [SplitwiseCsv] out. Amounts become integer minor units
/// with string maths and the currency exponent (rule 1), never floating point.
/// Problems are typed [SplitwiseCsvError]s carrying the 1-based row number
/// (row 1 = header, as a spreadsheet app numbers them).
library;

import 'package:csv/csv.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/money.dart';

/// The five fixed columns every Splitwise export starts with.
const splitwiseFixedColumns = ['Date', 'Description', 'Category', 'Cost', 'Currency'];

/// Description of the per-currency footer row (column sums = net balances).
const splitwiseTotalsDescription = 'Total balance';

/// Category Splitwise writes for settle-up rows in English exports.
const splitwisePaymentCategory = 'Payment';

/// One expense or payment row of the file.
final class SplitwiseRow {
  const SplitwiseRow({
    required this.row,
    required this.date,
    required this.description,
    required this.category,
    required this.isPayment,
    required this.currency,
    required this.cost,
    required this.nets,
  });

  /// 1-based row number in the file.
  final int row;

  /// Calendar date (UTC midnight).
  final DateTime date;
  final String description;

  /// Category text as written in the file, e.g. `Dining out` or `Utilities - Electricity`.
  final String category;

  /// True for settle-up rows (category = the payment category).
  final bool isPayment;
  final String currency;

  /// Cost in minor units of [currency] (sign kept as written).
  final int cost;

  /// Paid − owed per member for this row, in column order, 0 included. Sums to 0.
  final Map<String, int> nets;
}

/// A whole parsed export.
final class SplitwiseCsv {
  const SplitwiseCsv({
    required this.members,
    required this.rows,
    required this.columnSums,
    required this.totals,
  });

  /// Member names in column order (the fixed order for allocations and balances).
  final List<String> members;

  /// Expense and payment rows in file order (blank and total rows dropped).
  final List<SplitwiseRow> rows;

  /// Per currency, per member: sum of the row cells (what an import will produce).
  final Map<String, Map<String, int>> columnSums;

  /// Per currency, per member: the file's own "Total balance" row, where present.
  final Map<String, Map<String, int>> totals;

  /// Currencies used by rows or total rows, sorted by code.
  List<String> get currencies => ({...columnSums.keys, ...totals.keys}.toList()..sort());

  /// Where the file's "Total balance" rows disagree with the column sums (preview warning).
  /// A currency without a total row is not checked.
  List<TotalsMismatch> get totalsMismatches => [
    for (final entry in totals.entries)
      for (final m in members)
        if ((columnSums[entry.key]?[m] ?? 0) != entry.value[m])
          TotalsMismatch(
            currency: entry.key,
            member: m,
            fileTotal: entry.value[m]!,
            rowsTotal: columnSums[entry.key]?[m] ?? 0,
          ),
  ];
}

/// One member whose "Total balance" cell differs from the sum of their row cells.
final class TotalsMismatch {
  const TotalsMismatch({
    required this.currency,
    required this.member,
    required this.fileTotal,
    required this.rowsTotal,
  });

  final String currency;
  final String member;

  /// Minor units in the "Total balance" row.
  final int fileTotal;

  /// Minor units summed from the rows.
  final int rowsTotal;

  @override
  bool operator ==(Object other) =>
      other is TotalsMismatch &&
      other.currency == currency &&
      other.member == member &&
      other.fileTotal == fileTotal &&
      other.rowsTotal == rowsTotal;

  @override
  int get hashCode => Object.hash(currency, member, fileTotal, rowsTotal);

  @override
  String toString() => 'TotalsMismatch($currency $member: file $fileTotal, rows $rowsTotal)';
}

/// Why a file cannot be read. [row] is 1-based (header = 1), 0 for the whole file.
sealed class SplitwiseCsvError implements Exception {
  const SplitwiseCsvError(this.row);

  final int row;

  /// Stable code for the UI text.
  String get code;

  @override
  String toString() => 'SplitwiseCsvError($code, row $row)';
}

/// The file has no rows at all.
final class EmptyFile extends SplitwiseCsvError {
  const EmptyFile() : super(0);

  @override
  String get code => 'IMPORT_EMPTY_FILE';
}

/// The header is not `Date,Description,Category,Cost,Currency,<member>...`, a member
/// name is blank or repeated, or there is no member column.
final class BadHeader extends SplitwiseCsvError {
  const BadHeader() : super(1);

  @override
  String get code => 'IMPORT_BAD_HEADER';
}

/// A row has a different number of cells than the header.
final class WrongColumnCount extends SplitwiseCsvError {
  const WrongColumnCount(super.row, {required this.expected, required this.actual});

  final int expected;
  final int actual;

  @override
  String get code => 'IMPORT_WRONG_COLUMN_COUNT';
}

/// The date is not `YYYY-MM-DD` (optionally followed by a time) or not a real day.
final class InvalidDate extends SplitwiseCsvError {
  const InvalidDate(super.row, this.value);

  final String value;

  @override
  String get code => 'IMPORT_INVALID_DATE';
}

/// The currency is not a three-letter ISO code.
final class InvalidCurrency extends SplitwiseCsvError {
  const InvalidCurrency(super.row, this.value);

  final String value;

  @override
  String get code => 'IMPORT_INVALID_CURRENCY';
}

/// A cost or member cell is not a plain decimal (`-12.50`), has non-zero digits beyond the
/// currency's exponent, or is larger than `maxAmount`.
final class InvalidAmount extends SplitwiseCsvError {
  const InvalidAmount(super.row, {required this.column, required this.value});

  /// Header name of the cell (`Cost` or a member name).
  final String column;
  final String value;

  @override
  String get code => 'IMPORT_INVALID_AMOUNT';
}

/// A row's member cells do not add up to 0 (somebody's share is missing).
final class RowNotBalanced extends SplitwiseCsvError {
  const RowNotBalanced(super.row, this.remaining);

  /// Σ cells in minor units (≠ 0).
  final int remaining;

  @override
  String get code => 'IMPORT_ROW_NOT_BALANCED';
}

/// A second "Total balance" row for the same currency.
final class DuplicateTotals extends SplitwiseCsvError {
  const DuplicateTotals(super.row, this.currency);

  final String currency;

  @override
  String get code => 'IMPORT_DUPLICATE_TOTALS';
}

final _decimal = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$');
final _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[T ].*)?$');
final _currency = RegExp(r'^[A-Z]{3}$');

/// Parses a Splitwise group export.
///
/// [paymentCategory] is matched case-insensitively (German exports say `Zahlung`; the UI
/// can let the user pick it). A leading BOM, `\r\n` line ends, quoted cells with commas
/// or quotes and blank lines are accepted. Throws a [SplitwiseCsvError].
SplitwiseCsv parseSplitwiseCsv(String text, {String paymentCategory = splitwisePaymentCategory}) {
  final input = text.startsWith('\ufeff') ? text.substring(1) : text;
  final records = const CsvDecoder(fieldDelimiter: ',', skipEmptyLines: false).convert(input);
  final cells = [
    for (final r in records) [for (final c in r) '$c'.trim()],
  ];
  if (cells.every(_isBlank)) throw const EmptyFile();

  final header = cells.first;
  final members = header.length > splitwiseFixedColumns.length
      ? header.sublist(splitwiseFixedColumns.length)
      : const <String>[];
  final fixedOk =
      header.length >= splitwiseFixedColumns.length &&
      [
        for (var i = 0; i < splitwiseFixedColumns.length; i++)
          header[i].toLowerCase() == splitwiseFixedColumns[i].toLowerCase(),
      ].every((ok) => ok);
  if (!fixedOk ||
      members.isEmpty ||
      members.any((m) => m.isEmpty) ||
      members.toSet().length != members.length) {
    throw const BadHeader();
  }

  final payment = paymentCategory.trim().toLowerCase();
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
    final currency = cell[4].toUpperCase();
    if (!_currency.hasMatch(currency)) throw InvalidCurrency(row, cell[4]);
    final exponent = Currencies.exponentOf(currency);
    final nets = <String, int>{
      for (var m = 0; m < members.length; m++)
        members[m]: _minor(cell[5 + m], exponent, row, members[m]),
    };

    if (cell[1].toLowerCase() == splitwiseTotalsDescription.toLowerCase()) {
      if (totals.containsKey(currency)) throw DuplicateTotals(row, currency);
      totals[currency] = nets;
      continue;
    }
    final remaining = nets.values.fold(0, (a, b) => a + b);
    if (remaining != 0) throw RowNotBalanced(row, remaining);
    final sum = sums.putIfAbsent(currency, () => {for (final m in members) m: 0});
    nets.forEach((m, v) => sum[m] = sum[m]! + v);
    rows.add(
      SplitwiseRow(
        row: row,
        date: _parseDate(cell[0], row),
        description: cell[1],
        category: cell[2],
        isPayment: cell[2].toLowerCase() == payment,
        currency: currency,
        cost: _minor(cell[3], exponent, row, splitwiseFixedColumns[3], allowEmpty: false),
        nets: nets,
      ),
    );
  }
  return SplitwiseCsv(members: members, rows: rows, columnSums: sums, totals: totals);
}

bool _isBlank(List<String> cells) => cells.every((c) => c.isEmpty);

DateTime _parseDate(String text, int row) {
  final m = _date.firstMatch(text);
  if (m == null) throw InvalidDate(row, text);
  final y = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final d = int.parse(m[3]!);
  final date = DateTime.utc(y, mo, d);
  if (date.month != mo || date.day != d) throw InvalidDate(row, text);
  return date;
}

/// Plain decimal text → minor units. Extra fraction digits are allowed only when they are
/// zeros (`1500.00` JPY = 1500). Empty member cells count as 0.
int _minor(String text, int exponent, int row, String column, {bool allowEmpty = true}) {
  if (text.isEmpty && allowEmpty) return 0;
  final m = _decimal.firstMatch(text);
  if (m == null) throw InvalidAmount(row, column: column, value: text);
  final whole = m[2]!.replaceFirst(RegExp('^0+(?=.)'), '');
  final fraction = m[3] ?? '';
  final kept = fraction.length > exponent ? fraction.substring(0, exponent) : fraction;
  final dropped = fraction.length > exponent ? fraction.substring(exponent) : '';
  if (dropped.contains(RegExp('[1-9]'))) throw InvalidAmount(row, column: column, value: text);
  final digits = whole + kept.padRight(exponent, '0');
  // maxAmount has 12 digits; refuse longer strings before int.parse can overflow.
  final magnitude = digits.length > 15 ? maxAmount + 1 : int.parse(digits);
  if (magnitude > maxAmount) throw InvalidAmount(row, column: column, value: text);
  return m[1] == '-' ? -magnitude : magnitude;
}
