// W2-X P-9 "Show in INR" (rule 4): a record counts in INR only as it is or through the conversion saved with
// it, never recalculated; everything else stays in its own currency ("not converted"). Vectors + glados.
import 'package:glados/glados.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/features/currency/application/in_currency_providers.dart';
import 'package:splitify/features/currency/domain/converted_balances.dart';
import 'package:splitify/features/currency/domain/in_currency.dart';
import 'package:splitify/features/friends/application/friends_view.dart';

import '../../support/ledger_seed.dart';
import '../friends/friend_fixtures.dart' show ledgerOf;

FxRecord _inr(String id, int total, Map<String, int> paid, Map<String, int> shares) =>
    FxRecord.expense(
      id: id,
      date: '2026-11-20',
      currency: 'INR',
      amount: total,
      paid: paid,
      shares: shares,
    );

FxRecord _usd(
  String id,
  int total,
  Map<String, int> paid,
  Map<String, int> shares, {
  int? inr,
  Map<String, int>? fxPaid,
  Map<String, int>? fxShares,
}) => FxRecord.expense(
  id: id,
  date: '2026-11-20',
  currency: 'USD',
  amount: total,
  paid: paid,
  shares: shares,
  fxCurrency: inr == null ? null : 'INR',
  fxAmount: inr,
  fxPaid: fxPaid,
  fxShares: fxShares,
);

void main() {
  group('my net in INR', () {
    test('INR as it is, USD through its saved conversion, unconverted USD kept apart', () {
      final r = myNetIn('INR', 'me', [
        _inr('a', 10000, {'me': 10000}, {'me': 5000, 'x': 5000}),
        _usd(
          'b',
          2000,
          {'me': 2000},
          {'me': 1000, 'x': 1000},
          inr: 166667,
          fxPaid: {'me': 166667},
          fxShares: {'me': 83334, 'x': 83333},
        ),
        _usd('c', 4000, {'x': 4000}, {'me': 2000, 'x': 2000}),
      ]);
      expect(r.amount, 5000 + 83333);
      expect(r.notConverted, {'USD': -2000});
      expect(r.counted, isTrue);
    });

    test('payments: paying adds to my net, being paid takes from it', () {
      final r = myNetIn('INR', 'me', const [
        FxRecord.payment(
          id: 'p1',
          date: '2026-11-20',
          currency: 'INR',
          amount: 700,
          from: 'me',
          to: 'x',
        ),
        FxRecord.payment(
          id: 'p2',
          date: '2026-11-20',
          currency: 'USD',
          amount: 10,
          from: 'x',
          to: 'me',
          fxCurrency: 'INR',
          fxAmount: 834,
        ),
        FxRecord.payment(
          id: 'p3',
          date: '2026-11-20',
          currency: 'EUR',
          amount: 5,
          from: 'x',
          to: 'me',
        ),
      ]);
      expect(r.amount, 700 - 834);
      expect(r.notConverted, {'EUR': -5});
    });

    test('nothing in INR or converted: nothing counted, never a made-up rate', () {
      final r = myNetIn('INR', 'me', [
        _usd('c', 4000, {'me': 4000}, {'me': 2000, 'x': 2000}),
      ]);
      expect(r.counted, isFalse);
      expect(r.amount, 0);
      expect(r.notConverted, {'USD': 2000});
    });

    test('a conversion to another currency does not count in INR', () {
      final r = myNetIn('INR', 'me', const [
        FxRecord.expense(
          id: 'e',
          date: '2026-11-20',
          currency: 'USD',
          amount: 100,
          paid: {'me': 100},
          shares: {'x': 100},
          fxCurrency: 'EUR',
          fxAmount: 90,
          fxPaid: {'me': 90},
          fxShares: {'x': 90},
        ),
      ]);
      expect(r.counted, isFalse);
      expect(r.notConverted, {'USD': 100});
    });
  });

  group('between me and a friend in INR', () {
    test('original debts add up record by record', () {
      final r = pairIn(
        'INR',
        me: 'me',
        friend: 'x',
        order: const ['me', 'x', 'y'],
        records: [
          _inr('a', 9000, {'me': 9000}, {'me': 3000, 'x': 3000, 'y': 3000}),
          _usd(
            'b',
            300,
            {'x': 300},
            {'me': 100, 'x': 100, 'y': 100},
            inr: 25000,
            fxPaid: {'x': 25000},
            fxShares: {'me': 8334, 'x': 8333, 'y': 8333},
          ),
          _usd('c', 200, {'me': 200}, {'me': 100, 'x': 100}),
        ],
        simplify: false,
        shown: const {},
      );
      expect(r.amount, 3000 - 8334);
      expect(r.notConverted, {'USD': 100});
    });

    test(
      'simplified groups: redone in INR only when every record counts; else shown as they are',
      () {
        final done = pairIn(
          'INR',
          me: 'me',
          friend: 'x',
          order: const ['me', 'x'],
          records: [
            _inr('a', 1000, {'me': 1000}, {'me': 500, 'x': 500}),
          ],
          simplify: true,
          shown: const {'INR': 500},
        );
        expect(done.amount, 500);
        expect(done.notConverted, isEmpty);
        final kept = pairIn(
          'INR',
          me: 'me',
          friend: 'x',
          order: const ['me', 'x'],
          records: [
            _inr('a', 1000, {'me': 1000}, {'me': 500, 'x': 500}),
            _usd('b', 100, {'me': 100}, {'me': 50, 'x': 50}),
          ],
          simplify: true,
          shown: const {'INR': 500, 'USD': 50},
        );
        expect(kept.amount, 500);
        expect(kept.notConverted, {'USD': 50});
      },
    );

    test('friendTotalIn over a friend\'s groups (two currencies, one saved conversion)', () {
      final ledger = ledgerOf(
        seedGroup(id: 'g7', name: 'Abroad'),
        [
          seedMember('t1', groupId: 'g7', name: 'Mohit', userId: 'u1'),
          seedMember('t2', groupId: 'g7', name: 'Asha', userId: 'u2', position: 1),
        ],
        expenses: [
          seedExpense(
            't-e1',
            groupId: 'g7',
            total: 2000,
            payers: {'t1': 2000},
            shares: {'t1': 1000, 't2': 1000},
          ),
          seedExpense(
            't-e2',
            groupId: 'g7',
            currency: 'USD',
            total: 4000,
            payers: {'t1': 4000},
            shares: {'t1': 2000, 't2': 2000},
          ),
        ],
      );
      final asha = friendsOf([ledger], 'u1').single;
      final r = friendTotalIn('INR', asha);
      expect(r.amount, 1000);
      expect(r.notConverted, {'USD': 2000});
      // My overall: the same split.
      final mine = myTotalIn('INR', [ledger], 'u1');
      expect(mine.amount, 1000);
      expect(mine.notConverted, {'USD': 2000});
    });
  });

  group('properties', () {
    final explore = ExploreConfig(numRuns: 400);
    Generator<T> gen<T>(T Function(Random r) f) =>
        any.simple(generate: (r, _) => f(r), shrink: (_) => const []);

    // Random records in INR, USD (some with a saved INR conversion of ANY numbers) and EUR.
    List<FxRecord> records(Random r) {
      final people = ['me', 'x', 'y'];
      return [
        for (var i = 0, k = 1 + r.nextInt(8); i < k; i++)
          () {
            final code = ['INR', 'USD', 'EUR'][r.nextInt(3)];
            final total = 1 + r.nextInt(500000);
            final payer = people[r.nextInt(3)];
            final shares = split(total, SplitKind.equal, people, const {});
            final saved = code == 'USD' && r.nextBool();
            final fxTotal = 1 + r.nextInt(50000000);
            return FxRecord.expense(
              id: 'r$i',
              date: '2026-11-20',
              currency: code,
              amount: total,
              paid: {payer: total},
              shares: shares,
              fxCurrency: saved ? 'INR' : null,
              fxAmount: saved ? fxTotal : null,
              fxPaid: saved ? {payer: fxTotal} : null,
              fxShares: saved ? split(fxTotal, SplitKind.equal, people, const {}) : null,
            );
          }(),
      ];
    }

    Glados(gen(records), explore).test(
      'only saved numbers count; the rest stays in its own currency',
      (rs) {
        final r = myNetIn('INR', 'me', rs);
        var inr = 0;
        final left = <String, int>{};
        for (final x in rs) {
          final mine = (x.paid!['me'] ?? 0) - (x.shares!['me'] ?? 0);
          if (x.currency == 'INR') {
            inr += mine;
          } else if (x.fxCurrency == 'INR') {
            inr += (x.fxPaid!['me'] ?? 0) - (x.fxShares!['me'] ?? 0);
          } else {
            left[x.currency] = (left[x.currency] ?? 0) + mine;
          }
        }
        left.removeWhere((_, v) => v == 0);
        expect(r.amount, inr);
        expect(r.notConverted, left);
        expect(r.notConverted.containsKey('INR'), isFalse);
      },
    );

    Glados(gen(records), explore).test(
      'friend amounts in INR add up the same way (original debts)',
      (rs) {
        final x = pairIn(
          'INR',
          me: 'me',
          friend: 'x',
          order: const ['me', 'x', 'y'],
          records: rs,
          simplify: false,
          shown: const {},
        );
        final y = pairIn(
          'INR',
          me: 'me',
          friend: 'y',
          order: const ['me', 'x', 'y'],
          records: rs,
          simplify: false,
          shown: const {},
        );
        final mine = myNetIn('INR', 'me', rs);
        // With equal splits between the three, what x and y owe me is my whole net (pairs come from each expense's
        // payer to the others), per currency.
        expect(x.amount + y.amount, mine.amount);
        final left = <String, int>{};
        for (final m in [x.notConverted, y.notConverted]) {
          m.forEach((c, v) => left[c] = (left[c] ?? 0) + v);
        }
        left.removeWhere((_, v) => v == 0);
        expect(left, mine.notConverted);
      },
    );
  });

  test('InCurrency + keeps the currencies apart', () {
    const a = InCurrency(currency: 'INR', amount: 100, notConverted: {'USD': 5}, counted: true);
    const b = InCurrency(currency: 'INR', amount: -40, notConverted: {'USD': -5, 'EUR': 2});
    final s = a + b;
    expect(s.amount, 60);
    expect(s.notConverted, {'EUR': 2});
    expect(s.counted, isTrue);
    expect(const InCurrency(currency: 'INR').empty, isTrue);
  });
}
