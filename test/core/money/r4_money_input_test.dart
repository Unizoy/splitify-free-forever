// R4 robustness: money text in and out (planning/05-money-engine.md §7). Seeded random loops:
//
// TC-R4-MI-01  Indian grouping: shape, digits kept, intl's en_IN agrees, every table currency, int64 edges
// TC-R4-MI-02  display text parses back to the same minor units (all 160 currencies, list and detail styles)
// TC-R4-MI-03  amount keypad / pasted text: never throws, exact oracle for a ∘ b, typed Indian grouping,
//              unicode digits and garbage rejected, long input stays fast
// TC-R4-MI-04  split-editor inputs (ScaledInput): never throws, format → parse round trip, bounds
// TC-R4-MI-05  amount-field text the app writes (editor, settle all) reads back to the same amount
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:splitify/core/money/amount_expression.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/core/money/scaled_input.dart';
import 'package:splitify/features/payments/application/settle_all_controller.dart'
    show owedFieldText;

const int _intMax = 9223372036854775807;
const int _intMin = -9223372036854775807 - 1;

int _upTo(Random r, int max) {
  if (max < (1 << 32)) return r.nextInt(max + 1);
  final v = (r.nextInt(1 << 30) << 32) | r.nextInt(1 << 32);
  return v % (max + 1);
}

/// 1 … [max], log-uniform.
int _amount(Random r, [int max = maxAmount]) {
  var hi = 1;
  for (var d = r.nextInt(13); d > 0; d--) {
    hi *= 10;
  }
  return 1 + _upTo(r, (hi < max ? hi : max) - 1);
}

/// Any int64, log-uniform, either sign, edges included.
int _anyInt(Random r) => switch (r.nextInt(20)) {
  0 => _intMax,
  1 => _intMin,
  2 => 0,
  _ => (r.nextBool() ? 1 : -1) * (r.nextInt(4) == 0 ? _upTo(r, 1 << 62) : _amount(r)),
};

final _grouped = RegExp(r'^(\d{1,3}|\d{1,2}(,\d{2})*,\d{3})$');

BigInt _roundHalfAway(BigInt n, BigInt d) {
  final q = n.abs() ~/ d;
  final up = (n.abs() - q * d) * BigInt.two >= d ? q + BigInt.one : q;
  return n.isNegative ? -up : up;
}

/// Digits of a display amount with sign, unit and grouping taken off, as minor units.
BigInt _digitsBack(String text, String unit, int exponent, {required bool hidden}) {
  var t = text;
  if (t.startsWith(MoneyFormatter.minusSign) || t.startsWith(MoneyFormatter.plusSign)) {
    t = t.substring(1);
  }
  expect(t.startsWith(unit), isTrue, reason: '"$text" should start with "$unit"');
  t = t.substring(unit.length).replaceFirst(MoneyFormatter.unitGap, '');
  final dot = t.indexOf('.');
  final whole = dot < 0 ? t : t.substring(0, dot);
  expect(_grouped.hasMatch(whole), isTrue, reason: '"$text": "$whole" is not Indian-grouped');
  final fraction = dot < 0 ? '' : t.substring(dot + 1);
  expect(fraction.length, hidden ? 0 : exponent, reason: '"$text" fraction');
  return BigInt.parse(whole.replaceAll(',', '') + fraction.padRight(exponent, '0'));
}

/// a ∘ b written for the keypad, with the exact rational result (numerator, denominator).
({String text, BigInt? n, BigInt? d}) _binary(Random r, int exponent) {
  String operand() {
    final whole = '${_upTo(r, r.nextBool() ? 999 : 99999999)}';
    if (exponent == 0 || r.nextBool()) return whole;
    final decimals = 1 + r.nextInt(exponent);
    return '$whole.${[for (var i = 0; i < decimals; i++) r.nextInt(10)].join()}';
  }

  (BigInt, BigInt) frac(String s) {
    final dot = s.indexOf('.');
    if (dot < 0) return (BigInt.parse(s), BigInt.one);
    final f = s.substring(dot + 1);
    return (BigInt.parse(s.substring(0, dot) + f), BigInt.from(10).pow(f.length));
  }

  final a = operand();
  final b = operand();
  final op = '+-×÷*/−'[r.nextInt(7)];
  final (an, ad) = frac(a);
  final (bn, bd) = frac(b);
  final (BigInt? n, BigInt? d) = switch (op) {
    '+' => (an * bd + bn * ad, ad * bd),
    '-' || '−' => (an * bd - bn * ad, ad * bd),
    '×' || '*' => (an * bn, ad * bd),
    _ => bn == BigInt.zero ? (null, null) : (an * bd, ad * bn),
  };
  return (text: '$a$op$b', n: n, d: d);
}

void main() {
  // TC-R4-MI-01
  group('Indian grouping', () {
    test('examples: lakh and crore grouping, negatives, 0- and 3-decimal currencies', () {
      expect(MoneyFormatter.detail.format(10000000, 'INR'), '₹1,00,000.00');
      expect(MoneyFormatter.list.format(10000000, 'INR'), '₹1,00,000');
      expect(MoneyFormatter.detail.format(1234567890, 'INR'), '₹1,23,45,678.90');
      expect(MoneyFormatter.list.format(1234567890, 'INR'), '₹1,23,45,678.90');
      expect(MoneyFormatter.detail.format(-10000000, 'INR'), '−₹1,00,000.00');
      expect(MoneyFormatter.list.format(1234567, 'JPY'), '¥12,34,567');
      expect(MoneyFormatter.detail.format(1234567, 'KWD'), 'KWD\u00a01,234.567');
      expect(MoneyFormatter.list.format(1234000, 'KWD'), 'KWD\u00a01,234');
      expect(MoneyFormatter.detail.format(5, 'BHD'), 'BHD\u00a00.005');
      expect(MoneyFormatter.detail.format(1, 'INR'), '₹0.01');
      expect(MoneyFormatter.plain(-1, 'INR'), '-0.01');
      expect(MoneyFormatter.plain(maxAmount, 'INR'), '9999999999.99');
    });

    test('groupIndian keeps every digit and has the lakh/crore shape, up to 19 digits', () {
      final r = Random(4201);
      for (var k = 0; k < 5000; k++) {
        final len = 1 + r.nextInt(19);
        final digits = [
          for (var i = 0; i < len; i++)
            if (i == 0) 1 + r.nextInt(9) else r.nextInt(10),
        ].join();
        final g = MoneyFormatter.groupIndian(digits);
        expect(_grouped.hasMatch(g), isTrue, reason: digits);
        expect(g.replaceAll(',', ''), digits);
      }
    });

    test("intl's en_IN pattern agrees for random amounts below 10^15", () {
      final intl = NumberFormat('#,##,##0', 'en_IN');
      final r = Random(4202);
      for (var k = 0; k < 3000; k++) {
        final v = _upTo(r, 999999999999999);
        expect(MoneyFormatter.groupIndian('$v'), intl.format(v), reason: '$v');
      }
    });
  });

  // TC-R4-MI-02
  group('display text parses back', () {
    test('every table currency, any int64, detail and list styles, all sign modes', () {
      final r = Random(4203);
      final codes = Currencies.all.keys.toList();
      const styles = [
        MoneyFormatter.detail,
        MoneyFormatter.list,
        MoneyFormatter(sign: MoneySign.always),
        MoneyFormatter(sign: MoneySign.never, hideZeroFraction: true),
        MoneyFormatter(unit: MoneyUnit.code),
      ];
      for (var k = 0; k < 8000; k++) {
        final code = codes[k % codes.length];
        final c = Currencies.all[code]!;
        final minor = _anyInt(r);
        final style = styles[r.nextInt(styles.length)];
        final text = style.format(minor, code);
        final unit = style.unit == MoneyUnit.code ? c.code : c.symbol;
        final scale = BigInt.from(c.minorPerMajor);
        final magnitude = BigInt.from(minor).abs();
        final hidden =
            c.exponent == 0 || (style.hideZeroFraction && magnitude % scale == BigInt.zero);
        final back = _digitsBack(text, unit, c.exponent, hidden: hidden && c.exponent > 0);
        expect(back, magnitude, reason: '$minor $code → "$text"');
        final negative = text.startsWith(MoneyFormatter.minusSign);
        expect(negative, minor < 0 && style.sign != MoneySign.never, reason: text);
        expect(
          text.startsWith(MoneyFormatter.plusSign),
          style.sign == MoneySign.always && minor > 0,
        );
        // Machine text: no grouping, ASCII minus, parses back exactly.
        final plain = MoneyFormatter.plain(minor, code);
        expect(plain.contains(','), isFalse);
        if (minor >= -maxAmount && minor <= maxAmount) {
          expect(ScaledInput.parse(plain, c.exponent, signed: true), minor, reason: plain);
        }
      }
    });
  });

  // TC-R4-MI-03
  group('amount keypad and pasted text', () {
    test('random text never throws, is fast, and a valid result is 1 … maxMinor', () {
      final r = Random(4204);
      const alphabet = [
        '0',
        '1',
        '2',
        '5',
        '9',
        '.',
        ',',
        ' ',
        '+',
        '-',
        '−',
        '×',
        '*',
        '÷',
        '/',
        '₹',
        r'$',
        '€', //
        'Rs.',
        'INR',
        'usd',
        'e',
        'E',
        'x',
        '(',
        ')',
        '%',
        '=',
        '/-',
        '\u00a0',
        '\u200b',
        '\u2066', //
        '१',
        '२',
        '٣',
        '٫',
        '０',
        '５',
        '🎉',
        '👨\u200d👩\u200d👧',
        'ا',
        'ש',
        '\n',
        '\t',
        '\u0000',
        '\ufeff', //
      ];
      final codes = ['INR', 'JPY', 'KWD', 'USD', 'VND', 'BHD', 'XYZ'];
      final watch = Stopwatch()..start();
      var ok = 0;
      for (var k = 0; k < 20000; k++) {
        final text = [for (var i = 0; i < r.nextInt(14); i++) alphabet[r.nextInt(alphabet.length)]]
            .join();
        final code = codes[r.nextInt(codes.length)];
        final AmountResult res;
        try {
          res = AmountExpression.evaluate(text, code);
        } on Object catch (e) {
          fail('"$text" ($code) threw $e');
        }
        if (res case AmountOk(:final minor)) {
          expect(minor, inInclusiveRange(1, AmountExpression.maxMinor), reason: '"$text"');
          ok++;
        } else {
          expect(res.minorOrNull, isNull);
        }
      }
      expect(ok, greaterThan(500));
      expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
    });

    test('a ∘ b equals the exact result rounded once, half away from zero (0-, 2-, 3-decimal currencies)', () {
      final r = Random(4205);
      for (final code in ['INR', 'JPY', 'KWD', 'BHD', 'VND', 'USD']) {
        final e = Currencies.exponentOf(code);
        for (var k = 0; k < 3000; k++) {
          final c = _binary(r, e);
          final res = AmountExpression.evaluate(c.text, code);
          final reason = '"${c.text}" $code';
          if (c.n == null) {
            expect(res, isA<AmountDivisionByZero>(), reason: reason);
            continue;
          }
          final minor = _roundHalfAway(c.n! * BigInt.from(10).pow(e), c.d!);
          if (minor <= BigInt.zero) {
            expect(res, isA<AmountNotPositive>(), reason: reason);
          } else if (minor > BigInt.from(AmountExpression.maxMinor)) {
            expect(res, isA<AmountTooLarge>(), reason: reason);
          } else {
            expect(res.minorOrNull, minor.toInt(), reason: reason);
          }
        }
      }
    });

    test('typed and pasted forms people use', () {
      int? inr(String s) => AmountExpression.evaluate(s, 'INR').minorOrNull;
      expect(inr('1,00,000.50'), 10000050);
      expect(inr('1 00 000'), 10000000);
      expect(inr('₹ 1,200/-'), 120000);
      expect(inr('Rs.500'), 50000);
      expect(inr('rs 500'), 50000);
      expect(inr('INR 1,234.5'), 123450);
      expect(inr('+500'), 50000);
      expect(inr('12.'), 1200);
      expect(inr('.5'), 50);
      expect(inr('0.005'), isNull);
      expect(inr('9999999999.99'), maxAmount);
      expect(AmountExpression.evaluate('9999999999.991', 'INR'), isA<AmountTooManyDecimals>());
      expect(AmountExpression.evaluate('10000000000', 'INR'), isA<AmountTooLarge>());
      expect(AmountExpression.evaluate('9223372036854775807', 'INR'), isA<AmountTooLarge>());
      expect(AmountExpression.evaluate('99999999999999999999999999', 'JPY'), isA<AmountTooLarge>());
      expect(AmountExpression.evaluate('--5', 'INR'), isA<AmountInvalid>());
      expect(AmountExpression.evaluate('5..0', 'INR'), isA<AmountInvalid>());
      expect(AmountExpression.evaluate('1.234,56', 'INR'), isA<AmountTooManyDecimals>());
      expect(AmountExpression.evaluate('1e5', 'INR'), isA<AmountInvalid>());
      expect(AmountExpression.evaluate('12.5', 'JPY'), isA<AmountTooManyDecimals>());
      expect(AmountExpression.evaluate('1.2345', 'KWD'), isA<AmountTooManyDecimals>());
      expect(AmountExpression.evaluate('1.234', 'KWD').minorOrNull, 1234);
      expect(AmountExpression.evaluate('', 'INR'), isA<AmountEmpty>());
      expect(AmountExpression.evaluate('₹ , /-', 'INR'), isA<AmountEmpty>());
      expect(AmountExpression.evaluate('-500', 'INR'), isA<AmountNotPositive>());
      expect(AmountExpression.evaluate('0', 'INR'), isA<AmountNotPositive>());
      expect(AmountExpression.evaluate('5÷0', 'INR'), isA<AmountDivisionByZero>());
      expect(AmountExpression.evaluate('450+', 'INR'), isA<AmountIncomplete>());
    });

    test('unicode digits (Devanagari, Arabic-Indic, full-width) are refused, never misread', () {
      for (final s in ['१२३', '٣٤٥', '１２３', '12३', '٥٠٠٫٥٠', '５００']) {
        expect(AmountExpression.evaluate(s, 'INR'), isA<AmountInvalid>(), reason: s);
        expect(ScaledInput.parse(s, 2), isNull, reason: s);
      }
    });

    test('long input: 10,000 digits, 5,000 terms, 300 divisions all answer quickly', () {
      final watch = Stopwatch()..start();
      expect(AmountExpression.evaluate('9' * 10000, 'INR'), isA<AmountTooLarge>());
      expect(
        AmountExpression.evaluate(List.filled(5000, '1').join('+'), 'INR').minorOrNull,
        500000,
      );
      final thirds = '1${'÷3' * 300}${'×3' * 300}';
      expect(AmountExpression.evaluate(thirds, 'INR').minorOrNull, 100);
      expect(AmountExpression.evaluate('${'9' * 2000}÷${'9' * 2000}', 'KWD').minorOrNull, 1000);
      expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
    });
  });

  // TC-R4-MI-04
  group('split-editor inputs', () {
    test('format → parse round trip for 0–3 decimals, signed, up to ±maxAmount', () {
      final r = Random(4206);
      for (var k = 0; k < 10000; k++) {
        final d = r.nextInt(4);
        final v = (r.nextBool() ? -1 : 1) * (r.nextInt(10) == 0 ? 0 : _amount(r));
        final text = ScaledInput.format(v, d);
        expect(ScaledInput.parse(text, d, signed: true), v, reason: '$v at $d → "$text"');
        if (v >= 0) expect(ScaledInput.parse(text, d), v);
        if (v < 0) expect(ScaledInput.parse(text, d), isNull, reason: 'a sign when not signed');
      }
    });

    test('random text never throws and never answers above maxAmount', () {
      final r = Random(4207);
      const alphabet = [
        '0',
        '1',
        '9',
        '.',
        ',',
        ' ',
        '-',
        '−',
        '+',
        'e',
        '१',
        '٫',
        '\u00a0',
        '🎉',
        'a',
      ];
      for (var k = 0; k < 20000; k++) {
        final text = [for (var i = 0; i < r.nextInt(20); i++) alphabet[r.nextInt(alphabet.length)]]
            .join();
        final d = r.nextInt(4);
        final int? v;
        try {
          v = ScaledInput.parse(text, d, signed: r.nextBool());
        } on Object catch (e) {
          fail('"$text" threw $e');
        }
        if (v != null) expect(v.abs(), lessThanOrEqualTo(maxAmount), reason: '"$text"');
      }
      expect(ScaledInput.parse('000123.40', 2), 12340);
      expect(ScaledInput.parse('1,00,000', 2), 10000000);
      expect(ScaledInput.parse('10000000000', 2), isNull);
      expect(ScaledInput.parse('1.2345', 3), isNull);
      expect(ScaledInput.parse('.', 2), isNull);
      expect(ScaledInput.parse('−5', 2, signed: true), -500);
      expect(ScaledInput.parse('9' * 40, 0), isNull);
    });
  });

  // TC-R4-MI-05
  group('amount-field text the app writes', () {
    test(
      'editor and settle-all field text read back to the same minor units in every currency',
      () {
        final r = Random(4208);
        final codes = Currencies.all.keys.toList();
        for (var k = 0; k < 8000; k++) {
          final code = codes[k % codes.length];
          final e = Currencies.exponentOf(code);
          final minor = _amount(r);
          final editor = ScaledInput.format(minor, e);
          expect(
            AmountExpression.evaluate(editor, code).minorOrNull,
            minor,
            reason: '$code "$editor"',
          );
          final owed = owedFieldText(minor, code);
          expect(AmountExpression.evaluate(owed, code).minorOrNull, minor, reason: '$code "$owed"');
          final plain = MoneyFormatter.plain(minor, code);
          expect(
            AmountExpression.evaluate(plain, code).minorOrNull,
            minor,
            reason: '$code "$plain"',
          );
          // What the formatter shows, pasted back into the keypad, is the same amount.
          final shown = MoneyFormatter.detail.format(minor, code);
          expect(
            AmountExpression.evaluate(shown, code).minorOrNull,
            minor,
            reason: '$code "$shown"',
          );
        }
      },
    );
  });
}
