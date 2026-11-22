// Search box text -> terms (planning/08-feature-specs.md #34, TC-34-01). Pure; the local search
// (lib/data/repositories/search_repository.dart) turns the terms into FTS5 prefix matches and amount checks.
//
// - Words match description, notes and people's names by prefix, case-insensitively ("din" finds "Dinner").
// - A number ("1200", "1,200", "1,20,000", "₹1,200.50", "Rs.500") is an amount: it matches expenses of exactly
//   that amount in their currency's decimals, or the number in the text ("Flat 302"). Grouping commas may sit
//   anywhere (Indian and Western grouping both work).
// - Every term must match (AND). Currency words next to an amount ("Rs 500", "INR 1200", "₹ 1200") are dropped.

import 'package:splitify/core/money/scaled_input.dart';

/// One number typed in the search box: [text] is its digits with at most one `.` (no grouping, no symbol).
final class AmountTerm {
  const AmountTerm(this.text);

  final String text;

  /// The amount in minor units of a currency with [exponent] decimals; null when the number has more
  /// decimals than the currency (`12.5` for yen) or is too large.
  int? minorFor(int exponent) => ScaledInput.parse(text, exponent);

  @override
  bool operator ==(Object other) => other is AmountTerm && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'AmountTerm($text)';
}

/// What the search box asks for.
final class SearchQuery {
  const SearchQuery({this.words = const [], this.amounts = const []});

  /// Parses the search box text.
  factory SearchQuery.parse(String input) {
    final tokens = input
        .toLowerCase()
        .split(_space)
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final words = <String>[];
    final amounts = <AmountTerm>[];
    final currencyWords = <String>[];
    for (final raw in tokens) {
      final amount = _amount(raw);
      if (amount != null) {
        if (!amounts.contains(amount)) amounts.add(amount);
        continue;
      }
      if (_currencyWords.contains(raw)) {
        currencyWords.add(raw);
        continue;
      }
      final word = raw.replaceAll(_notWord, ' ').trim();
      for (final w in word.split(_space)) {
        if (w.isNotEmpty && !words.contains(w)) words.add(w);
      }
    }
    // A lone "inr" / "rs" is a word the person is looking for; next to an amount it is the currency.
    if (amounts.isEmpty) {
      for (final c in currencyWords) {
        final w = c.replaceAll(_notWord, '');
        if (w.isNotEmpty && !words.contains(w)) words.add(w);
      }
    }
    return SearchQuery(words: List.unmodifiable(words), amounts: List.unmodifiable(amounts));
  }

  /// Lower-case words, each matched by prefix.
  final List<String> words;

  /// Numbers, each matched as an amount or as text.
  final List<AmountTerm> amounts;

  bool get isEmpty => words.isEmpty && amounts.isEmpty;

  static final _space = RegExp(r'\s+');
  // Anything that is not a letter or digit separates words (FTS5 would treat it the same way).
  static final _notWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
  static final _number = RegExp(r'^(?:₹|rs\.?|inr)?(\d[\d,]*)(?:\.(\d+))?$');
  static const _currencyWords = {'₹', 'rs', 'rs.', 'inr', 'rupees', 'rupee'};

  static AmountTerm? _amount(String token) {
    final m = _number.firstMatch(token);
    if (m == null) return null;
    final whole = m[1]!;
    if (whole.endsWith(',') || whole.contains(',,')) return null;
    final digits = whole.replaceAll(',', '').replaceFirst(RegExp('^0+(?=\\d)'), '');
    final fraction = m[2];
    final text = fraction == null ? digits : '$digits.$fraction';
    // Too many decimals or too large for any currency: searched as text instead.
    if (ScaledInput.parse(text, 3) == null && ScaledInput.parse(text, 0) == null) return null;
    return AmountTerm(text);
  }

  @override
  String toString() => 'SearchQuery(words: $words, amounts: $amounts)';
}
