// UPI pay link (CLAUDE.md rule 13, planning/08-feature-specs.md #26,
// planning/research/06-upi-release-ci.md §1). Contract: test/fixtures/upi_vectors.json.
//
// `upi://pay?pa=<vpa>&pn=<name>&am=<amount>&cu=INR&tn=<note>`
// - Rupees only; the amount is integer paise (1 … maxAmount) written as plain 2-dp text (`100.50`).
// - `pn` and `tn` are cleaned to printable ASCII (other characters dropped, whitespace collapsed),
//   then percent-encoded (everything except `A–Z a–z 0–9 - . _ ~`; space = `%20`, never `+`).
// - `tn` is cut to [UpiLinkBuilder.noteMaxLength] characters and left out when empty; an empty
//   name falls back to the VPA (`pn` is required by the NPCI linking spec).
// - The link only opens the payer's UPI app; a payment is recorded only on "Mark as paid".
import 'dart:convert';

import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_formatter.dart';

/// Errors of [UpiLinkBuilder.build], each with a stable [code].
sealed class UpiLinkError implements Exception {
  const UpiLinkError();

  /// Stable error code, e.g. `UPI_CURRENCY_NOT_INR`.
  String get code;

  /// Extra values for the UI text.
  Map<String, Object> get data => const {};

  @override
  String toString() => data.isEmpty ? 'UpiLinkError($code)' : 'UpiLinkError($code, $data)';
}

/// UPI pays rupees only; the balance is in another currency (never convert, rule 13).
final class UpiCurrencyNotInr extends UpiLinkError {
  const UpiCurrencyNotInr(this.currency);

  final String currency;

  @override
  String get code => 'UPI_CURRENCY_NOT_INR';

  @override
  Map<String, Object> get data => {'currency': currency};
}

/// The amount is 0 or negative (same code as the money engine).
final class UpiAmountNotPositive extends UpiLinkError {
  const UpiAmountNotPositive();

  @override
  String get code => 'AMOUNT_NOT_POSITIVE';
}

/// The amount is above [maxAmount] (same code as the money engine).
final class UpiAmountTooLarge extends UpiLinkError {
  const UpiAmountTooLarge();

  @override
  String get code => 'AMOUNT_TOO_LARGE';
}

/// The receiver's UPI ID does not look like `name@handle`.
final class UpiInvalidVpa extends UpiLinkError {
  const UpiInvalidVpa();

  @override
  String get code => 'UPI_INVALID_VPA';
}

/// A built link plus the cleaned parts the fallback sheet shows (copy UPI ID, copy amount, QR).
final class UpiLink {
  const UpiLink({
    required this.uri,
    required this.vpa,
    required this.name,
    required this.amount,
    required this.note,
  });

  /// The full `upi://pay?…` text (also the content of the UPI QR code).
  final String uri;

  /// Normalised UPI ID (`pa`).
  final String vpa;

  /// Cleaned payee name (`pn`, not encoded).
  final String name;

  /// Plain 2-dp rupee amount (`am`), e.g. `100.50`.
  final String amount;

  /// Cleaned note (`tn`, not encoded); empty when the link has no `tn`.
  final String note;

  @override
  String toString() => uri;
}

/// Builds UPI intent links; pure and synchronous.
final class UpiLinkBuilder {
  const UpiLinkBuilder();

  /// Longest `tn` text, in characters (apps truncate longer notes).
  static const noteMaxLength = 50;

  /// The only currency UPI accepts.
  static const currency = 'INR';

  static final _vpa = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{1,255}@[a-zA-Z][a-zA-Z0-9]{1,63}$');
  static final _whitespace = RegExp(r'\s+');
  static final _notPrintableAscii = RegExp(r'[^\x20-\x7E]');

  /// The UPI ID trimmed, with the handle after `@` lower-cased, or `null` when it is not valid.
  static String? normalizeVpa(String raw) {
    final vpa = raw.trim();
    if (!_vpa.hasMatch(vpa)) return null;
    final at = vpa.indexOf('@');
    return '${vpa.substring(0, at)}${vpa.substring(at).toLowerCase()}';
  }

  /// Printable ASCII only, whitespace collapsed to single spaces, trimmed.
  static String cleanText(String raw) => raw
      .replaceAll(_whitespace, ' ')
      .replaceAll(_notPrintableAscii, '')
      .replaceAll(_whitespace, ' ')
      .trim();

  /// Percent-encodes every UTF-8 byte except the RFC 3986 unreserved characters `A–Z a–z 0–9 - . _ ~`.
  static String encode(String text) {
    final out = StringBuffer();
    for (final unit in utf8.encode(text)) {
      final unreserved =
          (unit >= 0x41 && unit <= 0x5A) ||
          (unit >= 0x61 && unit <= 0x7A) ||
          (unit >= 0x30 && unit <= 0x39) ||
          unit == 0x2D ||
          unit == 0x2E ||
          unit == 0x5F ||
          unit == 0x7E;
      if (unreserved) {
        out.writeCharCode(unit);
      } else {
        out.write('%${unit.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return out.toString();
  }

  /// Builds the link to pay [amountMinor] paise to [vpa]. Checks, in order: [currencyCode] is `INR`
  /// ([UpiCurrencyNotInr]), `1 ≤ amountMinor ≤ maxAmount` ([UpiAmountNotPositive],
  /// [UpiAmountTooLarge]), then the UPI ID ([UpiInvalidVpa]).
  UpiLink build({
    required String vpa,
    required String name,
    required int amountMinor,
    required String currencyCode,
    String note = '',
  }) {
    if (currencyCode != currency) throw UpiCurrencyNotInr(currencyCode);
    if (amountMinor <= 0) throw const UpiAmountNotPositive();
    if (amountMinor > maxAmount) throw const UpiAmountTooLarge();
    final pa = normalizeVpa(vpa);
    if (pa == null) throw const UpiInvalidVpa();

    final cleanName = cleanText(name);
    final pn = cleanName.isEmpty ? pa : cleanName;
    var tn = cleanText(note);
    if (tn.length > noteMaxLength) tn = tn.substring(0, noteMaxLength).trimRight();
    final am = MoneyFormatter.plain(amountMinor, currency);

    final uri = StringBuffer('upi://pay?pa=$pa&pn=${encode(pn)}&am=$am&cu=$currency');
    if (tn.isNotEmpty) uri.write('&tn=${encode(tn)}');
    return UpiLink(uri: uri.toString(), vpa: pa, name: pn, amount: am, note: tn);
  }
}
