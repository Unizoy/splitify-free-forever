/// Typing rules for the amount field of the one-screen editor (D-032): the phone's own number keyboard
/// replaced the custom keypad, so these rules decide what the field keeps. The kept text is evaluated by
/// `AmountExpression` (integer minor units, never a float).
abstract final class AmountInput {
  /// Most digits before the decimal point (`AmountExpression.maxMinor` is 999,999,999,999 minor units).
  static const maxWholeDigits = 12;

  static final RegExp _notAmount = RegExp('[^0-9.]');

  /// [text] as the field keeps it for a currency with [exponent] decimals, or null when the change is
  /// refused (the field then keeps its previous text). Pasted grouping commas, spaces and currency signs
  /// are dropped; a second `.`, more decimals than the currency has, a `.` for a currency without
  /// decimals and more than [maxWholeDigits] whole digits are refused.
  static String? accept(String text, int exponent) {
    final kept = text.replaceAll(_notAmount, '');
    final dot = kept.indexOf('.');
    if (dot >= 0) {
      if (exponent == 0) return null;
      if (kept.indexOf('.', dot + 1) >= 0) return null;
      if (kept.length - dot - 1 > exponent) return null;
    }
    final whole = dot < 0 ? kept : kept.substring(0, dot);
    if (whole.length > maxWholeDigits) return null;
    return kept;
  }
}
