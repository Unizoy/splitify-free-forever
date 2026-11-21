import 'package:splitify/core/money/money_error.dart';

/// Largest total of one expense or payment, in minor units (≈ ₹9,999 crore).
const int maxAmount = 999999999999;

/// Throws unless `1 ≤ total ≤ maxAmount` (planning/05-money-engine.md §1).
void checkAmount(int total) {
  if (total <= 0) throw const AmountNotPositive();
  if (total > maxAmount) throw const AmountTooLarge();
}

/// An amount of money: integer minor units plus an ISO 4217 currency code.
///
/// ₹100.50 is `Money(10050, 'INR')`. Arithmetic and comparison only work within
/// one currency; mixing currencies throws [CurrencyMismatch] (rule 4).
final class Money implements Comparable<Money> {
  const Money(this.minor, this.currency);

  /// Zero in [currency].
  const Money.zero(this.currency) : minor = 0;

  /// Amount in minor units (paise for INR, yen for JPY, fils for KWD).
  final int minor;

  /// Upper-case ISO 4217 code.
  final String currency;

  bool get isZero => minor == 0;

  bool get isNegative => minor < 0;

  bool get isPositive => minor > 0;

  Money operator +(Money other) => Money(minor + _same(other).minor, currency);

  Money operator -(Money other) => Money(minor - _same(other).minor, currency);

  Money operator -() => Money(-minor, currency);

  /// Same currency, absolute amount.
  Money abs() => Money(minor.abs(), currency);

  @override
  int compareTo(Money other) => minor.compareTo(_same(other).minor);

  bool operator <(Money other) => compareTo(other) < 0;

  bool operator <=(Money other) => compareTo(other) <= 0;

  bool operator >(Money other) => compareTo(other) > 0;

  bool operator >=(Money other) => compareTo(other) >= 0;

  Money _same(Money other) {
    if (other.currency != currency) throw CurrencyMismatch(currency, other.currency);
    return other;
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => 'Money($minor $currency)';
}
