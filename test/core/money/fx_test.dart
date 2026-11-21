// TC-32-01 FX edge cases beyond the shared vectors (expected values from the Python oracle).
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/fx.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_error.dart';

Matcher _code(String code, [Map<String, Object> data = const {}]) => throwsA(
  isA<MoneyError>().having((e) => e.code, 'code', code).having((e) => e.data, 'data', data),
);

ConvertedExpense _expense({
  int total = 10000,
  String from = 'USD',
  String to = 'INR',
  String rate = '83.1234',
  Map<String, int> paid = const {'A': 10000},
  Map<String, int> shares = const {'A': 5000, 'B': 5000},
  List<String> order = const ['A', 'B'],
}) => convertExpense(
  total: total,
  from: from,
  to: to,
  rate: rate,
  paid: paid,
  shares: shares,
  order: order,
);

void main() {
  group('parseRate', () {
    test('parseRate accepts a positive decimal when it has at most 10 decimals', () {
      expect(parseRate('83.1234'), Decimal.parse('83.1234'));
      expect(parseRate(' 83.5 '), Decimal.parse('83.5'));
      expect(parseRate('0.0000000001'), Decimal.parse('0.0000000001'));
      // Trailing zeros don't count as decimals.
      expect(parseRate('0.01203000000'), Decimal.parse('0.01203'));
      expect(parseRate('1e2'), Decimal.fromInt(100));
      expect(rateDecimals, 10);
    });

    test('parseRate throws INVALID_RATE when the rate is not a positive decimal', () {
      for (final bad in ['', '.', 'abc', '1.2.3', '1,5', '0', '0.000', '-1', '-0.5']) {
        expect(() => parseRate(bad), _code('INVALID_RATE'), reason: bad);
      }
    });

    test('parseRate throws INVALID_RATE when the rate has more than 10 decimals', () {
      expect(() => parseRate('0.00000000001'), _code('INVALID_RATE'));
      expect(() => parseRate('1e-11'), _code('INVALID_RATE'));
    });
  });

  group('convert', () {
    test('convert rounds half away from zero when the amount is negative', () {
      expect(convert(1, 'USD', 'INR', '0.5'), 1);
      expect(convert(-1, 'USD', 'INR', '0.5'), -1);
      expect(convert(3, 'USD', 'INR', '0.5'), 2);
      expect(convert(-3, 'USD', 'INR', '0.5'), -2);
      expect(convert(-1, 'USD', 'INR', '0.4'), 0);
      expect(convert(0, 'USD', 'INR', '83.1'), 0);
    });

    test(
      'convert shifts by the exponent difference when currencies have different minor units',
      () {
        // 1.500 KWD × 480.5 = ¥720.75 -> 721 (exp 3 -> 0)
        expect(convert(1500, 'KWD', 'JPY', '480.5'), 721);
        // Unknown codes use the ISO default exponent 2.
        expect(convert(10000, 'XYZ', 'INR', '2'), 20000);
        expect(convert(12345, 'INR', 'INR', '1'), 12345);
      },
    );

    test('convert throws INVALID_RATE when the rate is bad', () {
      expect(() => convert(1000, 'USD', 'INR', '-83'), _code('INVALID_RATE'));
      expect(() => convert(1000, 'USD', 'INR', 'x'), _code('INVALID_RATE'));
    });

    test('convert throws AMOUNT_TOO_LARGE when the result does not fit 64 bits', () {
      expect(() => convert(9000000000000000000, 'JPY', 'KWD', '1000'), _code('AMOUNT_TOO_LARGE'));
      expect(() => convert(-9000000000000000000, 'JPY', 'KWD', '1000'), _code('AMOUNT_TOO_LARGE'));
    });
  });

  group('convertExpense', () {
    test('convertExpense re-allocates payers and shares in fixed order when converting', () {
      final c = _expense(
        paid: const {'A': 6000, 'C': 4000},
        shares: const {'A': 0, 'B': 5000, 'C': 5000},
        order: const ['A', 'B', 'C'],
      );
      expect(c.currency, 'INR');
      expect(c.total, 831234);
      expect(c.paid, {'A': 498740, 'C': 332494});
      expect(c.shares, {'A': 0, 'B': 415617, 'C': 415617});
    });

    test('convertExpense breaks remainder ties by the fixed order when shares are equal', () {
      final c = _expense(
        total: 999,
        from: 'EUR',
        to: 'JPY',
        rate: '161.37',
        paid: const {'B': 999},
        shares: const {'A': 333, 'B': 333, 'C': 333},
        order: const ['C', 'A', 'B'],
      );
      expect(c.total, 1612);
      expect(c.paid, {'B': 1612});
      expect(c.shares, {'C': 538, 'A': 537, 'B': 537});
      expect(c.shares.keys.toList(), ['C', 'A', 'B']);
    });

    test(
      'convertExpense throws AMOUNT_NOT_POSITIVE when the input or converted total is not positive',
      () {
        expect(() => _expense(total: 0), _code('AMOUNT_NOT_POSITIVE'));
        // ₫1 × 0.0033 = ₹0.0033 -> 0 paise
        expect(
          () => _expense(
            total: 1,
            from: 'VND',
            rate: '0.0033',
            paid: const {'A': 1},
            shares: const {'B': 1},
          ),
          _code('AMOUNT_NOT_POSITIVE'),
        );
      },
    );

    test(
      'convertExpense throws AMOUNT_TOO_LARGE when the input or converted total is too large',
      () {
        expect(() => _expense(total: maxAmount + 1), _code('AMOUNT_TOO_LARGE'));
        expect(
          () => _expense(
            total: maxAmount,
            from: 'INR',
            to: 'VND',
            rate: '300',
            paid: const {'A': maxAmount},
            shares: const {'B': maxAmount},
          ),
          _code('AMOUNT_TOO_LARGE'),
        );
      },
    );

    test('convertExpense throws UNKNOWN_MEMBER or DUPLICATE_MEMBER when members do not match the order', () {
      expect(() => _expense(paid: const {'Z': 10000}), _code('UNKNOWN_MEMBER', {'member': 'Z'}));
      expect(
        () => _expense(shares: const {'A': 5000, 'Y': 5000}),
        _code('UNKNOWN_MEMBER', {'member': 'Y'}),
      );
      expect(
        () => _expense(order: const ['A', 'B', 'A']),
        _code('DUPLICATE_MEMBER', {'member': 'A'}),
      );
    });

    test('convertExpense throws INVALID_WEIGHTS when every share is 0', () {
      expect(() => _expense(shares: const {'A': 0, 'B': 0}), _code('INVALID_WEIGHTS'));
      expect(() => _expense(paid: const {}), _code('INVALID_WEIGHTS'));
    });

    test('convertExpense result maps are read-only', () {
      final c = _expense();
      expect(() => c.paid['A'] = 1, throwsUnsupportedError);
      expect(() => c.shares['A'] = 1, throwsUnsupportedError);
    });
  });

  group('crossRate', () {
    test('crossRate divides EUR-based rates when either side is EUR', () {
      expect(crossRate({'IDR': '17500.25'}, 'IDR', 'EUR'), '0.0000571420');
      expect(crossRate({'IDR': '17500.25'}, 'EUR', 'IDR'), '17500.2500000000');
      expect(crossRate(const {}, 'EUR', 'EUR'), '1.0000000000');
      expect(crossRate({'USD': '1.0834'}, 'USD', 'EUR'), '0.9230201218');
    });

    test('crossRate rounds half away from zero at the 11th decimal', () {
      // 0.0000000001 / 2 = 0.00000000005 -> up; / 3 -> down. (Python prints these as 1E-10 / 0E-10.)
      expect(crossRate({'X': '2', 'Y': '0.0000000001'}, 'X', 'Y'), '0.0000000001');
      expect(crossRate({'X': '3', 'Y': '0.0000000001'}, 'X', 'Y'), '0.0000000000');
    });

    test('crossRate throws RATE_NOT_FOUND when a currency is missing from the rates', () {
      expect(
        () => crossRate({'INR': '97.12'}, 'USD', 'INR'),
        _code('RATE_NOT_FOUND', {'currency': 'USD'}),
      );
      expect(
        () => crossRate({'USD': '1.08'}, 'USD', 'INR'),
        _code('RATE_NOT_FOUND', {'currency': 'INR'}),
      );
    });

    test('crossRate throws INVALID_RATE when a stored rate is not positive', () {
      expect(() => crossRate({'INR': '0', 'USD': '1.08'}, 'USD', 'INR'), _code('INVALID_RATE'));
      expect(() => crossRate({'INR': 'n/a'}, 'EUR', 'INR'), _code('INVALID_RATE'));
    });
  });
}
