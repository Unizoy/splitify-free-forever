// Shared money vectors (planning/05-money-engine.md, contract with the oracle
// planning/reference/money_reference.py and the Postgres `money` schema).
//
// TC-5..9-01  every split vector            (op split)
// TC-10-01    payer validation vectors      (op check_payers)
// TC-15-01    vectors BAL-*                 (op balances)
// TC-17-01    simplify vectors              (BAL-* "simplified")
// TC-25-01    payment effect on nets/pairs  (BAL-02, BAL-07)
// TC-11-01    IOU produces correct pair     (BAL-08)
// TC-32-01    FX vectors                    (ops convert, convert_expense, cross_rate)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/money/fx.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/core/money/split.dart';

const _fixture = 'test/fixtures/money_vectors.json';
const _planning = 'planning/reference/money_vectors.json';

typedef _Json = Map<String, dynamic>;

/// Vectors use one currency per case; balances records need one.
const _currency = 'INR';

Map<String, int> _ints(Object? json) => (json! as _Json).map((k, v) => MapEntry(k, v as int));

List<String> _strings(Object? json) => (json! as List).cast<String>();

List<List<Object>> _transfers(List<Transfer> ts) => [
  for (final t in ts) [t.from, t.to, t.amount],
];

List<ExpenseFlow> _expenses(Object? json) => [
  for (final e in (json! as List).cast<_Json>())
    ExpenseFlow(currency: _currency, paid: _ints(e['paid']), shares: _ints(e['shares'])),
];

List<Payment> _payments(Object? json) => [
  for (final p in (json! as List).cast<_Json>())
    Payment(
      currency: _currency,
      from: p['from'] as String,
      to: p['to'] as String,
      amount: p['amount'] as int,
    ),
];

/// Runs one vector's input through the Dart engine and returns the JSON-shaped result.
Object? _run(_Json v) {
  final input = v['input'] as _Json;
  switch (v['op']) {
    case 'split':
      final members = _strings(input['members']);
      final out = split(
        input['total'] as int,
        SplitKind.parse(input['kind'] as String),
        members,
        _ints(input['values']),
      );
      // Shares come back in fixed (members) order.
      expect(out.keys.toList(), members, reason: 'split order');
      return out;
    case 'check_payers':
      checkPayers(input['total'] as int, _ints(input['paid']));
      return true;
    case 'balances':
      final order = _strings(input['order']);
      final b = Balances.compute(order, _expenses(input['expenses']), _payments(input['payments']));
      expect(b.nets.keys.toList(), order, reason: 'nets order');
      return {'nets': b.nets, 'pairs': _transfers(b.pairs), 'simplified': _transfers(b.simplified)};
    case 'convert':
      return convert(
        input['amount'] as int,
        input['from'] as String,
        input['to'] as String,
        input['rate'] as String,
      );
    case 'convert_expense':
      final c = convertExpense(
        total: input['total'] as int,
        from: input['from'] as String,
        to: input['to'] as String,
        rate: input['rate'] as String,
        paid: _ints(input['paid']),
        shares: _ints(input['shares']),
        order: _strings(input['order']),
      );
      return {'total': c.total, 'paid': c.paid, 'shares': c.shares};
    case 'cross_rate':
      final rates = (input['eur_rates'] as _Json).map((k, v) => MapEntry(k, v as String));
      return crossRate(rates, input['from'] as String, input['to'] as String);
  }
  fail('unknown op ${v['op']} in ${v['id']}');
}

void _expectVector(_Json v) {
  final expected = v['expected'] as _Json;
  if (expected.containsKey('error')) {
    expect(
      () => _run(v),
      throwsA(
        isA<MoneyError>()
            .having((e) => e.code, 'code', expected['error'])
            .having((e) => e.data, 'data', expected['data'] ?? const <String, Object>{}),
      ),
    );
  } else {
    expect(_run(v), expected['ok']);
  }
}

void main() {
  final doc = jsonDecode(File(_fixture).readAsStringSync()) as _Json;
  final vectors = (doc['vectors'] as List).cast<_Json>();

  test('vectors fixture is a byte-identical copy of the planning file', () {
    expect(File(_fixture).readAsBytesSync(), File(_planning).readAsBytesSync());
  });

  test('vectors fixture has 52 vectors with unique ids and known ops', () {
    expect(doc['version'], 1);
    expect(vectors, hasLength(52));
    expect(vectors.map((v) => v['id']).toSet(), hasLength(52));
    expect(vectors.map((v) => v['op']).toSet(), {
      'split',
      'check_payers',
      'balances',
      'convert',
      'convert_expense',
      'cross_rate',
    });
  });

  // TC-5..9-01
  group('split', () {
    for (final v in vectors.where((v) => v['op'] == 'split')) {
      test('split matches vector ${v['id']}', () => _expectVector(v));
    }
  });

  // TC-10-01
  group('check_payers', () {
    for (final v in vectors.where((v) => v['op'] == 'check_payers')) {
      test('checkPayers matches vector ${v['id']}', () => _expectVector(v));
    }
  });

  // TC-15-01, TC-17-01; TC-25-01 (BAL-02, BAL-07 have payments); TC-11-01 (BAL-08 is an IOU)
  group('balances', () {
    for (final v in vectors.where((v) => v['op'] == 'balances')) {
      test('balances match vector ${v['id']}', () => _expectVector(v));
    }
  });

  // TC-32-01
  group('fx', () {
    for (final v in vectors.where(
      (v) => const {'convert', 'convert_expense', 'cross_rate'}.contains(v['op']),
    )) {
      test('${v['op']} matches vector ${v['id']}', () => _expectVector(v));
    }
  });
}
