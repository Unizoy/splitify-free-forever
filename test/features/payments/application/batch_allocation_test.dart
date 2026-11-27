// D-034 B1: how one payment to or from a friend is spread over our groups (batch_allocation.dart) — vectors for
// the documented order (coordinator decision: the BIGGEST group balance first, ties by group id; opposite
// balances cleared first) and glados properties, 500 cases each: the parts add up to the amount, no group is
// paid more than it owes or flipped, the overall balance moves by exactly the amount, and paying everything
// settles every group.
import 'package:glados/glados.dart';
import 'package:splitify/features/payments/application/batch_allocation.dart';

final _explore = ExploreConfig(numRuns: 500);

Generator<T> _gen<T>(T Function(Random r) f) =>
    any.simple(generate: (r, _) => f(r), shrink: (_) => const []);

typedef _Case = ({List<GroupOwed> balances, int amount});

/// 1–6 groups with balances up to ₹10 lakh either way (some zero), not cancelling out, and an amount in
/// 1 … |net| (often all of it).
_Case _case(Random r) {
  while (true) {
    final n = 1 + r.nextInt(6);
    final balances = [
      for (var i = 0; i < n; i++)
        (
          groupId: 'g${r.nextInt(4)}$i',
          owed:
              switch (r.nextInt(6)) {
                0 => 0,
                1 => -(1 + r.nextInt(100000000)),
                _ => 1 + r.nextInt(100000000),
              } *
              (r.nextBool() && r.nextInt(5) == 0 ? -1 : 1),
        ),
    ];
    final net = batchNet(balances).abs();
    if (net == 0) continue;
    final amount = r.nextInt(3) == 0 ? net : 1 + r.nextInt(net);
    return (balances: balances, amount: amount);
  }
}

int _signed(BatchPart p) => p.friendPays ? p.amount : -p.amount;

void main() {
  const goa = (groupId: 'goa', owed: 20000);
  const direct = (groupId: 'direct', owed: 25500);

  group('the documented order', () {
    test('everything: one payment per group, each its whole balance', () {
      expect(allocateBatch([goa, direct], 45500), [
        (groupId: 'direct', friendPays: true, amount: 25500),
        (groupId: 'goa', friendPays: true, amount: 20000),
      ]);
    });

    test('part of it pays the biggest group balance first (₹300 = direct ₹255 + Goa ₹45)', () {
      expect(allocateBatch([goa, direct], 30000), [
        (groupId: 'direct', friendPays: true, amount: 25500),
        (groupId: 'goa', friendPays: true, amount: 4500),
      ]);
    });

    test('less than the biggest balance touches only that group', () {
      expect(allocateBatch([goa, direct], 10000), [
        (groupId: 'direct', friendPays: true, amount: 10000),
      ]);
    });

    test('equal balances: the lower group id first', () {
      expect(allocateBatch([(groupId: 'b', owed: 5000), (groupId: 'a', owed: 5000)], 6000), [
        (groupId: 'a', friendPays: true, amount: 5000),
        (groupId: 'b', friendPays: true, amount: 1000),
      ]);
    });

    test('I owe on balance: the payments go from me, biggest first', () {
      expect(
        allocateBatch([(groupId: 'goa', owed: -30000), (groupId: 'flat', owed: -10000)], 35000),
        [
          (groupId: 'goa', friendPays: false, amount: 30000),
          (groupId: 'flat', friendPays: false, amount: 5000),
        ],
      );
    });

    test('a balance the other way is cleared first, so exactly the amount changes hands', () {
      // Asha owes me 500 in Goa and 100 direct; I owe her 200 in Flat: 400 overall.
      final parts = allocateBatch([
        (groupId: 'goa', owed: 50000),
        (groupId: 'direct', owed: 10000),
        (groupId: 'flat', owed: -20000),
      ], 30000);
      expect(parts, [
        (groupId: 'goa', friendPays: true, amount: 50000),
        (groupId: 'flat', friendPays: false, amount: 20000),
      ]);
      expect(parts.fold<int>(0, (a, p) => a + _signed(p)), 30000);
    });

    test('groups with nothing owed are left out', () {
      expect(allocateBatch([goa, (groupId: 'zero', owed: 0)], 20000), [
        (groupId: 'goa', friendPays: true, amount: 20000),
      ]);
    });

    test('afterBatch: what each group owes after paying', () {
      final parts = allocateBatch([goa, direct], 30000);
      expect(afterBatch([goa, direct], parts), [
        (groupId: 'goa', owed: 15500),
        (groupId: 'direct', owed: 0),
      ]);
    });
  });

  group('refused amounts', () {
    test('more than the overall balance, zero, negative or nothing owed overall', () {
      expect(() => allocateBatch([goa, direct], 45501), throwsA(isA<BatchAmountError>()));
      expect(() => allocateBatch([goa, direct], 0), throwsA(isA<BatchAmountError>()));
      expect(() => allocateBatch([goa, direct], -1), throwsA(isA<BatchAmountError>()));
      expect(
        () => allocateBatch([goa, (groupId: 'x', owed: -20000)], 1),
        throwsA(isA<BatchAmountError>()),
      );
    });
  });

  group('properties', () {
    Glados(_gen(_case), _explore).test('the overall balance moves by exactly the amount paid', (c) {
      final parts = allocateBatch(c.balances, c.amount);
      final net = batchNet(c.balances);
      final moved = parts.fold<int>(0, (a, p) => a + _signed(p));
      expect(moved, net > 0 ? c.amount : -c.amount);
      expect(batchNet(afterBatch(c.balances, parts)), net - moved);
    });

    Glados(_gen(_case), _explore).test(
      'each part is positive, at most what its group owes, and never flips a group',
      (c) {
        final parts = allocateBatch(c.balances, c.amount);
        final ids = [for (final p in parts) p.groupId];
        expect(ids.toSet().length, ids.length, reason: 'one payment per group');
        for (final p in parts) {
          final owed = c.balances.firstWhere((g) => g.groupId == p.groupId).owed;
          expect(p.amount, greaterThan(0));
          expect(p.amount, lessThanOrEqualTo(owed.abs()));
          expect(p.friendPays, owed > 0, reason: 'the payment goes the way the group owes');
        }
        for (final (i, after) in afterBatch(c.balances, parts).indexed) {
          final before = c.balances[i].owed;
          expect(after.owed.sign == before.sign || after.owed == 0, isTrue);
          expect(after.owed.abs(), lessThanOrEqualTo(before.abs()));
        }
      },
    );

    Glados(_gen(_case), _explore).test('paying everything settles every group', (c) {
      final all = batchNet(c.balances).abs();
      final after = afterBatch(c.balances, allocateBatch(c.balances, all));
      expect(after.every((g) => g.owed == 0), isTrue);
    });

    Glados(_gen(_case), _explore).test(
      'biggest first: a smaller group is paid only once every bigger one is full',
      (c) {
        final parts = allocateBatch(c.balances, c.amount);
        final net = batchNet(c.balances);
        final same = [
          for (final g in c.balances)
            if (net > 0 ? g.owed > 0 : g.owed < 0) g,
        ];
        int paid(String id) => parts.where((p) => p.groupId == id).fold(0, (a, p) => a + p.amount);
        for (final small in same) {
          if (paid(small.groupId) == 0) continue;
          for (final big in same) {
            final bigger =
                big.owed.abs() > small.owed.abs() ||
                (big.owed.abs() == small.owed.abs() && big.groupId.compareTo(small.groupId) < 0);
            if (bigger && big.groupId != small.groupId) {
              expect(
                paid(big.groupId),
                big.owed.abs(),
                reason: '${big.groupId} before ${small.groupId}',
              );
            }
          }
        }
      },
    );
  });
}
