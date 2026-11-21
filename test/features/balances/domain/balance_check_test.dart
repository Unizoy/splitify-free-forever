import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/features/balances/domain/balance_check.dart';

void main() {
  const order = ['a', 'b', 'c'];
  final flow = ExpenseFlow(
    currency: 'INR',
    paid: const {'a': 30000},
    shares: const {'a': 10000, 'b': 10000, 'c': 10000},
  );

  Map<String, Balances> computed() => balancesByCurrency(order, [flow], const []);

  group('balancesFingerprint / balancesChecksum', () {
    test('canonical text lists non-zero nets, pairs and simplified transfers', () {
      expect(
        balancesFingerprint(computed()),
        'INR|n:a=20000,b=-10000,c=-10000|p:b>a=10000,c>a=10000|s:b>a=10000,c>a=10000;',
      );
    });

    test('empty input gives empty text', () {
      expect(balancesFingerprint(const {}), '');
    });

    test('zero nets are left out and currencies are alphabetical', () {
      const settled = Balances(nets: {'a': 0, 'b': 0}, pairs: [], simplified: []);
      final text = balancesFingerprint({'USD': settled, 'EUR': settled});
      expect(text, 'EUR|n:|p:|s:;USD|n:|p:|s:;');
    });

    test('transfers are sorted by (from, to) so order does not matter', () {
      const a = Balances(
        nets: {'a': 3, 'b': 0, 'c': -3},
        pairs: [Transfer('c', 'b', 1), Transfer('b', 'a', 2), Transfer('b', 'c', 3)],
        simplified: [],
      );
      const b = Balances(
        nets: {'c': -3, 'a': 3},
        pairs: [Transfer('b', 'c', 3), Transfer('c', 'b', 1), Transfer('b', 'a', 2)],
        simplified: [],
      );
      expect(balancesFingerprint({'INR': a}), balancesFingerprint({'INR': b}));
      expect(balancesFingerprint({'INR': a}), contains('p:b>a=2,b>c=3,c>b=1'));
    });

    // TC-15-04
    test('TC-15-04 the same records give the same checksum', () {
      final one = balancesChecksum(computed());
      final two = balancesChecksum(balancesByCurrency(order, [flow], const []));
      expect(one, two);
    });

    // TC-15-04
    test('TC-15-04 one paisa of difference changes the checksum', () {
      final other = ExpenseFlow(
        currency: 'INR',
        paid: const {'a': 30000},
        shares: const {'a': 10001, 'b': 9999, 'c': 10000},
      );
      expect(
        balancesChecksum(computed()),
        isNot(balancesChecksum(balancesByCurrency(order, [other], const []))),
      );
    });
  });

  group('overviewFingerprint / overviewDifferences', () {
    test('lists non-zero nets per group, skipping settled groups', () {
      expect(
        overviewFingerprint({
          'g2': {'USD': 5, 'INR': -100, 'EUR': 0},
          'g1': {'INR': 0},
          'g0': {'INR': 7},
        }),
        'g0:INR=7;g2:INR=-100,USD=5;',
      );
      expect(overviewFingerprint(const {}), '');
    });

    test('same balances give no differences', () {
      final m = {
        'g1': {'INR': 100},
        'g2': {'INR': -100},
      };
      expect(overviewDifferences(m, {...m}), isEmpty);
    });

    test('a zero entry equals a missing group', () {
      expect(
        overviewDifferences({
          'g1': {'INR': 0},
        }, const {}),
        isEmpty,
      );
    });

    test('differing and one-sided groups are listed sorted', () {
      final diff = overviewDifferences(
        {
          'g3': {'INR': 10},
          'g1': {'INR': 100},
          'g2': {'INR': 5},
        },
        {
          'g1': {'INR': 101},
          'g2': {'INR': 5},
          'g0': {'USD': 1},
        },
      );
      expect(diff, ['g0', 'g1', 'g3']);
    });
  });

  test('checksumText pads to 8 hex digits', () {
    expect(checksumText(0x1a2b3c4d), '0x1a2b3c4d');
    expect(checksumText(255), '0x000000ff');
    expect(checksumText(0), '0x00000000');
  });
}
