import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/expenses/application/keypad_input.dart';

String _press(String start, List<KeypadKey> keys, [int exponent = 2]) =>
    keys.fold(start, (t, k) => KeypadInput.apply(t, k, exponent));

void main() {
  group('KeypadKey', () {
    test('isDigit and isOperator', () {
      for (final k in KeypadKey.values) {
        final digit = k.index <= KeypadKey.d9.index;
        expect(k.isDigit, digit, reason: '$k');
      }
      expect(KeypadKey.plus.isOperator, isTrue);
      expect(KeypadKey.minus.isOperator, isTrue);
      expect(KeypadKey.times.isOperator, isTrue);
      expect(KeypadKey.divide.isOperator, isTrue);
      expect(KeypadKey.dot.isOperator, isFalse);
      expect(KeypadKey.delete.isOperator, isFalse);
      expect(KeypadKey.d5.isOperator, isFalse);
      expect(KeypadKey.dot.isDigit, isFalse);
      expect(KeypadKey.d5.symbol, '5');
    });
  });

  group('KeypadInput.apply', () {
    test('digits append', () {
      expect(_press('', [KeypadKey.d4, KeypadKey.d5, KeypadKey.d0]), '450');
    });

    test('leading zero is replaced by the next digit', () {
      expect(_press('', [KeypadKey.d0, KeypadKey.d7]), '7');
      expect(_press('5+', [KeypadKey.d0, KeypadKey.d3]), '5+3');
      expect(_press('0', [KeypadKey.d0]), '0');
    });

    test('dot once per number, 0. when the number is empty', () {
      expect(_press('', [KeypadKey.dot]), '0.');
      expect(_press('12', [KeypadKey.dot, KeypadKey.dot]), '12.');
      expect(_press('12+', [KeypadKey.dot]), '12+0.');
      expect(_press('1.5+2', [KeypadKey.dot]), '1.5+2.');
      expect(_press('1.5', [KeypadKey.dot]), '1.5');
    });

    test('dot ignored when the currency has no decimals', () {
      expect(_press('12', [KeypadKey.dot], 0), '12');
      expect(_press('', [KeypadKey.dot], 0), '');
    });

    test('decimals are capped at the exponent', () {
      expect(_press('1.', [KeypadKey.d2, KeypadKey.d5, KeypadKey.d9]), '1.25');
      expect(_press('1.', [KeypadKey.d2, KeypadKey.d5], 1), '1.2');
      expect(_press('1.234', [KeypadKey.d5], 3), '1.234');
      // The cap is per number.
      expect(_press('1.25+', [KeypadKey.d3, KeypadKey.d4, KeypadKey.d5]), '1.25+345');
    });

    test('operators ignored when empty, replace a trailing operator', () {
      expect(_press('', [KeypadKey.plus, KeypadKey.times]), '');
      expect(_press('5', [KeypadKey.plus]), '5+');
      expect(_press('5', [KeypadKey.plus, KeypadKey.minus]), '5−');
      expect(_press('5', [KeypadKey.times, KeypadKey.divide, KeypadKey.plus]), '5+');
      expect(_press('5', [KeypadKey.plus, KeypadKey.d3, KeypadKey.times]), '5+3×');
    });

    test('delete removes the last character, no-op when empty', () {
      expect(_press('12', [KeypadKey.delete]), '1');
      expect(_press('1', [KeypadKey.delete, KeypadKey.delete]), '');
      expect(_press('5+', [KeypadKey.delete]), '5');
    });

    test('maxLength caps digits, dots and operators', () {
      final full = '9' * KeypadInput.maxLength;
      expect(KeypadInput.apply(full, KeypadKey.d1, 2), full);
      expect(KeypadInput.apply(full, KeypadKey.plus, 2), full);
      final nearly = '${'9' * (KeypadInput.maxLength - 1)}';
      expect(KeypadInput.apply('${'9' * 10}+${'9' * 20}', KeypadKey.dot, 2).length, 32);
      expect(KeypadInput.apply(nearly, KeypadKey.d1, 2), '${nearly}1');
      expect(KeypadInput.apply('${'1' * 31}+', KeypadKey.d1, 2).length, 32);
      expect(KeypadInput.apply('${'1' * 15}+${'1' * 16}', KeypadKey.dot, 2).length, 32);
      expect(KeypadInput.apply(full, KeypadKey.dot, 2), full);
    });
  });

  group('KeypadInput helpers', () {
    test('currentNumber', () {
      expect(KeypadInput.currentNumber(''), '');
      expect(KeypadInput.currentNumber('12'), '12');
      expect(KeypadInput.currentNumber('12+3.5'), '3.5');
      expect(KeypadInput.currentNumber('12+'), '');
      expect(KeypadInput.currentNumber('1×2÷3−4'), '4');
    });

    test('hasOperator', () {
      expect(KeypadInput.hasOperator(''), isFalse);
      expect(KeypadInput.hasOperator('12.5'), isFalse);
      expect(KeypadInput.hasOperator('12+3'), isTrue);
      expect(KeypadInput.hasOperator('12÷'), isTrue);
    });

    test('display groups Indian style and spaces operators', () {
      expect(KeypadInput.display(''), '');
      expect(KeypadInput.display('120000.5+300'), '1,20,000.5 + 300');
      expect(KeypadInput.display('1234567'), '12,34,567');
      expect(KeypadInput.display('999'), '999');
      expect(KeypadInput.display('0.'), '0.');
      expect(KeypadInput.display('5+'), '5 + ');
      expect(KeypadInput.display('1000×2÷3−4'), '1,000 × 2 ÷ 3 − 4');
    });
  });
}
