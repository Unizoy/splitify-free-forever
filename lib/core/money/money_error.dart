/// Errors of the money engine (planning/05-money-engine.md §4).
///
/// Every error has a stable [MoneyError.code] (the same string the oracle
/// `planning/reference/money_reference.py` and the Postgres `money` schema use)
/// and [MoneyError.data] with exactly the oracle's data keys, so the UI, the
/// vectors test and the SQL tests can all compare them.
sealed class MoneyError implements Exception {
  const MoneyError();

  /// Stable error code, e.g. `SUM_MISMATCH`.
  String get code;

  /// Extra values for the UI text, keyed like the oracle (`remaining`, `remaining_bps`, `over`).
  Map<String, Object> get data => const {};

  @override
  String toString() => data.isEmpty ? 'MoneyError($code)' : 'MoneyError($code, $data)';
}

/// An expense/payment total is 0 or negative.
final class AmountNotPositive extends MoneyError {
  const AmountNotPositive();

  @override
  String get code => 'AMOUNT_NOT_POSITIVE';
}

/// An amount is above `maxAmount` (999 999 999 999 minor units).
final class AmountTooLarge extends MoneyError {
  const AmountTooLarge();

  @override
  String get code => 'AMOUNT_TOO_LARGE';
}

/// No member was chosen for the split. UI: "Pick at least one person".
final class NoParticipants extends MoneyError {
  const NoParticipants();

  @override
  String get code => 'NO_PARTICIPANTS';
}

/// Exact amounts do not add up to the total. UI: "₹x left" (`remaining > 0`) / "₹x over" (`< 0`).
final class SumMismatch extends MoneyError {
  const SumMismatch(this.remaining);

  /// `total − Σ amounts` in minor units.
  final int remaining;

  @override
  String get code => 'SUM_MISMATCH';

  @override
  Map<String, Object> get data => {'remaining': remaining};
}

/// A share (exact amount, share count or adjusted result) is below 0.
final class NegativeShare extends MoneyError {
  const NegativeShare();

  @override
  String get code => 'NEGATIVE_SHARE';
}

/// Percentages do not add up to 100 %. UI: "x % left".
final class PercentSumMismatch extends MoneyError {
  const PercentSumMismatch(this.remainingBps);

  /// `10000 − Σ basis points`.
  final int remainingBps;

  @override
  String get code => 'PERCENT_SUM_MISMATCH';

  @override
  Map<String, Object> get data => {'remaining_bps': remainingBps};
}

/// A percentage is below 0 % or above 100 %.
final class PercentOutOfRange extends MoneyError {
  const PercentOutOfRange();

  @override
  String get code => 'PERCENT_OUT_OF_RANGE';
}

/// Every share count is 0. UI: "Give someone at least one share".
final class NoShares extends MoneyError {
  const NoShares();

  @override
  String get code => 'NO_SHARES';
}

/// Adjustments add up to more than the total.
final class AdjustmentsExceedTotal extends MoneyError {
  const AdjustmentsExceedTotal(this.over);

  /// `Σ adjustments − total` in minor units (> 0).
  final int over;

  @override
  String get code => 'ADJUSTMENTS_EXCEED_TOTAL';

  @override
  Map<String, Object> get data => {'over': over};
}

/// A stored split kind name is not one of the five kinds.
final class UnknownSplit extends MoneyError {
  const UnknownSplit();

  @override
  String get code => 'UNKNOWN_SPLIT';
}

/// What the payers paid does not add up to the total.
final class PayersSumMismatch extends MoneyError {
  const PayersSumMismatch(this.remaining);

  /// `total − Σ paid` in minor units.
  final int remaining;

  @override
  String get code => 'PAYERS_SUM_MISMATCH';

  @override
  Map<String, Object> get data => {'remaining': remaining};
}

/// No payer, or a payer with a negative amount.
final class InvalidPayers extends MoneyError {
  const InvalidPayers();

  @override
  String get code => 'INVALID_PAYERS';
}

/// Ratio weights are negative or add up to 0.
final class InvalidWeights extends MoneyError {
  const InvalidWeights();

  @override
  String get code => 'INVALID_WEIGHTS';
}

/// Nets given to simplify do not add up to 0.
final class NetsDoNotSumToZero extends MoneyError {
  const NetsDoNotSumToZero();

  @override
  String get code => 'NETS_DO_NOT_SUM_TO_ZERO';
}

/// An exchange rate is not a decimal > 0 with at most 10 decimal places.
final class InvalidRate extends MoneyError {
  const InvalidRate();

  @override
  String get code => 'INVALID_RATE';
}

/// The rates table has no rate for [currency].
final class RateNotFound extends MoneyError {
  const RateNotFound(this.currency);

  final String currency;

  @override
  String get code => 'RATE_NOT_FOUND';

  @override
  Map<String, Object> get data => {'currency': currency};
}

/// Amounts in two different currencies were combined.
final class CurrencyMismatch extends MoneyError {
  const CurrencyMismatch(this.left, this.right);

  final String left;
  final String right;

  @override
  String get code => 'CURRENCY_MISMATCH';

  @override
  Map<String, Object> get data => {'left': left, 'right': right};
}

/// A member id is not in the fixed member order.
final class UnknownMember extends MoneyError {
  const UnknownMember(this.member);

  final String member;

  @override
  String get code => 'UNKNOWN_MEMBER';

  @override
  Map<String, Object> get data => {'member': member};
}

/// A member id appears twice in a member list.
final class DuplicateMember extends MoneyError {
  const DuplicateMember(this.member);

  final String member;

  @override
  String get code => 'DUPLICATE_MEMBER';

  @override
  Map<String, Object> get data => {'member': member};
}

/// A payment whose sender is also its receiver.
final class InvalidPayment extends MoneyError {
  const InvalidPayment(this.member);

  final String member;

  @override
  String get code => 'INVALID_PAYMENT';

  @override
  Map<String, Object> get data => {'member': member};
}
