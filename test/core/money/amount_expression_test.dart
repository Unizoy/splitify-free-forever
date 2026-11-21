// AmountExpression (planning/05-money-engine.md §7; phase 03 task T5). No catalog id.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/amount_expression.dart';

AmountResult _eval(String input, [String currency = 'INR']) =>
    AmountExpression.evaluate(input, currency);

/// Expects [input] to evaluate to [minor] units.
void _ok(String input, int minor, [String currency = 'INR']) {
  final result = _eval(input, currency);
  expect(result, isA<AmountOk>(), reason: '"$input" $currency gave $result');
  expect(result.minorOrNull, minor, reason: '"$input" $currency');
}

/// Expects [input] to fail with error type [T].
void _fails<T extends AmountInputError>(String input, [String currency = 'INR']) {
  final result = _eval(input, currency);
  expect(result, isA<T>(), reason: '"$input" $currency gave $result');
  expect(result.minorOrNull, isNull);
}

void main() {
  group('numbers', () {
    test('whole and decimal rupees', () {
      _ok('450', 45000);
      _ok('12.5', 1250);
      _ok('12.50', 1250);
      _ok('.5', 50);
      _ok('12.', 1200);
      _ok('0.01', 1);
      _ok('007', 700);
    });

    test('unknown currency uses the ISO exponent rule', () {
      _ok('1.25', 125, 'XYZ');
    });
  });

  group('operators', () {
    test('+ − × ÷ and ASCII aliases', () {
      _ok('450+120', 57000);
      _ok('450 + 120', 57000);
      _ok('500−120', 38000);
      _ok('500-120', 38000);
      _ok('12×3', 3600);
      _ok('12*3', 3600);
      _ok('90÷4', 2250);
      _ok('90/4', 2250);
    });

    test('× and ÷ before + and −, then left to right', () {
      _ok('2+3×4', 1400);
      _ok('10−2×3', 400);
      _ok('100÷4+5', 3000);
      _ok('100÷2÷5', 1000);
      _ok('10−3−2', 500);
      _ok('5−10+20', 1500);
      _ok('2×3+4×5−6÷3', 2400);
    });

    test('one leading sign', () {
      _ok('+5', 500);
      _ok('−5+20', 1500);
      _ok('-5×2+20', 1000);
    });
  });

  group('rounding: exact, once, half away from zero', () {
    test('to paise', () {
      _ok('100÷3', 3333);
      _ok('200÷3', 6667);
      _ok('0.01÷2', 1);
      _ok('0.03÷2', 2);
      _ok('0.05÷2', 3);
      _ok('100÷8', 1250);
    });

    test('no drift through ÷ then ×', () {
      _ok('100÷3×3', 10000);
      _ok('0.01÷3×1.5', 1);
      _ok('1÷7×7', 100);
    });

    test('exponent 0 (JPY)', () {
      _ok('1200', 1200, 'JPY');
      _ok('1000÷3', 333, 'JPY');
      _ok('500÷3', 167, 'JPY');
      _ok('5÷2', 3, 'JPY');
    });

    test('exponent 3 (KWD)', () {
      _ok('1.234', 1234, 'KWD');
      _ok('10÷3', 3333, 'KWD');
      _ok('0.001÷2', 1, 'KWD');
    });
  });

  group('pasting', () {
    test('ignores commas, spaces, invisible marks and currency signs', () {
      _ok('₹1,00,000.50', 10000050);
      _ok(' 1 200 ', 120000);
      _ok('1 000', 100000);
      _ok('1 000', 100000);
      _ok('​500‎', 50000);
      _ok('₹ 450 + ₹ 120', 57000);
      _ok('¢5', 500);
    });

    test('ignores currency codes and letter symbols, any case', () {
      _ok('INR 1,200', 120000);
      _ok('inr1200', 120000);
      _ok('Rs. 500', 50000);
      _ok('rs500', 50000);
      _ok(r'$12.34', 1234, 'USD');
      _ok(r'CA$ 5', 500, 'CAD');
      _ok('AED 50', 5000, 'AED');
      _ok('Rp 1,000', 100000, 'IDR');
      _ok('zł5', 500, 'PLN');
      _ok('€ 5', 500, 'EUR');
    });

    test('ignores a trailing Indian /-', () {
      _ok('Rs. 500/-', 50000);
      _ok('₹1,200/-', 120000);
    });
  });

  group('errors', () {
    test('codes are stable', () {
      const errors = <AmountInputError, String>{
        AmountEmpty(): 'AMOUNT_EMPTY',
        AmountInvalid(): 'AMOUNT_INVALID',
        AmountIncomplete(): 'AMOUNT_INCOMPLETE',
        AmountTooManyDecimals(2): 'AMOUNT_TOO_MANY_DECIMALS',
        AmountDivisionByZero(): 'AMOUNT_DIVISION_BY_ZERO',
        AmountNotPositive(): 'AMOUNT_NOT_POSITIVE',
        AmountTooLarge(AmountExpression.maxMinor): 'AMOUNT_TOO_LARGE',
      };
      errors.forEach((error, code) {
        expect(error.code, code);
        expect(error.toString(), code);
      });
    });

    test('empty input', () {
      _fails<AmountEmpty>('');
      _fails<AmountEmpty>('   ');
      _fails<AmountEmpty>(',,');
      _fails<AmountEmpty>('₹');
      _fails<AmountEmpty>('INR');
    });

    test('invalid characters, numbers and operator placement', () {
      _fails<AmountInvalid>('abc');
      _fails<AmountInvalid>('12a');
      _fails<AmountInvalid>('1e5');
      _fails<AmountInvalid>('(1+2)');
      _fails<AmountInvalid>('5%');
      _fails<AmountInvalid>('1.2.3');
      _fails<AmountInvalid>('.');
      _fails<AmountInvalid>('5+.');
      _fails<AmountInvalid>('×5');
      _fails<AmountInvalid>('÷5');
      _fails<AmountInvalid>('5+×3');
      _fails<AmountInvalid>('5++3');
      _fails<AmountInvalid>('--5');
      _fails<AmountInvalid>('1.2.3', 'JPY');
    });

    test('ends with an operator', () {
      _fails<AmountIncomplete>('450+');
      _fails<AmountIncomplete>('5×');
      _fails<AmountIncomplete>('−');
      _fails<AmountIncomplete>('+');
      _fails<AmountIncomplete>('₹450 −');
    });

    test('more decimals than the exponent allows, in any operand', () {
      final rupees = _eval('1.234');
      expect(rupees, isA<AmountTooManyDecimals>());
      expect((rupees as AmountTooManyDecimals).maxDecimals, 2);
      _fails<AmountTooManyDecimals>('1.23+4.567');
      _fails<AmountTooManyDecimals>('0.004');
      _fails<AmountTooManyDecimals>('1.2345', 'KWD');

      final yen = _eval('1.5', 'JPY');
      expect((yen as AmountTooManyDecimals).maxDecimals, 0);
      _fails<AmountTooManyDecimals>('12.', 'JPY');
      _fails<AmountTooManyDecimals>('.5', 'JPY');
    });

    test('division by zero', () {
      _fails<AmountDivisionByZero>('5÷0');
      _fails<AmountDivisionByZero>('5/0.00');
      _fails<AmountDivisionByZero>('5÷0×2');
      _fails<AmountDivisionByZero>('5÷0−10');
    });

    test('zero or negative results', () {
      _fails<AmountNotPositive>('0');
      _fails<AmountNotPositive>('0.00');
      _fails<AmountNotPositive>('5−5');
      _fails<AmountNotPositive>('100−200');
      _fails<AmountNotPositive>('−500');
      _fails<AmountNotPositive>('0.01÷3');
      _fails<AmountNotPositive>('1÷1000');
      _fails<AmountNotPositive>('−99999999999999999999');
      _fails<AmountNotPositive>('0×5', 'JPY');
    });

    test('above 999,999,999,999 minor units', () {
      expect(AmountExpression.maxMinor, 999999999999);
      _ok('9999999999.99', 999999999999);
      _ok('9,99,99,99,999.99', 999999999999);
      _ok('999999999999', 999999999999, 'JPY');
      final big = _eval('10000000000');
      expect(big, isA<AmountTooLarge>());
      expect((big as AmountTooLarge).maxMinor, 999999999999);
      _fails<AmountTooLarge>('1000000000000', 'JPY');
      _fails<AmountTooLarge>('9999999999.995÷1', 'KWD');
      _fails<AmountTooLarge>('99999999999999999999×99999999999');
    });

    test('first failure wins: numbers before division by zero, that before range', () {
      _fails<AmountTooManyDecimals>('1.234÷0');
      _fails<AmountInvalid>('1.2.3÷0');
      _fails<AmountDivisionByZero>('0÷0');
    });
  });

  group('AmountResult', () {
    test('AmountOk exposes minor units', () {
      const ok = AmountOk(57000);
      expect(ok.minor, 57000);
      expect(ok.minorOrNull, 57000);
      expect(ok.toString(), 'AmountOk(57000)');
    });

    test('errors have no minor units', () {
      expect(const AmountEmpty().minorOrNull, isNull);
    });
  });
}
