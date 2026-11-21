import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/scaled_input.dart';

void main() {
  group('ScaledInput.parse', () {
    test('scales typed numbers', () {
      expect(ScaledInput.parse('33.33', 2), 3333);
      expect(ScaledInput.parse('1.5', 3), 1500);
      expect(ScaledInput.parse('1.', 3), 1000);
      expect(ScaledInput.parse('.5', 2), 50);
      expect(ScaledInput.parse(' 1,200 ', 2), 120000);
      expect(ScaledInput.parse('007', 0), 7);
      expect(ScaledInput.parse('0', 2), 0);
      expect(ScaledInput.parse('', 2), 0);
    });

    test('signs only when allowed', () {
      expect(ScaledInput.parse('-50', 2, signed: true), -5000);
      expect(ScaledInput.parse('−2.5', 2, signed: true), -250);
      expect(ScaledInput.parse('-50', 2), isNull);
    });

    test('rejects malformed input', () {
      expect(ScaledInput.parse('.', 2), isNull);
      expect(ScaledInput.parse('1.2.3', 2), isNull);
      expect(ScaledInput.parse('abc', 2), isNull);
      expect(ScaledInput.parse('1.234', 2), isNull);
      expect(ScaledInput.parse('1234567890123456', 0), isNull);
      expect(ScaledInput.parse('9999999999999', 0), isNull);
    });
  });

  test('ScaledInput.format trims trailing zeros', () {
    expect(ScaledInput.format(3333, 2), '33.33');
    expect(ScaledInput.format(1500, 3), '1.5');
    expect(ScaledInput.format(1000, 3), '1');
    expect(ScaledInput.format(-200, 2), '-2');
    expect(ScaledInput.format(5, 2), '0.05');
    expect(ScaledInput.format(42, 0), '42');
  });
}
