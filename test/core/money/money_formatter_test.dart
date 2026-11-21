// MoneyFormatter (planning/05-money-engine.md §7; phase 03 task T5). No catalog id.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/currency.dart';
import 'package:splitify/core/money/money_formatter.dart';

const _minus = '−';
const _nbsp = ' ';

void main() {
  const detail = MoneyFormatter.detail;
  const list = MoneyFormatter.list;

  group('groupIndian', () {
    test('last three digits, then groups of two', () {
      const cases = {
        '': '',
        '0': '0',
        '12': '12',
        '123': '123',
        '1234': '1,234',
        '12345': '12,345',
        '123456': '1,23,456',
        '1234567': '12,34,567',
        '100000': '1,00,000',
        '10000000': '1,00,00,000',
        '9999999999': '9,99,99,99,999',
      };
      cases.forEach((input, out) => expect(MoneyFormatter.groupIndian(input), out, reason: input));
    });

    test("matches intl's en_IN pattern", () {
      final intl = NumberFormat('#,##,##0', 'en_IN');
      final values = <int>[0, 7, 99, 999, 1000, 99999, 100000, 1234567, 999999999999];
      for (var v = 1; v < 1000000000000000; v = v * 10 + 3) {
        values.add(v);
      }
      for (final v in values) {
        expect(MoneyFormatter.groupIndian('$v'), intl.format(v), reason: '$v');
      }
    });
  });

  group('MoneyFormatter rupees', () {
    test('en_IN grouping with full precision', () {
      expect(detail.format(10050, 'INR'), '₹100.50');
      expect(detail.format(10000050, 'INR'), '₹1,00,000.50');
      expect(detail.format(120000, 'INR'), '₹1,200.00');
      expect(detail.format(5, 'INR'), '₹0.05');
      expect(detail.format(50, 'INR'), '₹0.50');
      expect(detail.format(0, 'INR'), '₹0.00');
    });

    test('largest amount (999,999,999,999 paise)', () {
      expect(detail.format(999999999999, 'INR'), '₹9,99,99,99,999.99');
    });

    test('hideZeroFraction drops only an all-zero fraction', () {
      expect(list.format(120000, 'INR'), '₹1,200');
      expect(list.format(120050, 'INR'), '₹1,200.50');
      expect(list.format(120005, 'INR'), '₹1,200.05');
      expect(list.format(0, 'INR'), '₹0');
      expect(list.hideZeroFraction, isTrue);
      expect(detail.hideZeroFraction, isFalse);
    });

    test('negative amounts: U+2212 minus before the symbol', () {
      expect(MoneyFormatter.minusSign, _minus);
      expect(detail.format(-50000, 'INR'), '$_minus₹500.00');
      expect(list.format(-50000, 'INR'), '$_minus₹500');
      expect(list.format(-1, 'INR'), '$_minus₹0.01');
    });

    test('int minimum value does not overflow', () {
      // -9223372036854775808 paise.
      expect(detail.format(-9223372036854775807 - 1, 'INR'), '$_minus₹92,23,37,20,36,85,47,758.08');
    });
  });

  group('MoneySign', () {
    test('negativeOnly is the default', () {
      expect(detail.sign, MoneySign.negativeOnly);
      expect(detail.format(50000, 'INR'), '₹500.00');
    });

    test('always: + for positive, − for negative, none for zero', () {
      const signed = MoneyFormatter(hideZeroFraction: true, sign: MoneySign.always);
      expect(MoneyFormatter.plusSign, '+');
      expect(signed.format(50000, 'INR'), '+₹500');
      expect(signed.format(-50000, 'INR'), '$_minus₹500');
      expect(signed.format(0, 'INR'), '₹0');
    });

    test('never: magnitude only', () {
      const bare = MoneyFormatter(hideZeroFraction: true, sign: MoneySign.never);
      expect(bare.format(-50000, 'INR'), '₹500');
      expect(bare.format(50000, 'INR'), '₹500');
    });
  });

  group('exponent 0 and 3', () {
    test('JPY and VND have no fraction', () {
      expect(detail.format(1200, 'JPY'), '¥1,200');
      expect(list.format(1200, 'JPY'), '¥1,200');
      expect(detail.format(-5, 'JPY'), '$_minus¥5');
      expect(detail.format(2500000, 'VND'), '₫25,00,000');
      expect(detail.format(0, 'JPY'), '¥0');
    });

    test('KWD shows three decimals', () {
      expect(detail.format(1234567, 'KWD'), 'KWD${_nbsp}1,234.567');
      expect(detail.format(5, 'KWD'), 'KWD${_nbsp}0.005');
      expect(detail.format(1000, 'KWD'), 'KWD${_nbsp}1.000');
      expect(list.format(1000, 'KWD'), 'KWD${_nbsp}1');
      expect(list.format(1010, 'KWD'), 'KWD${_nbsp}1.010');
    });
  });

  group('units', () {
    test('symbols touch the number; letter units get a no-break space', () {
      expect(MoneyFormatter.unitGap, _nbsp);
      expect(detail.format(500, 'USD'), r'$5.00');
      expect(detail.format(500, 'EUR'), '€5.00');
      expect(detail.format(500, 'CAD'), r'CA$5.00');
      expect(detail.format(500, 'CNY'), 'CN¥5.00');
      expect(detail.format(500000, 'AED'), 'AED${_nbsp}5,000.00');
      expect(detail.format(100000, 'IDR'), 'Rp${_nbsp}1,000.00');
      expect(detail.format(500, 'PLN'), 'zł${_nbsp}5.00');
      expect(detail.format(-500, 'ZAR'), '${_minus}R${_nbsp}5.00');
    });

    test('code unit', () {
      const byCode = MoneyFormatter(unit: MoneyUnit.code);
      expect(byCode.unit, MoneyUnit.code);
      expect(byCode.format(120000, 'INR'), 'INR${_nbsp}1,200.00');
      expect(byCode.format(-500, 'USD'), '${_minus}USD${_nbsp}5.00');
      expect(byCode.format(1200, 'JPY'), 'JPY${_nbsp}1,200');
    });

    test('no unit', () {
      const bare = MoneyFormatter(unit: MoneyUnit.none);
      expect(bare.format(10000050, 'INR'), '1,00,000.50');
      expect(bare.format(-10000050, 'INR'), '${_minus}1,00,000.50');
    });

    test('unknown codes show the code and use the ISO exponent rule', () {
      expect(detail.format(500, 'XYZ'), 'XYZ${_nbsp}5.00');
      expect(detail.format(500, 'UYI'), 'UYI${_nbsp}500');
    });

    test('formatCurrency takes a Currency', () {
      const custom = Currency(code: 'TST', exponent: 4, symbol: '¤', name: 'Test');
      expect(detail.formatCurrency(123456789, custom), '¤12,345.6789');
      expect(list.formatCurrency(10000, custom), '¤1');
      expect(detail.formatCurrency(10050, Currencies.inr), '₹100.50');
    });
  });

  group('plain', () {
    test('ASCII minus, no grouping, no unit, full precision', () {
      expect(MoneyFormatter.plain(10050, 'INR'), '100.50');
      expect(MoneyFormatter.plain(100000000, 'INR'), '1000000.00');
      expect(MoneyFormatter.plain(-10050, 'INR'), '-100.50');
      expect(MoneyFormatter.plain(0, 'INR'), '0.00');
      expect(MoneyFormatter.plain(1200, 'JPY'), '1200');
      expect(MoneyFormatter.plain(5, 'KWD'), '0.005');
    });
  });
}
