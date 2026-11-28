// R4 robustness: the Splitwise / Splitify CSV importer with hostile and odd files.
//
// TC-R4-C-01  random bytes and mutated real files: a typed SplitwiseCsvError or a file whose rows balance,
//             never another exception; reconstruction either sums exactly or is a MoneyError
// TC-R4-C-02  export → import round trip with emoji, RTL, quotes, commas, line breaks, formula-like text and
//             apostrophes in names and descriptions, 0-, 2- and 3-decimal currencies: same people, same text,
//             same nets
// TC-R4-C-03  an expense called "Total balance" is an expense, not the footer
// TC-R4-C-04  malformed numbers, unknown currencies, huge files
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/features/export/domain/csv_export.dart';
import 'package:splitify/features/import_splitwise/domain/import_csv.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_csv_parser.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_reconstruction.dart';

const _textPieces = [
  'Asha',
  'Rahul',
  ' ',
  ',',
  '"',
  "'",
  '=',
  '+',
  '-',
  '@',
  '\n',
  '\r\n',
  'é',
  '🎉',
  '👨\u200d👩\u200d👧', //
  'مرحبا',
  'שלום',
  'मोहित',
  '🇮🇳',
  'Dinner',
  '₹',
  '100',
  ';',
  '\t',
  'Total balance',
  '=SUM(A1)',
  "'=x",
];

String _text(Random r, int pieces) =>
    [for (var i = 0; i < pieces; i++) _textPieces[r.nextInt(_textPieces.length)]].join();

const _codes = ['INR', 'USD', 'JPY', 'KWD', 'BHD', 'VND', 'EUR'];

int _sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);

/// Parses [text] like the importer; returns null when it is a typed import error.
ImportCsv? _parse(String text) {
  try {
    return parseImportCsv(text);
  } on SplitwiseCsvError {
    return null;
  }
}

void main() {
  final fixture = File('test/fixtures/splitwise/group_inr_usd.csv').readAsStringSync();

  // TC-R4-C-01
  group('hostile files', () {
    test('random text: a typed error or balanced rows, never another exception', () {
      final r = Random(4501);
      const alphabet = [
        'a',
        '1',
        '.',
        ',',
        '"',
        '\n',
        '\r',
        ' ',
        '-',
        'Date',
        'INR',
        '\ufeff',
        '🎉',
        '\u0000',
      ];
      for (var k = 0; k < 3000; k++) {
        final text = [for (var i = 0; i < r.nextInt(200); i++) alphabet[r.nextInt(alphabet.length)]]
            .join();
        try {
          final parsed = _parse(text);
          if (parsed != null) {
            for (final row in parsed.file.rows) {
              expect(_sum(row.nets.values), 0);
            }
          }
        } on Object catch (e) {
          fail('case $k threw ${e.runtimeType}: $e');
        }
      }
    });

    test('mutated real export: typed error, or rows that rebuild to exactly the file nets', () {
      final r = Random(4502);
      const inserts = [
        '"',
        ',',
        '\n',
        '\r\n',
        '""',
        '-',
        '.',
        '0',
        '9',
        'x',
        '\ufeff',
        ' ',
        '\u0000',
        '🎉',
      ];
      var rebuilt = 0;
      for (var k = 0; k < 3000; k++) {
        final chars = fixture.split('');
        for (var m = 0; m < 1 + r.nextInt(4); m++) {
          final at = r.nextInt(chars.length);
          switch (r.nextInt(3)) {
            case 0:
              chars.removeAt(at);
            case 1:
              chars.insert(at, inserts[r.nextInt(inserts.length)]);
            default:
              chars[at] = inserts[r.nextInt(inserts.length)];
          }
        }
        final text = chars.join();
        try {
          final parsed = _parse(text);
          if (parsed == null) continue;
          try {
            final result = reconstructSplitwise(parsed.file, acceptTotalsMismatch: true);
            for (final e in result.expenses) {
              expect(_sum(e.shares.values), e.totalMinor, reason: 'case $k');
              expect(_sum(e.paidBy.values), e.totalMinor, reason: 'case $k');
              expect(e.totalMinor, inInclusiveRange(1, maxAmount));
            }
            for (final p in result.payments) {
              expect(p.amountMinor, greaterThan(0));
            }
            rebuilt++;
          } on MoneyError {
            // A file the engine refuses is reported, not imported.
          }
        } on Object catch (e) {
          fail('case $k threw ${e.runtimeType}: $e');
        }
      }
      expect(rebuilt, greaterThan(100));
    });
  });

  // TC-R4-C-02
  group('export → import round trip', () {
    test('odd names and text in 7 currencies come back the same, with the same nets', () {
      final r = Random(4503);
      for (var k = 0; k < 400; k++) {
        final n = 2 + r.nextInt(6);
        final names = <String>{};
        while (names.length < n) {
          final name = _text(r, 1 + r.nextInt(4)).trim();
          if (name.isNotEmpty && name != csvTotalLabel) names.add(name);
        }
        final members = [for (final (i, name) in names.indexed) CsvMember('m$i', name)];
        final ids = [for (final m in members) m.id];
        final expenses = <CsvExpense>[];
        for (var e = 0; e < 1 + r.nextInt(8); e++) {
          final currency = _codes[r.nextInt(_codes.length)];
          final total = 1 + r.nextInt(r.nextBool() ? 1000 : 100000000);
          final payer = ids[r.nextInt(n)];
          final owed = split(total, SplitKind.equal, [
            for (final id in ids)
              if (r.nextBool() || id == ids.first) id,
          ]);
          var description = _text(r, 1 + r.nextInt(6)).trim();
          if (description.isEmpty) description = 'x';
          expenses.add(
            CsvExpense(
              date: '2026-11-${(1 + r.nextInt(28)).toString().padLeft(2, '0')}',
              description: description,
              category: 'food.dining_out',
              currency: currency,
              total: total,
              splitType: 'equal',
              paid: {payer: total},
              owed: owed,
              notes: r.nextBool() ? _text(r, 4).trim() : null,
            ),
          );
        }
        final payments = <CsvPayment>[
          for (var p = 0; p < r.nextInt(3); p++)
            CsvPayment(
              date: '2026-11-15',
              fromId: ids[0],
              toId: ids[1],
              currency: _codes[r.nextInt(_codes.length)],
              amount: 1 + r.nextInt(100000),
            ),
        ];
        final csv = buildGroupCsv(members: members, expenses: expenses, payments: payments);
        final reason = 'case $k';
        final ImportCsv parsed;
        try {
          parsed = parseImportCsv(csv);
        } on SplitwiseCsvError catch (e) {
          fail('$reason: our own export was refused: $e\n$csv');
        }
        expect(parsed.format, ImportFormat.splitify, reason: reason);
        expect(parsed.file.members, [for (final m in members) m.name], reason: reason);
        final descriptions = [
          for (final row in parsed.file.rows)
            if (!row.isPayment) row.description,
        ];
        final sorted = [...expenses]..sort((a, b) => a.date.compareTo(b.date));
        expect(descriptions.toSet(), {for (final e in sorted) e.description}, reason: reason);
        // Nets per currency and member: what the export wrote is what the import rebuilds.
        final want = <String, Map<String, int>>{};
        for (final e in expenses) {
          final per = want.putIfAbsent(e.currency, () => {});
          for (final (i, id) in ids.indexed) {
            per[names.elementAt(i)] =
                (per[names.elementAt(i)] ?? 0) + (e.paid[id] ?? 0) - (e.owed[id] ?? 0);
          }
        }
        for (final p in payments) {
          final per = want.putIfAbsent(p.currency, () => {});
          per[names.elementAt(0)] = (per[names.elementAt(0)] ?? 0) + p.amount;
          per[names.elementAt(1)] = (per[names.elementAt(1)] ?? 0) - p.amount;
        }
        final result = reconstructSplitwise(parsed.file);
        for (final c in want.keys) {
          for (final name in names) {
            expect(result.nets[c]?[name] ?? 0, want[c]![name] ?? 0, reason: '$reason $c $name');
          }
        }
      }
    });

    test(
      'formula-like text and a leading apostrophe both survive (CSV injection guard round trip)',
      () {
        const members = [
          CsvMember('m1', "'=Asha"),
          CsvMember('m2', '=Rahul'),
          CsvMember('m3', "''+x"),
        ];
        final csv = buildGroupCsv(
          members: members,
          expenses: const [
            CsvExpense(
              date: '2026-11-01',
              description: "'=1+1 tea",
              category: 'food.dining_out',
              currency: 'INR',
              total: 300,
              splitType: 'equal',
              paid: {'m1': 300},
              owed: {'m1': 100, 'm2': 100, 'm3': 100},
            ),
          ],
        );
        final parsed = parseImportCsv(csv);
        expect(parsed.file.members, ["'=Asha", '=Rahul', "''+x"]);
        expect(parsed.file.rows.single.description, "'=1+1 tea");
      },
    );
  });

  // TC-R4-C-03
  group('"Total balance" as a description', () {
    test('a Splitwise expense called "Total balance" is imported as an expense', () {
      const text =
          'Date,Description,Category,Cost,Currency,Asha,Rahul\n'
          '2026-01-05,Total balance,General,100.00,INR,50.00,-50.00\n'
          '2026-01-06,Total balance,General,40.00,INR,20.00,-20.00\n'
          '2026-01-06,Total balance,,,INR,70.00,-70.00\n';
      final file = parseSplitwiseCsv(text);
      expect(file.rows, hasLength(2));
      expect(file.totals['INR'], {'Asha': 7000, 'Rahul': -7000});
      expect(file.totalsMismatches, isEmpty);
    });
  });

  // TC-R4-C-04
  group('cells and sizes', () {
    String file(String cost, String asha, String rahul, {String currency = 'INR'}) =>
        'Date,Description,Category,Cost,Currency,Asha,Rahul\n'
        '2026-01-05,Tea,General,$cost,$currency,$asha,$rahul\n';

    test('malformed numbers are IMPORT_INVALID_AMOUNT with the cell named', () {
      for (final bad in [
        '1e3',
        '1,000.00',
        '١٠٠',
        '１００',
        '12.3.4',
        '--5',
        '5-',
        'NaN',
        '₹100',
        '0x10',
        '1 000',
      ]) {
        expect(
          () => parseSplitwiseCsv(file('"$bad"', '50.00', '-50.00')),
          throwsA(isA<InvalidAmount>().having((e) => e.column, 'column', 'Cost')),
          reason: bad,
        );
      }
      expect(
        () => parseSplitwiseCsv(file('100.00', '99999999999999999999.00', '-50.00')),
        throwsA(isA<InvalidAmount>().having((e) => e.column, 'column', 'Asha')),
      );
      expect(
        () => parseSplitwiseCsv(file('100.001', '50.00', '-50.00')),
        throwsA(isA<InvalidAmount>()),
      );
      expect(parseSplitwiseCsv(file('100.000', '50.00', '-50.00')).rows.single.cost, 10000);
    });

    test(
      'currencies: lower case is read, not-a-code is IMPORT_INVALID_CURRENCY, 0 and 3 decimals',
      () {
        expect(
          parseSplitwiseCsv(file('100.00', '50.00', '-50.00', currency: 'inr'))
              .rows
              .single
              .currency,
          'INR',
        );
        for (final bad in ['RUPEES', '₹', 'IN', '12A', '']) {
          expect(
            () => parseSplitwiseCsv(file('100.00', '50.00', '-50.00', currency: bad)),
            throwsA(isA<InvalidCurrency>()),
            reason: bad,
          );
        }
        expect(
          parseSplitwiseCsv(file('1500', '750', '-750', currency: 'JPY')).rows.single.cost,
          1500,
        );
        expect(
          () => parseSplitwiseCsv(file('15.5', '7.75', '-7.75', currency: 'JPY')),
          throwsA(isA<InvalidAmount>()),
        );
        expect(
          parseSplitwiseCsv(file('1.250', '0.625', '-0.625', currency: 'KWD')).rows.single.cost,
          1250,
        );
      },
    );

    test('20,000 rows x 10 people parse and rebuild well within the time budget', () {
      final names = [for (var i = 0; i < 10; i++) 'P$i'];
      final b = StringBuffer('Date,Description,Category,Cost,Currency,${names.join(',')}\r\n');
      for (var i = 0; i < 20000; i++) {
        b.write('2026-01-05,"Row $i, ok",General,10.00,INR,9.00${',-1.00' * 9}\r\n');
      }
      final watch = Stopwatch()..start();
      final parsed = parseImportCsv(b.toString());
      final result = reconstructSplitwise(parsed.file);
      expect(result.expenses, hasLength(20000));
      expect(result.nets['INR']!['P0'], 20000 * 900);
      expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
    });
  });
}
