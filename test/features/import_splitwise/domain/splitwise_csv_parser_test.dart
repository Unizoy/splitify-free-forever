import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_csv_parser.dart';

String _fixture(String name) => File('test/fixtures/splitwise/$name').readAsStringSync();

const _head = 'Date,Description,Category,Cost,Currency,Aarav,Priya';

SplitwiseCsv _parse(List<String> rows, {String head = _head}) =>
    parseSplitwiseCsv([head, ...rows].join('\n'));

Matcher _throws<T extends SplitwiseCsvError>(int row, String code) =>
    throwsA(isA<T>().having((e) => e.row, 'row', row).having((e) => e.code, 'code', code));

void main() {
  group('TC-X1-01 group export (INR + USD, payments, multi-payer, quotes)', () {
    final file = parseSplitwiseCsv(_fixture('group_inr_usd.csv'));

    test('members in column order, blank and total rows dropped', () {
      expect(file.members, ['Aarav', 'Priya', 'Rohan', 'Meera']);
      expect(file.rows, hasLength(8));
      expect(file.rows.map((r) => r.row), [2, 3, 4, 5, 6, 7, 8, 9]);
      expect(file.currencies, ['INR', 'USD']);
    });

    test('quoted commas and escaped quotes stay in the description', () {
      expect(file.rows[0].description, 'Dinner at Toit, Indiranagar');
      expect(file.rows[2].description, 'Goa "villa" booking, 2 nights');
      expect(file.rows[5].description, 'Museum tickets, NYC');
    });

    test('row fields become typed values in minor units', () {
      final dinner = file.rows[0];
      expect(dinner.date, DateTime.utc(2026, 1, 5));
      expect(dinner.category, 'Dining out');
      expect(dinner.isPayment, isFalse);
      expect(dinner.currency, 'INR');
      expect(dinner.cost, 300000);
      expect(dinner.nets, {'Aarav': 225000, 'Priya': -75000, 'Rohan': -75000, 'Meera': -75000});
      expect(file.rows[6].nets, {'Aarav': 0, 'Priya': -333, 'Rohan': -333, 'Meera': 666});
    });

    test('Payment rows are flagged', () {
      expect(
        [for (final r in file.rows) r.isPayment],
        [
          false, false, false, false, true, false, false, true, //
        ],
      );
    });

    test('column sums per currency match the Total balance rows', () {
      expect(file.columnSums, {
        'INR': {'Aarav': 555000, 'Priya': -378334, 'Rohan': -8333, 'Meera': -168333},
        'USD': {'Aarav': 0, 'Priya': -333, 'Rohan': 2667, 'Meera': -2334},
      });
      expect(file.totals, file.columnSums);
      expect(file.totalsMismatches, isEmpty);
    });
  });

  test('BOM, CRLF and JPY (exponent 0, zero decimals accepted)', () {
    final file = parseSplitwiseCsv(_fixture('bom_jpy_crlf.csv'));
    expect(file.members, ['Aarav', 'Priya', 'Rohan']);
    expect(file.rows.map((r) => r.cost), [3000, 1000]);
    expect(file.rows[1].nets, {'Aarav': -333, 'Priya': 666, 'Rohan': -333});
    expect(file.totals['JPY'], {'Aarav': 1667, 'Priya': -334, 'Rohan': -1333});
    expect(file.totalsMismatches, isEmpty);
  });

  test('BOM and CRLF in an inline string', () {
    final file = parseSplitwiseCsv(
      '\ufeff$_head\r\n2026-01-05,Tea,General,20.00,INR,10.00,-10.00\r\n',
    );
    expect(file.members, ['Aarav', 'Priya']);
    expect(file.rows.single.nets, {'Aarav': 1000, 'Priya': -1000});
  });

  group('checksum', () {
    test('mismatching Total balance row is reported per member', () {
      final file = parseSplitwiseCsv(_fixture('checksum_mismatch.csv'));
      expect(file.totalsMismatches, const [
        TotalsMismatch(currency: 'INR', member: 'Priya', fileTotal: -25000, rowsTotal: -20000),
        TotalsMismatch(currency: 'INR', member: 'Rohan', fileTotal: -15000, rowsTotal: -20000),
      ]);
      final m = file.totalsMismatches.first;
      expect(m.hashCode, file.totalsMismatches.first.hashCode);
      expect(m == file.totalsMismatches.last, isFalse);
      expect(m.toString(), 'TotalsMismatch(INR Priya: file -25000, rows -20000)');
    });

    test('a total row for a currency without rows is checked against 0', () {
      final file = _parse(['2026-01-05,Total balance,,,EUR,5.00,-5.00']);
      expect(file.rows, isEmpty);
      expect(file.currencies, ['EUR']);
      expect(file.totalsMismatches, hasLength(2));
    });

    test('a currency without a total row is not checked', () {
      final file = _parse(['2026-01-05,Tea,General,20.00,INR,10.00,-10.00']);
      expect(file.totals, isEmpty);
      expect(file.totalsMismatches, isEmpty);
    });

    test('two total rows for one currency', () {
      expect(
        () => _parse(['2026-01-05,Total balance,,,INR,0,0', '2026-01-05,Total balance,,,INR,0,0']),
        _throws<DuplicateTotals>(3, 'IMPORT_DUPLICATE_TOTALS'),
      );
    });
  });

  group('header', () {
    test('fixture with a renamed column', () {
      expect(
        () => parseSplitwiseCsv(_fixture('bad_header.csv')),
        _throws<BadHeader>(1, 'IMPORT_BAD_HEADER'),
      );
    });

    for (final head in [
      'Date,Description,Category,Cost',
      'Date,Description,Category,Cost,Currency',
      'Date,Description,Category,Cost,Currency,Aarav,',
      'Date,Description,Category,Cost,Currency,Aarav,Aarav',
      '',
    ]) {
      test('rejects "$head"', () {
        expect(
          () => parseSplitwiseCsv('$head\n2026-01-05,x,y,1,INR,1'),
          _throws<BadHeader>(1, 'IMPORT_BAD_HEADER'),
        );
      });
    }

    test('fixed columns are matched case-insensitively and trimmed', () {
      final file = parseSplitwiseCsv(' date ,DESCRIPTION,category,cost,currency, Aarav ');
      expect(file.members, ['Aarav']);
      expect(file.rows, isEmpty);
    });

    test('empty file', () {
      expect(() => parseSplitwiseCsv(''), _throws<EmptyFile>(0, 'IMPORT_EMPTY_FILE'));
      expect(() => parseSplitwiseCsv('\ufeff\n\n'), _throws<EmptyFile>(0, 'IMPORT_EMPTY_FILE'));
    });
  });

  group('rows', () {
    test('wrong number of cells', () {
      expect(
        () => _parse(['2026-01-05,Tea,General,20.00,INR,10.00']),
        throwsA(
          isA<WrongColumnCount>()
              .having((e) => e.row, 'row', 2)
              .having((e) => e.expected, 'expected', 7)
              .having((e) => e.actual, 'actual', 6)
              .having((e) => e.code, 'code', 'IMPORT_WRONG_COLUMN_COUNT'),
        ),
      );
    });

    test('dates: plain, with a time, invalid text, impossible day', () {
      final ok = _parse([
        '2026-01-05,Tea,General,20.00,INR,10.00,-10.00',
        '2026-01-06T10:30:00Z,Tea,General,20.00,INR,10.00,-10.00',
      ]);
      expect(ok.rows.map((r) => r.date), [DateTime.utc(2026, 1, 5), DateTime.utc(2026, 1, 6)]);
      for (final bad in ['05/01/2026', '2026-02-30', '2026-13-01']) {
        expect(
          () => _parse(['$bad,Tea,General,20.00,INR,10.00,-10.00']),
          throwsA(
            isA<InvalidDate>()
                .having((e) => e.row, 'row', 2)
                .having((e) => e.value, 'value', bad)
                .having((e) => e.code, 'code', 'IMPORT_INVALID_DATE'),
          ),
        );
      }
    });

    test('currency codes: lower case accepted, others rejected', () {
      expect(_parse(['2026-01-05,Tea,General,20.00,inr,10.00,-10.00']).rows.single.currency, 'INR');
      expect(
        () => _parse(['2026-01-05,Tea,General,20.00,Rs,10.00,-10.00']),
        throwsA(
          isA<InvalidCurrency>()
              .having((e) => e.value, 'value', 'Rs')
              .having((e) => e.code, 'code', 'IMPORT_INVALID_CURRENCY'),
        ),
      );
    });

    test('amounts: exponent-aware, signs, empty member cells, leading zeros', () {
      final file = _parse([
        '2026-01-05,Fuel,Gas/fuel,1.234,KWD,+1.234,-1.234',
        '2026-01-05,Tea,General,007.5,INR,,0',
        '2026-01-05,Tea,General,20,INR,-0.5,0.50',
      ]);
      expect(file.rows[0].cost, 1234);
      expect(file.rows[0].nets, {'Aarav': 1234, 'Priya': -1234});
      expect(file.rows[1].cost, 750);
      expect(file.rows[1].nets, {'Aarav': 0, 'Priya': 0});
      expect(file.rows[2].cost, 2000);
      expect(file.rows[2].nets, {'Aarav': -50, 'Priya': 50});
    });

    for (final (cost, cells, column) in [
      ('"1,000.00"', '0,0', 'Cost'),
      ('', '0,0', 'Cost'),
      ('12.345', '0,0', 'Cost'),
      ('₹20', '0,0', 'Cost'),
      ('20', '1e3,-1e3', 'Aarav'),
      ('20', '0,-10.001', 'Priya'),
      ('20', '10000000000.00,-10000000000.00', 'Aarav'),
      ('12345678901234567890', '0,0', 'Cost'),
    ]) {
      test('rejects amount $cost / $cells', () {
        expect(
          () => _parse(['2026-01-05,Tea,General,$cost,INR,$cells']),
          throwsA(
            isA<InvalidAmount>()
                .having((e) => e.row, 'row', 2)
                .having((e) => e.column, 'column', column)
                .having((e) => e.code, 'code', 'IMPORT_INVALID_AMOUNT'),
          ),
        );
      });
    }

    test('largest amount is accepted', () {
      final file = _parse([
        '2026-01-05,Big,General,9999999999.99,INR,9999999999.99,-9999999999.99',
      ]);
      expect(file.rows.single.cost, 999999999999);
    });

    test('cells that do not sum to 0', () {
      expect(
        () => _parse(['2026-01-05,Tea,General,20.00,INR,10.00,-9.99']),
        throwsA(
          isA<RowNotBalanced>()
              .having((e) => e.row, 'row', 2)
              .having((e) => e.remaining, 'remaining', 1)
              .having((e) => e.code, 'code', 'IMPORT_ROW_NOT_BALANCED'),
        ),
      );
    });

    test('blank lines are skipped but still counted in row numbers', () {
      expect(
        () => _parse(['', ',,,,,,', '2026-01-05,Tea,General,20.00,INR,10.00,-9.99']),
        throwsA(isA<RowNotBalanced>().having((e) => e.row, 'row', 4)),
      );
    });

    test('localised payment category', () {
      final rows = parseSplitwiseCsv(
        '$_head\n2026-01-05,Priya zahlte Aarav,Zahlung,5,EUR,-5,5',
        paymentCategory: ' zahlung ',
      ).rows;
      expect(rows.single.isPayment, isTrue);
    });
  });

  test('error toString names code and row', () {
    expect(const InvalidDate(7, 'x').toString(), 'SplitwiseCsvError(IMPORT_INVALID_DATE, row 7)');
  });
}
