// TC-34-01: the search box parser (planning/08-feature-specs.md #34): words and amounts.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/rules/search_query.dart';

void main() {
  List<String> amounts(String input) => [for (final a in SearchQuery.parse(input).amounts) a.text];
  List<String> words(String input) => SearchQuery.parse(input).words;

  group('amounts', () {
    // TC-34-01
    test('plain, Western and Indian grouping give the same number', () {
      expect(amounts('1200'), ['1200']);
      expect(amounts('1,200'), ['1200']);
      expect(amounts('1,20,000'), ['120000']);
      expect(amounts('12,00,000'), ['1200000']);
      expect(amounts('1,200,000'), ['1200000']);
    });

    // TC-34-01
    test('decimals are kept, leading zeros dropped', () {
      expect(amounts('1200.50'), ['1200.50']);
      expect(amounts('0.5'), ['0.5']);
      expect(amounts('007'), ['7']);
      expect(amounts('1,200.5'), ['1200.5']);
    });

    // TC-34-01
    test('currency prefixes stick to the number', () {
      expect(amounts('₹1,200.50'), ['1200.50']);
      expect(amounts('Rs.500'), ['500']);
      expect(amounts('rs500'), ['500']);
      expect(amounts('INR1200'), ['1200']);
    });

    // TC-34-01
    test('currency words next to an amount are dropped', () {
      for (final input in ['Rs 500', 'rs. 500', 'INR 500', '₹ 500', 'rupees 500']) {
        final q = SearchQuery.parse(input);
        expect(q.words, isEmpty, reason: input);
        expect([for (final a in q.amounts) a.text], ['500'], reason: input);
      }
    });

    // TC-34-01
    test('a lone currency word is something to look for, a lone symbol is nothing', () {
      expect(words('rs'), ['rs']);
      expect(words('INR'), ['inr']);
      expect(words('rs.'), ['rs']);
      expect(SearchQuery.parse('₹').isEmpty, isTrue);
    });

    // TC-34-01
    test('the same amount twice is one term', () {
      expect(amounts('1,200 1200 ₹1200'), ['1200']);
      expect(amounts('500 700'), ['500', '700']);
    });

    // TC-34-01
    test('misplaced commas make words, not amounts', () {
      final a = SearchQuery.parse('1,,200');
      expect(a.amounts, isEmpty);
      expect(a.words, ['1', '200']);
      final b = SearchQuery.parse('1200,');
      expect(b.amounts, isEmpty);
      expect(b.words, ['1200']);
    });

    // TC-34-01
    test('too many decimals or too large becomes words', () {
      final decimals = SearchQuery.parse('1.2345');
      expect(decimals.amounts, isEmpty);
      expect(decimals.words, ['1', '2345']);
      const huge = '99999999999999999999999999';
      final big = SearchQuery.parse(huge);
      expect(big.amounts, isEmpty);
      expect(big.words, [huge]);
    });

    // TC-34-01
    test('minorFor follows the currency decimals', () {
      const a = AmountTerm('1200');
      expect(a.minorFor(0), 1200);
      expect(a.minorFor(2), 120000);
      expect(a.minorFor(3), 1200000);
      const b = AmountTerm('1200.5');
      expect(b.minorFor(2), 120050);
      expect(b.minorFor(3), 1200500);
      expect(b.minorFor(0), isNull);
      const c = AmountTerm('1.234');
      expect(c.minorFor(3), 1234);
      expect(c.minorFor(2), isNull);
    });

    // TC-34-01
    test('AmountTerm compares by text', () {
      expect(const AmountTerm('5'), const AmountTerm('5'));
      expect(const AmountTerm('5').hashCode, const AmountTerm('5').hashCode);
      expect(const AmountTerm('5'), isNot(const AmountTerm('6')));
    });
  });

  group('words', () {
    // TC-34-01
    test('lower-cased, deduplicated, split at punctuation', () {
      expect(words('Dinner, GOA! dinner'), ['dinner', 'goa']);
      expect(words('  Sea-food   (lunch)  '), ['sea', 'food', 'lunch']);
      expect(words('50% off'), ['50', 'off']);
      expect(words('.5'), ['5']);
    });

    // TC-34-01
    test('letters of any script stay', () {
      expect(words('Café Ñandú'), ['café', 'ñandú']);
    });

    // TC-34-01
    test('words and amounts mix', () {
      final q = SearchQuery.parse('Dinner 1,200 goa');
      expect(q.words, ['dinner', 'goa']);
      expect(q.amounts, [const AmountTerm('1200')]);
      expect(q.isEmpty, isFalse);
    });

    // TC-34-01
    test('empty or punctuation-only text is an empty query', () {
      for (final input in ['', '   ', '!!!', ', ;']) {
        expect(SearchQuery.parse(input).isEmpty, isTrue, reason: input);
      }
      expect(SearchQuery.parse('a').isEmpty, isFalse);
      expect(SearchQuery.parse('5').isEmpty, isFalse);
      expect(const SearchQuery().isEmpty, isTrue);
    });
  });
}
