import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_csv_parser.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_reconstruction.dart';

SplitwiseCsv _fixture(String name) =>
    parseSplitwiseCsv(File('test/fixtures/splitwise/$name').readAsStringSync());

SplitwiseImport _rebuild(List<String> rows) => reconstructSplitwise(
  parseSplitwiseCsv(
    ['Date,Description,Category,Cost,Currency,Aarav,Priya,Rohan', ...rows].join('\n'),
  ),
);

void main() {
  group('TC-X1-02 group export (INR + USD)', () {
    final file = _fixture('group_inr_usd.csv');
    final result = reconstructSplitwise(file);
    ImportedExpense row(int n) => result.expenses.firstWhere((e) => e.row == n);

    test('6 expenses, 2 payments, nothing skipped', () {
      expect(result.members, file.members);
      expect(result.expenses.map((e) => e.row), [2, 3, 4, 5, 7, 8]);
      expect(result.payments.map((p) => p.row), [6, 9]);
      expect(result.skipped, isEmpty);
    });

    test('single payer keeps the cost and gets exact shares', () {
      final dinner = row(2);
      expect(dinner.kind, ImportedExpenseKind.exact);
      expect(dinner.date, DateTime.utc(2026, 1, 5));
      expect(dinner.description, 'Dinner at Toit, Indiranagar');
      expect(dinner.splitwiseCategory, 'Dining out');
      expect(dinner.categoryKey, 'food.dining_out');
      expect(dinner.total, const Money(300000, 'INR'));
      expect(dinner.originalCostMinor, 300000);
      expect(dinner.paidBy, {'Aarav': 300000});
      expect(dinner.shares, {'Aarav': 75000, 'Priya': 75000, 'Rohan': 75000, 'Meera': 75000});
      expect(dinner.notes, isNull);

      expect(row(3).shares, {'Priya': 33334, 'Rohan': 33333, 'Meera': 33333});
    });

    test('payer outside the split is not a participant', () {
      final bill = row(5);
      expect(bill.categoryKey, 'utilities.electricity');
      expect(bill.paidBy, {'Meera': 240000});
      expect(bill.shares, {'Aarav': 120000, 'Priya': 120000});
    });

    test('multi-payer imports as nets with the cost in notes', () {
      final villa = row(4);
      expect(villa.kind, ImportedExpenseKind.nets);
      expect(villa.categoryKey, 'travel.hotel');
      expect(villa.totalMinor, 600000);
      expect(villa.originalCostMinor, 1200000);
      expect(villa.paidBy, {'Aarav': 500000, 'Rohan': 100000});
      expect(villa.shares, {'Priya': 300000, 'Meera': 300000});
      expect(villa.notes, contains('12000.00 INR'));
    });

    test('payments go from the positive cell to the negative cell', () {
      final inr = result.payments.first;
      expect((inr.from, inr.to, inr.amount), ('Priya', 'Aarav', const Money(50000, 'INR')));
      expect(inr.date, DateTime.utc(2026, 1, 15));
      expect(inr.description, 'Priya paid Aarav');
      final usd = result.payments.last;
      expect((usd.from, usd.to, usd.amountMinor, usd.currency), ('Aarav', 'Rohan', 3000, 'USD'));
    });

    test('per-currency nets equal the file, also through the balances engine', () {
      expect(result.nets, file.totals);
      for (final c in ['INR', 'USD']) {
        final recomputed = nets(
          file.members,
          [
            for (final e in result.expenses)
              if (e.currency == c) e.flow,
          ],
          [
            for (final p in result.payments)
              if (p.currency == c) p.flow,
          ],
        );
        expect(recomputed, file.columnSums[c]);
      }
    });
  });

  test('JPY fixture with BOM keeps whole-yen exact shares', () {
    final result = reconstructSplitwise(_fixture('bom_jpy_crlf.csv'));
    expect(result.expenses.map((e) => e.shares), [
      {'Aarav': 1000, 'Priya': 1000, 'Rohan': 1000},
      {'Aarav': 333, 'Priya': 334, 'Rohan': 333},
    ]);
    expect(result.expenses.last.categoryKey, 'travel.train_bus');
  });

  group('Total balance checksum', () {
    final file = _fixture('checksum_mismatch.csv');

    test('mismatch throws SUM_MISMATCH by default', () {
      expect(
        () => reconstructSplitwise(file),
        throwsA(isA<SumMismatch>().having((e) => e.remaining, 'remaining', -5000)),
      );
    });

    test('accepted after the preview warning: nets follow the rows', () {
      final result = reconstructSplitwise(file, acceptTotalsMismatch: true);
      expect(result.nets, file.columnSums);
    });
  });

  test('checkImportNets reports expected − actual for the first wrong member', () {
    const order = ['A', 'B'];
    const expected = {
      'INR': {'A': 100, 'B': -100},
    };
    expect(() => checkImportNets(order, expected, expected), returnsNormally);
    expect(
      () => checkImportNets(order, const {
        'INR': {'A': 90, 'B': -100},
      }, expected),
      throwsA(isA<SumMismatch>().having((e) => e.remaining, 'remaining', 10)),
    );
    expect(
      () => checkImportNets(order, const {}, expected),
      throwsA(isA<SumMismatch>().having((e) => e.remaining, 'remaining', 100)),
    );
  });

  group('edge rows', () {
    test('all-zero rows are skipped', () {
      final result = _rebuild([
        '2026-01-05,My own lunch,General,250.00,INR,0,0,0',
        '2026-01-05,Nothing,Payment,0,INR,0,0,0',
      ]);
      expect(result.expenses, isEmpty);
      expect(result.payments, isEmpty);
      expect(result.skipped.map((s) => (s.row, s.description)), [
        (2, 'My own lunch'),
        (3, 'Nothing'),
      ]);
      expect(result.nets['INR'], {'Aarav': 0, 'Priya': 0, 'Rohan': 0});
    });

    test('a cost the cells cannot explain falls back to nets', () {
      final result = _rebuild([
        '2026-01-05,Odd,General,50.00,INR,60.00,-60.00,0',
        '2026-01-05,Refund,General,-30.00,INR,30.00,-30.00,0',
      ]);
      expect(result.expenses.map((e) => e.kind), everyElement(ImportedExpenseKind.nets));
      expect(result.expenses.map((e) => e.totalMinor), [6000, 3000]);
      expect(result.expenses.last.notes, contains('-30.00 INR'));
    });

    test('a payment row with several people is matched in column order', () {
      final result = _rebuild(['2026-01-05,Group settle,Payment,30,INR,20,-10,-10']);
      expect(
        [for (final p in result.payments) (p.from, p.to, p.amountMinor)],
        [('Aarav', 'Priya', 1000), ('Aarav', 'Rohan', 1000)],
      );
    });

    test('nets above the largest amount are refused by the money engine', () {
      const max = '9999999999.99';
      final file = parseSplitwiseCsv(
        'Date,Description,Category,Cost,Currency,A,B,C,D\n'
        '2026-01-05,Huge,General,1,INR,$max,$max,-$max,-$max',
      );
      expect(() => reconstructSplitwise(file), throwsA(isA<AmountTooLarge>()));
    });
  });

  group('category mapping (best effort to D-016)', () {
    for (final (text, key) in [
      ('Utilities - Electricity', 'utilities.electricity'),
      ('Utilities - TV/Phone/Internet', 'utilities.internet_phone'),
      ('Transportation - Other', 'travel.cab_auto'),
      ('Food and drink', 'food.dining_out'),
      ('  GROCERIES ', 'groceries.groceries'),
      ('Life - Medical expenses', 'other.medical'),
      ('Home - Other', 'rent.maintenance'),
      ('Payment', 'other.general'),
      ('Something new', 'other.general'),
      ('', 'other.general'),
    ]) {
      test('"$text" → $key', () => expect(splitwiseCategoryKey(text), key));
    }
  });
}
