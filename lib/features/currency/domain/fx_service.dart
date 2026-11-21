/// Exchange-rate lookup for conversions (planning/05-money-engine.md §6, phase 14 T3).
///
/// Reads the phone's cache of the server's Frankfurter rates (`fx_rates`: units of a
/// currency per 1 EUR, per day) through [RatesSource], so it works offline. Rates stay
/// exact decimal strings: the cross rate comes from [crossRate], manual rates are checked
/// with [parseRate]. Lookup rules: S-093..S-095 in planning/00-decisions.md.
library;

import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/fx.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/domain/rules/recurrence.dart';

/// One cached `fx_rates` row: [rate] units of [currency] per 1 EUR on [date].
final class EurRate {
  const EurRate({required this.date, required this.currency, required this.rate});

  /// Date-only UTC.
  final DateTime date;
  final String currency;

  /// Exact decimal text, as stored (`numeric`).
  final String rate;
}

/// Read access to the cached rates (the pulled Drift table in phase 14 T3).
abstract interface class RatesSource {
  /// Every cached row of one of [currencies] dated on or before [date] (date-only UTC),
  /// in any order.
  Future<List<EurRate>> ratesOnOrBefore(Set<String> currencies, DateTime date);
}

/// Where a rate came from; [code] is the `fx_source` column value.
enum FxSource {
  frankfurter('frankfurter'),
  manual('manual');

  const FxSource(this.code);

  final String code;
}

/// A rate ready to save with a record: [rate] major units of [to] per major unit of [from].
final class FxRate {
  const FxRate({
    required this.from,
    required this.to,
    required this.rate,
    required this.effectiveDate,
    required this.source,
    required this.isFallback,
  });

  final String from;
  final String to;

  /// Decimal text accepted by [parseRate] and [convert].
  final String rate;

  /// `fx_rate_date`: the date of the cached rates used, or the record date for a manual rate.
  final DateTime effectiveDate;
  final FxSource source;

  /// True when [effectiveDate] is earlier than the date asked for (the UI says so).
  final bool isFallback;
}

/// Result of [FxService.rate].
sealed class FxLookup {
  const FxLookup();
}

/// An automatic rate from the cache.
final class FxRateFound extends FxLookup {
  const FxRateFound(this.rate);

  final FxRate rate;
}

/// Why no automatic rate exists.
enum FxMissingReason {
  /// Frankfurter does not publish one of the currencies.
  unlistedCurrency,

  /// No cached rates on or before the date (empty cache or a date older than it).
  noRates,
}

/// The UI must ask for a manual rate ("1 [from] = ___ [to]"), then call [FxService.manualRate].
final class FxNeedsManualRate extends FxLookup {
  const FxNeedsManualRate({
    required this.from,
    required this.to,
    required this.date,
    required this.reason,
    required this.currencies,
  });

  final String from;
  final String to;
  final DateTime date;
  final FxMissingReason reason;

  /// The unlisted currencies, or those without cached rates.
  final List<String> currencies;
}

/// Finds the rate to convert between two currencies on a date.
final class FxService {
  const FxService(this._source);

  final RatesSource _source;

  /// The cached Frankfurter rate `from → to` for [date] (date-only UTC): the most recent
  /// date on or before [date] on which every non-EUR currency of the pair has a row
  /// (S-093). Throws [ArgumentError] when [from] equals [to], `NotADate`, or
  /// [InvalidRate] for a bad cached rate.
  Future<FxLookup> rate(String from, String to, DateTime date) async {
    _checkPair(from, to, date);
    final needed = [
      for (final c in [from, to])
        if (c != 'EUR') c,
    ];
    final unlisted = [
      for (final c in needed)
        if (Currencies.all[c]?.frankfurter != true) c,
    ];
    if (unlisted.isNotEmpty) {
      return _manual(from, to, date, FxMissingReason.unlistedCurrency, unlisted);
    }

    final byDate = <DateTime, Map<String, String>>{};
    for (final row in await _source.ratesOnOrBefore(needed.toSet(), date)) {
      if (row.date.isAfter(date) || !needed.contains(row.currency)) continue;
      (byDate[row.date] ??= {})[row.currency] = row.rate;
    }
    DateTime? best;
    for (final MapEntry(key: day, value: rates) in byDate.entries) {
      if (needed.every(rates.containsKey) && (best == null || day.isAfter(best))) best = day;
    }
    if (best == null) {
      final seen = {for (final rates in byDate.values) ...rates.keys};
      final missing = [
        for (final c in needed)
          if (!seen.contains(c)) c,
      ];
      return _manual(from, to, date, FxMissingReason.noRates, missing.isEmpty ? needed : missing);
    }
    return FxRateFound(
      FxRate(
        from: from,
        to: to,
        rate: crossRate(byDate[best]!, from, to),
        effectiveDate: best,
        source: FxSource.frankfurter,
        isFallback: best != date,
      ),
    );
  }

  /// A rate the user typed ("1 [from] = [rate] [to]") for a record dated [date]
  /// (S-095). Throws [InvalidRate] unless [rate] is a decimal > 0 with at most
  /// [rateDecimals] decimals, [ArgumentError] when [from] equals [to], `NotADate`.
  FxRate manualRate(String from, String to, DateTime date, String rate) {
    _checkPair(from, to, date);
    return FxRate(
      from: from,
      to: to,
      rate: parseRate(rate).toString(),
      effectiveDate: date,
      source: FxSource.manual,
      isFallback: false,
    );
  }

  static void _checkPair(String from, String to, DateTime date) {
    checkDateOnly(date);
    if (from == to) throw ArgumentError.value(to, 'to', 'must differ from "from"');
  }

  static FxNeedsManualRate _manual(
    String from,
    String to,
    DateTime date,
    FxMissingReason reason,
    List<String> currencies,
  ) => FxNeedsManualRate(
    from: from,
    to: to,
    date: date,
    reason: reason,
    currencies: List.unmodifiable(currencies),
  );
}
