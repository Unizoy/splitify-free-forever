import 'package:splitify/core/money/allocation.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_error.dart';

/// How an expense is split (planning/05-money-engine.md §4). The enum names
/// are the stored `split_kind` values.
enum SplitKind {
  /// Same share for everyone; values ignored.
  equal,

  /// Minor units per member; must sum to the total.
  exact,

  /// Basis points per member (10000 = 100 %); must sum to 10000.
  percent,

  /// Thousandths of a share per member (1500 = 1.5 shares).
  shares,

  /// Signed minor-unit adjustment per member, the rest split equally.
  adjust;

  /// The kind stored as [name]. Throws [UnknownSplit] for anything else.
  static SplitKind parse(String name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    throw const UnknownSplit();
  }
}

/// Splits [total] minor units over [members] (chosen participants, in fixed
/// order) by [kind] and the raw editor [values] (keyed by member id; missing =
/// 0; ids not in [members] are ignored).
///
/// Returns each member's share in [members] order; members with a 0 share stay
/// listed. Shares always sum to [total]. Throws a [MoneyError]:
/// `AMOUNT_NOT_POSITIVE` / `AMOUNT_TOO_LARGE` (total or a value outside
/// ±`maxAmount`), `NO_PARTICIPANTS`, `DUPLICATE_MEMBER`, and per kind
/// `SUM_MISMATCH`, `NEGATIVE_SHARE`, `PERCENT_OUT_OF_RANGE`,
/// `PERCENT_SUM_MISMATCH`, `NO_SHARES`, `ADJUSTMENTS_EXCEED_TOTAL`.
Map<String, int> split(
  int total,
  SplitKind kind,
  List<String> members, [
  Map<String, int> values = const {},
]) {
  checkAmount(total);
  if (members.isEmpty) throw const NoParticipants();
  fixedOrderIndex(members);
  final v = [for (final m in members) values[m] ?? 0];
  final parts = switch (kind) {
    SplitKind.equal => allocateEqual(total, members.length),
    SplitKind.exact => _exact(total, v),
    SplitKind.percent => _percent(total, v),
    SplitKind.shares => _shares(total, v),
    SplitKind.adjust => _adjust(total, v),
  };
  return Map.unmodifiable({for (var i = 0; i < members.length; i++) members[i]: parts[i]});
}

/// Checks what each payer paid for an expense of [total]: at least one payer,
/// none negative, and the amounts sum to [total]. Payers needn't be
/// participants. Throws `INVALID_PAYERS`, `AMOUNT_TOO_LARGE` or
/// `PAYERS_SUM_MISMATCH{remaining}`.
void checkPayers(int total, Map<String, int> paid) {
  if (paid.isEmpty || paid.values.any((v) => v < 0)) throw const InvalidPayers();
  _checkMagnitudes(paid.values);
  final diff = total - _sum(paid.values);
  if (diff != 0) throw PayersSumMismatch(diff);
}

List<int> _exact(int total, List<int> amounts) {
  _checkMagnitudes(amounts);
  if (amounts.any((a) => a < 0)) throw const NegativeShare();
  final diff = total - _sum(amounts);
  if (diff != 0) throw SumMismatch(diff);
  return amounts;
}

List<int> _percent(int total, List<int> bps) {
  if (bps.any((b) => b < 0 || b > 10000)) throw const PercentOutOfRange();
  final sum = _sum(bps);
  if (sum != 10000) throw PercentSumMismatch(10000 - sum);
  return allocateRatio(total, bps);
}

List<int> _shares(int total, List<int> shares) {
  _checkMagnitudes(shares);
  if (shares.any((s) => s < 0)) throw const NegativeShare();
  if (_sum(shares) == 0) throw const NoShares();
  return allocateRatio(total, shares);
}

List<int> _adjust(int total, List<int> adjustments) {
  _checkMagnitudes(adjustments);
  final rest = total - _sum(adjustments);
  if (rest < 0) throw AdjustmentsExceedTotal(-rest);
  final equal = allocateEqual(rest, adjustments.length);
  final out = [for (var i = 0; i < adjustments.length; i++) equal[i] + adjustments[i]];
  if (out.any((v) => v < 0)) throw const NegativeShare();
  return out;
}

/// Per-member values are bounded by ±maxAmount so their sums can't overflow
/// 64-bit ints (the oracle has unbounded Python ints).
void _checkMagnitudes(Iterable<int> values) {
  if (values.any((v) => v > maxAmount || v < -maxAmount)) throw const AmountTooLarge();
}

int _sum(Iterable<int> values) => values.fold(0, (a, b) => a + b);
