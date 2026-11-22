import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:splitify/core/money/fx.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/features/currency/domain/fx_service.dart';
import 'package:splitify/l10n/app_localizations.dart';

/// A rate for reading (the saved rate stays exact): 4 decimals from 1 up, else 4 significant digits
/// (`89.6437142330` → `89.6437`, `0.0033512345` → `0.003351`), no trailing zeros.
String displayRate(String rate) {
  final Decimal r;
  try {
    r = parseRate(rate);
  } on MoneyError {
    return rate;
  }
  if (r >= Decimal.one) return r.round(scale: 4).toString();
  final digits = r.toString().split('.').last;
  final zeros = digits.length - digits.replaceFirst(RegExp('^0+'), '').length;
  final scale = (zeros + 4).clamp(4, rateDecimals);
  return r.round(scale: scale).toString();
}

/// "21 Nov 2026" of a date-only UTC date.
String fxDate(BuildContext context, DateTime date) => DateFormat(
  'd MMM y',
  Localizations.localeOf(context).toLanguageTag(),
).format(DateTime(date.year, date.month, date.day));

/// "1 USD = 89.6437 INR".
String rateLine(AppLocalizations l, String from, String to, String rate) =>
    l.fxRateLine(from, displayRate(rate), to);

/// Where [rate] comes from: "Frankfurter · 20 Nov 2026" (", the latest before 21 Nov 2026" when it is an
/// earlier day than [asked]) or "Rate you typed · 21 Nov 2026".
String sourceLine(BuildContext context, FxRate rate, {DateTime? asked}) {
  final l = AppLocalizations.of(context);
  final day = fxDate(context, rate.effectiveDate);
  if (rate.source == FxSource.manual) return l.fxSourceManual(day);
  final a = asked;
  if (rate.isFallback && a != null && a != rate.effectiveDate) {
    return l.fxSourceFallback(day, fxDate(context, a));
  }
  return l.fxSourceFrankfurter(day);
}

/// Why there is no automatic rate.
String noRateText(BuildContext context, FxNeedsManualRate missing) {
  final l = AppLocalizations.of(context);
  return switch (missing.reason) {
    FxMissingReason.unlistedCurrency => l.fxNoRateUnlisted(missing.currencies.join(', ')),
    FxMissingReason.noRates => l.fxNoRateMissing(fxDate(context, missing.date)),
  };
}
