import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/money/money_error.dart';

const abc = ['A', 'B', 'C'];

ExpenseFlow inr(Map<String, int> paid, Map<String, int> shares) =>
    ExpenseFlow(currency: 'INR', paid: paid, shares: shares);

Payment pay(String from, String to, int amount, [String currency = 'INR']) =>
    Payment(currency: currency, from: from, to: to, amount: amount);

Matcher _code(String code, [Map<String, Object> data = const {}]) => throwsA(
  isA<MoneyError>().having((e) => e.code, 'code', code).having((e) => e.data, 'data', data),
);

void main() {
  group('Transfer', () {
    test('Transfer equality uses from, to and amount', () {
      const t = Transfer('B', 'A', 300);
      expect(t, const Transfer('B', 'A', 300));
      expect(t.hashCode, const Transfer('B', 'A', 300).hashCode);
      expect(t == const Transfer('A', 'B', 300), isFalse);
      expect(t == const Transfer('B', 'C', 300), isFalse);
      expect(t == const Transfer('B', 'A', 301), isFalse);
      expect(t.toString(), 'Transfer(B → A: 300)');
    });
  });

  // TC-10-03
  group('expensePairs', () {
    test('expensePairs makes everyone owe the payer their share when there is one payer', () {
      expect(expensePairs(abc, {'A': 9000}, {'A': 3000, 'B': 3000, 'C': 3000}), const [
        Transfer('B', 'A', 3000),
        Transfer('C', 'A', 3000),
      ]);
    });

    test('expensePairs matches debtors to creditors in fixed order when several people paid', () {
      // A +6000, B +1500, C −2500, D −5000 (A paid without a share: payers needn't be participants).
      const paid = {'A': 6000, 'B': 4000};
      const shares = {'B': 2500, 'C': 2500, 'D': 5000};
      expect(expensePairs(['A', 'B', 'C', 'D'], paid, shares), const [
        Transfer('C', 'A', 2500),
        Transfer('D', 'A', 3500),
        Transfer('D', 'B', 1500),
      ]);
      // A different fixed order gives a different (still exact) matching.
      expect(expensePairs(['D', 'C', 'B', 'A'], paid, shares), const [
        Transfer('D', 'B', 1500),
        Transfer('D', 'A', 3500),
        Transfer('C', 'A', 2500),
      ]);
    });

    test('expensePairs leaves out members who paid exactly their share', () {
      expect(expensePairs(abc, {'A': 5000, 'B': 5000}, {'A': 5000, 'B': 2500, 'C': 2500}), const [
        Transfer('C', 'B', 2500),
      ]);
      expect(expensePairs(abc, {'A': 100}, {'A': 100}), isEmpty);
    });

    test('expensePairs throws UNKNOWN_MEMBER when a payer or participant is not in the order', () {
      expect(
        () => expensePairs(abc, {'Z': 100}, {'A': 100}),
        _code('UNKNOWN_MEMBER', {'member': 'Z'}),
      );
      expect(
        () => expensePairs(abc, {'A': 100}, {'Y': 100}),
        _code('UNKNOWN_MEMBER', {'member': 'Y'}),
      );
    });
  });

  // TC-11-01
  group('IOU', () {
    test('IOU makes the borrower owe the lender the whole amount when A lent B', () {
      // "I lent B ₹500": payer = lender A, one share = borrower B × total.
      final loan = inr({'A': 50000}, {'B': 50000});
      final b = Balances.compute(abc, [loan], const []);
      expect(b.nets, {'A': 50000, 'B': -50000, 'C': 0});
      expect(b.pairs, const [Transfer('B', 'A', 50000)]);
      expect(b.simplified, const [Transfer('B', 'A', 50000)]);
    });

    test('IOU makes me owe the friend when I borrowed', () {
      final loan = inr({'B': 20000}, {'A': 20000});
      expect(pairwise(abc, [loan], const []), const [Transfer('A', 'B', 20000)]);
    });
  });

  group('nets', () {
    test('nets lists every member in fixed order when some have no records', () {
      final n = nets(
        ['C', 'B', 'A'],
        [
          inr({'A': 900}, {'A': 300, 'B': 600}),
        ],
        const [],
      );
      expect(n.keys.toList(), ['C', 'B', 'A']);
      expect(n, {'C': 0, 'B': -600, 'A': 600});
      expect(() => n['A'] = 0, throwsUnsupportedError);
    });

    test('nets are all 0 when there are no records', () {
      expect(nets(abc, const [], const []), {'A': 0, 'B': 0, 'C': 0});
    });

    test('nets throws UNKNOWN_MEMBER when an expense names someone outside the order', () {
      expect(
        () => nets(abc, [
          inr({'Z': 100}, {'A': 100}),
        ], const []),
        _code('UNKNOWN_MEMBER', {'member': 'Z'}),
      );
      expect(
        () => nets(abc, [
          inr({'A': 100}, {'Y': 100}),
        ], const []),
        _code('UNKNOWN_MEMBER', {'member': 'Y'}),
      );
    });

    test('nets throws DUPLICATE_MEMBER when the order repeats an id', () {
      expect(
        () => nets(['A', 'B', 'A'], const [], const []),
        _code('DUPLICATE_MEMBER', {'member': 'A'}),
      );
    });
  });

  // TC-25-01
  group('payments', () {
    final dinner = inr({'A': 9000}, {'A': 3000, 'B': 3000, 'C': 3000});

    test('payment reduces what the sender owes when it is partial', () {
      final b = Balances.compute(abc, [dinner], [pay('B', 'A', 1000)]);
      expect(b.nets, {'A': 5000, 'B': -2000, 'C': -3000});
      expect(b.pairs, const [Transfer('B', 'A', 2000), Transfer('C', 'A', 3000)]);
    });

    test('payment removes the pair when it settles the debt exactly', () {
      final b = Balances.compute(abc, [dinner], [pay('B', 'A', 2000), pay('B', 'A', 1000)]);
      expect(b.nets, {'A': 3000, 'B': 0, 'C': -3000});
      expect(b.pairs, const [Transfer('C', 'A', 3000)]);
    });

    test('payment flips the debt when the sender pays too much', () {
      final b = Balances.compute(abc, [dinner], [pay('C', 'A', 4000)]);
      expect(b.nets, {'A': 2000, 'B': -3000, 'C': 1000});
      expect(b.pairs, const [Transfer('B', 'A', 3000), Transfer('A', 'C', 1000)]);
    });

    test('payment alone creates a debt back to the sender when there are no expenses', () {
      final b = Balances.compute(abc, const [], [pay('A', 'B', 500)]);
      expect(b.nets, {'A': 500, 'B': -500, 'C': 0});
      expect(b.pairs, const [Transfer('B', 'A', 500)]);
    });

    test('payment reduces the pair from a multi-payer expense', () {
      final e = inr({'A': 6000, 'C': 3000}, {'A': 3000, 'B': 3000, 'C': 3000});
      expect(pairwise(abc, [e], [pay('B', 'A', 1000)]), const [Transfer('B', 'A', 2000)]);
    });

    test('payment throws INVALID_PAYMENT when someone pays themselves', () {
      expect(
        () => nets(abc, const [], [pay('A', 'A', 100)]),
        _code('INVALID_PAYMENT', {'member': 'A'}),
      );
      expect(
        () => pairwise(abc, const [], [pay('B', 'B', 100)]),
        _code('INVALID_PAYMENT', {'member': 'B'}),
      );
    });

    test('payment throws UNKNOWN_MEMBER when sender or receiver is not in the group', () {
      expect(
        () => nets(abc, const [], [pay('Z', 'A', 100)]),
        _code('UNKNOWN_MEMBER', {'member': 'Z'}),
      );
      expect(
        () => pairwise(abc, const [], [pay('A', 'Y', 100)]),
        _code('UNKNOWN_MEMBER', {'member': 'Y'}),
      );
    });

    test('payment throws AMOUNT_NOT_POSITIVE when its amount is 0 or negative', () {
      expect(() => nets(abc, const [], [pay('A', 'B', 0)]), _code('AMOUNT_NOT_POSITIVE'));
      expect(() => pairwise(abc, const [], [pay('A', 'B', -5)]), _code('AMOUNT_NOT_POSITIVE'));
    });
  });

  // TC-14-01
  group('currencies', () {
    test('nets and pairwise throw CURRENCY_MISMATCH when records mix currencies', () {
      final expense = inr({'A': 900}, {'B': 900});
      final usd = pay('B', 'A', 100, 'USD');
      expect(
        () => nets(abc, [expense], [usd]),
        _code('CURRENCY_MISMATCH', {'left': 'INR', 'right': 'USD'}),
      );
      expect(
        () => pairwise(abc, [expense], [usd]),
        _code('CURRENCY_MISMATCH', {'left': 'INR', 'right': 'USD'}),
      );
      const usdExpense = ExpenseFlow(currency: 'USD', paid: {'A': 1}, shares: {'B': 1});
      expect(
        () => Balances.compute(abc, [usdExpense, expense], const []),
        _code('CURRENCY_MISMATCH', {'left': 'USD', 'right': 'INR'}),
      );
    });

    test('balancesByCurrency keeps one block per currency when a group mixes currencies', () {
      final byCurrency = balancesByCurrency(
        abc,
        [
          const ExpenseFlow(currency: 'USD', paid: {'A': 3000}, shares: {'A': 1500, 'B': 1500}),
          inr({'A': 9000}, {'A': 3000, 'B': 3000, 'C': 3000}),
        ],
        [pay('B', 'A', 1500, 'USD'), pay('C', 'A', 1000, 'EUR')],
      );
      expect(byCurrency.keys.toList(), ['EUR', 'INR', 'USD']);
      // B settles the USD debt; that never pays off B's INR debt.
      expect(byCurrency['USD']!.nets, {'A': 0, 'B': 0, 'C': 0});
      expect(byCurrency['USD']!.pairs, isEmpty);
      expect(byCurrency['INR']!.nets, {'A': 6000, 'B': -3000, 'C': -3000});
      expect(byCurrency['INR']!.pairs, const [Transfer('B', 'A', 3000), Transfer('C', 'A', 3000)]);
      expect(byCurrency['EUR']!.nets, {'A': -1000, 'B': 0, 'C': 1000});
      expect(byCurrency['EUR']!.simplified, const [Transfer('A', 'C', 1000)]);
      for (final b in byCurrency.values) {
        expect(b.nets.values.fold(0, (a, v) => a + v), 0);
      }
    });

    test('balancesByCurrency is empty when there are no records', () {
      expect(balancesByCurrency(abc, const [], const []), isEmpty);
    });
  });

  // TC-15-01
  group('Balances', () {
    test('Balances.shown returns simplified transfers only when simplify is on', () {
      final b = Balances.compute(
        ['A', 'B', 'C', 'D'],
        [
          inr({'A': 10000}, {'B': 10000}),
          inr({'B': 10000}, {'C': 10000}),
          inr({'D': 5000}, {'A': 5000}),
        ],
        const [],
      );
      expect(b.shown(simplify: false), b.pairs);
      expect(b.shown(simplify: true), b.simplified);
      expect(b.pairs, hasLength(3));
      expect(b.simplified, const [Transfer('C', 'A', 5000), Transfer('C', 'D', 5000)]);
    });
  });

  // TC-17-01
  group('simplify', () {
    test('simplify settles exact opposites first in fixed order', () {
      expect(simplify(['A', 'B', 'C', 'D'], {'A': -500, 'B': 300, 'C': -300, 'D': 500}), const [
        Transfer('A', 'D', 500),
        Transfer('C', 'B', 300),
      ]);
    });

    test(
      'simplify moves from the largest debtor to the largest creditor with fixed-order ties',
      () {
        // Same as the oracle: B and C tie at 400 -> B first.
        expect(
          simplify(['A', 'B', 'C', 'D', 'E'], {'A': -700, 'B': 400, 'C': 400, 'D': -100, 'E': 0}),
          const [Transfer('A', 'B', 400), Transfer('A', 'C', 300), Transfer('D', 'C', 100)],
        );
      },
    );

    test('simplify gives no transfers when everyone is settled', () {
      expect(simplify(abc, {'A': 0, 'B': 0, 'C': 0}), isEmpty);
      expect(simplify(abc, const {}), isEmpty);
    });

    test('simplify treats missing members as 0 when the nets map is partial', () {
      expect(simplify(abc, {'C': -100, 'A': 100}), const [Transfer('C', 'A', 100)]);
    });

    test('simplify throws NETS_DO_NOT_SUM_TO_ZERO when nets are unbalanced', () {
      expect(() => simplify(abc, {'A': 100, 'B': -99}), _code('NETS_DO_NOT_SUM_TO_ZERO'));
    });

    test('simplify throws UNKNOWN_MEMBER when a net belongs to someone outside the order', () {
      expect(() => simplify(abc, {'A': 100, 'Z': -100}), _code('UNKNOWN_MEMBER', {'member': 'Z'}));
    });
  });

  // TC-16-01
  group('friendTotals', () {
    // Shared group 1 (simplify off): me paid ₹90 for three -> friend owes me ₹30.
    final trip = balancesByCurrency(
      ['me1', 'fr1', 'x1'],
      [
        inr({'me1': 9000}, {'me1': 3000, 'fr1': 3000, 'x1': 3000}),
      ],
      const [],
    );
    // Shared group 2: a cycle me2 -> fr2 -> z2 -> me2. Pairs show fr2 owes me2 ₹30, but every net is 0.
    final flat = balancesByCurrency(
      ['me2', 'fr2', 'z2'],
      [
        inr({'me2': 3000}, {'fr2': 3000}),
        inr({'fr2': 3000}, {'z2': 3000}),
        inr({'z2': 3000}, {'me2': 3000}),
      ],
      const [],
    );
    // Direct (friend) group: I owe $10 and a settled INR loan.
    final direct = balancesByCurrency(
      ['me3', 'fr3'],
      [
        const ExpenseFlow(currency: 'USD', paid: {'fr3': 1000}, shares: {'me3': 1000}),
        inr({'me3': 2000}, {'fr3': 2000}),
      ],
      [pay('fr3', 'me3', 2000)],
    );

    test('friendTotals sums shared groups and the direct group per currency', () {
      final totals = friendTotals([
        FriendGroup(me: 'me1', friend: 'fr1', balances: trip),
        FriendGroup(me: 'me2', friend: 'fr2', balances: flat, simplify: true),
        FriendGroup(me: 'me3', friend: 'fr3', balances: direct),
      ]);
      expect(totals, {'INR': 3000, 'USD': -1000});
      expect(totals.keys.toList(), ['INR', 'USD']);
    });

    test('friendTotals uses pairs when a group has simplify off', () {
      final totals = friendTotals([
        FriendGroup(me: 'me1', friend: 'fr1', balances: trip),
        FriendGroup(me: 'me2', friend: 'fr2', balances: flat),
        FriendGroup(me: 'me3', friend: 'fr3', balances: direct),
      ]);
      expect(totals, {'INR': 6000, 'USD': -1000});
    });

    test('friendTotals counts what I owe the friend as negative', () {
      expect(friendTotals([FriendGroup(me: 'fr1', friend: 'me1', balances: trip)]), {'INR': -3000});
    });

    test('friendTotals leaves out currencies that net to 0', () {
      expect(
        friendTotals([FriendGroup(me: 'me2', friend: 'fr2', balances: flat, simplify: true)]),
        isEmpty,
      );
      expect(
        friendTotals([
          FriendGroup(me: 'me1', friend: 'fr1', balances: trip),
          FriendGroup(me: 'fr1', friend: 'me1', balances: trip),
        ]),
        isEmpty,
      );
      expect(friendTotals(const []), isEmpty);
    });

    test('friendTotals ignores debts with other members when they do not involve the friend', () {
      // x1 owes me1 too, but only fr1 counts.
      expect(friendTotals([FriendGroup(me: 'me1', friend: 'x1', balances: trip)]), {'INR': 3000});
      expect(friendTotals([FriendGroup(me: 'fr1', friend: 'x1', balances: trip)]), isEmpty);
    });
  });
}
