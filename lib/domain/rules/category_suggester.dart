import 'package:splitify/domain/rules/expense_categories.dart';

/// How specific a keyword is. When two phrases of the same length match, the higher tier wins.
enum KeywordTier {
  /// A booking site that sells many things (MakeMyTrip): any other word beats it.
  weak,

  /// A plain word (`dinner`, `cab`).
  word,

  /// A brand or a specific name (`Swiggy`, `IRCTC`).
  brand,

  /// Learned from this user's own picks on this phone.
  learned,
}

/// A phrase found in a description and the category it stands for.
final class CategoryMatch {
  const CategoryMatch({required this.category, required this.phrase, required this.tier});

  /// A key of [ExpenseCategories.tree].
  final String category;

  /// The matched phrase, normalised ([CategorySuggester.normalize]).
  final String phrase;
  final KeywordTier tier;

  @override
  String toString() => 'CategoryMatch($phrase → $category, ${tier.name})';
}

final class _Rule {
  const _Rule(this.words, this.category, this.tier, this.order);

  final List<String> words;
  final String category;
  final KeywordTier tier;

  /// Position in the keyword file (the last tie-break).
  final int order;
}

/// Auto-category (D-028, like Splitwise): picks a category from an expense description with the keyword list in
/// `assets/category_keywords.json` plus what the user taught this phone.
///
/// Matching is on whole words after [normalize]: case and accents do not matter, punctuation counts as a space,
/// apostrophes vanish (`Domino's` = `dominos`) and a UPI ID keeps only its name part (`zomato.payu@axis` →
/// `zomato payu`). Several phrases can match; the longest one (in words) wins, then the higher [KeywordTier], then
/// the one earliest in the text, then the one first in the file. No match → null (the caller keeps its category).
final class CategorySuggester {
  CategorySuggester._(this.version, this._index, this.phraseCount);

  /// Reads the keyword file (`{version, rules: [{category, tier, phrases}]}`). Unknown categories and tiers are
  /// skipped, so an older app can read a newer file; a phrase listed twice keeps its first category.
  factory CategorySuggester.fromJson(Map<String, Object?> json) {
    final index = <String, List<_Rule>>{};
    final seen = <String>{};
    var order = 0;
    for (final r in (json['rules'] as List<Object?>?) ?? const <Object?>[]) {
      if (r is! Map) continue;
      final category = r['category'];
      final tier = KeywordTier.values.where((t) => t.name == r['tier']).firstOrNull;
      if (category is! String || !ExpenseCategories.isKnown(category)) continue;
      if (tier == null || tier == KeywordTier.learned) continue;
      for (final p in (r['phrases'] as List<Object?>?) ?? const <Object?>[]) {
        if (p is! String) continue;
        final words = tokens(p);
        if (words.isEmpty || !seen.add(words.join(' '))) continue;
        (index[words.first] ??= []).add(_Rule(words, category, tier, order++));
      }
    }
    return CategorySuggester._((json['version'] as int?) ?? 0, index, order);
  }

  /// No keywords: suggests only what was learned.
  static final empty = CategorySuggester._(0, const {}, 0);

  /// Version of the keyword file.
  final int version;

  /// How many distinct phrases the file has.
  final int phraseCount;

  final Map<String, List<_Rule>> _index;

  /// The category for [description], or null when nothing matches. [learned] maps normalised phrases to
  /// categories (the user's own picks); they beat the keyword file at equal length.
  String? suggest(String description, {Map<String, String> learned = const {}}) =>
      match(description, learned: learned)?.category;

  /// Like [suggest], with the phrase that decided it.
  CategoryMatch? match(String description, {Map<String, String> learned = const {}}) {
    final words = tokens(description);
    if (words.isEmpty) return null;
    _Rule? best;
    var bestAt = 0;
    void consider(_Rule rule, int at) {
      final b = best;
      if (b == null || _beats(rule, at, b, bestAt)) {
        best = rule;
        bestAt = at;
      }
    }

    var order = -learned.length;
    for (final e in learned.entries) {
      final rule = _Rule(tokens(e.key), e.value, KeywordTier.learned, order++);
      if (rule.words.isEmpty || !ExpenseCategories.isKnown(e.value)) continue;
      for (var i = 0; i + rule.words.length <= words.length; i++) {
        if (_matchesAt(words, i, rule.words)) consider(rule, i);
      }
    }
    for (var i = 0; i < words.length; i++) {
      for (final rule in _index[words[i]] ?? const <_Rule>[]) {
        if (_matchesAt(words, i, rule.words)) consider(rule, i);
      }
    }
    final b = best;
    return b == null
        ? null
        : CategoryMatch(category: b.category, phrase: b.words.join(' '), tier: b.tier);
  }

  /// What to remember after the user picked [chosen] for [description] by hand (D-028 learning): the normalised
  /// description (up to [maxLearnedWords] words) → [chosen]. A short description is the keyword itself
  /// (`Starbucks` → also used for "Starbucks with Asha"); a longer one only comes back when typed again. Empty
  /// when the suggestion already was [chosen], or nothing was suggested and [chosen] is the default.
  Map<String, String> lessons(
    String description,
    String chosen, {
    Map<String, String> learned = const {},
  }) {
    final words = tokens(description);
    if (words.isEmpty || words.length > maxLearnedWords) return const {};
    if (!ExpenseCategories.isKnown(chosen)) return const {};
    final hit = match(description, learned: learned);
    if (hit?.category == chosen) return const {};
    if (hit == null && chosen == ExpenseCategories.defaultKey) return const {};
    return {words.join(' '): chosen};
  }

  /// Longest description that is learned as a whole.
  static const maxLearnedWords = 8;

  static bool _beats(_Rule a, int aAt, _Rule b, int bAt) {
    if (a.words.length != b.words.length) return a.words.length > b.words.length;
    if (a.tier != b.tier) return a.tier.index > b.tier.index;
    if (aAt != bAt) return aAt < bAt;
    return a.order < b.order;
  }

  static bool _matchesAt(List<String> words, int at, List<String> phrase) {
    if (at + phrase.length > words.length) return false;
    for (var k = 0; k < phrase.length; k++) {
      if (words[at + k] != phrase[k]) return false;
    }
    return true;
  }

  /// [text] as its words joined by single spaces (see [tokens]).
  static String normalize(String text) => tokens(text).join(' ');

  /// The words of [text]: lower case, accents and Devanagari nukta folded, apostrophes removed, the handle of a
  /// UPI ID (`@icici`) dropped, every other non-letter/digit a separator.
  static List<String> tokens(String text) {
    final out = <String>[];
    for (var chunk in text.toLowerCase().split(_space)) {
      if (chunk.isEmpty) continue;
      final at = chunk.indexOf('@');
      if (at > 0) chunk = chunk.substring(0, at);
      final folded = _fold(chunk);
      for (final m in _word.allMatches(folded)) {
        out.add(m.group(0)!);
      }
    }
    return out;
  }

  static final _space = RegExp(r'\s+');
  static final _word = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);

  static String _fold(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r == 0x27 || r == 0x2019 || r == 0x2018 || r == 0x60 || r == 0xB4 || r == 0x93C) continue;
      final f = _folds[r];
      if (f != null) {
        b.write(f);
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  /// Latin letters with accents → plain letters; Devanagari letters with a nukta → the letter without it.
  static final Map<int, String> _folds = {
    for (final e in const {
      'a': 'àáâãäåāăą',
      'c': 'çćĉċč',
      'd': 'ďđ',
      'e': 'èéêëēĕėęě',
      'g': 'ĝğġģ',
      'h': 'ĥħ',
      'i': 'ìíîïĩīĭįı',
      'j': 'ĵ',
      'k': 'ķ',
      'l': 'ĺļľŀł',
      'n': 'ñńņňŉ',
      'o': 'òóôõöøōŏő',
      'r': 'ŕŗř',
      's': 'śŝşš',
      't': 'ţťŧ',
      'u': 'ùúûüũūŭůűų',
      'w': 'ŵ',
      'y': 'ýÿŷ',
      'z': 'źżž',
    }.entries)
      for (final r in e.value.runes) r: e.key,
    0xDF: 'ss',
    0xE6: 'ae',
    0x153: 'oe',
    0x958: 'क',
    0x959: 'ख',
    0x95A: 'ग',
    0x95B: 'ज',
    0x95C: 'ड',
    0x95D: 'ढ',
    0x95E: 'फ',
    0x95F: 'य',
  };
}
