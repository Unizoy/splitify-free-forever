// TC-32-08: a saved conversion follows an expense edit (same currency: the saved rate re-converts the
// new amounts; another currency: the conversion is dropped), and the currency switch of the draft.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/fx.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';

import '../../../support/ledger_seed.dart';
import 'expense_test_env.dart';

const _rate = '75.0000000000';

Map<String, int> _ints(String? json) => {
  for (final e in (jsonDecode(json!) as Map<String, Object?>).entries) e.key: e.value! as int,
};

int _sum(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

void main() {
  late ExpenseEnv env;
  late String me;
  late String asha;
  late String ravi;

  setUp(() async {
    env = await ExpenseEnv.create();
    me = env.me;
    asha = env.ids['Asha']!;
    ravi = env.ids['Ravi']!;
  });
  tearDown(() => env.dispose());

  /// $100.01 paid by Mohit, shared equally by the three; converted to INR at 75 when [fx].
  Future<void> usdExpense({bool fx = true, String source = 'frankfurter', String rate = _rate}) {
    final base = seedExpense(
      'e1',
      groupId: env.groupId,
      currency: 'USD',
      total: 10001,
      payers: {me: 10001},
      shares: {me: 3334, asha: 3334, ravi: 3333},
      createdBy: 'u1',
    );
    final row = !fx
        ? base
        : base.copyWith(
            fxRate: Value(rate),
            fxRateDate: const Value('2026-11-17'),
            fxSource: Value(source),
            fxCurrency: const Value('INR'),
            fxTotal: const Value(750075),
            fxPayers: Value(jsonEncode({me: 750075})),
            fxShares: Value(jsonEncode({me: 250025, asha: 250025, ravi: 250025})),
          );
    return env.db.seed(expenses: [row]);
  }

  Future<LocalExpense> expense() =>
      (env.db.select(env.db.expenses)..where((e) => e.id.equals('e1'))).getSingle();

  Future<Map<String, Object?>> lastPayload() async {
    final rows = await env.db.select(env.db.outbox).get();
    return jsonDecode(rows.where((r) => r.entity == 'expense').last.payload)
        as Map<String, Object?>;
  }

  const fxKeys = [
    'fx_rate',
    'fx_rate_date',
    'fx_source',
    'fx_currency',
    'fx_total',
    'fx_payers',
    'fx_shares',
  ];

  group('a converted expense edited in the same currency', () {
    // TC-32-08
    test('an amount edit keeps the saved rate and re-converts total and parts', () async {
      await usdExpense();
      final e = await env.open(expenseId: 'e1');
      expect(e.draft.currency, 'USD');
      e.edit((d) => d.copyWith(amountText: '200'));
      expect(await e.save(), 'e1');

      final row = await expense();
      expect(row.total, 20000);
      // the saved rate, its day and its source are not recalculated
      expect(row.fxRate, _rate);
      expect(row.fxRateDate, '2026-11-17');
      expect(row.fxSource, 'frankfurter');
      expect(row.fxCurrency, 'INR');
      expect(row.fxTotal, convert(20000, 'USD', 'INR', _rate));
      expect(row.fxTotal, 1500000);

      final c = convertExpense(
        total: 20000,
        from: 'USD',
        to: 'INR',
        rate: _rate,
        paid: _ints(row.payers),
        shares: _ints(row.shares),
        order: [me, asha, ravi],
      );
      expect(_ints(row.fxPayers), c.paid);
      expect(_ints(row.fxShares), c.shares);
      expect(_sum(_ints(row.fxPayers)), row.fxTotal);
      expect(_sum(_ints(row.fxShares)), row.fxTotal);

      final p = await lastPayload();
      expect(p['total'], 20000);
      expect(p['fx_total'], 1500000);
      expect(p['fx_rate'], _rate);
      expect(p['fx_currency'], 'INR');
    });

    // TC-32-08
    test('a change that is not about money keeps the conversion as it was', () async {
      await usdExpense();
      final e = await env.open(expenseId: 'e1');
      e.edit((d) => d.copyWith(description: 'Renamed'));
      await e.save();
      final row = await expense();
      expect(row.description, 'Renamed');
      expect(row.fxTotal, 750075);
      expect(row.fxRate, _rate);
      expect(row.fxRateDate, '2026-11-17');
      expect(_sum(_ints(row.fxShares)), 750075);
    });

    // TC-32-08
    test('a new split re-allocates the converted shares', () async {
      await usdExpense();
      final e = await env.open(expenseId: 'e1');
      e.edit((d) => d.copyWith(split: d.split.toggle(ravi)));
      await e.save();
      final row = await expense();
      expect(_ints(row.shares).keys, {me, asha});
      final fxShares = _ints(row.fxShares);
      expect(fxShares.keys, {me, asha});
      expect(_sum(fxShares), row.fxTotal);
      expect(row.fxTotal, 750075); // the total did not change
      // 5001 : 5000 of $100.01 (2 people), re-allocated over 750075 paise by those amounts
      expect(_ints(row.shares), {me: 5001, asha: 5000});
      expect(fxShares, {me: 375075, asha: 375000});
    });

    // TC-32-08
    test('a typed rate stays a typed rate', () async {
      await usdExpense(source: 'manual', rate: '80');
      final e = await env.open(expenseId: 'e1');
      e.edit((d) => d.copyWith(amountText: '50'));
      await e.save();
      final row = await expense();
      expect(row.fxSource, 'manual');
      expect(row.fxRate, '80');
      expect(row.fxTotal, convert(5000, 'USD', 'INR', '80'));
      expect(row.fxTotal, 400000);
    });

    // TC-32-08
    test('an edit that can no longer be converted drops the conversion', () async {
      await usdExpense(rate: '1000000000000000');
      final e = await env.open(expenseId: 'e1');
      e.edit((d) => d.copyWith(amountText: '200'));
      await e.save();
      final row = await expense();
      expect(row.total, 20000);
      expect(row.fxTotal, isNull);
      expect(row.fxRate, isNull);
      expect(row.fxPayers, isNull);
    });
  });

  group('currency change', () {
    // TC-32-08
    test('another currency clears the conversion (all fx columns, also in the outbox)', () async {
      await usdExpense();
      final e = await env.open(expenseId: 'e1');
      e.edit((d) => d.withCurrency('EUR'));
      expect(e.draft.currency, 'EUR');
      expect(await e.save(), 'e1');
      final row = await expense();
      expect(row.currency, 'EUR');
      expect(row.total, 10001);
      expect(row.fxRate, isNull);
      expect(row.fxRateDate, isNull);
      expect(row.fxSource, isNull);
      expect(row.fxCurrency, isNull);
      expect(row.fxTotal, isNull);
      expect(row.fxPayers, isNull);
      expect(row.fxShares, isNull);
      final p = await lastPayload();
      for (final k in fxKeys) {
        expect(p.containsKey(k), isTrue, reason: k);
        expect(p[k], isNull, reason: k);
      }
    });

    // TC-32-08
    test('moving to the group currency also clears it', () async {
      await usdExpense();
      final e = await env.open(expenseId: 'e1');
      e.edit((d) => d.withCurrency('INR'));
      await e.save();
      final row = await expense();
      expect(row.currency, 'INR');
      expect(row.fxTotal, isNull);
      expect(row.fxRate, isNull);
    });

    // TC-32-08
    test('an expense without a conversion never gets fx keys', () async {
      await usdExpense(fx: false);
      final e = await env.open(expenseId: 'e1');
      e.edit((d) => d.copyWith(amountText: '120'));
      await e.save();
      final row = await expense();
      expect(row.total, 12000);
      expect(row.fxTotal, isNull);
      expect(row.fxRate, isNull);
      final p = await lastPayload();
      expect(p.keys.where((k) => k.startsWith('fx_')), isEmpty);

      final f = await env.open(expenseId: 'e1');
      f.edit((d) => d.withCurrency('EUR'));
      await f.save();
      expect((await lastPayload()).keys.where((k) => k.startsWith('fx_')), isEmpty);
    });

    // TC-32-08
    test('a new expense in another currency has no fx keys', () async {
      final e = await env.open();
      e.edit((d) => d.withCurrency('USD').copyWith(amountText: '10', description: 'Coffee'));
      expect(e.draft.canSave, isTrue);
      final id = (await e.save())!;
      final row = await (env.db.select(env.db.expenses)..where((x) => x.id.equals(id))).getSingle();
      expect((row.currency, row.total), ('USD', 1000));
      expect(row.fxTotal, isNull);
      expect((await lastPayload()).keys.where((k) => k.startsWith('fx_')), isEmpty);
    });
  });

  group('draft currency switch', () {
    // TC-32-08
    test('ExpenseDraft.withCurrency keeps everything but the currency and the exponent', () async {
      final e = await env.open();
      e.edit(
        (d) => d.copyWith(
          amountText: '100',
          description: 'Dinner',
          category: 'food.dining_out',
          notes: 'n',
          split: d.split.toggle(ravi),
        ),
      );
      final before = e.draft;
      final after = before.withCurrency('JPY');
      expect(after.currency, 'JPY');
      expect(after.split.exponent, 0);
      expect(after.amountText, '100');
      expect(after.description, 'Dinner');
      expect(after.category, 'food.dining_out');
      expect(after.notes, 'n');
      expect(after.groupId, before.groupId);
      expect(after.date, before.date);
      expect(after.payerId, before.payerId);
      expect(after.split.participants, before.split.participants);
      expect(after.split.kind, SplitKind.equal);
      expect(after.total, 100);

      // back to rupees: 100 is a hundred rupees
      expect(after.withCurrency('INR').total, 10000);
      expect(after.withCurrency('INR').split.exponent, 2);
    });

    // TC-32-08
    test('the saved expense id is kept', () async {
      await usdExpense(fx: false);
      final e = await env.open(expenseId: 'e1');
      expect(e.draft.withCurrency('EUR').expenseId, 'e1');
      expect(e.draft.withCurrency('EUR').isEdit, isTrue);
    });

    // TC-32-08
    test('SplitDraft.withExponent re-checks typed exact values in the new exponent', () {
      final base = SplitDraft.initial([
        me,
        asha,
      ], 2).switchTo(SplitKind.exact, total: 10050).setText(me, '60.50').setText(asha, '40');
      expect(base.exponent, 2);
      expect(base.check(10050), isA<SplitReady>());

      final yen = base.withExponent(0);
      expect(yen.exponent, 0);
      expect(yen.kind, SplitKind.exact);
      expect(yen.text, base.text); // the typed text is kept
      expect(yen.participants, base.participants);
      // 60.50 has decimals a yen does not have
      expect(yen.check(10050), isA<SplitInvalid>());

      final back = yen.withExponent(2);
      expect(back.check(10050), isA<SplitReady>());
    });
  });
}
