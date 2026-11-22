import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/export/domain/csv_export.dart';
import 'package:splitify/features/import_splitwise/domain/import_csv.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_csv_parser.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_reconstruction.dart';

const _members = [CsvMember('m1', 'Mohit'), CsvMember('m2', 'Asha'), CsvMember('m3', 'Ravi')];

/// A Splitify export header for [names], then [rows] (cells already in file order).
String _splitify(List<String> names, List<List<String>> rows) => [
  [...csvLeadingColumns, ...names, ...csvTrailingColumns],
  ...rows,
].map((r) => r.join(',')).join('\n');

List<String> _row(List<String> nets, {String desc = 'Lunch', String deleted = 'no'}) => [
  '2026-11-01',
  desc,
  'food.dining_out',
  'INR',
  '10.00',
  'Mohit',
  'equal',
  ...nets,
  '',
  '',
  deleted,
];

void main() {
  group('format detection', () {
    test('Splitwise header (fixture) is read as Splitwise with totals', () {
      final text = File('test/fixtures/splitwise/group_inr_usd.csv').readAsStringSync();
      final r = parseImportCsv(text);
      expect(r.format, ImportFormat.splitwise);
      expect(r.file.members, ['Aarav', 'Priya', 'Rohan', 'Meera']);
      expect(r.file.rows, hasLength(8));
      expect(r.file.rows.where((x) => x.isPayment), hasLength(2));
      expect(r.file.totals.keys, unorderedEquals(['INR', 'USD']));
      expect(r.file.totals['INR']!['Priya'], -378334);
      expect(r.file.totalsMismatches, isEmpty);
    });

    test('Splitify export header is read as Splitify', () {
      final r = parseImportCsv(
        buildGroupCsv(
          members: _members,
          expenses: const [
            CsvExpense(
              date: '2026-11-03',
              description: 'Dinner',
              category: 'food.dining_out',
              currency: 'INR',
              total: 30000,
              splitType: 'equal',
              paid: {'m1': 30000},
              owed: {'m1': 10000, 'm2': 10000, 'm3': 10000},
            ),
          ],
        ),
      );
      expect(r.format, ImportFormat.splitify);
      expect(r.file.members, ['Mohit', 'Asha', 'Ravi']);
      expect(r.file.rows.single.nets, {'Mohit': 20000, 'Asha': -10000, 'Ravi': -10000});
      expect(r.file.rows.single.cost, 30000);
      expect(r.file.totals['INR'], {'Mohit': 20000, 'Asha': -10000, 'Ravi': -10000});
    });

    test('a BOM in front is ignored (both formats)', () {
      final splitwise = parseImportCsv(
        '﻿Date,Description,Category,Cost,Currency,A,B\n2026-01-01,x,General,10.00,INR,5.00,-5.00',
      );
      expect(splitwise.format, ImportFormat.splitwise);
      expect(splitwise.file.members, ['A', 'B']);
      final splitify = parseImportCsv(
        '﻿${_splitify(['A', 'B'], [
          _row(['5.00', '-5.00']),
        ])}',
      );
      expect(splitify.format, ImportFormat.splitify);
      expect(splitify.file.members, ['A', 'B']);
    });
  });

  group('Splitify rows', () {
    test('deleted rows are skipped, even when they would not balance', () {
      final r = parseImportCsv(
        _splitify(
          ['A', 'B'],
          [
            _row(['5.00', '-5.00']),
            _row(['7.00', '0.00'], desc: 'Gone', deleted: 'yes'),
          ],
        ),
      );
      expect(r.file.rows.map((x) => x.description), ['Lunch']);
      expect(r.file.columnSums['INR'], {'A': 500, 'B': -500});
    });

    test('Total balance rows become totals, not rows', () {
      final totalRow = ['', 'Total balance', '', 'INR', '', '', '', '5.00', '-5.00', '', '', ''];
      final r = parseImportCsv(
        _splitify(
          ['A', 'B'],
          [
            _row(['5.00', '-5.00']),
            totalRow,
          ],
        ),
      );
      expect(r.file.rows, hasLength(1));
      expect(r.file.totals, {
        'INR': {'A': 500, 'B': -500},
      });
    });

    test('payment rows are flagged and the Notes column is carried', () {
      final r = parseImportCsv(
        buildGroupCsv(
          members: _members,
          expenses: const [
            CsvExpense(
              date: '2026-11-03',
              description: 'Cab',
              category: 'travel.cab_auto',
              currency: 'INR',
              total: 1000,
              splitType: 'equal',
              paid: {'m1': 1000},
              owed: {'m2': 1000},
              notes: 'airport run',
            ),
          ],
          payments: const [
            CsvPayment(
              date: '2026-11-04',
              fromId: 'm2',
              toId: 'm1',
              currency: 'INR',
              amount: 500,
              note: 'thanks',
            ),
          ],
        ),
      );
      final cab = r.file.rows.firstWhere((x) => x.description == 'Cab');
      final pay = r.file.rows.firstWhere((x) => x.isPayment);
      expect(cab.isPayment, isFalse);
      expect(cab.notes, 'airport run');
      expect(pay.description, 'Asha paid Mohit');
      expect(pay.notes, 'thanks');
      expect(pay.nets, {'Mohit': -500, 'Asha': 500, 'Ravi': 0});
    });

    test('formula-guard apostrophes are removed from description and member names', () {
      final r = parseImportCsv(
        buildGroupCsv(
          members: const [CsvMember('a', '-Mohit'), CsvMember('b', 'Asha')],
          expenses: const [
            CsvExpense(
              date: '2026-11-03',
              description: '=SUM(A1)',
              category: 'other.general',
              currency: 'INR',
              total: 1000,
              splitType: 'equal',
              paid: {'a': 1000},
              owed: {'b': 1000},
            ),
          ],
        ),
      );
      expect(r.file.members, ['-Mohit', 'Asha']);
      expect(r.file.rows.single.description, '=SUM(A1)');
      expect(r.file.rows.single.nets, {'-Mohit': 1000, 'Asha': -1000});
    });
  });

  group('errors', () {
    test('an unknown header is BadHeader', () {
      expect(() => parseImportCsv('Foo,Bar\n1,2'), throwsA(isA<BadHeader>()));
    });

    test('an empty file is EmptyFile', () {
      expect(() => parseImportCsv(''), throwsA(isA<EmptyFile>()));
    });

    test('a Splitify row with the wrong cell count names its row', () {
      final text = _splitify(
        ['A', 'B'],
        [
          ['2026-11-01', 'Short', 'x'],
        ],
      );
      expect(
        () => parseImportCsv(text),
        throwsA(
          isA<WrongColumnCount>()
              .having((e) => e.row, 'row', 2)
              .having((e) => e.actual, 'actual', 3)
              .having((e) => e.expected, 'expected', 12),
        ),
      );
    });

    test('a Splitify row that does not sum to 0 is RowNotBalanced', () {
      expect(
        () => parseImportCsv(
          _splitify(
            ['A', 'B'],
            [
              _row(['5.00', '-4.00']),
            ],
          ),
        ),
        throwsA(isA<RowNotBalanced>().having((e) => e.remaining, 'remaining', 100)),
      );
    });

    test('a Splitify header with a repeated member is BadHeader', () {
      expect(() => parseImportCsv(_splitify(['A', 'A'], const [])), throwsA(isA<BadHeader>()));
    });
  });

  group('TC-22-02 export then import round trip', () {
    const expenses = [
      CsvExpense(
        date: '2026-11-01',
        description: 'Dinner',
        category: 'food.dining_out',
        currency: 'INR',
        total: 30000,
        splitType: 'equal',
        paid: {'m1': 30000},
        owed: {'m1': 10000, 'm2': 10000, 'm3': 10000},
        notes: 'birthday',
      ),
      CsvExpense(
        date: '2026-11-02',
        description: 'Villa',
        category: 'travel.hotel',
        currency: 'INR',
        total: 100000,
        splitType: 'equal',
        paid: {'m2': 60000, 'm3': 40000},
        owed: {'m1': 50000, 'm2': 50000},
      ),
      CsvExpense(
        date: '2026-11-03',
        description: 'Tickets',
        category: 'entertainment.events',
        currency: 'USD',
        total: 1250,
        splitType: 'exact',
        paid: {'m2': 1250},
        owed: {'m1': 750, 'm3': 500},
      ),
      CsvExpense(
        date: '2026-11-04',
        description: 'Ramen',
        category: 'food.dining_out',
        currency: 'JPY',
        total: 3000,
        splitType: 'exact',
        paid: {'m3': 3000},
        owed: {'m1': 1000, 'm2': 2000},
      ),
      CsvExpense(
        date: '2026-11-05',
        description: 'Removed',
        category: 'other.general',
        currency: 'INR',
        total: 500,
        splitType: 'equal',
        paid: {'m1': 500},
        owed: {'m2': 500},
        deleted: true,
      ),
    ];
    const payments = [
      CsvPayment(
        date: '2026-11-06',
        fromId: 'm2',
        toId: 'm1',
        currency: 'INR',
        amount: 10000,
        note: 'settled',
      ),
    ];

    test('nets, totals, kinds and notes survive', () {
      final text = buildGroupCsv(members: _members, expenses: expenses, payments: payments);
      final parsed = parseImportCsv(text);
      expect(parsed.format, ImportFormat.splitify);
      expect(parsed.file.totalsMismatches, isEmpty);

      // Nets of the non-deleted rows, from the same inputs as the export.
      final expected = <String, Map<String, int>>{};
      for (final e in expenses.where((e) => !e.deleted)) {
        final sums = expected.putIfAbsent(e.currency, () => {for (final m in _members) m.name: 0});
        for (final m in _members) {
          sums[m.name] = sums[m.name]! + (e.paid[m.id] ?? 0) - (e.owed[m.id] ?? 0);
        }
      }
      final inr = expected['INR']!;
      inr['Asha'] = inr['Asha']! + 10000;
      inr['Mohit'] = inr['Mohit']! - 10000;

      final result = reconstructSplitwise(parsed.file);
      expect(result.nets['INR'], expected['INR']);
      expect(result.nets['USD'], expected['USD']);
      expect(result.nets['JPY'], expected['JPY']);
      expect(parsed.file.columnSums, expected);
      expect(parsed.file.totals, expected);

      ImportedExpense byName(String d) => result.expenses.firstWhere((e) => e.description == d);
      expect(result.expenses, hasLength(4));
      expect(result.expenses.map((e) => e.description), isNot(contains('Removed')));
      final dinner = byName('Dinner');
      expect(dinner.kind, ImportedExpenseKind.exact);
      expect(dinner.totalMinor, 30000);
      expect(dinner.notes, 'birthday');
      expect(byName('Tickets').kind, ImportedExpenseKind.exact);
      expect(byName('Tickets').totalMinor, 1250);
      expect(byName('Ramen').totalMinor, 3000);
      expect(byName('Ramen').currency, 'JPY');
      final villa = byName('Villa');
      expect(villa.kind, ImportedExpenseKind.nets);
      expect(villa.originalCostMinor, 100000);
      expect(villa.notes, contains('1000.00'));
      expect(result.payments, hasLength(1));
      expect(result.payments.single.amountMinor, 10000);
      expect(result.payments.single.note, 'settled');
    });
  });
}
