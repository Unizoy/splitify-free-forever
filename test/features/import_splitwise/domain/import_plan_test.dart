import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/repositories/import_repository.dart';
import 'package:splitify/features/import_splitwise/domain/import_csv.dart';
import 'package:splitify/features/import_splitwise/domain/import_plan.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_reconstruction.dart';

import '../../../support/category_support.dart';

const _ids = {'Aarav': 'id-a', 'Priya': 'id-p'};

ImportedExpense _expense({
  String description = 'Dinner',
  String? notes,
  int total = 1000,
  DateTime? date,
  String splitwiseCategory = 'Dining out',
  String categoryKey = 'food.dining_out',
}) => ImportedExpense(
  row: 2,
  date: date ?? DateTime.utc(2026, 1, 5),
  description: description,
  splitwiseCategory: splitwiseCategory,
  categoryKey: categoryKey,
  currency: 'INR',
  totalMinor: total,
  paidBy: {'Aarav': total},
  shares: {'Aarav': total ~/ 2, 'Priya': total - total ~/ 2},
  kind: ImportedExpenseKind.exact,
  originalCostMinor: total,
  notes: notes,
);

ImportedPayment _payment({String description = 'Payment', String? note}) => ImportedPayment(
  row: 3,
  date: DateTime.utc(2026, 1, 6),
  description: description,
  currency: 'INR',
  from: 'Priya',
  to: 'Aarav',
  amountMinor: 500,
  note: note,
);

SplitwiseImport _import({
  List<ImportedExpense> expenses = const [],
  List<ImportedPayment> payments = const [],
}) => SplitwiseImport(
  members: const ['Aarav', 'Priya'],
  expenses: expenses,
  payments: payments,
  skipped: const [],
  nets: const {},
);

ImportRows _build(
  SplitwiseImport import, {
  ImportFormat format = ImportFormat.splitwise,
  String fallback = 'Imported expense',
  String? Function(String description)? suggest,
}) {
  var n = 0;
  return buildImportRows(
    import: import,
    memberIds: _ids,
    batchId: 'batch-1',
    format: format,
    fallbackDescription: fallback,
    newId: () => 'new-${n++}',
    suggestCategory: suggest,
  );
}

void main() {
  group('expenses', () {
    // Auto-category (D-028, S-273): only rows the file left as General get a suggestion.
    test('uncategorised rows get the suggested category; categorised rows keep theirs', () {
      final rows = _build(
        _import(
          expenses: [
            _expense(
              description: 'Swiggy',
              splitwiseCategory: 'General',
              categoryKey: 'other.general',
            ),
            _expense(
              description: 'Uber',
              splitwiseCategory: 'Groceries',
              categoryKey: 'groceries.groceries',
            ),
            _expense(description: 'Misc', splitwiseCategory: '', categoryKey: 'other.general'),
          ],
        ),
        suggest: suggester.suggest,
      );
      expect(
        [for (final e in rows.expenses) e.data['category']],
        ['food.takeaway', 'groceries.groceries', 'other.general'],
      );
      final plain = _build(
        _import(
          expenses: [
            _expense(
              description: 'Swiggy',
              splitwiseCategory: 'General',
              categoryKey: 'other.general',
            ),
          ],
        ),
      );
      expect(plain.expenses.single.data['category'], 'other.general');
    });

    test('names become member ids; exact split with the batch id in split_values', () {
      final rows = _build(_import(expenses: [_expense()], payments: [_payment()]));
      expect(rows.batchId, 'batch-1');
      final data = rows.expenses.single.data;
      expect(data['kind'], 'expense');
      expect(data['description'], 'Dinner');
      expect(data['category'], 'food.dining_out');
      expect(data['date'], '2026-01-05');
      expect(data['currency'], 'INR');
      expect(data['total'], 1000);
      expect(data['payers'], {'id-a': 1000});
      expect(data['shares'], {'id-a': 500, 'id-p': 500});
      expect(data['split_kind'], 'exact');
      expect(data['source'], 'import');
      final values = data['split_values']! as Map<String, Object?>;
      expect(values['id-a'], 500);
      expect(values['id-p'], 500);
      expect(values[importBatchKey], 'batch-1');
    });

    test('only the last expense carries the summary', () {
      final rows = _build(
        _import(
          expenses: [
            _expense(),
            _expense(description: 'B'),
            _expense(description: 'C'),
          ],
          payments: [_payment()],
        ),
        format: ImportFormat.splitify,
      );
      Map<String, Object?> values(int i) =>
          rows.expenses[i].data['split_values']! as Map<String, Object?>;
      expect(values(0).containsKey(importSummaryKey), isFalse);
      expect(values(1).containsKey(importSummaryKey), isFalse);
      expect(values(2)[importSummaryKey], {'source': 'splitify', 'expenses': 3, 'payments': 1});
      expect(rows.expenses.every((e) => e.data['source'] == 'import'), isTrue);
      expect(
        rows.expenses.every((e) => (e.data['split_values']! as Map)[importBatchKey] == 'batch-1'),
        isTrue,
      );
    });

    test('empty description uses the fallback; long text is clipped', () {
      final rows = _build(
        _import(
          expenses: [
            _expense(description: '   '),
            _expense(description: 'd' * 130, notes: 'n' * 1100),
          ],
        ),
        fallback: 'Expense without a name',
      );
      expect(rows.expenses[0].data['description'], 'Expense without a name');
      expect(rows.expenses[0].data['notes'], isNull);
      expect(rows.expenses[1].data['description'], 'd' * maxImportDescription);
      expect(rows.expenses[1].data['notes'], 'n' * maxImportNotes);
    });

    test('ids are fresh and expenses come after payments in id order', () {
      final rows = _build(_import(expenses: [_expense()], payments: [_payment()]));
      expect(rows.payments.single.id, 'new-0');
      expect(rows.expenses.single.id, 'new-1');
    });
  });

  group('payments', () {
    Object? note(ImportedPayment p) =>
        _build(_import(expenses: [_expense()], payments: [p])).payments.single.data['note'];

    test('fields, method other, source import when expenses exist', () {
      final data = _build(_import(expenses: [_expense()], payments: [_payment()]))
          .payments
          .single
          .data;
      expect(data['from_member'], 'id-p');
      expect(data['to_member'], 'id-a');
      expect(data['amount'], 500);
      expect(data['currency'], 'INR');
      expect(data['date'], '2026-01-06');
      expect(data['method'], 'other');
      expect(data['source'], 'import');
    });

    test('a payments-only import sends ordinary payments (source app)', () {
      final rows = _build(_import(payments: [_payment(), _payment()]));
      expect(rows.expenses, isEmpty);
      expect(rows.payments.every((p) => p.data['source'] == 'app'), isTrue);
    });

    test('own note wins over the description', () {
      expect(note(_payment(description: 'Rent share', note: ' thanks ')), 'thanks');
    });

    test('"A paid B" and "Payment" descriptions give no note', () {
      expect(note(_payment(description: 'Priya paid Aarav')), isNull);
      expect(note(_payment(description: 'payment')), isNull);
      expect(note(_payment(description: '')), isNull);
    });

    test('another description becomes the note, clipped to 200', () {
      expect(note(_payment(description: 'Settling the trip')), 'Settling the trip');
      expect(note(_payment(description: 'x' * 250)), 'x' * maxImportPaymentNote);
    });
  });

  group('isoDay', () {
    test('pads to YYYY-MM-DD', () {
      expect(isoDay(DateTime.utc(2026, 3, 7)), '2026-03-07');
      expect(isoDay(DateTime.utc(987, 12, 31)), '0987-12-31');
    });
  });
}
