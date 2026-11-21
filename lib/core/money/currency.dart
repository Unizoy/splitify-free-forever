/// An ISO 4217 currency (planning/05-money-engine.md §1).
///
/// Two currencies are equal when their codes are equal.
final class Currency {
  const Currency({
    required this.code,
    required this.exponent,
    required this.symbol,
    required this.name,
    this.frankfurter = false,
  });

  /// Upper-case ISO 4217 code, e.g. `INR`.
  final String code;

  /// Number of minor-unit digits: 2 for INR (paise), 0 for JPY, 3 for KWD.
  final int exponent;

  /// Display symbol, e.g. `₹`, `$`, `€`; falls back to the code when none is common.
  final String symbol;

  /// English name, e.g. `Indian Rupee`.
  final String name;

  /// True when Frankfurter v2 publishes daily rates for it (server rates exist).
  final bool frankfurter;

  /// Minor units per major unit: 10^exponent (100 for INR).
  int get minorPerMajor {
    var v = 1;
    for (var i = 0; i < exponent; i++) {
      v *= 10;
    }
    return v;
  }

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}
