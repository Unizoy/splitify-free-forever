import 'package:splitify/core/money/money.dart';

/// Typed split-editor values that are fixed-point integers (planning/05-money-engine.md §4): percentages
/// as basis points (2 decimals), shares as thousandths (3 decimals), exact and adjust amounts in minor
/// units (the currency exponent). Pure digit handling, no floating point.
abstract final class ScaledInput {
  static final RegExp _ignorable = RegExp(r'[\s,]');
  static final RegExp _number = RegExp(r'^(\d*)(?:\.(\d*))?$');

  /// Parses [text] (`33.33`, `1.5`, `-50`) into an integer scaled by 10^[decimals]. Empty text is 0;
  /// spaces and commas are ignored. Returns null for anything else: other characters, a lone `.`,
  /// more than [decimals] decimals, a sign when not [signed], or a magnitude above [maxAmount].
  static int? parse(String text, int decimals, {bool signed = false}) {
    var t = text.replaceAll(_ignorable, '');
    if (t.isEmpty) return 0;
    var negative = false;
    if (t.startsWith('-') || t.startsWith('−')) {
      if (!signed) return null;
      negative = true;
      t = t.substring(1);
    }
    final m = _number.firstMatch(t);
    if (m == null) return null;
    final whole = m[1]!;
    final fraction = m[2] ?? '';
    if (whole.isEmpty && fraction.isEmpty) return null;
    if (fraction.length > decimals) return null;
    final digits = (whole + fraction.padRight(decimals, '0')).replaceFirst(RegExp('^0+'), '');
    if (digits.length > 15) return null;
    final value = digits.isEmpty ? 0 : int.parse(digits);
    if (value > maxAmount) return null;
    return negative ? -value : value;
  }

  /// [value] scaled by 10^[decimals] as plain input text without trailing zeros:
  /// `format(3333, 2)` → `33.33`, `format(1500, 3)` → `1.5`, `format(-200, 2)` → `-2`.
  static String format(int value, int decimals) {
    final digits = value.abs().toString().padLeft(decimals + 1, '0');
    final whole = digits.substring(0, digits.length - decimals);
    final fraction = digits.substring(digits.length - decimals).replaceFirst(RegExp(r'0+$'), '');
    final sign = value < 0 ? '-' : '';
    return fraction.isEmpty ? '$sign$whole' : '$sign$whole.$fraction';
  }
}
