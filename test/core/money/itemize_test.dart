// Itemized split (D-034 A2): vectors + glados properties (500 inputs each).
// TC-D034-A2-01 vectors (acceptance: ₹1,000 bill, ₹100 between three)
// TC-D034-A2-02 properties: parts add up to the total, never negative, fixed rounding order
import 'package:glados/glados.dart';
import 'package:splitify/core/money/itemize.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_error.dart';

final _explore = ExploreConfig(numRuns: 500);

Generator<T> _gen<T>(T Function(Random r) f) =>
    any.simple(generate: (r, _) => f(r), shrink: (_) => const []);

int _sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);

typedef _Case = ({List<String> order, List<ItemLine> items, ItemExtras extras});

/// A random bill: 1–8 people in a shuffled fixed order, 1–12 lines each shared by 1+ people, extras.
_Case _bill(Random r) {
  final n = 1 + r.nextInt(8);
  final order = [for (var i = 0; i < n; i++) 'm$i']..shuffle(r);
  final items = <ItemLine>[
    for (var i = 0, k = 1 + r.nextInt(12); i < k; i++)
      (
        amount: r.nextInt(5) == 0 ? r.nextInt(10) : r.nextInt(5000000),
        members: (List.of(order)..shuffle(r)).take(1 + r.nextInt(n)).toList(),
      ),
  ];
  final lines = _sum([for (final i in items) i.amount]);
  return (
    order: order,
    items: items,
    extras: (
      tax: r.nextBool() ? r.nextInt(500000) : 0,
      service: r.nextBool() ? r.nextInt(300000) : 0,
      tip: r.nextInt(3) == 0 ? r.nextInt(100000) : 0,
      // Up to the whole bill (sometimes all of it).
      discount: r.nextInt(3) == 0 ? r.nextInt(lines + 1) : 0,
    ),
  );
}

void main() {
  group('itemize vectors', () {
    test('acceptance: ₹1,000 = 400 (A) + 350 (A, B) + 150 (B) + ₹100 tax', () {
      final shares = itemize(
        ['a', 'b'],
        [
          (amount: 40000, members: ['a']),
          (amount: 35000, members: ['a', 'b']),
          (amount: 15000, members: ['b']),
        ],
        (tax: 10000, service: 0, tip: 0, discount: 0),
      );
      // A's lines 575, B's 325; the ₹100 tax 575:325 → 63.89 + 36.11.
      expect(shares, {'a': 63889, 'b': 36111});
      expect(_sum(shares.values), 100000);
    });

    test('fixed rounding: ₹100 between three is 33.34 + 33.33 + 33.33 in member order', () {
      expect(
        itemize(
          ['x', 'y', 'z'],
          [
            (amount: 10000, members: ['z', 'y', 'x']),
          ],
        ),
        {'x': 3334, 'y': 3333, 'z': 3333},
      );
      // The order of the member list decides, not the order of the ticks.
      expect(
        itemize(
          ['z', 'x', 'y'],
          [
            (amount: 10000, members: ['x', 'y', 'z']),
          ],
        ),
        {'z': 3334, 'x': 3333, 'y': 3333},
      );
    });

    test('people without lines get 0 and no extras', () {
      final shares = itemize(
        ['a', 'b', 'c'],
        [
          (amount: 30000, members: ['a', 'b']),
        ],
        (tax: 1500, service: 3000, tip: 0, discount: 0),
      );
      expect(shares, {'a': 17250, 'b': 17250, 'c': 0});
    });

    test('discount comes off in proportion', () {
      final shares = itemize(
        ['a', 'b'],
        [
          (amount: 30000, members: ['a']),
          (amount: 10000, members: ['b']),
        ],
        (tax: 0, service: 0, tip: 0, discount: 4000),
      );
      expect(shares, {'a': 27000, 'b': 9000});
    });

    test('tax + service + tip − discount all together', () {
      final items = <ItemLine>[
        (amount: 25000, members: ['a', 'b', 'c']),
        (amount: 18000, members: ['b']),
        (amount: 9900, members: ['c']),
      ];
      const extras = (tax: 2645, service: 2645, tip: 2000, discount: 1000);
      final shares = itemize(['a', 'b', 'c'], items, extras);
      expect(_sum(shares.values), itemizedTotal(items, extras));
      expect(itemizedTotal(items, extras), 59190);
      // Lines a 83.34, b 263.33, c 182.33; the ₹62.90 of extras by 8334:26333:18233.
      expect(shares, {'a': 9325, 'b': 29464, 'c': 20401});
    });

    test('a discount equal to the whole bill leaves 0 → AMOUNT_NOT_POSITIVE', () {
      expect(
        () => itemize(
          ['a'],
          [
            (amount: 500, members: ['a']),
          ],
          (tax: 0, service: 0, tip: 0, discount: 500),
        ),
        throwsA(isA<AmountNotPositive>()),
      );
    });

    test('a discount bigger than the lines and extras is NEGATIVE_SHARE', () {
      expect(
        () => itemize(
          ['a', 'b'],
          [
            (amount: 500, members: ['a']),
          ],
          (tax: 100, service: 0, tip: 0, discount: 700),
        ),
        throwsA(isA<NegativeShare>()),
      );
    });

    test('errors', () {
      expect(() => itemize(const [], const []), throwsA(isA<NoParticipants>()));
      expect(
        () => itemize(['a'], [(amount: 100, members: <String>[])]),
        throwsA(isA<NoParticipants>()),
      );
      expect(
        () => itemize(
          ['a'],
          [
            (amount: 100, members: ['zz']),
          ],
        ),
        throwsA(isA<UnknownMember>()),
      );
      expect(
        () => itemize(
          ['a', 'a'],
          [
            (amount: 100, members: ['a']),
          ],
        ),
        throwsA(isA<DuplicateMember>()),
      );
      expect(
        () => itemize(
          ['a', 'b'],
          [
            (amount: 100, members: ['a', 'a']),
          ],
        ),
        throwsA(isA<DuplicateMember>()),
      );
      expect(() => itemize(['a'], const []), throwsA(isA<NoShares>()));
      expect(
        () => itemize(
          ['a'],
          [
            (amount: 0, members: ['a']),
          ],
          (tax: 100, service: 0, tip: 0, discount: 0),
        ),
        throwsA(isA<NoShares>()),
      );
      expect(
        () => itemize(
          ['a'],
          [
            (amount: -1, members: ['a']),
          ],
        ),
        throwsA(isA<NegativeShare>()),
      );
      expect(
        () => itemize(
          ['a'],
          [
            (amount: 100, members: ['a']),
          ],
          (tax: -1, service: 0, tip: 0, discount: 0),
        ),
        throwsA(isA<NegativeShare>()),
      );
      expect(
        () => itemize(
          ['a'],
          [
            (amount: maxAmount + 1, members: ['a']),
          ],
        ),
        throwsA(isA<AmountTooLarge>()),
      );
      expect(
        () => itemize(
          ['a'],
          [
            (amount: maxAmount, members: ['a']),
          ],
          (tax: 1, service: 0, tip: 0, discount: 0),
        ),
        throwsA(isA<AmountTooLarge>()),
      );
      expect(
        () => itemizedTotal(const [], (tax: -5, service: 0, tip: 0, discount: 0)),
        throwsA(isA<NegativeShare>()),
      );
    });
  });

  group('itemize properties', () {
    Glados(_gen(_bill), _explore).test(
      'parts add up to the total, nobody below 0, people without lines get 0',
      (c) {
        final total = itemizedTotal(c.items, c.extras);
        final lines = _sum([for (final i in c.items) i.amount]);
        late final Map<String, int> shares;
        try {
          shares = itemize(c.order, c.items, c.extras);
        } on MoneyError catch (e) {
          // Only a bill that comes to nothing (or has no line with an amount) is refused.
          expect(lines == 0 || total <= 0, isTrue, reason: '${e.code} for $c');
          return;
        }
        expect(_sum(shares.values), total);
        expect(shares.keys.toList(), c.order);
        expect(shares.values.every((s) => s >= 0), isTrue);
        final onLines = {for (final i in c.items) ...i.members};
        for (final id in c.order) {
          if (!onLines.contains(id)) expect(shares[id], 0);
        }
      },
    );

    Glados(
      _gen(_bill),
      _explore,
    ).test('extras are within one unit of the exact proportional amount', (c) {
      final total = itemizedTotal(c.items, c.extras);
      final lines = _sum([for (final i in c.items) i.amount]);
      if (lines == 0 || total <= 0) return;
      final noExtras = itemize(c.order, c.items);
      final shares = itemize(c.order, c.items, c.extras);
      final net = total - lines;
      for (final id in c.order) {
        final extra = shares[id]! - noExtras[id]!;
        // |extra × lines − net × subtotal| < lines
        final diff =
            BigInt.from(extra) * BigInt.from(lines) - BigInt.from(net) * BigInt.from(noExtras[id]!);
        expect(diff.abs() < BigInt.from(lines), isTrue, reason: '$id in $c');
      }
    });

    Glados(_gen(_bill), _explore).test(
      'one line shared by everyone without extras is an equal split in fixed order',
      (c) {
        final amount = 1 + _sum([for (final i in c.items) i.amount]);
        final shares = itemize(c.order, [(amount: amount, members: c.order.reversed.toList())]);
        final base = amount ~/ c.order.length;
        final rest = amount % c.order.length;
        for (var i = 0; i < c.order.length; i++) {
          expect(shares[c.order[i]], i < rest ? base + 1 : base);
        }
      },
    );
  });
}
