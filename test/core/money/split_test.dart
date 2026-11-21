// TC-5..9-01 split edge cases beyond the shared vectors; TC-10-01 payer validation.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/core/money/split.dart';

const abc = ['A', 'B', 'C'];

Matcher _code(String code, [Map<String, Object> data = const {}]) => throwsA(
  isA<MoneyError>().having((e) => e.code, 'code', code).having((e) => e.data, 'data', data),
);

void main() {
  group('SplitKind', () {
    test('SplitKind.parse returns the kind when the stored name is known', () {
      for (final kind in SplitKind.values) {
        expect(SplitKind.parse(kind.name), kind);
      }
      expect(SplitKind.values.map((k) => k.name), [
        'equal',
        'exact',
        'percent',
        'shares',
        'adjust',
      ]);
    });

    test('SplitKind.parse throws UNKNOWN_SPLIT when the name is unknown', () {
      expect(() => SplitKind.parse('itemized'), _code('UNKNOWN_SPLIT'));
      expect(() => SplitKind.parse('Equal'), _code('UNKNOWN_SPLIT'));
    });
  });

  group('split', () {
    test('split returns shares in members order when members are not sorted', () {
      final out = split(10000, SplitKind.equal, ['C', 'A', 'B']);
      expect(out.keys.toList(), ['C', 'A', 'B']);
      expect(out, {'C': 3334, 'A': 3333, 'B': 3333});
    });

    test('split result is read-only', () {
      final out = split(100, SplitKind.equal, abc);
      expect(() => out['A'] = 1, throwsUnsupportedError);
    });

    test('split ignores values when kind is equal', () {
      expect(split(300, SplitKind.equal, abc, {'A': 999}), {'A': 100, 'B': 100, 'C': 100});
    });

    test('split ignores values of non-members when they are left in the editor state', () {
      expect(split(10000, SplitKind.exact, ['A', 'B'], {'A': 6000, 'B': 4000, 'Z': 50}), {
        'A': 6000,
        'B': 4000,
      });
    });

    test('split treats missing values as 0 when a member has no entry', () {
      expect(split(10000, SplitKind.exact, abc, {'A': 10000}), {'A': 10000, 'B': 0, 'C': 0});
      expect(split(10000, SplitKind.shares, abc, {'B': 1000}), {'A': 0, 'B': 10000, 'C': 0});
    });

    test('split throws DUPLICATE_MEMBER when a member is listed twice', () {
      expect(
        () => split(100, SplitKind.equal, ['A', 'A']),
        _code('DUPLICATE_MEMBER', {'member': 'A'}),
      );
    });

    test('split checks the total before the members when both are invalid', () {
      expect(() => split(0, SplitKind.equal, []), _code('AMOUNT_NOT_POSITIVE'));
      expect(() => split(-1, SplitKind.equal, abc), _code('AMOUNT_NOT_POSITIVE'));
      expect(() => split(maxAmount, SplitKind.equal, abc), returnsNormally);
    });

    test('split exact reports money over when amounts exceed the total', () {
      expect(
        () => split(10000, SplitKind.exact, abc, {'A': 6000, 'B': 3000, 'C': 2000}),
        _code('SUM_MISMATCH', {'remaining': -1000}),
      );
    });

    test('split exact checks negatives before the sum when both are wrong', () {
      expect(() => split(10000, SplitKind.exact, abc, {'A': -1}), _code('NEGATIVE_SHARE'));
    });

    test('split throws AMOUNT_TOO_LARGE when a value is beyond ±maxAmount', () {
      const huge = maxAmount + 1;
      expect(() => split(100, SplitKind.exact, abc, {'A': huge}), _code('AMOUNT_TOO_LARGE'));
      expect(() => split(100, SplitKind.shares, abc, {'A': huge}), _code('AMOUNT_TOO_LARGE'));
      expect(() => split(100, SplitKind.adjust, abc, {'A': -huge}), _code('AMOUNT_TOO_LARGE'));
    });

    test('split percent throws PERCENT_OUT_OF_RANGE when a value is below 0 or above 100 %', () {
      expect(
        () => split(10000, SplitKind.percent, abc, {'A': 10001, 'B': -1}),
        _code('PERCENT_OUT_OF_RANGE'),
      );
      expect(() => split(10000, SplitKind.percent, abc, {'A': -5}), _code('PERCENT_OUT_OF_RANGE'));
    });

    test('split percent reports basis points left when the sum is below 100 %', () {
      expect(
        () => split(10000, SplitKind.percent, abc, {'A': 5000, 'B': 2500}),
        _code('PERCENT_SUM_MISMATCH', {'remaining_bps': 2500}),
      );
    });

    test('split percent keeps every share within one unit when percentages have decimals', () {
      // 33.33 % / 33.33 % / 33.34 % of ₹1.00
      expect(split(100, SplitKind.percent, abc, {'A': 3333, 'B': 3333, 'C': 3334}), {
        'A': 33,
        'B': 33,
        'C': 34,
      });
    });

    test('split shares throws NEGATIVE_SHARE when a share count is negative', () {
      expect(
        () => split(10000, SplitKind.shares, abc, {'A': 2000, 'B': -1000}),
        _code('NEGATIVE_SHARE'),
      );
    });

    test('split shares throws NO_SHARES when no value is given', () {
      expect(() => split(10000, SplitKind.shares, abc), _code('NO_SHARES'));
    });

    test('split adjust splits the rest equally when there are no adjustments', () {
      expect(split(10000, SplitKind.adjust, abc), {'A': 3334, 'B': 3333, 'C': 3333});
    });

    test('split adjust gives the whole total to one member when adjustments use it all', () {
      expect(split(10000, SplitKind.adjust, abc, {'A': 10000}), {'A': 10000, 'B': 0, 'C': 0});
    });

    test('split adjust allows a negative adjustment when the share stays at or above 0', () {
      // rest = 9000 + 3000 = 12000 -> 4000 each; B: 4000 − 4000 = 0
      expect(split(9000, SplitKind.adjust, abc, {'B': -4000, 'C': 1000}), {
        'A': 4000,
        'B': 0,
        'C': 5000,
      });
    });

    test('split throws NO_PARTICIPANTS for every kind when members is empty', () {
      for (final kind in SplitKind.values) {
        expect(() => split(100, kind, const []), _code('NO_PARTICIPANTS'));
      }
    });
  });

  // TC-10-01
  group('checkPayers', () {
    test('checkPayers passes when one or more payers add up to the total', () {
      checkPayers(10000, {'A': 10000});
      checkPayers(10000, {'A': 6000, 'B': 4000, 'C': 0});
    });

    test('checkPayers reports the amount over when payers paid too much', () {
      expect(
        () => checkPayers(10000, {'A': 6000, 'B': 5000}),
        _code('PAYERS_SUM_MISMATCH', {'remaining': -1000}),
      );
    });

    test('checkPayers throws INVALID_PAYERS when there is no payer or a negative amount', () {
      expect(() => checkPayers(10000, {}), _code('INVALID_PAYERS'));
      expect(() => checkPayers(10000, {'A': 11000, 'B': -1000}), _code('INVALID_PAYERS'));
    });

    test('checkPayers throws AMOUNT_TOO_LARGE when one payer is beyond maxAmount', () {
      expect(() => checkPayers(10000, {'A': maxAmount + 1}), _code('AMOUNT_TOO_LARGE'));
    });
  });
}
