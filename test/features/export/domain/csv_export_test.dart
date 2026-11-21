import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/export/domain/csv_export.dart';

const _members = [CsvMember('m1', 'Mohit'), CsvMember('m2', 'Asha, "A"'), CsvMember('m3', 'Ravi')];

void main() {
  group('TC-22-01 CSV writer', () {
    test('fixture: BOM, header, rows by date, payments, totals per currency, deleted flag', () {
      final csv = buildGroupCsv(
        members: _members,
        expenses: [
          const CsvExpense(
            date: '2026-11-03',
            description: 'Dinner, "Goa"',
            category: 'food.dining',
            currency: 'INR',
            total: 30000,
            splitType: 'equal',
            paid: {'m1': 30000},
            owed: {'m1': 10000, 'm2': 10000, 'm3': 10000},
            notes: 'line1\nline2',
            addedBy: 'Mohit',
          ),
          const CsvExpense(
            date: '2026-11-01',
            description: '=SUM(A1)',
            category: 'travel.taxi',
            currency: 'USD',
            total: 1250,
            splitType: 'exact',
            paid: {'m2': 1000, 'm3': 250},
            owed: {'m1': 1250},
          ),
          const CsvExpense(
            date: '2026-11-04',
            description: 'Removed',
            category: 'other.general',
            currency: 'INR',
            total: 500,
            splitType: 'equal',
            paid: {'m1': 500},
            owed: {'m2': 500},
            deleted: true,
          ),
        ],
        payments: [
          const CsvPayment(
            date: '2026-11-03',
            fromId: 'm2',
            toId: 'm1',
            currency: 'INR',
            amount: 10000,
            method: 'upi',
            note: 'thanks',
            addedBy: 'Asha',
          ),
          const CsvPayment(
            date: '2026-11-05',
            fromId: 'gone',
            toId: 'm1',
            currency: 'JPY',
            amount: 700,
          ),
        ],
      );
      const expected =
          '﻿'
          'Date,Description,Category,Currency,Amount,Paid by,Split type,Mohit,"Asha, ""A""",Ravi,Notes,Added by,Deleted\r\n'
          "2026-11-01,'=SUM(A1),travel.taxi,USD,12.50,\"Asha, \"\"A\"\", Ravi\",exact,-12.50,10.00,2.50,,,no\r\n"
          '2026-11-03,"Dinner, ""Goa""",food.dining,INR,300.00,Mohit,equal,200.00,-100.00,-100.00,"line1\nline2",Mohit,no\r\n'
          '2026-11-03,"Asha, ""A"" paid Mohit",Payment,INR,100.00,"Asha, ""A""",payment (upi),-100.00,100.00,0.00,thanks,Asha,no\r\n'
          '2026-11-04,Removed,other.general,INR,5.00,Mohit,equal,5.00,-5.00,0.00,,,yes\r\n'
          '2026-11-05,gone paid Mohit,Payment,JPY,700,gone,payment (cash),-700,0,0,,,no\r\n'
          ',Total balance,,INR,,,,100.00,0.00,-100.00,,,\r\n'
          ',Total balance,,JPY,,,,-700,0,0,,,\r\n'
          ',Total balance,,USD,,,,-12.50,10.00,2.50,,,\r\n';
      expect(csv, expected);
    });

    test('empty export is BOM + header only', () {
      expect(
        buildGroupCsv(members: const [CsvMember('m1', 'Mohit')]),
        '﻿Date,Description,Category,Currency,Amount,Paid by,Split type,Mohit,Notes,Added by,Deleted\r\n',
      );
    });

    test('bytes start with the UTF-8 BOM and keep non-ASCII text', () {
      final bytes = buildGroupCsvBytes(members: const [CsvMember('m1', 'राम')]);
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(String.fromCharCodes(bytes), isNot(contains('?')));
      expect(bytes.length, greaterThan(3 + 'Date'.length));
    });

    test('csvEscape quotes only when needed', () {
      expect(csvEscape('plain'), 'plain');
      expect(csvEscape('a,b'), '"a,b"');
      expect(csvEscape('say "hi"'), '"say ""hi"""');
      expect(csvEscape('a\r\nb'), '"a\r\nb"');
      expect(csvEscape(''), '');
    });

    test('formula-like text is neutralised in every text column', () {
      final csv = buildGroupCsv(
        members: const [CsvMember('m1', '+Plus')],
        expenses: const [
          CsvExpense(
            date: '2026-01-01',
            description: '-dash',
            category: '@cat',
            currency: 'INR',
            total: 100,
            splitType: 'equal',
            paid: {'m1': 100},
            owed: {'m1': 100},
            notes: '\tTab',
            addedBy: '=me',
          ),
        ],
      );
      final lines = csv.split('\r\n');
      expect(lines[0], contains(",'+Plus,"));
      expect(lines[1], "2026-01-01,'-dash,'@cat,INR,1.00,'+Plus,equal,0.00,'\tTab,'=me,no");
    });
  });
}
