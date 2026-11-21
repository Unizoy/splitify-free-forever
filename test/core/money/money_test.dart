import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_error.dart';

void main() {
  group('checkAmount', () {
    test('checkAmount accepts totals when they are within 1…maxAmount', () {
      checkAmount(1);
      checkAmount(maxAmount);
    });

    test('checkAmount throws AMOUNT_NOT_POSITIVE when the total is 0 or negative', () {
      expect(() => checkAmount(0), throwsA(isA<AmountNotPositive>()));
      expect(() => checkAmount(-5), throwsA(isA<AmountNotPositive>()));
    });

    test('checkAmount throws AMOUNT_TOO_LARGE when the total is above maxAmount', () {
      expect(maxAmount, 999999999999);
      expect(() => checkAmount(maxAmount + 1), throwsA(isA<AmountTooLarge>()));
    });
  });

  group('Money', () {
    const a = Money(10050, 'INR');
    const b = Money(2500, 'INR');
    const usd = Money(100, 'USD');

    test('Money adds, subtracts and negates when currencies match', () {
      expect(a + b, const Money(12550, 'INR'));
      expect(a - b, const Money(7550, 'INR'));
      expect(b - a, const Money(-7550, 'INR'));
      expect(-a, const Money(-10050, 'INR'));
      expect((-a).abs(), a);
    });

    test('Money reports zero, negative and positive', () {
      expect(const Money.zero('INR').isZero, isTrue);
      expect(const Money.zero('INR').currency, 'INR');
      expect(a.isZero, isFalse);
      expect((-a).isNegative, isTrue);
      expect(a.isNegative, isFalse);
      expect(a.isPositive, isTrue);
      expect(const Money.zero('INR').isPositive, isFalse);
    });

    test('Money compares when currencies match', () {
      expect(a.compareTo(b), greaterThan(0));
      expect(b.compareTo(a), lessThan(0));
      expect(a.compareTo(a), 0);
      expect(b < a, isTrue);
      expect(a <= a, isTrue);
      expect(a > b, isTrue);
      expect(a >= a, isTrue);
      expect(a < b, isFalse);
    });

    test('Money throws CURRENCY_MISMATCH when currencies differ', () {
      final mismatch = isA<CurrencyMismatch>()
          .having((e) => e.code, 'code', 'CURRENCY_MISMATCH')
          .having((e) => e.data, 'data', {'left': 'INR', 'right': 'USD'});
      expect(() => a + usd, throwsA(mismatch));
      expect(() => a - usd, throwsA(mismatch));
      expect(() => a.compareTo(usd), throwsA(mismatch));
      expect(() => a < usd, throwsA(mismatch));
    });

    test('Money equality uses minor units and currency', () {
      expect(a, const Money(10050, 'INR'));
      expect(a.hashCode, const Money(10050, 'INR').hashCode);
      expect(a == const Money(10050, 'USD'), isFalse);
      expect(a == const Money(10051, 'INR'), isFalse);
      expect(a.toString(), 'Money(10050 INR)');
    });
  });

  group('MoneyError', () {
    test('MoneyError codes and data match the oracle when each error is built', () {
      final cases = <MoneyError, (String, Map<String, Object>)>{
        const AmountNotPositive(): ('AMOUNT_NOT_POSITIVE', {}),
        const AmountTooLarge(): ('AMOUNT_TOO_LARGE', {}),
        const NoParticipants(): ('NO_PARTICIPANTS', {}),
        const SumMismatch(-300): ('SUM_MISMATCH', {'remaining': -300}),
        const NegativeShare(): ('NEGATIVE_SHARE', {}),
        const PercentSumMismatch(25): ('PERCENT_SUM_MISMATCH', {'remaining_bps': 25}),
        const PercentOutOfRange(): ('PERCENT_OUT_OF_RANGE', {}),
        const NoShares(): ('NO_SHARES', {}),
        const AdjustmentsExceedTotal(200): ('ADJUSTMENTS_EXCEED_TOTAL', {'over': 200}),
        const UnknownSplit(): ('UNKNOWN_SPLIT', {}),
        const PayersSumMismatch(1000): ('PAYERS_SUM_MISMATCH', {'remaining': 1000}),
        const InvalidPayers(): ('INVALID_PAYERS', {}),
        const InvalidWeights(): ('INVALID_WEIGHTS', {}),
        const NetsDoNotSumToZero(): ('NETS_DO_NOT_SUM_TO_ZERO', {}),
        const InvalidRate(): ('INVALID_RATE', {}),
        const RateNotFound('XYZ'): ('RATE_NOT_FOUND', {'currency': 'XYZ'}),
        const CurrencyMismatch('INR', 'USD'): (
          'CURRENCY_MISMATCH',
          {'left': 'INR', 'right': 'USD'},
        ),
        const UnknownMember('Z'): ('UNKNOWN_MEMBER', {'member': 'Z'}),
        const DuplicateMember('A'): ('DUPLICATE_MEMBER', {'member': 'A'}),
        const InvalidPayment('A'): ('INVALID_PAYMENT', {'member': 'A'}),
      };
      expect(cases, hasLength(20));
      cases.forEach((error, expected) {
        expect(error, isA<Exception>());
        expect(error.code, expected.$1);
        expect(error.data, expected.$2);
      });
    });

    test('MoneyError toString shows the code and any data', () {
      expect(const NoShares().toString(), 'MoneyError(NO_SHARES)');
      expect(const SumMismatch(5).toString(), 'MoneyError(SUM_MISMATCH, {remaining: 5})');
    });
  });

  test('Money.zero built at runtime is zero in its currency', () {
    // Runtime (non-const) call so coverage counts the constructor line.
    final currency = ['INR'].first;
    final zero = Money.zero(currency);
    expect(zero.isZero, isTrue);
    expect(zero, Money(0, currency));
  });
}
