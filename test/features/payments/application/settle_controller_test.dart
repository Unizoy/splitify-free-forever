import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/fx.dart';
import 'package:splitify/data/local/app_database.dart' show LocalPayment;
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/payments/application/settle_controller.dart';

import '../../../support/ledger_seed.dart';
import '../../expenses/application/expense_test_env.dart';

void main() {
  late ExpenseEnv env;
  late String me;
  late String asha;
  late String ravi;

  /// Mohit paid 300.00 for the three of them: Asha and Ravi each owe him 100.00.
  Future<void> dinner() async {
    await env.db.seed(
      expenses: [
        seedExpense(
          'e1',
          groupId: env.groupId,
          total: 30000,
          payers: {me: 30000},
          shares: {me: 10000, asha: 10000, ravi: 10000},
          createdBy: 'u1',
        ),
      ],
    );
  }

  setUp(() async {
    env = await ExpenseEnv.create();
    me = env.me;
    asha = env.ids['Asha']!;
    ravi = env.ids['Ravi']!;
  });
  tearDown(() => env.dispose());

  SettleArgs args({
    String? from,
    String? to,
    String? currency,
    String? paymentId,
    String? groupId,
  }) => (
    groupId: groupId ?? env.groupId,
    from: from,
    to: to,
    currency: currency,
    paymentId: paymentId,
  );

  Future<SettleDraft> open(SettleArgs a) {
    env.container.listen(settleProvider(a), (_, _) {});
    return env.container.read(settleProvider(a).future);
  }

  SettleController ctl(SettleArgs a) => env.container.read(settleProvider(a).notifier);
  SettleDraft draft(SettleArgs a) => env.container.read(settleProvider(a)).requireValue;

  Future<Map<String, Object?>> outboxPayload() async {
    final rows = await env.db.select(env.db.outbox).get();
    final o = rows.where((r) => r.entity == 'payment').last;
    return jsonDecode(o.payload) as Map<String, Object?>;
  }

  group('new payment', () {
    test('prefills from the first transfer that involves me (TC-25-02 unit side)', () async {
      await dinner();
      final d = await open(args());
      // TC-25-02: the owed amount is suggested, I am the one paid.
      expect((d.from, d.to), (asha, me));
      expect(d.amount, 10000);
      expect(d.amountText, isNotEmpty);
      expect(d.owed, 10000);
      expect(d.currency, 'INR');
      expect(d.meId, me);
      expect(d.isEdit, isFalse);
      expect(d.amountEdited, isFalse);
      expect(d.method, 'cash');
      expect(d.date, DateTime(2026, 11, 21));
      expect(d.groupName, 'Goa trip');
      expect(d.nameOf(asha), 'Asha');
      expect(d.canSave, isTrue);
      expect([for (final m in d.members) m.id], [me, asha, ravi]);
    });

    test('a given payer picks the transfer that involves them', () async {
      await dinner();
      final d = await open(args(from: ravi));
      expect((d.from, d.to), (ravi, me));
      expect(d.amount, 10000);
    });

    test('a given receiver picks the transfer that involves them', () async {
      await dinner();
      final d = await open(args(to: asha));
      expect((d.from, d.to), (asha, me));
    });

    test('given from and to are kept, with the amount they owe each other', () async {
      await dinner();
      final d = await open(args(from: me, to: asha));
      expect((d.from, d.to), (me, asha));
      expect(d.owed, 0);
      expect(d.amountText, '');
      expect(d.canSave, isFalse);
      expect(d.amount, isNull);
    });

    test('a given currency wins', () async {
      await dinner();
      final d = await open(args(from: asha, to: me, currency: 'USD'));
      expect(d.currency, 'USD');
      expect(d.owed, 0);
    });

    test('with nothing owed: me pays the first other member, nothing prefilled', () async {
      final d = await open(args());
      expect((d.from, d.to), (me, asha));
      expect(d.amountText, '');
      expect(d.canSave, isFalse);
    });

    test('without an account the first two members are used', () async {
      env.dispose();
      env = await ExpenseEnv.create(userId: null);
      me = env.me;
      final d = await open(args());
      expect(d.meId, isNull);
      expect(d.from, me);
      expect(d.to, env.ids['Asha']);
    });

    test('a group that is not here is SettleNotFound', () async {
      await expectLater(open(args(groupId: 'nope')), throwsA(isA<SettleNotFound>()));
    });

    test('a group with fewer than two active members is SettleNotFound', () async {
      await env.db.customStatement(
        "UPDATE group_members SET deleted_at = '2026-11-20T00:00:00Z' WHERE id <> '$me'",
      );
      await expectLater(open(args()), throwsA(isA<SettleNotFound>()));
    });

    test('removed members are not offered', () async {
      await env.db.customStatement("UPDATE group_members SET status = 'left' WHERE id = '$ravi'");
      final d = await open(args());
      expect([for (final m in d.members) m.id], [me, asha]);
    });

    // D-033 bug: the Balances tab still lists what someone who left owes; its Settle opened a form whose
    // payer was not among the form's people, and the screen threw (`firstWhere`, no element).
    test('a person who left but still owes can be settled from their balance row', () async {
      await dinner();
      await env.db.customStatement("UPDATE group_members SET status = 'left' WHERE id = '$ravi'");
      final d = await open(args(from: ravi, to: me, currency: 'INR'));
      expect((d.from, d.to), (ravi, me));
      expect(d.members.map((m) => m.id), containsAll([ravi, me]));
      expect(d.owed, 10000);
      expect(d.amountText, '100');
      expect(d.canSave, isTrue);
    });

    test('people that are not in the group fall back to a suggested pair', () async {
      await dinner();
      final d = await open(args(from: 'ghost', to: me));
      final ids = d.members.map((m) => m.id);
      expect(ids, contains(d.from));
      expect(ids, contains(d.to));
      expect(d.from, isNot(d.to));
      expect((d.from, d.to), (asha, me));
    });

    test('the same person on both sides falls back to a suggested pair', () async {
      await dinner();
      final d = await open(args(from: me, to: me));
      expect(d.from, isNot(d.to));
    });
  });

  group('changing the form', () {
    test('picking the other side swaps; amount follows what they owe', () async {
      await dinner();
      final a = args();
      await open(a);
      ctl(a).setFrom(ravi);
      expect((draft(a).from, draft(a).to), (ravi, me));
      expect(draft(a).amount, 10000);
      ctl(a).setTo(asha);
      // Ravi → Asha: nothing owed.
      expect((draft(a).from, draft(a).to), (ravi, asha));
      expect(draft(a).amountText, '');
      ctl(a).setTo(ravi);
      // Picking the payer as receiver swaps them.
      expect((draft(a).from, draft(a).to), (asha, ravi));
      ctl(a).setFrom(ravi);
      expect((draft(a).from, draft(a).to), (ravi, asha));
      ctl(a).swap();
      expect((draft(a).from, draft(a).to), (asha, ravi));
      ctl(a).setTo(me);
      ctl(a).setFrom(asha);
      expect((draft(a).from, draft(a).to), (asha, me));
      expect(draft(a).amount, 10000);
    });

    test('a typed amount stays when the people change', () async {
      await dinner();
      final a = args();
      await open(a);
      ctl(a).setAmountText('42.50');
      expect(draft(a).amount, 4250);
      expect(draft(a).amountEdited, isTrue);
      ctl(a).setFrom(ravi);
      expect(draft(a).amount, 4250);
      ctl(a).swap();
      expect(draft(a).amount, 4250);
    });

    test('useOwed fills in exactly what is owed', () async {
      await dinner();
      final a = args();
      await open(a);
      ctl(a).setAmountText('1');
      ctl(a).useOwed();
      expect(draft(a).amount, 10000);
      expect(draft(a).amountEdited, isTrue);
      ctl(a).setTo(asha);
      ctl(a).useOwed();
      expect(draft(a).amountText, '');
    });

    test('method, date and note', () async {
      await dinner();
      final a = args();
      await open(a);
      ctl(a)
        ..setMethod('upi')
        ..setDate(DateTime(2026, 11, 3))
        ..setNote('  for dinner ');
      final d = draft(a);
      expect((d.method, d.date, d.note), ('upi', DateTime(2026, 11, 3), '  for dinner '));
      expect(d.toRow()['note'], 'for dinner');
      expect(d.toRow()['date'], '2026-11-03');
    });

    test('a note over 200 characters blocks saving', () async {
      await dinner();
      final a = args();
      await open(a);
      ctl(a).setNote('x' * maxPaymentNote);
      expect(draft(a).noteTooLong, isFalse);
      expect(draft(a).canSave, isTrue);
      ctl(a).setNote('x' * (maxPaymentNote + 1));
      expect(draft(a).noteTooLong, isTrue);
      expect(draft(a).canSave, isFalse);
      expect(await ctl(a).save(), isNull);
      expect(() => draft(a).toRow(), throwsStateError);
    });

    test('same payer and receiver cannot be saved', () async {
      await dinner();
      final a = args();
      final d = await open(a);
      expect(d.copyWith(to: d.from).canSave, isFalse);
    });

    test('an invalid amount cannot be saved', () async {
      await dinner();
      final a = args();
      await open(a);
      ctl(a).setAmountText('abc');
      expect(draft(a).amount, isNull);
      expect(await ctl(a).save(), isNull);
      expect(await env.db.select(env.db.payments).get(), isEmpty);
    });
  });

  group('save', () {
    test('TC-25-02 a new payment goes to the payments table and the outbox', () async {
      await dinner();
      final a = args();
      await open(a);
      ctl(a)
        ..setMethod('upi')
        ..setNote('thanks')
        ..setDate(DateTime(2026, 11, 20));
      final id = (await ctl(a).save())!;
      final row = await (env.db.select(env.db.payments)..where((p) => p.id.equals(id))).getSingle();
      expect((row.fromMember, row.toMember, row.amount), (asha, me, 10000));
      expect(
        (row.currency, row.date, row.method, row.note),
        ('INR', '2026-11-20', 'upi', 'thanks'),
      );
      expect(row.groupId, env.groupId);
      expect(row.syncState, 'pending');
      final p = await outboxPayload();
      expect(p['from_member'], asha);
      expect(p['to_member'], me);
      expect(p['amount'], 10000);
      expect(p['currency'], 'INR');
      expect(p['date'], '2026-11-20');
      expect(p['method'], 'upi');
      expect(p['note'], 'thanks');
      expect(p['created_at'], env.clock.time.toUtc().toIso8601String());
      final box = await env.db.select(env.db.outbox).get();
      final o = box.firstWhere((r) => r.entity == 'payment');
      expect((o.op, o.recordId, o.groupId), ('upsert', id, env.groupId));
    });

    test('an empty note is saved as null', () async {
      await dinner();
      final a = args();
      await open(a);
      final id = (await ctl(a).save())!;
      final row = await (env.db.select(env.db.payments)..where((p) => p.id.equals(id))).getSingle();
      expect(row.note, isNull);
    });

    test('the group balances move once the payment is saved', () async {
      await dinner();
      final a = args();
      await open(a);
      await ctl(a).save();
      final ledger = (await env.container.read(settleProvider(args(from: asha, to: me)).future));
      expect(ledger.owed, 0);
    });
  });

  group('edit', () {
    Future<void> payment() => env.db.seed(
      payments: [
        seedPayment(
          'p1',
          groupId: env.groupId,
          from: asha,
          to: me,
          amount: 10000,
          date: '2026-11-18',
          method: 'bank',
          note: 'first part',
        ),
      ],
    );

    test('loads the saved payment; owed is computed without it', () async {
      await dinner();
      await payment();
      final a = args(paymentId: 'p1');
      final d = await open(a);
      expect(d.isEdit, isTrue);
      expect(d.paymentId, 'p1');
      expect((d.from, d.to, d.currency, d.method), (asha, me, 'INR', 'bank'));
      expect(d.amount, 10000);
      expect(d.amountEdited, isTrue);
      expect(d.date, DateTime(2026, 11, 18));
      expect(d.note, 'first part');
      // Without the payment Asha still owes 100.00.
      expect(d.owed, 10000);
    });

    test('saving writes the same row, with no created_at', () async {
      await dinner();
      await payment();
      final a = args(paymentId: 'p1');
      await open(a);
      ctl(a).setAmountText('60');
      final id = await ctl(a).save();
      expect(id, 'p1');
      final row = await (env.db.select(
        env.db.payments,
      )..where((p) => p.id.equals('p1'))).getSingle();
      expect(row.amount, 6000);
      expect(await env.db.select(env.db.payments).get(), hasLength(1));
      final p = await outboxPayload();
      expect(p.containsKey('created_at'), isFalse);
      expect(p['amount'], 6000);
    });

    test('keeps removed people of the saved payment in the form', () async {
      await dinner();
      await payment();
      await env.db.customStatement(
        "UPDATE group_members SET status = 'left', deleted_at = '2026-11-19T00:00:00Z' WHERE id = '$asha'",
      );
      final d = await open(args(paymentId: 'p1'));
      expect(d.members.map((m) => m.id), contains(asha));
    });

    test('a missing payment is SettleNotFound', () async {
      await expectLater(open(args(paymentId: 'nope')), throwsA(isA<SettleNotFound>()));
    });

    test('a deleted payment is SettleNotFound', () async {
      await env.db.seed(
        payments: [
          seedPayment(
            'p2',
            groupId: env.groupId,
            from: asha,
            to: me,
            amount: 1,
            deletedAt: '2026-11-20T00:00:00Z',
          ),
        ],
      );
      await expectLater(open(args(paymentId: 'p2')), throwsA(isA<SettleNotFound>()));
    });

    test('a payment of a group that is gone is SettleNotFound', () async {
      await env.db.seed(
        payments: [seedPayment('p3', groupId: 'ghost', from: 'a', to: 'b', amount: 1)],
      );
      await expectLater(open(args(paymentId: 'p3')), throwsA(isA<SettleNotFound>()));
    });
  });

  group('settleSuggestions', () {
    test('my transfers come first, the others after, in the tab order', () {
      // I (u1) sit last in the fixed order, so the tab lists the others' debt first.
      final b = groupBalancesOf(
        GroupLedger(
          group: seedGroup(),
          members: [
            seedMember('a', position: 0),
            seedMember('b', position: 1),
            seedMember('me', position: 2, userId: 'u1'),
          ],
          expenses: [
            seedExpense('e1', total: 100, payers: {'a': 100}, shares: {'b': 100}),
            seedExpense('e2', total: 200, payers: {'me': 200}, shares: {'a': 200}),
            seedExpense('e3', currency: 'USD', total: 50, payers: {'a': 50}, shares: {'b': 50}),
          ],
          payments: const [],
        ),
        'u1',
      );
      final s = settleSuggestions(b);
      expect(
        [for (final x in s) (x.currency, x.transfer.from, x.transfer.to, x.transfer.amount)],
        [('INR', 'a', 'me', 200), ('INR', 'b', 'a', 100), ('USD', 'b', 'a', 50)],
      );
    });

    test('without an account the order is the tab order', () {
      final b = groupBalancesOf(
        GroupLedger(
          group: seedGroup(),
          members: [seedMember('a'), seedMember('b', position: 1)],
          expenses: [
            seedExpense('e1', total: 100, payers: {'a': 100}, shares: {'b': 100}),
          ],
          payments: const [],
        ),
        null,
      );
      expect(settleSuggestions(b).single.transfer.amount, 100);
      expect(
        settleSuggestions(
          groupBalancesOf(
            GroupLedger(
              group: seedGroup(),
              members: const [],
              expenses: const [],
              payments: const [],
            ),
            null,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('currency and conversion (phase 14)', () {
    /// Mohit paid $20.00 for himself and Ravi: Ravi owes him $10.00 (1000 cents).
    Future<void> usdLunch() => env.db.seed(
      expenses: [
        seedExpense(
          'e2',
          groupId: env.groupId,
          currency: 'USD',
          total: 2000,
          payers: {me: 2000},
          shares: {me: 1000, ravi: 1000},
          createdBy: 'u1',
        ),
      ],
    );

    /// A payment of $50.00 Asha to Mohit, converted to INR at 75.
    Future<void> convertedPayment() => env.db.seed(
      payments: [
        seedPayment(
          'p1',
          groupId: env.groupId,
          from: asha,
          to: me,
          amount: 5000,
          currency: 'USD',
          date: '2026-11-18',
        ).copyWith(
          fxRate: const Value('75.0000000000'),
          fxRateDate: const Value('2026-11-17'),
          fxSource: const Value('frankfurter'),
          fxCurrency: const Value('INR'),
          fxAmount: const Value(375000),
        ),
      ],
    );

    Future<LocalPayment> paymentRow(String id) =>
        (env.db.select(env.db.payments)..where((p) => p.id.equals(id))).getSingle();

    // TC-32-08
    test('setCurrency makes the amount follow what is owed in the new currency', () async {
      await dinner();
      await usdLunch();
      final a = args(from: ravi, to: me);
      final d = await open(a);
      expect((d.currency, d.amount), ('INR', 10000));

      ctl(a).setCurrency('USD');
      expect(draft(a).currency, 'USD');
      expect(draft(a).owed, 1000);
      expect(draft(a).amountText, '10');
      expect(draft(a).amount, 1000);
      expect(draft(a).amountEdited, isFalse);

      ctl(a).setCurrency('EUR');
      expect(draft(a).currency, 'EUR');
      expect(draft(a).amountText, '');
      expect(draft(a).canSave, isFalse);

      ctl(a).setCurrency('INR');
      expect(draft(a).amountText, '100');
      // the people are kept
      expect((draft(a).from, draft(a).to), (ravi, me));
    });

    // TC-32-08
    test('a typed amount stays when the currency changes (read in the new exponent)', () async {
      await dinner();
      await usdLunch();
      final a = args(from: ravi, to: me);
      await open(a);
      ctl(a).setAmountText('42.50');
      ctl(a).setCurrency('USD');
      expect(draft(a).amountText, '42.50');
      expect(draft(a).amount, 4250);
      expect(draft(a).amountEdited, isTrue);
      // yen has no decimals: the same text is no longer an amount
      ctl(a).setCurrency('JPY');
      expect(draft(a).amountText, '42.50');
      expect(draft(a).amount, isNull);
      expect(draft(a).canSave, isFalse);
      ctl(a).setAmountText('4250');
      expect(draft(a).amount, 4250);
    });

    // TC-32-08
    test('a new payment in another currency saves that currency, with no fx keys', () async {
      await dinner();
      await usdLunch();
      final a = args(from: ravi, to: me);
      await open(a);
      ctl(a).setCurrency('USD');
      final id = (await ctl(a).save())!;
      final row = await paymentRow(id);
      expect((row.currency, row.amount), ('USD', 1000));
      expect(row.fxCurrency, isNull);
      expect(row.fxAmount, isNull);
      final p = await outboxPayload();
      expect(p['currency'], 'USD');
      expect(p.keys.where((k) => k.startsWith('fx_')), isEmpty);
    });

    // TC-32-08
    test(
      'editing a converted payment keeps the saved rate and re-converts the new amount',
      () async {
        await dinner();
        await convertedPayment();
        final a = args(paymentId: 'p1');
        final d = await open(a);
        expect((d.currency, d.amount), ('USD', 5000));

        ctl(a).setAmountText('80');
        expect(await ctl(a).save(), 'p1');
        final row = await paymentRow('p1');
        expect(row.amount, 8000);
        expect(row.fxAmount, convert(8000, 'USD', 'INR', '75.0000000000'));
        expect(row.fxAmount, 600000);
        // saved rates are never recalculated: rate, its date and source are the ones saved
        expect(row.fxRate, '75.0000000000');
        expect(row.fxRateDate, '2026-11-17');
        expect(row.fxSource, 'frankfurter');
        expect(row.fxCurrency, 'INR');

        final p = await outboxPayload();
        expect(p['amount'], 8000);
        expect(p['fx_amount'], 600000);
        expect(p['fx_rate'], '75.0000000000');
        expect(p['fx_currency'], 'INR');
      },
    );

    // TC-32-08
    test('editing other fields of a converted payment keeps its conversion', () async {
      await dinner();
      await convertedPayment();
      final a = args(paymentId: 'p1');
      await open(a);
      ctl(a).setNote('thanks');
      await ctl(a).save();
      final row = await paymentRow('p1');
      expect(row.note, 'thanks');
      expect(row.fxAmount, 375000);
      expect(row.fxRate, '75.0000000000');
    });

    // TC-32-08
    test('changing the currency of a converted payment clears its conversion', () async {
      await dinner();
      await convertedPayment();
      final a = args(paymentId: 'p1');
      await open(a);
      ctl(a).setCurrency('EUR');
      expect(draft(a).amountEdited, isTrue); // an edit keeps the typed amount
      expect(await ctl(a).save(), 'p1');
      final row = await paymentRow('p1');
      expect(row.currency, 'EUR');
      expect(row.amount, 5000);
      for (final v in [row.fxRate, row.fxRateDate, row.fxSource, row.fxCurrency]) {
        expect(v, isNull);
      }
      expect(row.fxAmount, isNull);
      final p = await outboxPayload();
      expect(p['currency'], 'EUR');
      for (final k in ['fx_rate', 'fx_rate_date', 'fx_source', 'fx_currency', 'fx_amount']) {
        expect(p.containsKey(k), isTrue, reason: k);
        expect(p[k], isNull, reason: k);
      }
    });

    // TC-32-08
    test('changing it to the currency of the conversion also clears it', () async {
      await dinner();
      await convertedPayment();
      final a = args(paymentId: 'p1');
      await open(a);
      ctl(a).setCurrency('INR');
      await ctl(a).save();
      final row = await paymentRow('p1');
      expect(row.currency, 'INR');
      expect(row.fxAmount, isNull);
      expect(row.fxRate, isNull);
    });

    // TC-32-08
    test('editing a payment that was never converted adds no fx keys', () async {
      await dinner();
      await env.db.seed(
        payments: [
          seedPayment(
            'p2',
            groupId: env.groupId,
            from: asha,
            to: me,
            amount: 5000,
            currency: 'USD',
          ),
        ],
      );
      final a = args(paymentId: 'p2');
      await open(a);
      ctl(a).setAmountText('60');
      await ctl(a).save();
      final p = await outboxPayload();
      expect(p['amount'], 6000);
      expect(p.keys.where((k) => k.startsWith('fx_')), isEmpty);
    });
  });
}
