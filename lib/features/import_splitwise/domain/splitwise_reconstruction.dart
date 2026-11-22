/// Rebuilds expenses and payments from a parsed Splitwise export (X1,
/// planning/08-feature-specs.md; algorithm in planning/research/01-product-research.md §4).
///
/// Output is a neutral model keyed by Splitwise member NAME: the mapping step (phase 18 T3)
/// turns names into member ids and records into outbox mutations. Every record is checked
/// against the money engine, and the per-currency nets of the result are asserted equal to
/// the file's columns (and its "Total balance" rows) — a mismatch throws a `MoneyError`.
library;

import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_csv_parser.dart';

/// How an expense was rebuilt.
enum ImportedExpenseKind {
  /// One payer: original cost, payer paid it all, exact shares from the cells.
  exact,

  /// Several payers (or a cost the cells cannot explain): total = Σ positive cells, payers
  /// pay their positive cell, others owe their negative cell. Original cost goes in notes.
  nets,
}

/// An expense to import. Maps are keyed by Splitwise member name, in column order.
final class ImportedExpense {
  const ImportedExpense({
    required this.row,
    required this.date,
    required this.description,
    required this.splitwiseCategory,
    required this.categoryKey,
    required this.currency,
    required this.totalMinor,
    required this.paidBy,
    required this.shares,
    required this.kind,
    required this.originalCostMinor,
    this.notes,
  });

  /// 1-based row in the file.
  final int row;
  final DateTime date;
  final String description;

  /// Category text from the file.
  final String splitwiseCategory;

  /// Best-effort D-016 category key (`food.dining_out` …), `other.general` when unknown.
  final String categoryKey;
  final String currency;

  /// Expense total in minor units (> 0).
  final int totalMinor;

  /// Minor units paid per member name; sums to [totalMinor].
  final Map<String, int> paidBy;

  /// Minor units owed per member name (exact split, only members with a share > 0).
  final Map<String, int> shares;
  final ImportedExpenseKind kind;

  /// The file's Cost cell (equals [totalMinor] for [ImportedExpenseKind.exact]).
  final int originalCostMinor;

  /// English note for [ImportedExpenseKind.nets] rows (original cost), else null.
  final String? notes;

  Money get total => Money(totalMinor, currency);

  /// The balances view of this expense.
  ExpenseFlow get flow => ExpenseFlow(currency: currency, paid: paidBy, shares: shares);
}

/// A payment to import: [from] paid [to] [amountMinor].
final class ImportedPayment {
  const ImportedPayment({
    required this.row,
    required this.date,
    required this.description,
    required this.currency,
    required this.from,
    required this.to,
    required this.amountMinor,
    this.note,
  });

  final int row;
  final DateTime date;
  final String description;
  final String currency;
  final String from;
  final String to;
  final int amountMinor;

  /// Notes cell of the row (Splitify's own export), else null.
  final String? note;

  Money get amount => Money(amountMinor, currency);

  /// The balances view of this payment.
  Payment get flow => Payment(currency: currency, from: from, to: to, amount: amountMinor);
}

/// A row with every member cell 0: it changes no balance, so nothing is imported.
final class SkippedRow {
  const SkippedRow({required this.row, required this.description});

  final int row;
  final String description;
}

/// Everything an import will write, plus the nets it produces.
final class SplitwiseImport {
  const SplitwiseImport({
    required this.members,
    required this.expenses,
    required this.payments,
    required this.skipped,
    required this.nets,
  });

  /// Member names in column order.
  final List<String> members;
  final List<ImportedExpense> expenses;
  final List<ImportedPayment> payments;
  final List<SkippedRow> skipped;

  /// Per currency, per member: net of the imported records (equals the file).
  final Map<String, Map<String, int>> nets;
}

/// Rebuilds [file] into expenses and payments.
///
/// The nets are always checked against the column sums. They are also checked against the
/// file's "Total balance" rows unless [acceptTotalsMismatch] (the user saw the preview
/// warning, `SplitwiseCsv.totalsMismatches`, and chose to go on). Throws a `MoneyError`
/// (`SUM_MISMATCH{remaining}` on a nets mismatch).
SplitwiseImport reconstructSplitwise(SplitwiseCsv file, {bool acceptTotalsMismatch = false}) {
  final order = file.members;
  final expenses = <ImportedExpense>[];
  final payments = <ImportedPayment>[];
  final skipped = <SkippedRow>[];
  for (final r in file.rows) {
    final positive = {
      for (final e in r.nets.entries)
        if (e.value > 0) e.key: e.value,
    };
    final negative = {
      for (final e in r.nets.entries)
        if (e.value < 0) e.key: -e.value,
    };
    if (positive.isEmpty) {
      skipped.add(SkippedRow(row: r.row, description: r.description));
    } else if (r.isPayment) {
      // Payer cell +x, receiver cell −x. Several on a side: match in column order.
      for (final t in expensePairs(order, positive, negative)) {
        payments.add(
          ImportedPayment(
            row: r.row,
            date: r.date,
            description: r.description,
            currency: r.currency,
            from: t.to,
            to: t.from,
            amountMinor: t.amount,
            note: r.notes,
          ),
        );
      }
    } else {
      expenses.add(_expense(r, order, positive, negative));
    }
  }

  final byCurrency = <String, Map<String, int>>{};
  for (final c in file.currencies) {
    byCurrency[c] = nets(
      order,
      [
        for (final e in expenses)
          if (e.currency == c) e.flow,
      ],
      [
        for (final p in payments)
          if (p.currency == c) p.flow,
      ],
    );
  }
  checkImportNets(order, byCurrency, file.columnSums);
  if (!acceptTotalsMismatch) checkImportNets(order, byCurrency, file.totals);
  return SplitwiseImport(
    members: order,
    expenses: expenses,
    payments: payments,
    skipped: skipped,
    nets: byCurrency,
  );
}

/// Throws `SUM_MISMATCH{remaining = expected − actual}` for the first member (currencies in
/// [expected] order, members in [order]) whose [actual] net differs from [expected].
void checkImportNets(
  List<String> order,
  Map<String, Map<String, int>> actual,
  Map<String, Map<String, int>> expected,
) {
  for (final c in expected.entries) {
    for (final m in order) {
      final diff = (c.value[m] ?? 0) - (actual[c.key]?[m] ?? 0);
      if (diff != 0) throw SumMismatch(diff);
    }
  }
}

ImportedExpense _expense(
  SplitwiseRow r,
  List<String> order,
  Map<String, int> positive,
  Map<String, int> negative,
) {
  final lent = positive.values.fold(0, (a, b) => a + b);
  // One payer who paid the whole cost: they owe `cost − lent` themselves.
  final exact = positive.length == 1 && r.cost >= lent;
  final total = exact ? r.cost : lent;
  final payer = positive.keys.first;
  final paidBy = exact ? {payer: total} : positive;
  final owed = exact ? {...negative, payer: total - lent} : negative;
  final participants = [
    for (final m in order)
      if ((owed[m] ?? 0) > 0) m,
  ];
  // Validates through the engine: payers sum, exact shares sum (SUM_MISMATCH otherwise).
  checkPayers(total, paidBy);
  final shares = split(total, SplitKind.exact, participants, {
    for (final m in participants) m: owed[m]!,
  });
  return ImportedExpense(
    row: r.row,
    date: r.date,
    description: r.description,
    splitwiseCategory: r.category,
    categoryKey: splitwiseCategoryKey(r.category),
    currency: r.currency,
    totalMinor: total,
    paidBy: paidBy,
    shares: shares,
    kind: exact ? ImportedExpenseKind.exact : ImportedExpenseKind.nets,
    originalCostMinor: r.cost,
    notes: _notes(r, exact: exact),
  );
}

String? _notes(SplitwiseRow r, {required bool exact}) {
  final own = r.notes?.trim() ?? '';
  if (exact) return own.isEmpty ? null : own;
  final cost =
      'Imported from Splitwise as net amounts. Original cost: '
      '${MoneyFormatter.plain(r.cost, r.currency)} ${r.currency}.';
  return own.isEmpty ? cost : '$own\n$cost';
}

/// Best-effort map from a Splitwise category (`Dining out`, `Utilities - Electricity`,
/// `Transportation - Other`) to a D-016 key (planning/08-feature-specs.md #13).
String splitwiseCategoryKey(String category) {
  // Splitify's own export writes D-016 keys (`food.dining_out`); keep them.
  if (ExpenseCategories.isKnown(category.trim())) return category.trim();
  final text = category.trim().toLowerCase();
  final dash = text.lastIndexOf(' - ');
  final sub = dash < 0 ? text : text.substring(dash + 3);
  final parent = dash < 0 ? text : text.substring(0, dash);
  return _subCategories[sub] ?? _parentCategories[parent] ?? 'other.general';
}

const _subCategories = {
  // Entertainment
  'games': 'entertainment.games',
  'movies': 'entertainment.movies',
  'music': 'entertainment.events',
  'sports': 'entertainment.sports',
  // Food and drink
  'dining out': 'food.dining_out',
  'groceries': 'groceries.groceries',
  'liquor': 'food.dining_out',
  // Home
  'electronics': 'shopping.electronics',
  'furniture': 'shopping.other',
  'household supplies': 'groceries.household',
  'maintenance': 'rent.maintenance',
  'mortgage': 'rent.rent',
  'pets': 'shopping.other',
  'rent': 'rent.rent',
  'services': 'other.services',
  // Life
  'childcare': 'other.services',
  'clothing': 'shopping.clothing',
  'education': 'other.education',
  'gifts': 'shopping.gifts',
  'insurance': 'other.services',
  'medical expenses': 'other.medical',
  'taxes': 'other.services',
  // Transportation
  'bicycle': 'travel.cab_auto',
  'bus/train': 'travel.train_bus',
  'car': 'travel.cab_auto',
  'gas/fuel': 'travel.fuel',
  'hotel': 'travel.hotel',
  'parking': 'travel.parking_tolls',
  'plane': 'travel.flights',
  'taxi': 'travel.cab_auto',
  // Uncategorized
  'general': 'other.general',
  // Utilities
  'cleaning': 'other.services',
  'electricity': 'utilities.electricity',
  'heat/gas': 'utilities.gas',
  'trash': 'other.services',
  'tv/phone/internet': 'utilities.internet_phone',
  'water': 'utilities.water',
};

const _parentCategories = {
  'entertainment': 'entertainment.events',
  'food and drink': 'food.dining_out',
  'home': 'rent.maintenance',
  'life': 'other.general',
  'transportation': 'travel.cab_auto',
  'utilities': 'utilities.subscriptions',
};
