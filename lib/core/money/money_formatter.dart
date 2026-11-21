import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/currency.dart';

/// How [MoneyFormatter] shows the sign of an amount.
enum MoneySign {
  /// `−₹500` for negatives; positives and zero have no sign (default).
  negativeOnly,

  /// `+₹500` and `−₹500`; zero has no sign.
  always,

  /// Magnitude only (`₹500` for both): the caller shows the direction with colour or words.
  never,
}

/// What [MoneyFormatter] puts in front of the number.
enum MoneyUnit {
  /// The table symbol: `₹1,200`, `CA$5`; currencies without a common symbol show their code
  /// (`AED 50`).
  symbol,

  /// Always the ISO code: `INR 1,200`.
  code,

  /// The number only: `1,200`.
  none,
}

/// Turns integer minor units into display text (planning/05-money-engine.md §7).
///
/// - Indian (`en_IN`) grouping for every currency: last three digits, then groups of two
///   (`₹1,00,000.50`). Computed from the decimal digits of the `int`, so no binary floating point
///   is involved; it matches `intl`'s `en_IN` pattern (checked in tests).
/// - The sign goes before the unit. Negative amounts use U+2212 MINUS SIGN (`−₹500`), the same
///   character as `MoneyTone.sign` in the UI; [plain] uses ASCII `-` for machines.
/// - A unit that ends in a letter (`AED`, `Rp`, `zł`) is followed by a no-break space
///   (`AED 1,200`); symbols such as `₹`, `$`, `CA$` touch the number.
/// - [hideZeroFraction] (lists and cards) drops an all-zero fraction (`₹1,200`); a non-zero
///   fraction is always shown in full (`₹1,200.50`). Detail screens use full precision.
///
/// Returns text only: labels around the amount ("You owe …") belong to the UI's l10n files.
final class MoneyFormatter {
  const MoneyFormatter({
    this.hideZeroFraction = false,
    this.sign = MoneySign.negativeOnly,
    this.unit = MoneyUnit.symbol,
  });

  /// Full precision, for detail screens: `₹1,200.00`.
  static const detail = MoneyFormatter();

  /// Whole amounts without `.00`, for lists and cards: `₹1,200`, `₹1,200.50`.
  static const list = MoneyFormatter(hideZeroFraction: true);

  /// U+2212 MINUS SIGN, used before negative display amounts.
  static const minusSign = '−';

  /// Used before positive amounts when [sign] is [MoneySign.always].
  static const plusSign = '+';

  /// U+00A0 NO-BREAK SPACE between a letter unit and the number.
  static const unitGap = ' ';

  static final RegExp _endsWithLetter = RegExp(r'\p{L}$', unicode: true);

  /// Hide an all-zero fraction (`₹1,200` instead of `₹1,200.00`).
  final bool hideZeroFraction;

  /// How the sign is shown.
  final MoneySign sign;

  /// What goes in front of the number.
  final MoneyUnit unit;

  /// Formats [minor] units of [currencyCode]; unknown codes use the ISO exponent rule and the code.
  String format(int minor, String currencyCode) =>
      formatCurrency(minor, Currencies.of(currencyCode));

  /// Formats [minor] units of [currency].
  String formatCurrency(int minor, Currency currency) {
    final (:negative, :digits) = _digitsOf(minor);
    final fullUnit = switch (unit) {
      MoneyUnit.symbol => currency.symbol,
      MoneyUnit.code => currency.code,
      MoneyUnit.none => '',
    };
    final gap = _endsWithLetter.hasMatch(fullUnit) ? unitGap : '';
    final signText = switch (sign) {
      _ when negative && sign != MoneySign.never => minusSign,
      MoneySign.always when minor > 0 => plusSign,
      _ => '',
    };
    final number = _decimal(
      digits,
      currency.exponent,
      grouped: true,
      hideZeroFraction: hideZeroFraction,
    );
    return '$signText$fullUnit$gap$number';
  }

  /// Plain decimal text for machines: ASCII `-`, no grouping, no unit, full precision
  /// (`-1200.50`). For CSV export, the UPI `am=` field and pre-filling the amount keypad.
  static String plain(int minor, String currencyCode) {
    final (:negative, :digits) = _digitsOf(minor);
    final number = _decimal(
      digits,
      Currencies.exponentOf(currencyCode),
      grouped: false,
      hideZeroFraction: false,
    );
    return negative ? '-$number' : number;
  }

  /// Indian grouping of a string of ASCII digits: `100000` → `1,00,000`.
  static String groupIndian(String digits) {
    if (digits.length <= 3) return digits;
    final head = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    var end = head.length;
    while (end > 0) {
      final start = end > 2 ? end - 2 : 0;
      groups.insert(0, head.substring(start, end));
      end = start;
    }
    return '${groups.join(',')},${digits.substring(digits.length - 3)}';
  }

  /// Sign and magnitude digits of [minor]; string-based so `int` minimum value works too.
  static ({bool negative, String digits}) _digitsOf(int minor) {
    final text = minor.toString();
    final negative = text.startsWith('-');
    return (negative: negative, digits: negative ? text.substring(1) : text);
  }

  static String _decimal(
    String digits,
    int exponent, {
    required bool grouped,
    required bool hideZeroFraction,
  }) {
    final padded = digits.padLeft(exponent + 1, '0');
    final whole = padded.substring(0, padded.length - exponent);
    final fraction = padded.substring(padded.length - exponent);
    final wholeText = grouped ? groupIndian(whole) : whole;
    final hide = fraction.isEmpty || (hideZeroFraction && fraction.replaceAll('0', '').isEmpty);
    return hide ? wholeText : '$wholeText.$fraction';
  }
}
