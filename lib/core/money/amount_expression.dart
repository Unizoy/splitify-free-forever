import 'package:decimal/decimal.dart';
import 'package:splitify/core/money/currencies.dart';

/// Result of [AmountExpression.evaluate]: [AmountOk] or one of the [AmountInputError]s.
sealed class AmountResult {
  const AmountResult();

  /// The minor units when valid, else null.
  int? get minorOrNull => switch (this) {
    AmountOk(:final minor) => minor,
    AmountInputError() => null,
  };
}

/// A valid amount: [minor] units, `1 … AmountExpression.maxMinor`.
final class AmountOk extends AmountResult {
  const AmountOk(this.minor);

  final int minor;

  @override
  String toString() => 'AmountOk($minor)';
}

/// Why keypad or pasted input is not a valid amount. [code] is stable; the UI maps it to text.
sealed class AmountInputError extends AmountResult {
  const AmountInputError();

  /// Stable error code, e.g. `AMOUNT_TOO_MANY_DECIMALS`.
  String get code;

  @override
  String toString() => code;
}

/// Nothing to evaluate (empty, or only spaces, commas and currency signs).
final class AmountEmpty extends AmountInputError {
  const AmountEmpty();

  @override
  String get code => 'AMOUNT_EMPTY';
}

/// Not an amount: an unknown character, a malformed number (`1.2.3`, `.`) or a misplaced
/// operator (`×5`, `5+×3`).
final class AmountInvalid extends AmountInputError {
  const AmountInvalid();

  @override
  String get code => 'AMOUNT_INVALID';
}

/// Ends with an operator (`450+`): still being typed.
final class AmountIncomplete extends AmountInputError {
  const AmountIncomplete();

  @override
  String get code => 'AMOUNT_INCOMPLETE';
}

/// A number has more decimals than the currency allows ([maxDecimals] = its exponent); for
/// exponent-0 currencies any `.` counts.
final class AmountTooManyDecimals extends AmountInputError {
  const AmountTooManyDecimals(this.maxDecimals);

  final int maxDecimals;

  @override
  String get code => 'AMOUNT_TOO_MANY_DECIMALS';
}

/// `÷ 0` somewhere in the expression.
final class AmountDivisionByZero extends AmountInputError {
  const AmountDivisionByZero();

  @override
  String get code => 'AMOUNT_DIVISION_BY_ZERO';
}

/// The result rounds to 0 or below (same code as the split engine's common error).
final class AmountNotPositive extends AmountInputError {
  const AmountNotPositive();

  @override
  String get code => 'AMOUNT_NOT_POSITIVE';
}

/// The result is above [maxMinor] units (same code as the split engine's common error).
final class AmountTooLarge extends AmountInputError {
  const AmountTooLarge(this.maxMinor);

  final int maxMinor;

  @override
  String get code => 'AMOUNT_TOO_LARGE';
}

enum _Op { plus, minus, times, divide }

/// Evaluates amount-keypad input (planning/05-money-engine.md §7) into integer minor units.
///
/// - Numbers: digits with at most one `.` (`12.5`, `.5`, `12.`), no more decimals than the
///   currency exponent (exponent 0: no `.` at all).
/// - Operators `+`, `-`/`−`, `×`/`*`, `÷`/`/`; `×` and `÷` bind tighter, then left to right.
///   One leading `+` or `-` is allowed (so a pasted `-500` reports [AmountNotPositive]).
/// - Pasting: whitespace, commas, invisible marks, currency signs, codes and symbols from the
///   table (`₹`, `INR`, `Rs.`, `CA$`) and a trailing Indian `/-` are ignored.
/// - Exact: operands are [Decimal]s and the expression is evaluated as exact fractions; the result
///   is rounded once, half away from zero (sign × floor(|v| + ½), as `convert` in §6), to the
///   currency exponent.
/// - Valid results are `1 … [maxMinor]`.
///
/// Checks run in this order, first failure wins: empty → characters → numbers (left to right) →
/// operator placement → division by zero → range.
abstract final class AmountExpression {
  /// Largest amount in minor units (§1 bounds).
  static const maxMinor = 999999999999;

  static final RegExp _ignorable = RegExp(r'[\s,​-‏⁠﻿]', unicode: true);
  static final RegExp _currencySign = RegExp(r'\p{Sc}', unicode: true);
  static final RegExp _allowed = RegExp(r'^[0-9.+\-−×*÷/]+$');
  static final RegExp _currencyWords = _buildCurrencyWords();

  /// Evaluates [input] for an amount in [currencyCode].
  static AmountResult evaluate(String input, String currencyCode) {
    final exponent = Currencies.exponentOf(currencyCode);
    final text = _clean(input);
    if (text.isEmpty) return const AmountEmpty();
    if (!_allowed.hasMatch(text)) return const AmountInvalid();

    // Tokens: optional leading sign, then number (operator number)*.
    final numbers = <Decimal>[];
    final ops = <_Op>[];
    final lead = _opOf(text[0]);
    final negate = lead == _Op.minus;
    var i = negate || lead == _Op.plus ? 1 : 0;
    if (i == text.length) return const AmountIncomplete();
    while (true) {
      final start = i;
      while (i < text.length && _opOf(text[i]) == null) {
        i++;
      }
      if (i == start) return const AmountInvalid();
      final literal = text.substring(start, i);
      final literalError = _checkLiteral(literal, exponent);
      if (literalError != null) return literalError;
      numbers.add(Decimal.parse(literal));
      if (i == text.length) break;
      ops.add(_opOf(text[i])!);
      i++;
      if (i == text.length) return const AmountIncomplete();
    }

    // Exact evaluation (Decimal → fraction); × and ÷ fold into the current term.
    var sum = Decimal.zero.toRational();
    var term = numbers.first.toRational();
    if (negate) term = -term;
    for (var k = 0; k < ops.length; k++) {
      final operand = numbers[k + 1];
      switch (ops[k]) {
        case _Op.times:
          term = term * operand.toRational();
        case _Op.divide:
          if (operand == Decimal.zero) return const AmountDivisionByZero();
          term = term / operand.toRational();
        case _Op.plus:
          sum += term;
          term = operand.toRational();
        case _Op.minus:
          sum += term;
          term = -operand.toRational();
      }
    }
    sum += term;

    // Round half away from zero to the exponent: sign × floor((2|n|·10^e + d) / 2d).
    final scaled = sum.numerator * BigInt.from(10).pow(exponent);
    final denominator = sum.denominator;
    final magnitude = (scaled.abs() * BigInt.two + denominator) ~/ (denominator * BigInt.two);
    final minor = scaled.isNegative ? -magnitude : magnitude;
    if (minor <= BigInt.zero) return const AmountNotPositive();
    if (minor > BigInt.from(maxMinor)) return const AmountTooLarge(maxMinor);
    return AmountOk(minor.toInt());
  }

  static String _clean(String input) {
    var text = input.replaceAll(_ignorable, '');
    text = text.replaceAll(_currencyWords, '');
    text = text.replaceAll(_currencySign, '');
    if (text.endsWith('/-')) text = text.substring(0, text.length - 2);
    return text;
  }

  /// Codes and symbols from the table (plus `Rs.`/`Rs`), longest first, any case.
  static RegExp _buildCurrencyWords() {
    final words = <String>{'Rs.', 'Rs'};
    for (final currency in Currencies.all.values) {
      words
        ..add(currency.code)
        ..add(currency.symbol);
    }
    final sorted = words.toList()..sort((a, b) => b.length.compareTo(a.length));
    return RegExp(sorted.map(RegExp.escape).join('|'), caseSensitive: false, unicode: true);
  }

  static _Op? _opOf(String char) => switch (char) {
    '+' => _Op.plus,
    '-' || '−' => _Op.minus,
    '×' || '*' => _Op.times,
    '÷' || '/' => _Op.divide,
    _ => null,
  };

  static AmountInputError? _checkLiteral(String literal, int exponent) {
    final dot = literal.indexOf('.');
    if (dot < 0) return null;
    if (literal.length == 1 || literal.indexOf('.', dot + 1) >= 0) return const AmountInvalid();
    if (exponent == 0 || literal.length - dot - 1 > exponent) {
      return AmountTooManyDecimals(exponent);
    }
    return null;
  }
}
