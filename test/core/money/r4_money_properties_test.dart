// R4 robustness: money properties the earlier suites don't pin down (planning/05-money-engine.md, rules 1-4, 12).
// Seeded random loops (thousands of cases each, the seed and case go in every failure reason):
//
// TC-R4-M-01  rounding order (rule 2): leftovers one each to the first members in fixed order, ties too
// TC-R4-M-02  every split kind in groups of up to 50 members, from 1 minor unit to maxAmount
// TC-R4-M-03  adjust = equal part of the rest + the adjustment; never a negative share
// TC-R4-M-04  int64 edges: too large is rejected (AMOUNT_TOO_LARGE), never wrapped
// TC-R4-M-05  conversions with saved rates match an exact BigInt oracle; trailing zeros change nothing
// TC-R4-M-06  converted parts stay within one unit of their exact share; round trip stays close
// TC-R4-M-07  simplify never changes anyone's net on 50-member groups with huge amounts (rule 12)
// TC-R4-M-08  30 currencies: balances per currency equal a brute-force sum, never mixed (rule 4)
// TC-R4-M-09  overall = sum of per-group balances = sum of per-person balances, ad-hoc groups too (rule 3)
// TC-R4-M-10  batch settle per currency with 50 groups and big balances
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/allocation.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/fx.dart';
import 'package:splitify/core/money/itemize.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/friends/application/friend_identity.dart';
import 'package:splitify/features/payments/application/batch_allocation.dart';

/// 30 currencies of the table: the 0- and 3-decimal ones plus common 2-decimal ones.
const r4Currencies = [
  'INR',
  'USD',
  'EUR',
  'GBP',
  'AED',
  'SGD',
  'THB',
  'AUD',
  'CAD',
  'CHF',
  'CNY',
  'HKD',
  'NZD',
  'ZAR', //
  'BRL',
  'MXN',
  'TRY',
  'IDR',
  'PHP',
  'NPR',
  'LKR',
  'JPY',
  'KRW',
  'VND',
  'CLP',
  'ISK',
  'KWD',
  'BHD', //
  'OMR', 'JOD', 'TND',
];

int _sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);

/// Roughly uniform int in [0, max] for any max up to 2^62.
int _upTo(Random r, int max) {
  if (max < (1 << 32)) return r.nextInt(max + 1);
  final v = (r.nextInt(1 << 30) << 32) | r.nextInt(1 << 32);
  return v % (max + 1);
}

/// Amount in [1, max] with a log-uniform size (1 minor unit … max).
int _amount(Random r, [int max = maxAmount]) {
  var hi = 1;
  for (var d = r.nextInt(13); d > 0; d--) {
    hi *= 10;
  }
  return 1 + _upTo(r, (hi < max ? hi : max) - 1);
}

/// [n] non-negative parts summing to [total].
List<int> _partsOf(Random r, int total, int n) {
  final cuts = [for (var i = 0; i < n - 1; i++) _upTo(r, total)]..sort();
  final points = [0, ...cuts, total];
  return [for (var i = 0; i < n; i++) points[i + 1] - points[i]];
}

/// Member ids in a fixed order that is NOT their sorted order.
List<String> _members(Random r, int n) => [for (var i = 0; i < n; i++) 'p${(i * 7919) % 1000}-$i'];

Map<String, int> _zip(List<String> ids, List<int> values) => {
  for (var i = 0; i < ids.length; i++) ids[i]: values[i],
};

/// A random lower-case UUID text.
String _uuid(Random r) {
  const hex = '0123456789abcdef';
  final b = StringBuffer();
  for (var i = 0; i < 32; i++) {
    if (i == 8 || i == 12 || i == 16 || i == 20) b.write('-');
    b.write(hex[r.nextInt(16)]);
  }
  return '$b';
}

/// sign(n / d) × ⌊|n / d| + ½⌋ for d > 0 (the spec's half-away-from-zero, written independently).
BigInt _roundHalfAway(BigInt n, BigInt d) {
  final q = n.abs() ~/ d;
  final rem = n.abs() - q * d;
  final up = rem * BigInt.two >= d ? q + BigInt.one : q;
  return n.isNegative ? -up : up;
}

/// A decimal rate text with 0–10 decimals, > 0, between about 1e-10 and 1e7.
String _rateText(Random r) {
  final decimals = r.nextInt(11);
  final whole = switch (r.nextInt(4)) {
    0 => '0',
    1 => '${r.nextInt(10)}',
    2 => '${r.nextInt(1000)}',
    _ => '${r.nextInt(10000000)}',
  };
  final frac = [for (var i = 0; i < decimals; i++) r.nextInt(10)].join();
  final text = decimals == 0 ? whole : '$whole.$frac';
  // Never 0.
  return RegExp('[1-9]').hasMatch(text) ? text : '1';
}

/// numerator / denominator of a plain decimal text.
(BigInt, BigInt) _fraction(String text) {
  final dot = text.indexOf('.');
  if (dot < 0) return (BigInt.parse(text), BigInt.one);
  final frac = text.substring(dot + 1);
  return (BigInt.parse(text.substring(0, dot) + frac), BigInt.from(10).pow(frac.length));
}

/// The exact conversion oracle: amount × rate × 10^(exp(to) − exp(from)), rounded half away from zero.
BigInt _convertOracle(int amount, String from, String to, String rate) {
  final (rn, rd) = _fraction(rate);
  final shift = Currencies.exponentOf(to) - Currencies.exponentOf(from);
  var n = BigInt.from(amount) * rn;
  var d = rd;
  if (shift >= 0) {
    n *= BigInt.from(10).pow(shift);
  } else {
    d *= BigInt.from(10).pow(-shift);
  }
  return _roundHalfAway(n, d);
}

LocalGroup _group(String id, {String type = 'trip', bool simplify = false}) => LocalGroup(
  id: id,
  name: 'G $id',
  type: type,
  mainCurrency: 'INR',
  coverKind: 'generated',
  simplifyDebts: simplify,
  seq: 1,
  syncState: 'synced',
);

LocalMember _member(String id, String groupId, int position, {String? userId}) => LocalMember(
  id: id,
  groupId: groupId,
  userId: userId,
  displayName: 'N $id',
  position: position,
  role: position == 0 ? 'owner' : 'member',
  status: 'active',
  seq: 1,
  syncState: 'synced',
);

LocalExpense _expense(
  String id,
  String groupId,
  String currency,
  Map<String, int> paid,
  Map<String, int> owed,
) => LocalExpense(
  id: id,
  groupId: groupId,
  kind: 'expense',
  description: 'E $id',
  category: 'other.general',
  date: '2026-11-20',
  currency: currency,
  total: _sum(paid.values),
  payers: jsonEncode(paid),
  shares: jsonEncode(owed),
  splitKind: 'exact',
  source: 'app',
  seq: 1,
  syncState: 'synced',
);

LocalPayment _payment(
  String id,
  String groupId,
  String currency,
  String from,
  String to,
  int amount,
) => LocalPayment(
  id: id,
  groupId: groupId,
  fromMember: from,
  toMember: to,
  amount: amount,
  currency: currency,
  date: '2026-11-20',
  method: 'cash',
  seq: 1,
  syncState: 'synced',
);

void main() {
  test('the 30+ test currencies are all in the table, with 0-, 2- and 3-decimal ones', () {
    for (final c in r4Currencies) {
      expect(Currencies.all.containsKey(c), isTrue, reason: c);
    }
    final exponents = {for (final c in r4Currencies) Currencies.exponentOf(c)};
    expect(exponents, {0, 2, 3});
  });

  // TC-R4-M-01
  group('rounding order (rule 2)', () {
    test('₹100 between three is 33.34 + 33.33 + 33.33 in member order, whatever the ids', () {
      for (final order in [
        ['a', 'b', 'c'],
        ['c', 'b', 'a'],
        ['zz', 'aa', 'mm'],
      ]) {
        expect(split(10000, SplitKind.equal, order).values.toList(), [3334, 3333, 3333]);
      }
    });

    test('1 paisa among 50 goes to the first member; 49 paise to the first 49', () {
      final m = _members(Random(1), 50);
      final one = split(1, SplitKind.equal, m);
      expect(one[m.first], 1);
      expect(_sum(one.values), 1);
      expect(one.values.skip(1).every((v) => v == 0), isTrue);
      final many = split(49, SplitKind.equal, m);
      expect(many.values.take(49).every((v) => v == 1), isTrue);
      expect(many[m.last], 0);
    });

    test('equal split: parts never increase along the fixed order and differ by at most one', () {
      final r = Random(4101);
      for (var k = 0; k < 4000; k++) {
        final n = 1 + r.nextInt(50);
        final total = r.nextInt(3) == 0 ? 1 + r.nextInt(n * 2) : _amount(r);
        final m = _members(r, n);
        final parts = split(total, SplitKind.equal, m).values.toList();
        final reason = 'case $k: $total / $n';
        expect(_sum(parts), total, reason: reason);
        for (var i = 1; i < n; i++) {
          expect(parts[i] <= parts[i - 1], isTrue, reason: reason);
        }
        expect(parts.first - parts.last <= 1, isTrue, reason: reason);
        expect(parts.where((p) => p == parts.last + 1).length, total % n, reason: reason);
      }
    });

    test(
      'percent and shares: each part is its floor quota or one more; ties go to the earlier member',
      () {
        final r = Random(4102);
        for (var k = 0; k < 3000; k++) {
          final n = 1 + r.nextInt(50);
          final m = _members(r, n);
          final total = _amount(r);
          final percent = r.nextBool();
          // Repeated weights make ties likely.
          final pool = [for (var i = 0; i < 3; i++) 1 + r.nextInt(5000)];
          final weights = percent
              ? _partsOf(r, 10000, n)
              : [for (var i = 0; i < n; i++) pool[r.nextInt(pool.length)]];
          final kind = percent ? SplitKind.percent : SplitKind.shares;
          final parts = split(total, kind, m, _zip(m, weights)).values.toList();
          final wSum = BigInt.from(_sum(weights));
          final reason = 'case $k: $total by $weights';
          expect(_sum(parts), total, reason: reason);
          final rems = <BigInt>[];
          final extra = <bool>[];
          for (var i = 0; i < n; i++) {
            final quota = BigInt.from(total) * BigInt.from(weights[i]);
            final floor = quota ~/ wSum;
            final got = BigInt.from(parts[i]);
            expect(got == floor || got == floor + BigInt.one, isTrue, reason: '$reason, member $i');
            rems.add(quota % wSum);
            extra.add(got != floor);
          }
          // Largest remainder first; equal remainders by fixed order.
          for (var i = 0; i < n; i++) {
            for (var j = 0; j < n; j++) {
              if (extra[j] && !extra[i]) {
                final c = rems[j].compareTo(rems[i]);
                expect(
                  c > 0 || (c == 0 && j < i),
                  isTrue,
                  reason: '$reason: $j got a unit before $i',
                );
              }
            }
          }
        }
      },
    );

    test('itemized line between people uses the fixed member order, not the order ticked', () {
      final m = _members(Random(2), 5);
      final ticked = [m[4], m[0], m[2]];
      final shares = itemize(m, [(amount: 10000, members: ticked)]);
      expect([shares[m[0]], shares[m[2]], shares[m[4]]], [3334, 3333, 3333]);
    });
  });

  // TC-R4-M-02
  group('every split kind, groups up to 50 members', () {
    test('parts sum to the total, never below 0, keys in member order', () {
      final r = Random(4103);
      final counts = {for (final k in SplitKind.values) k: 0};
      for (var k = 0; k < 5000; k++) {
        final n = 1 + r.nextInt(50);
        final m = _members(r, n);
        final total = r.nextInt(4) == 0 ? 1 + r.nextInt(100) : _amount(r);
        final kind = SplitKind.values[k % SplitKind.values.length];
        final values = switch (kind) {
          SplitKind.equal => <String, int>{},
          SplitKind.exact => _zip(m, _partsOf(r, total, n)),
          SplitKind.percent => _zip(m, _partsOf(r, 10000, n)),
          SplitKind.shares => _zip(m, [
            for (var i = 0; i < n; i++)
              if (i == 0) 1 + r.nextInt(9000) else r.nextInt(9001),
          ]),
          SplitKind.adjust => _zip(m, _partsOf(r, _upTo(r, total), n)),
        };
        final out = split(total, kind, m, values);
        final reason = 'case $k ($kind, $total over $n)';
        expect(out.keys.toList(), m, reason: reason);
        expect(_sum(out.values), total, reason: reason);
        expect(out.values.every((v) => v >= 0), isTrue, reason: reason);
        if (kind == SplitKind.exact) expect(out, values, reason: reason);
        counts[kind] = counts[kind]! + 1;
      }
      expect(counts.values.every((c) => c >= 1000), isTrue);
    });

    test('payers that add up pass; any other sum reports exactly what is left', () {
      final r = Random(4104);
      for (var k = 0; k < 3000; k++) {
        final n = 1 + r.nextInt(50);
        final m = _members(r, n);
        final total = _amount(r);
        final paid = _zip(m, _partsOf(r, total, n));
        checkPayers(total, paid);
        final off = 1 + r.nextInt(1000);
        final who = m[r.nextInt(n)];
        final wrong = {...paid, who: paid[who]! + off};
        expect(
          () => checkPayers(total, wrong),
          throwsA(isA<PayersSumMismatch>().having((e) => e.remaining, 'remaining', -off)),
        );
      }
    });

    test('itemize with 50 people and 40 lines: parts sum, nobody below 0', () {
      final r = Random(4105);
      for (var k = 0; k < 500; k++) {
        final m = _members(r, 1 + r.nextInt(50));
        List<String> people() {
          final some = [
            for (final x in m)
              if (r.nextInt(3) == 0) x,
          ];
          return some.isEmpty ? [m[r.nextInt(m.length)]] : some;
        }

        final lines = <ItemLine>[
          for (var i = 0; i < 1 + r.nextInt(40); i++)
            (amount: r.nextInt(5) == 0 ? 0 : _amount(r, 100000000), members: people()),
        ];
        final extras = (
          tax: r.nextInt(100000),
          service: r.nextInt(50000),
          tip: r.nextInt(20000),
          discount: r.nextInt(30000),
        );
        try {
          final out = itemize(m, lines, extras);
          expect(_sum(out.values), itemizedTotal(lines, extras), reason: 'case $k');
          expect(out.values.every((v) => v >= 0), isTrue, reason: 'case $k');
        } on MoneyError catch (e) {
          expect(
            e,
            anyOf(
              isA<NoShares>(),
              isA<NegativeShare>(),
              isA<AmountNotPositive>(),
              isA<AmountTooLarge>(),
            ),
            reason: 'case $k',
          );
        }
      }
    });
  });

  // TC-R4-M-03
  group('adjust', () {
    test('each share is the equal part of the rest plus its adjustment, or a clean error', () {
      final r = Random(4106);
      var valid = 0;
      for (var k = 0; k < 4000; k++) {
        final n = 1 + r.nextInt(50);
        final m = _members(r, n);
        final total = _amount(r, 100000000);
        final adj = [
          for (var i = 0; i < n; i++)
            switch (r.nextInt(4)) {
              0 => 0,
              1 => -r.nextInt(total ~/ n + 2),
              _ => r.nextInt(total ~/ n + 2),
            },
        ];
        try {
          final out = split(total, SplitKind.adjust, m, _zip(m, adj)).values.toList();
          final equal = allocateEqual(total - _sum(adj), n);
          for (var i = 0; i < n; i++) {
            expect(out[i], equal[i] + adj[i], reason: 'case $k member $i');
            expect(out[i] >= 0, isTrue, reason: 'case $k member $i');
          }
          valid++;
        } on NegativeShare {
          expect(
            allocateEqual(total - _sum(adj), n).indexed.any((e) => e.$2 + adj[e.$1] < 0),
            isTrue,
          );
        } on AdjustmentsExceedTotal catch (e) {
          expect(e.over, _sum(adj) - total, reason: 'case $k');
        }
      }
      expect(valid, greaterThan(1000));
    });
  });

  // TC-R4-M-04
  group('int64 edges', () {
    const intMax = 9223372036854775807;
    const intMin = -9223372036854775807 - 1;

    test('totals outside 1 … maxAmount are rejected for every kind', () {
      for (final kind in SplitKind.values) {
        for (final t in [0, -1, maxAmount + 1, intMax, intMin]) {
          expect(
            () => split(t, kind, ['a', 'b'], const {'a': 1, 'b': 1}),
            throwsA(isA<MoneyError>()),
            reason: '$kind $t',
          );
        }
        expect(_sum(split(maxAmount, SplitKind.equal, ['a', 'b', 'c']).values), maxAmount);
      }
    });

    test(
      'per-member values beyond ±maxAmount are AMOUNT_TOO_LARGE, never wrapped into a valid sum',
      () {
        // intMax + intMax + 2 wraps to 0 in 64 bits: without the bound these would "sum" to the total.
        final m = ['a', 'b', 'c'];
        expect(
          () => split(2, SplitKind.exact, m, const {'a': intMax, 'b': intMax, 'c': 4}),
          throwsA(isA<AmountTooLarge>()),
        );
        expect(
          () => split(2, SplitKind.adjust, m, const {'a': intMax, 'b': intMax}),
          throwsA(isA<AmountTooLarge>()),
        );
        expect(
          () => split(2, SplitKind.shares, m, const {'a': intMax}),
          throwsA(isA<AmountTooLarge>()),
        );
        expect(
          () => checkPayers(2, const {'a': intMax, 'b': intMax, 'c': 4}),
          throwsA(isA<AmountTooLarge>()),
        );
        expect(
          () => itemize(m, const [
            (amount: intMax, members: ['a']),
          ]),
          throwsA(isA<AmountTooLarge>()),
        );
      },
    );

    test('a bill or a 100-member split at the limits stays exact', () {
      final m = _members(Random(3), 100);
      final out = split(maxAmount, SplitKind.shares, m, {for (final x in m) x: 999999});
      expect(_sum(out.values), maxAmount);
      final lines = [for (var i = 0; i < 40; i++) (amount: maxAmount, members: m)];
      expect(() => itemize(m, lines), throwsA(isA<AmountTooLarge>()));
      expect(itemizedTotal(lines), 40 * maxAmount);
      // 1,000 maximal expenses still net exactly (no 64-bit overflow).
      final flows = [
        for (var i = 0; i < 1000; i++)
          ExpenseFlow(currency: 'INR', paid: {m[0]: maxAmount}, shares: {m[1]: maxAmount}),
      ];
      final n = nets(m, flows, const []);
      expect(n[m[0]], 1000 * maxAmount);
      expect(n[m[1]], -1000 * maxAmount);
      expect(simplify(m, n), [Transfer(m[1], m[0], 1000 * maxAmount)]);
    });

    test('conversions that do not fit 64 bits are AMOUNT_TOO_LARGE; a converted expense must fit maxAmount', () {
      expect(
        () => convert(maxAmount, 'KWD', 'VND', '99999999999999'),
        throwsA(isA<AmountTooLarge>()),
      );
      expect(() => convert(intMax, 'INR', 'INR', '2'), throwsA(isA<AmountTooLarge>()));
      expect(convert(intMax, 'INR', 'INR', '1'), intMax);
      expect(
        () => convertExpense(
          total: maxAmount,
          from: 'INR',
          to: 'KWD',
          rate: '2',
          paid: const {'a': maxAmount},
          shares: const {'a': maxAmount},
          order: const ['a'],
        ),
        throwsA(isA<AmountTooLarge>()),
      );
    });
  });

  // TC-R4-M-05
  group('conversions with saved rates', () {
    test('convert equals the exact oracle for 30 currencies, any sign, rates 1e-10 … 1e7', () {
      final r = Random(4107);
      var checked = 0;
      for (var k = 0; k < 6000; k++) {
        final from = r4Currencies[r.nextInt(r4Currencies.length)];
        final to = r4Currencies[r.nextInt(r4Currencies.length)];
        final rate = _rateText(r);
        final amount = (r.nextBool() ? 1 : -1) * (r.nextInt(8) == 0 ? r.nextInt(3) : _amount(r));
        final want = _convertOracle(amount, from, to, rate);
        final reason = 'case $k: $amount $from → $to at $rate';
        if (want.isValidInt) {
          expect(convert(amount, from, to, rate), want.toInt(), reason: reason);
          checked++;
        } else {
          expect(
            () => convert(amount, from, to, rate),
            throwsA(isA<AmountTooLarge>()),
            reason: reason,
          );
        }
      }
      expect(checked, greaterThan(5000));
    });

    test('a saved rate gives the same result with trailing zeros or spaces; bad rate texts are INVALID_RATE', () {
      final r = Random(4108);
      for (var k = 0; k < 2000; k++) {
        final rate = _rateText(r);
        final amount = _amount(r, 1000000000);
        final from = r4Currencies[r.nextInt(r4Currencies.length)];
        final to = r4Currencies[r.nextInt(r4Currencies.length)];
        final base = convert(amount, from, to, rate);
        final decimals = rate.contains('.') ? rate.length - rate.indexOf('.') - 1 : 0;
        if (decimals < 10) {
          final padded = rate.contains('.') ? '${rate}0' : '$rate.0';
          expect(convert(amount, from, to, padded), base, reason: '$rate vs $padded');
        }
        expect(convert(amount, from, to, ' $rate '), base, reason: 'spaces around $rate');
      }
      for (final bad in ['', '0', '-1', '0.0', 'abc', '1,5', '1.00000000001', 'NaN', '∞', '١٫٥']) {
        expect(() => convert(100, 'INR', 'USD', bad), throwsA(isA<InvalidRate>()), reason: bad);
      }
    });
  });

  // TC-R4-M-06
  group('converted expenses', () {
    test('each converted part is within one unit of its exact share; parts and payers sum to the new total', () {
      final r = Random(4109);
      var converted = 0;
      for (var k = 0; k < 3000; k++) {
        final n = 1 + r.nextInt(50);
        final m = _members(r, n);
        final total = _amount(r, 1000000000);
        final shares = _zip(m, _partsOf(r, total, n));
        final payers = {m[r.nextInt(n)]: total};
        final from = r4Currencies[r.nextInt(r4Currencies.length)];
        final to = r4Currencies[r.nextInt(r4Currencies.length)];
        final rate = _rateText(r);
        final t = _convertOracle(total, from, to, rate);
        ConvertedExpense run() => convertExpense(
          total: total,
          from: from,
          to: to,
          rate: rate,
          paid: payers,
          shares: shares,
          order: m,
        );
        if (t < BigInt.one || t > BigInt.from(maxAmount)) {
          expect(run, throwsA(isA<MoneyError>()), reason: 'case $k');
          continue;
        }
        final out = run();
        final nt = t.toInt();
        expect(out.total, nt);
        expect(_sum(out.shares.values), nt, reason: 'case $k');
        expect(_sum(out.paid.values), nt, reason: 'case $k');
        expect(out.paid.keys, payers.keys);
        for (final id in m) {
          // |part × total − newTotal × share| < total
          final diff =
              BigInt.from(out.shares[id]!) * BigInt.from(total) - t * BigInt.from(shares[id]!);
          expect(diff.abs() < BigInt.from(total), isTrue, reason: 'case $k member $id');
        }
        converted++;
      }
      expect(converted, greaterThan(1000));
    });

    test('converting there and back with the cross rate stays within the rounding bound', () {
      final r = Random(4110);
      final eur = <String, String>{
        for (final c in r4Currencies)
          if (c != 'EUR')
            c: '${1 + r.nextInt(2000)}.${r.nextInt(10000).toString().padLeft(4, '0')}',
      };
      for (var k = 0; k < 3000; k++) {
        final a = r4Currencies[r.nextInt(r4Currencies.length)];
        final b = r4Currencies[r.nextInt(r4Currencies.length)];
        final amount = _amount(r, 10000000000);
        final there = crossRate(eur, a, b);
        final back = crossRate(eur, b, a);
        final x = convert(amount, a, b, there);
        final y = convert(x, b, a, back);
        // |y − amount| ≤ ½·back·10^−shift (rounding x) + |amount|·|there·back − 1| + ½ (rounding y).
        final shift = Currencies.exponentOf(b) - Currencies.exponentOf(a);
        final (tn, td) = _fraction(there);
        final (qn, qd) = _fraction(back);
        final ten = BigInt.from(10);
        final n1 = qn * ten.pow(shift < 0 ? -shift : 0);
        final d1 = BigInt.two * qd * ten.pow(shift > 0 ? shift : 0);
        final n2 = BigInt.from(amount) * (tn * qn - td * qd).abs();
        final d2 = td * qd;
        final err = BigInt.from((y - amount).abs());
        // err ≤ n1/d1 + n2/d2 + 1/2
        final ok = err * d1 * d2 * BigInt.two <= BigInt.two * (n1 * d2 + n2 * d1) + d1 * d2;
        expect(ok, isTrue, reason: 'case $k: $amount $a→$b→$a = $y');
      }
    });
  });

  // TC-R4-M-07
  group('simplify (rule 12)', () {
    test('50-member groups with amounts up to maxAmount: nets kept, at most n − 1 transfers', () {
      final r = Random(4111);
      for (var k = 0; k < 300; k++) {
        final n = 2 + r.nextInt(49);
        final m = _members(r, n);
        final flows = <ExpenseFlow>[
          for (var e = 0; e < 1 + r.nextInt(40); e++)
            () {
              final total = _amount(r);
              final payer = m[r.nextInt(n)];
              final sharers = [
                for (final x in m)
                  if (r.nextBool()) x,
              ];
              final who = sharers.isEmpty ? [m[r.nextInt(n)]] : sharers;
              return ExpenseFlow(
                currency: 'INR',
                paid: {payer: total},
                shares: split(total, SplitKind.equal, who),
              );
            }(),
        ];
        final b = Balances.compute(m, flows, const []);
        expect(_sum(b.nets.values), 0);
        for (final shown in [b.simplified, b.pairs]) {
          final after = {for (final x in m) x: b.nets[x]!};
          for (final t in shown) {
            expect(t.amount, greaterThan(0));
            after[t.from] = after[t.from]! + t.amount;
            after[t.to] = after[t.to]! - t.amount;
          }
          expect(
            after.values.every((v) => v == 0),
            isTrue,
            reason: 'case $k: settling leaves someone owing',
          );
        }
        expect(b.simplified.length, lessThanOrEqualTo(n - 1), reason: 'case $k');
      }
    });
  });

  // TC-R4-M-08
  group('currencies are never mixed (rule 4)', () {
    test('30 currencies in one group: each block equals a brute-force net of its own records', () {
      final r = Random(4112);
      for (var k = 0; k < 300; k++) {
        final m = _members(r, 2 + r.nextInt(12));
        final codes = [
          for (var i = 0; i < 1 + r.nextInt(8); i++) r4Currencies[r.nextInt(r4Currencies.length)],
        ];
        final flows = <ExpenseFlow>[];
        final payments = <Payment>[];
        final brute = <String, Map<String, int>>{};
        void add(String c, String id, int v) {
          final per = brute.putIfAbsent(c, () => {});
          per[id] = (per[id] ?? 0) + v;
        }

        for (var e = 0; e < 1 + r.nextInt(20); e++) {
          final c = codes[r.nextInt(codes.length)];
          final total = _amount(r, 10000000000);
          final payer = m[r.nextInt(m.length)];
          final owed = split(total, SplitKind.equal, m);
          flows.add(ExpenseFlow(currency: c, paid: {payer: total}, shares: owed));
          add(c, payer, total);
          owed.forEach((id, v) => add(c, id, -v));
        }
        for (var p = 0; p < r.nextInt(6); p++) {
          final c = codes[r.nextInt(codes.length)];
          final from = r.nextInt(m.length);
          final to = (from + 1 + r.nextInt(m.length - 1)) % m.length;
          final amount = _amount(r, 100000000);
          payments.add(Payment(currency: c, from: m[from], to: m[to], amount: amount));
          add(c, m[from], amount);
          add(c, m[to], -amount);
        }
        final blocks = balancesByCurrency(m, flows, payments);
        expect(blocks.keys.toSet(), brute.keys.toSet(), reason: 'case $k');
        blocks.forEach((c, b) {
          for (final id in m) {
            expect(b.nets[id], brute[c]![id] ?? 0, reason: 'case $k $c $id');
          }
          expect(_sum(b.nets.values), 0);
        });
        if (blocks.length > 1) {
          expect(() => nets(m, flows, payments), throwsA(isA<CurrencyMismatch>()));
        }
      }
    });

    test('Money arithmetic refuses another currency for every pair of the 30', () {
      for (final a in r4Currencies) {
        for (final b in r4Currencies) {
          if (a == b) continue;
          expect(() => Money(1, a) + Money(1, b), throwsA(isA<CurrencyMismatch>()));
        }
      }
    });
  });

  // TC-R4-M-09
  group('overall balance (rule 3)', () {
    test('overall = Σ per-group nets = Σ per-person balances, per currency; ad-hoc people are one friend', () {
      final r = Random(4113);
      const me = 'u-me';
      for (var k = 0; k < 250; k++) {
        final codes = [for (var i = 0; i < 1 + r.nextInt(3); i++) r4Currencies[r.nextInt(8)]];
        final ledgers = <GroupLedger>[];
        final named = <LocalMember>[]; // name-only people of normal groups (origins)
        var e = 0;
        GroupLedger ledgerOf(LocalGroup g, List<LocalMember> members) {
          final ids = [for (final x in members) x.id];
          final expenses = <LocalExpense>[];
          for (var i = 0; i < r.nextInt(8); i++) {
            final total = _amount(r, 10000000000);
            final payers = [
              for (final x in ids)
                if (r.nextInt(3) == 0) x,
            ];
            final who = payers.isEmpty ? [ids[r.nextInt(ids.length)]] : payers;
            final sharers = [
              for (final x in ids)
                if (r.nextBool()) x,
            ];
            final owedBy = sharers.isEmpty ? ids : sharers;
            expenses.add(
              _expense(
                'e${e++}',
                g.id,
                codes[r.nextInt(codes.length)],
                _zip(who, _partsOf(r, total, who.length)),
                split(total, SplitKind.equal, owedBy),
              ),
            );
          }
          final payments = <LocalPayment>[];
          for (var i = 0; i < r.nextInt(4); i++) {
            final from = r.nextInt(ids.length);
            final to = (from + 1 + r.nextInt(ids.length - 1)) % ids.length;
            payments.add(
              _payment(
                'p${e++}',
                g.id,
                codes[r.nextInt(codes.length)],
                ids[from],
                ids[to],
                _amount(r, 100000000),
              ),
            );
          }
          return GroupLedger(group: g, members: members, expenses: expenses, payments: payments);
        }

        for (var gi = 0; gi < 1 + r.nextInt(4); gi++) {
          final g = _group(_uuid(r), simplify: r.nextBool());
          final members = [
            _member(_uuid(r), g.id, 0, userId: me),
            for (var i = 1; i < 2 + r.nextInt(5); i++)
              _member(_uuid(r), g.id, i, userId: r.nextInt(3) == 0 ? 'u$i' : null),
          ];
          named.addAll(members.where((x) => x.userId == null));
          ledgers.add(ledgerOf(g, members));
        }
        // Several friends without a group: name-only people picked from the groups above (S-421 derived ids).
        if (named.isNotEmpty && r.nextBool()) {
          final g = _group(_uuid(r), type: 'adhoc', simplify: r.nextBool());
          final picked = {for (var i = 0; i < 1 + r.nextInt(3); i++) named[r.nextInt(named.length)]}
              .toList();
          final members = [
            _member(_uuid(r), g.id, 0, userId: me),
            for (final (i, o) in picked.indexed) _member(derivedMemberId(o.id, g.id), g.id, i + 1),
          ];
          ledgers.add(ledgerOf(g, members));
        }

        final views = [for (final l in ledgers) groupBalancesOf(l, me)];
        final mine = myBalancesOf(views);
        final reason = 'case $k';
        // Brute force: my net per currency over every group, straight from the rows.
        final brute = <String, int>{};
        for (final l in ledgers) {
          final myId = l.members.firstWhere((x) => x.userId == me).id;
          for (final x in l.expenses) {
            final paid = (jsonDecode(x.payers) as Map)[myId] as int? ?? 0;
            final owed = (jsonDecode(x.shares) as Map)[myId] as int? ?? 0;
            brute[x.currency] = (brute[x.currency] ?? 0) + paid - owed;
          }
          for (final p in l.payments) {
            if (p.fromMember == myId) brute[p.currency] = (brute[p.currency] ?? 0) + p.amount;
            if (p.toMember == myId) brute[p.currency] = (brute[p.currency] ?? 0) - p.amount;
          }
        }
        brute.removeWhere((_, v) => v == 0);
        expect(mine.totals, brute, reason: reason);
        for (final c in {...brute.keys, ...codes}) {
          final byGroup = _sum([for (final g in mine.byGroup.values) g[c] ?? 0]);
          final byPeople = _sum([for (final p in mine.people) p.balances[c] ?? 0]);
          expect(byGroup, mine.totals[c] ?? 0, reason: '$reason $c: groups');
          expect(byPeople, mine.totals[c] ?? 0, reason: '$reason $c: people');
        }
        // One person is one friend: no derived member shows up as its own person.
        final keys = [for (final p in mine.people) p.key];
        expect(keys.toSet().length, keys.length, reason: reason);
        final adhoc = ledgers.where((l) => l.group.type == 'adhoc');
        for (final l in adhoc) {
          for (final x in l.members.where((x) => x.userId == null)) {
            expect(
              keys,
              isNot(contains('m:${x.id}')),
              reason: '$reason: derived ${x.id} listed apart',
            );
          }
        }
      }
    });
  });

  // TC-R4-M-10
  group('batch settle', () {
    test(
      'per currency, 50 groups with big balances: biggest first, exact amount, all paid = all zero',
      () {
        final r = Random(4114);
        for (var k = 0; k < 1000; k++) {
          final byCurrency = <String, List<GroupOwed>>{
            for (final c in [
              for (var i = 0; i < 1 + r.nextInt(3); i++)
                r4Currencies[r.nextInt(r4Currencies.length)],
            ])
              c: [
                for (var g = 0; g < 1 + r.nextInt(50); g++)
                  (groupId: 'g$g', owed: (r.nextInt(4) == 0 ? -1 : 1) * _amount(r)),
              ],
          };
          for (final MapEntry(key: c, value: balances) in byCurrency.entries) {
            final net = batchNet(balances);
            if (net == 0) continue;
            final amount = r.nextBool() ? net.abs() : 1 + _upTo(r, net.abs() - 1);
            final parts = allocateBatch(balances, amount);
            final moved = _sum([
              for (final p in parts)
                if (p.friendPays) p.amount else -p.amount,
            ]);
            expect(moved, net > 0 ? amount : -amount, reason: 'case $k $c');
            final same = parts.where((p) => p.friendPays == net > 0).toList();
            for (var i = 1; i < same.length; i++) {
              final a = balances.firstWhere((g) => g.groupId == same[i - 1].groupId).owed.abs();
              final b = balances.firstWhere((g) => g.groupId == same[i].groupId).owed.abs();
              expect(a >= b, isTrue, reason: 'case $k $c: not biggest first');
            }
            if (amount == net.abs()) {
              expect(
                afterBatch(balances, parts).every((g) => g.owed == 0),
                isTrue,
                reason: 'case $k $c',
              );
            }
          }
        }
      },
    );
  });
}
