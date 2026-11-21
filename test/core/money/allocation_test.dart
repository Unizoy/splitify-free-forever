// TC-5..9-01 (allocation behind every split kind)
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/allocation.dart';
import 'package:splitify/core/money/money_error.dart';

void main() {
  group('fixedOrderIndex', () {
    test('fixedOrderIndex maps ids to positions when ids are unique', () {
      expect(fixedOrderIndex(['C', 'A', 'B']), {'C': 0, 'A': 1, 'B': 2});
      expect(fixedOrderIndex([]), isEmpty);
    });

    test('fixedOrderIndex throws DUPLICATE_MEMBER when an id repeats', () {
      expect(
        () => fixedOrderIndex(['A', 'B', 'A']),
        throwsA(isA<DuplicateMember>().having((e) => e.member, 'member', 'A')),
      );
    });

    test('checkKnownMembers throws UNKNOWN_MEMBER when an id is not in the order', () {
      final index = fixedOrderIndex(['A', 'B']);
      checkKnownMembers(index, ['B', 'A']);
      expect(
        () => checkKnownMembers(index, ['A', 'Z']),
        throwsA(isA<UnknownMember>().having((e) => e.data, 'data', {'member': 'Z'})),
      );
    });
  });

  group('allocateEqual', () {
    test('allocateEqual gives leftover units to the first members when total is not divisible', () {
      expect(allocateEqual(10000, 3), [3334, 3333, 3333]);
      expect(allocateEqual(2, 3), [1, 1, 0]);
      expect(allocateEqual(0, 2), [0, 0]);
      expect(allocateEqual(7, 1), [7]);
    });

    test('allocateEqual floors like divmod when the total is negative', () {
      // Python: divmod(-10, 3) == (-4, 2) -> [-3, -3, -4]
      expect(allocateEqual(-10, 3), [-3, -3, -4]);
      expect(allocateEqual(-9, 3), [-3, -3, -3]);
    });

    test('allocateEqual throws NO_PARTICIPANTS when n is 0', () {
      expect(() => allocateEqual(100, 0), throwsA(isA<NoParticipants>()));
      expect(() => allocateEqual(100, -1), throwsA(isA<NoParticipants>()));
    });
  });

  group('allocateRatio', () {
    test('allocateRatio gives leftovers to the largest remainders when quotas are fractional', () {
      // 10000 × (1500, 1000, 500) / 3000 = 5000, 3333.33, 1666.67 -> C has the larger remainder.
      expect(allocateRatio(10000, [1500, 1000, 500]), [5000, 3333, 1667]);
      // 7 × (1, 2) / 3 = 2.33, 4.67
      expect(allocateRatio(7, [1, 2]), [2, 5]);
    });

    test('allocateRatio breaks remainder ties by fixed order when remainders are equal', () {
      expect(allocateRatio(100, [1, 1, 1]), [34, 33, 33]);
      expect(allocateRatio(5, [2, 2, 2, 2]), [2, 1, 1, 1]);
    });

    test('allocateRatio gives zero weights nothing when others have weight', () {
      expect(allocateRatio(10, [0, 1, 0, 2]), [0, 3, 0, 7]);
      expect(allocateRatio(1, [0, 0, 5]), [0, 0, 1]);
    });

    test('allocateRatio keeps exact quotas when total × weight exceeds 64 bits', () {
      // 999 999 999 999 × 9 000 000 000 overflows int64; BigInt keeps it exact.
      final parts = allocateRatio(999999999999, [9000000000, 9000000000, 9000000001]);
      expect(parts.fold(0, (a, b) => a + b), 999999999999);
      // Same as the Python oracle.
      expect(parts, [333333333321, 333333333320, 333333333358]);
    });

    test('allocateRatio floors like the oracle when the total is negative', () {
      // Fractions: -10/3 -> floor -4 (rem 2/3), -20/3 -> floor -7 (rem 1/3); one unit left -> first.
      expect(allocateRatio(-10, [1, 2]), [-3, -7]);
    });

    test('allocateRatio throws INVALID_WEIGHTS when weights are negative, all zero or empty', () {
      expect(() => allocateRatio(100, [1, -1, 3]), throwsA(isA<InvalidWeights>()));
      expect(() => allocateRatio(100, [0, 0]), throwsA(isA<InvalidWeights>()));
      expect(() => allocateRatio(100, []), throwsA(isA<InvalidWeights>()));
    });
  });
}
