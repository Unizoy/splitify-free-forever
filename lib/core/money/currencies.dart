import 'package:splitify/core/money/currency.dart';

/// ISO 4217 currency table (planning/05-money-engine.md §1). Mirrors
/// `public.currencies` on the server.
abstract final class Currencies {
  /// Indian rupee, the app default.
  static const inr = Currency(
    code: 'INR',
    exponent: 2,
    symbol: '₹',
    name: 'Indian Rupee',
    frankfurter: true,
  );

  static const _exponent0 = {
    'BIF', 'CLP', 'DJF', 'GNF', 'ISK', 'JPY', 'KMF', 'KRW', 'PYG', 'RWF', 'UGX', 'UYI', 'VND', //
    'VUV', 'XAF', 'XOF', 'XPF',
  };
  static const _exponent3 = {'BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND'};

  /// Known currencies by code. TODO(phase-03 T2): full ISO table incl. every Frankfurter v2 currency.
  static const Map<String, Currency> all = {'INR': inr};

  /// Minor-unit digits for [code]: from the table, else the ISO rule (0/3 lists, default 2).
  static int exponentOf(String code) {
    final known = all[code];
    if (known != null) return known.exponent;
    if (_exponent0.contains(code)) return 0;
    if (_exponent3.contains(code)) return 3;
    return 2;
  }

  /// The currency for [code]; unknown codes get a generic entry (symbol = code).
  static Currency of(String code) =>
      all[code] ?? Currency(code: code, exponent: exponentOf(code), symbol: code, name: code);
}
