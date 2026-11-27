// Receipt text parser (D-034 A3): fixture receipts (OCR rows), Indian number formats, no total found.
// TC-D034-A3-01 fixtures: the right total on ≥ 7 of 8 Indian receipts (acceptance), plus dates/merchants
// TC-D034-A3-02 number formats (₹ / Rs. / INR / "/-", 1,23,456.00, decimal comma, no doubles)
// TC-D034-A3-03 GST / service / round off / discount lines and item lines (Itemize prefill)
// TC-D034-A3-04 rows rebuilt from OCR boxes
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/rules/receipt_text_parser.dart';

final _today = DateTime(2026, 11, 27);

List<String> _rows(String name) =>
    File('test/fixtures/receipts/$name.txt').readAsLinesSync().where((l) => l.isNotEmpty).toList();

ReceiptScan _scan(String name) => parseReceipt(_rows(name), today: _today);

/// The eight acceptance receipts and the total each one says (minor units).
const _expected = <String, int>{
  'restaurant_gst': 99200,
  'grocery': 117400,
  'fuel': 200000,
  'pharmacy': 34560,
  'cab': 31200,
  'handwritten': 19000,
  'hotel_en': 1050100,
  'upi_screenshot': 25000,
};

void main() {
  group('acceptance fixtures', () {
    test('the right total on at least 7 of the 8 Indian receipts', () {
      final wrong = <String>[];
      for (final e in _expected.entries) {
        final scan = _scan(e.key);
        if (scan.total != e.value) wrong.add('${e.key}: ${scan.total} (want ${e.value})');
      }
      expect(wrong.length, lessThanOrEqualTo(1), reason: wrong.join('\n'));
      // This parser reads all eight.
      expect(wrong, isEmpty);
    });

    test('restaurant with GST, service charge and round off', () {
      final s = _scan('restaurant_gst');
      expect(s.total, 99200);
      expect(s.date, DateTime(2026, 11, 21));
      expect(s.merchant, 'Hotel Saravana Bhavan');
      expect(s.tax, 4726);
      expect(s.service, 4500);
      expect(s.roundOff, -26);
      expect(s.items, [
        (name: 'Masala Dosa', amount: 18000),
        (name: 'Ghee Roast', amount: 14000),
        (name: 'Mini Meals', amount: 44000),
        (name: 'Filter Coffee', amount: 14000),
      ]);
      expect(s.itemsTotal, s.total);
    });

    test(
      'grocery: Net Payable, quantities and savings are not amounts, tax included in prices',
      () {
        final s = _scan('grocery');
        expect(s.total, 117400);
        expect(s.date, DateTime(2026, 11, 21));
        expect(s.merchant, 'D Mart');
        expect(s.tax, 0);
        expect(
          [for (final i in s.items) i.name],
          [
            'Aashirvaad Atta 5kg',
            'Amul Butter 500g',
            'Tata Salt 1kg',
            'Maggi Noodles 12pk',
            'Surf Excel 1kg',
          ],
        );
        expect(s.itemsTotal, 117400);
      },
    );

    test('fuel: no "total" word, the amount line wins over rate and volume', () {
      final s = _scan('fuel');
      expect(s.total, 200000);
      expect(s.date, DateTime(2026, 11, 21));
      expect(s.merchant, 'Indian Oil');
      expect(s.items, isEmpty);
    });

    test('pharmacy: Net Amt after the discount', () {
      final s = _scan('pharmacy');
      expect(s.total, 34560);
      expect(s.date, DateTime(2026, 11, 20));
      expect(s.merchant, 'Apollo Pharmacy');
      expect(s.discount, 1440);
      expect(s.items.map((i) => i.amount), [6182, 11950, 17868]);
      expect(s.items.first.name, 'Dolo 650 Tab');
      expect(s.itemsTotal, 34560);
    });

    test('cab: ₹ amounts, taxes, a written-out date', () {
      final s = _scan('cab');
      expect(s.total, 31200);
      expect(s.date, DateTime(2026, 11, 21));
      expect(s.merchant, 'Uber');
      expect(s.tax, 2652);
    });

    test('hand-written-ish bill: "Total = 190/-", qty x rate lines, dd/mm/yy', () {
      final s = _scan('handwritten');
      expect(s.total, 19000);
      expect(s.date, DateTime(2026, 11, 21));
      expect(s.merchant, 'Shree Ganesh Tea Stall');
      expect(s.items, [
        (name: 'Tea', amount: 4000),
        (name: 'Samosa', amount: 9000),
        (name: 'Bread Pakora', amount: 6000),
      ]);
    });

    test('English hotel bill: the grand total after round off, the bill date', () {
      final s = _scan('hotel_en');
      expect(s.total, 1050100);
      expect(s.date, DateTime(2026, 11, 21));
      expect(s.merchant, 'The Grand Palace Hotel');
      expect(s.service, 44650);
      expect(s.tax, 112518);
      expect(s.roundOff, -68);
      expect(s.items.map((i) => i.name), [
        'Room Charges (3 nights)',
        'Food & Beverages',
        'Laundry',
      ]);
      expect(s.itemsTotal, 1050100);
    });

    test('UPI screenshot: the ₹ amount, the payee, ids and times are not amounts', () {
      final s = _scan('upi_screenshot');
      expect(s.total, 25000);
      expect(s.merchant, 'Ramesh Kumar');
      expect(s.date, DateTime(2026, 11, 21));
      expect(s.items, isEmpty);
    });

    test('electronics: lakh grouping, INR, amount in words ignored', () {
      final s = _scan('electronics');
      expect(s.total, 13997900);
      expect(s.date, DateTime(2026, 11, 15));
      expect(s.merchant, 'Croma');
      expect(s.items.map((i) => i.amount), [2999000, 10499000, 499900]);
      expect(s.itemsTotal, 13997900);
    });

    test('nothing to read: no total', () {
      final s = _scan('no_total');
      expect(s.total, isNull);
      expect(s.date, isNull);
      expect(s.items, isEmpty);
      expect(parseReceipt(const []).isEmpty, isTrue);
      expect(parseReceipt(const ['', '   ', '|||', '----']).isEmpty, isTrue);
    });
  });

  group('what the on-device text model read (emulator run, S-374)', () {
    test('"₹" read as a leading 1 is undone by the payment line; "₹" read as T is a mark', () {
      final cab = _scan('cab_device_ocr');
      expect(cab.total, 31200);
      expect(cab.merchant, 'Uber');
      final upi = _scan('upi_device_ocr');
      expect(upi.total, 25000);
      expect(upi.merchant, 'Ramesh Kumar');
      expect(upi.date, DateTime(2026, 11, 21));
    });

    test('a leading 1 stays when nothing else says otherwise', () {
      expect(parseReceipt(const ['Total 1312.00', 'Cash 1312.00']).total, 131200);
      expect(parseReceipt(const ['Total 1312.00', 'Masala Dosa 312.00']).total, 131200);
      expect(parseReceipt(const ['Total <312.00']).total, 31200);
      expect(parseReceipt(const ['Table T2', 'Coffee 120']).total, 12000);
    });
  });

  group('number formats', () {
    int? total(String row, {int exponent = 2}) =>
        parseReceipt([row], exponent: exponent, today: _today).total;

    test('₹, Rs., INR, /- and Indian grouping', () {
      expect(total('Total ₹1,23,456.00'), 12345600);
      expect(total('Grand Total Rs.250/-'), 25000);
      expect(total('Total Rs 99'), 9900);
      expect(total('Net Amount INR 1,200'), 120000);
      expect(total('TOTAL: 12,34,567.50'), 123456750);
      expect(total('Amount Payable  1234.5'), 123450);
      expect(total('Bill Total 945,00'), 94500);
      expect(total('Total ₹ 0.99'), 99);
    });

    test('a currency without decimals', () {
      expect(total('Total 1,200', exponent: 0), 1200);
      expect(total('Total 1,200.00', exponent: 0), 1200);
      expect(total('Total 1,200.50', exponent: 0), isNull);
    });

    test('dates, times, percentages, phones and ids are never amounts', () {
      expect(total('21/11/2026'), isNull);
      expect(total('Time 13:45'), isNull);
      expect(total('Ph: 9876543210'), isNull);
      expect(total('GSTIN 33AABCS1234C1Z9'), isNull);
      expect(total('Total 5% 945.00'), 94500);
      expect(total('Total 3 items 945.00'), 94500);
    });

    test('malformed grouping is skipped', () {
      expect(total('Total 1,2345.00'), isNull);
      expect(total('Total 12,34'), 1234);
    });

    test('the lower of two equal totals wins, a stronger word beats a plain total', () {
      expect(parseReceipt(['Total 900.00', 'Total 945.00']).total, 94500);
      expect(parseReceipt(['Grand Total 945.00', 'Total 900.00']).total, 94500);
      // No total line at all: the biggest amount that ends a row.
      expect(parseReceipt(['Sub Total 900.00', 'CGST 22.50']).total, 90000);
    });

    test('a total whose amount is on the next row', () {
      expect(parseReceipt(['Grand Total', '₹ 1,045.00', 'Thank you']).total, 104500);
    });
  });

  group('dates', () {
    DateTime? date(String row) => parseReceipt([row], today: _today).date;

    test('Indian formats', () {
      expect(date('Date: 05/11/2026'), DateTime(2026, 11, 5));
      expect(date('Dt 05-11-26'), DateTime(2026, 11, 5));
      expect(date('05.11.2026'), DateTime(2026, 11, 5));
      expect(date('5 Nov 2026'), DateTime(2026, 11, 5));
      expect(date('05-Nov-26'), DateTime(2026, 11, 5));
      expect(date('Nov 5, 2026'), DateTime(2026, 11, 5));
      expect(date('2026-11-05'), DateTime(2026, 11, 5));
      expect(date('21st November 2026'), DateTime(2026, 11, 21));
    });

    test('day first; month first only when day first is impossible; no future dates', () {
      expect(date('03/04/2026'), DateTime(2026, 4, 3));
      expect(date('11/25/2026'), DateTime(2026, 11, 25));
      expect(date('31/02/2026'), isNull);
      expect(date('01/12/2026'), isNull);
      expect(date('Date 12/12/2030'), isNull);
    });
  });

  group('shared text (D-034 A7)', () {
    test('a UPI app\'s "Paid ₹250 to …" gives the amount and the payee', () {
      final s = parseReceipt(const [
        'Paid ₹250 to Ramesh Kumar via Google Pay. UPI transaction ID: 432112345678',
      ]);
      expect(s.total, 25000);
      expect(s.merchant, 'Ramesh Kumar');
      final p = parseReceipt(const ['You sent Rs. 1,200.50 to SHARMA GROCERY using PhonePe']);
      expect(p.total, 120050);
      expect(p.merchant, 'Sharma Grocery');
    });
  });

  group('rows from OCR boxes', () {
    test('a name on the left and its price on the right become one row', () {
      final rows = receiptRows(const [
        OcrLine('HOTEL SARAVANA BHAVAN', left: 80, top: 10, right: 400, bottom: 40),
        OcrLine('180.00', left: 380, top: 101, right: 460, bottom: 129),
        OcrLine('Masala Dosa', left: 20, top: 100, right: 200, bottom: 128),
        OcrLine('Grand Total', left: 20, top: 300, right: 200, bottom: 330),
        OcrLine('Rs. 992.00', left: 340, top: 304, right: 460, bottom: 334),
        OcrLine('Ghee Roast', left: 20, top: 140, right: 180, bottom: 168),
        OcrLine('140.00', left: 380, top: 139, right: 460, bottom: 167),
      ]);
      expect(rows, [
        'HOTEL SARAVANA BHAVAN',
        'Masala Dosa  180.00',
        'Ghee Roast  140.00',
        'Grand Total  Rs. 992.00',
      ]);
      final s = parseReceipt(rows);
      expect(s.total, 99200);
      expect(s.items.length, 2);
    });

    test('lines without boxes keep their order; blank lines go', () {
      expect(receiptRows(const [OcrLine('A'), OcrLine(' '), OcrLine('B')]), ['A', 'B']);
    });
  });
}
