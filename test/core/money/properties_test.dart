// Property tests of the money engine (planning/05-money-engine.md §8), 500 inputs each.
//
// TC-5..9-02  glados property tests (allocation, split)
// TC-17-01    simplify properties
// TC-15-01    pairwise nets equal nets
// TC-32-01    conversion properties
import 'package:decimal/decimal.dart';
import 'package:glados/glados.dart';
import 'package:splitify/core/money/allocation.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/money/fx.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/core/money/split.dart';

final _explore = ExploreConfig(numRuns: 500);

/// A generator from a plain random function (no shrinking: failures print the whole case).
Generator<T> _gen<T>(T Function(Random r) f) =>
    any.simple(generate: (r, _) => f(r), shrink: (_) => const []);

/// Roughly uniform int in [0, max] for any max up to 2^62.
int _upTo(Random r, int max) {
  if (max < (1 << 32)) return r.nextInt(max + 1);
  final v = (r.nextInt(1 << 30) << 32) | r.nextInt(1 << 32);
  return v % (max + 1);
}

/// Amount in [1, maxAmount] with a log-uniform size (1 paisa … ₹9,999 crore).
int _amount(Random r) {
  var hi = 1;
  for (var d = r.nextInt(13); d > 0; d--) {
    hi *= 10;
  }
  return 1 + _upTo(r, (hi < maxAmount ? hi : maxAmount) - 1);
}

/// 1…[max] member ids in a shuffled fixed order (so it differs from sorted order).
List<String> _members(Random r, int max) {
  final n = 1 + r.nextInt(max);
  return [for (var i = 0; i < n; i++) 'm$i']..shuffle(r);
}

/// [n] non-negative parts summing to [total] (random cut points).
List<int> _partsOf(Random r, int total, int n) {
  final cuts = [for (var i = 0; i < n - 1; i++) _upTo(r, total)]..sort();
  final points = [0, ...cuts, total];
  return [for (var i = 0; i < n; i++) points[i + 1] - points[i]];
}

Map<String, int> _zip(List<String> ids, List<int> values) => {
  for (var i = 0; i < ids.length; i++) ids[i]: values[i],
};

int _sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);

typedef _SplitCase = ({int total, SplitKind kind, List<String> members, Map<String, int> values});

/// Valid split inputs for every kind.
_SplitCase _validSplit(Random r) {
  final total = _amount(r);
  final members = _members(r, r.nextInt(10) == 0 ? 100 : 12);
  final n = members.length;
  final kind = SplitKind.values[r.nextInt(SplitKind.values.length)];
  final values = switch (kind) {
    SplitKind.equal => <String, int>{},
    SplitKind.exact => _zip(members, _partsOf(r, total, n)),
    SplitKind.percent => _zip(members, _partsOf(r, 10000, n)),
    SplitKind.shares => _zip(members, [
      for (var i = 0; i < n; i++)
        if (i == 0) 1 + r.nextInt(5000) else r.nextInt(5001),
    ]),
    // Non-negative adjustments within the total are always valid.
    SplitKind.adjust => _zip(members, _partsOf(r, _upTo(r, total), n)),
  };
  return (total: total, kind: kind, members: members, values: values);
}

/// Arbitrary (often invalid) split inputs.
_SplitCase _rawSplit(Random r) {
  final members = _members(r, 8);
  final kind = SplitKind.values[r.nextInt(SplitKind.values.length)];
  final total = r.nextInt(20) == 0 ? -r.nextInt(100) : _amount(r);
  final values = {for (final m in members) m: r.nextInt(30001) - 10000};
  return (total: total, kind: kind, members: members, values: values);
}

typedef _Group = ({List<String> order, List<ExpenseFlow> expenses, List<Payment> payments});

/// Random balanced expenses (Σ paid = Σ shares = total) and payments in one currency.
_Group _group(Random r) {
  final order = _members(r, 8);
  List<String> subset() {
    final s = [
      for (final m in order)
        if (r.nextBool()) m,
    ];
    return s.isEmpty ? [order[r.nextInt(order.length)]] : s;
  }

  final expenseCount = 1 + r.nextInt(6);
  final paymentCount = order.length > 1 ? r.nextInt(5) : 0;
  final expenses = <ExpenseFlow>[
    for (var e = 0; e < expenseCount; e++)
      () {
        final total = _amount(r) ~/ (1 + r.nextInt(1000));
        final t = total < 1 ? 1 : total;
        final payers = subset();
        final sharers = subset();
        return ExpenseFlow(
          currency: 'INR',
          paid: _zip(payers, _partsOf(r, t, payers.length)),
          shares: _zip(sharers, _partsOf(r, t, sharers.length)),
        );
      }(),
  ];
  final payments = <Payment>[
    for (var p = 0; p < paymentCount; p++)
      () {
        final from = r.nextInt(order.length);
        final to = (from + 1 + r.nextInt(order.length - 1)) % order.length;
        return Payment(
          currency: 'INR',
          from: order[from],
          to: order[to],
          amount: 1 + r.nextInt(1000000),
        );
      }(),
  ];
  return (order: order, expenses: expenses, payments: payments);
}

const _codes = ['INR', 'USD', 'JPY', 'KWD', 'VND', 'BHD', 'EUR'];

/// A rate between 1e-10 and 1000 with 3 to 10 decimals (results stay inside 64-bit ints).
String _rate(Random r) {
  final scale = 3 + r.nextInt(8);
  final unscaled = 1 + _upTo(r, 999998);
  return Decimal.fromBigInt(BigInt.from(unscaled)).shift(-scale).toString();
}

void main() {
  // TC-5..9-02
  group('allocation properties', () {
    Glados(
      _gen((r) {
        final n = 1 + r.nextInt(r.nextBool() ? 5 : 60);
        return (
          total: r.nextInt(10) == 0 ? -_amount(r) : _amount(r),
          weights: [
            for (var i = 0; i < n; i++)
              if (r.nextInt(4) == 0) 0 else _upTo(r, 1000000),
          ],
        );
      }),
      _explore,
    ).test('allocateRatio parts sum to total and stay within one unit of the exact quota', (c) {
      if (_sum(c.weights) == 0) {
        expect(() => allocateRatio(c.total, c.weights), throwsA(isA<InvalidWeights>()));
        return;
      }
      final parts = allocateRatio(c.total, c.weights);
      expect(_sum(parts), c.total);
      final wSum = BigInt.from(_sum(c.weights));
      for (var i = 0; i < parts.length; i++) {
        if (c.weights[i] == 0) expect(parts[i], 0);
        // |part × Σw − total × w| < Σw
        final diff =
            BigInt.from(parts[i]) * wSum - BigInt.from(c.total) * BigInt.from(c.weights[i]);
        expect(diff.abs() < wSum, isTrue, reason: 'part $i too far from its quota');
      }
    });

    Glados(
      _gen((r) => (total: _amount(r), n: 1 + r.nextInt(100), w: 1 + r.nextInt(100000))),
      _explore,
    ).test('allocateEqual equals allocateRatio with equal weights', (c) {
      final equal = allocateEqual(c.total, c.n);
      expect(_sum(equal), c.total);
      expect(allocateRatio(c.total, List.filled(c.n, c.w)), equal);
      final members = [for (var i = 0; i < c.n; i++) 'x${c.n - i}'];
      expect(
        split(c.total, SplitKind.shares, members, {for (final m in members) m: c.w}),
        split(c.total, SplitKind.equal, members),
      );
    });
  });

  // TC-5..9-02
  group('split properties', () {
    Glados(_gen(_validSplit), _explore).test(
      'split parts sum to total and are never negative when inputs are valid',
      (c) {
        final out = split(c.total, c.kind, c.members, c.values);
        expect(out.keys.toList(), c.members);
        expect(_sum(out.values), c.total);
        expect(out.values.every((v) => v >= 0), isTrue);
      },
    );

    Glados(_gen(_rawSplit), _explore).test(
      'split either sums to total or throws a MoneyError when inputs are arbitrary',
      (c) {
        try {
          final out = split(c.total, c.kind, c.members, c.values);
          expect(_sum(out.values), c.total);
          expect(out.values.every((v) => v >= 0), isTrue);
        } on MoneyError catch (e) {
          expect(e.code, isNotEmpty);
        }
      },
    );

    Glados(_gen((r) => (c: _validSplit(r), seed: r.nextInt(1 << 30))), _explore).test(
      'split depends only on member list order when values map order and extra keys vary',
      (x) {
        final c = x.c;
        final base = split(c.total, c.kind, c.members, c.values);
        final keys = c.values.keys.toList()..shuffle(Random(x.seed));
        final shuffled = <String, int>{
          'not-a-member': 123456,
          for (final k in keys) k: c.values[k]!,
          'other-stranger': -5,
        };
        final again = split(c.total, c.kind, c.members, shuffled);
        expect(again, base);
        expect(again.keys.toList(), c.members);
      },
    );
  });

  // TC-17-01
  group('simplify properties', () {
    Glados(
      _gen((r) {
        final order = _members(r, 20);
        final big = r.nextBool();
        final values = [
          for (var i = 0; i < order.length - 1; i++)
            if (r.nextInt(3) == 0)
              0
            else
              (big ? _amount(r) ~/ 20 : r.nextInt(2001)) * (r.nextBool() ? 1 : -1),
        ];
        return (order: order, nets: _zip(order, [...values, -_sum(values)]));
      }),
      _explore,
    ).test('simplify keeps every net and gives at most n − 1 transfers', (c) {
      final transfers = simplify(c.order, c.nets);
      final after = {for (final m in c.order) m: 0};
      for (final t in transfers) {
        expect(t.amount, greaterThan(0));
        expect(t.from, isNot(t.to));
        after[t.from] = after[t.from]! - t.amount;
        after[t.to] = after[t.to]! + t.amount;
      }
      expect(after, c.nets);
      final nonZero = c.nets.values.where((v) => v != 0).length;
      expect(transfers.length, lessThanOrEqualTo(nonZero == 0 ? 0 : nonZero - 1));
      expect(transfers.length, lessThanOrEqualTo(c.order.length - 1));
      // Deterministic, and independent of the nets map's iteration order.
      final reversed = Map.fromEntries(c.nets.entries.toList().reversed);
      expect(simplify(c.order, reversed), transfers);
    });
  });

  // TC-15-01
  group('pairwise properties', () {
    Glados(_gen(_group), _explore).test('pairwise nets equal nets for balanced expenses', (g) {
      final n = nets(g.order, g.expenses, g.payments);
      expect(_sum(n.values), 0);
      final pairs = pairwise(g.order, g.expenses, g.payments);
      final fromPairs = {for (final m in g.order) m: 0};
      final seen = <String>{};
      for (final t in pairs) {
        expect(t.amount, greaterThan(0));
        final key = ([t.from, t.to]..sort()).join('|');
        expect(seen.add(key), isTrue, reason: 'one entry per pair');
        fromPairs[t.from] = fromPairs[t.from]! - t.amount;
        fromPairs[t.to] = fromPairs[t.to]! + t.amount;
      }
      expect(fromPairs, n);
      final b = Balances.compute(g.order, g.expenses, g.payments);
      expect(b.pairs, pairs);
      expect(b.nets, n);
    });
  });

  // TC-32-01
  group('conversion properties', () {
    Glados(
      _gen((r) {
        int amount() => (r.nextBool() ? 1 : -1) * (r.nextInt(5) == 0 ? r.nextInt(10) : _amount(r));
        return (
          a: amount(),
          b: amount(),
          from: _codes[r.nextInt(_codes.length)],
          to: _codes[r.nextInt(_codes.length)],
          rate: _rate(r),
        );
      }),
      _explore,
    ).test('convert is monotonic in amount and symmetric around zero', (c) {
      final lo = c.a < c.b ? c.a : c.b;
      final hi = c.a < c.b ? c.b : c.a;
      expect(
        convert(lo, c.from, c.to, c.rate),
        lessThanOrEqualTo(convert(hi, c.from, c.to, c.rate)),
      );
      expect(convert(-c.a, c.from, c.to, c.rate), -convert(c.a, c.from, c.to, c.rate));
      expect(convert(0, c.from, c.to, c.rate), 0);
    });

    Glados(
      _gen((r) {
        final order = _members(r, 8);
        final total = _amount(r) ~/ (1 + r.nextInt(1000)) + 1;
        return (
          total: total,
          order: order,
          paid: _zip(order, _partsOf(r, total, order.length)),
          shares: _zip(order, _partsOf(r, total, order.length)),
          from: _codes[r.nextInt(_codes.length)],
          to: _codes[r.nextInt(_codes.length)],
          rate: _rate(r),
        );
      }),
      _explore,
    ).test('convertExpense parts sum to the converted total', (c) {
      final t = convert(c.total, c.from, c.to, c.rate);
      ConvertedExpense run() => convertExpense(
        total: c.total,
        from: c.from,
        to: c.to,
        rate: c.rate,
        paid: c.paid,
        shares: c.shares,
        order: c.order,
      );
      if (t < 1 || t > maxAmount) {
        expect(run, throwsA(isA<MoneyError>()));
        return;
      }
      final out = run();
      expect(out.total, t);
      expect(_sum(out.paid.values), t);
      expect(_sum(out.shares.values), t);
      expect(out.shares.keys.toList(), c.order);
    });
  });
}
