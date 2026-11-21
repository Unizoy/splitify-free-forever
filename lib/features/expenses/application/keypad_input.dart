import 'package:splitify/core/money/money_formatter.dart';

/// Keys of the amount keypad (05 §7): digits, `.`, ⌫ and `+ − × ÷` for quick sums like `450+120`.
enum KeypadKey {
  d0('0'),
  d1('1'),
  d2('2'),
  d3('3'),
  d4('4'),
  d5('5'),
  d6('6'),
  d7('7'),
  d8('8'),
  d9('9'),
  dot('.'),
  plus('+'),
  minus('−'),
  times('×'),
  divide('÷'),
  delete('');

  const KeypadKey(this.symbol);

  /// What the key adds to the expression (empty for [delete]).
  final String symbol;

  bool get isOperator =>
      this == KeypadKey.plus ||
      this == KeypadKey.minus ||
      this == KeypadKey.times ||
      this == KeypadKey.divide;

  bool get isDigit => index <= KeypadKey.d9.index;
}

/// Pure editing rules for the keypad text; the result is evaluated by `AmountExpression`.
abstract final class KeypadInput {
  /// Longest expression the keypad builds.
  static const maxLength = 32;

  static const _operators = {'+', '−', '×', '÷'};

  /// [text] after pressing [key], for a currency with [exponent] decimals. Keys that would make the
  /// text invalid (a second `.`, too many decimals, two operators in a row, a leading operator)
  /// are ignored or replace the last operator.
  static String apply(String text, KeypadKey key, int exponent) {
    if (key == KeypadKey.delete) {
      return text.isEmpty ? text : text.substring(0, text.length - 1);
    }
    final last = text.isEmpty ? '' : text[text.length - 1];
    final lastIsOp = _operators.contains(last);
    if (key.isOperator) {
      if (text.isEmpty) return text;
      if (lastIsOp) return text.substring(0, text.length - 1) + key.symbol;
      return _capped(text + key.symbol, text);
    }
    final number = currentNumber(text);
    if (key == KeypadKey.dot) {
      if (exponent == 0 || number.contains('.')) return text;
      return _capped(text + (number.isEmpty ? '0.' : '.'), text);
    }
    // Digit.
    final dot = number.indexOf('.');
    if (dot >= 0 && number.length - dot - 1 >= exponent) return text;
    if (number == '0') return text.substring(0, text.length - 1) + key.symbol;
    return _capped(text + key.symbol, text);
  }

  /// The number being typed at the end of [text] (after the last operator).
  static String currentNumber(String text) {
    var i = text.length;
    while (i > 0 && !_operators.contains(text[i - 1])) {
      i--;
    }
    return text.substring(i);
  }

  /// True when [text] holds an operator, so the evaluated result is worth showing.
  static bool hasOperator(String text) => text.split('').any(_operators.contains);

  /// [text] for display: Indian digit grouping per number and thin spaces around operators
  /// (`12000.5+300` → `12,000.5 + 300`).
  static String display(String text) {
    final out = StringBuffer();
    var number = StringBuffer();
    void flush() {
      final n = number.toString();
      if (n.isNotEmpty) {
        final dot = n.indexOf('.');
        final whole = dot < 0 ? n : n.substring(0, dot);
        final rest = dot < 0 ? '' : n.substring(dot);
        out.write((whole.isEmpty ? '' : MoneyFormatter.groupIndian(whole)) + rest);
      }
      number = StringBuffer();
    }

    for (final ch in text.split('')) {
      if (_operators.contains(ch)) {
        flush();
        out.write(' $ch ');
      } else {
        number.write(ch);
      }
    }
    flush();
    return out.toString();
  }

  static String _capped(String next, String previous) => next.length > maxLength ? previous : next;
}
