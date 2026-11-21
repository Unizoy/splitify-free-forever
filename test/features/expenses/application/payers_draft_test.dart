// TC-10-01, TC-10-02 (logic): "Multiple people" payer amounts on the expense draft.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';

const _ids = ['a', 'b', 'c'];

ExpenseDraft _draft({
  String amount = '100',
  String? payerId = 'a',
  Map<String, int> payers = const {},
  List<String> splitMembers = _ids,
}) => ExpenseDraft(
  groupId: 'g',
  groupName: 'Goa',
  currency: 'INR',
  members: [for (final id in _ids) (id: id, name: id.toUpperCase(), isMe: id == 'a')],
  split: SplitDraft.initial(splitMembers, 2),
  date: DateTime(2026, 11, 21),
  payerId: payerId,
  payers: payers,
  amountText: amount,
  description: 'Dinner',
);

PayersInvalid _bad(ExpenseDraft d) => d.payersCheck as PayersInvalid;

void main() {
  group('switching between one and several payers', () {
    // TC-10-01
    test('withMultiplePayers starts from the saved amounts, zeros left out', () {
      final d = _draft(payerId: 'a', payers: {'a': 6000, 'b': 4000, 'c': 0}).withMultiplePayers();
      expect(d.multiplePayers, isTrue);
      expect(d.payerId, isNull);
      expect(d.payerInputs, {'a': '60', 'b': '40'});
    });

    // TC-10-01
    test('withPayerText edits one person and keeps the others', () {
      var d = _draft(payerId: null, payers: {'a': 6000, 'b': 4000});
      d = d.withPayerText('b', '25.50');
      expect(d.payerInputs, {'a': '60', 'b': '25.50'});
      expect(d.multiplePayers, isTrue);
      d = d.withPayerText('c', '14.50');
      expect(d.payerInputs, {'a': '60', 'b': '25.50', 'c': '14.50'});
    });

    // TC-10-01
    test('withSinglePayer picks one person; typed text is kept for coming back', () {
      var d = _draft(payerId: null, payers: {'a': 5000, 'b': 5000}).withPayerText('c', '1');
      d = d.withSinglePayer('b');
      expect(d.payerId, 'b');
      expect(d.multiplePayers, isFalse);
      expect(d.payerText, isNotNull);
      expect(d.payersCheck, isA<PayersReady>());
      expect((d.payersCheck as PayersReady).paid, {'b': 10000});
      expect(d.withMultiplePayers().payerInputs['c'], '1');
    });

    // TC-10-01
    test('copyWith keeps typed payer text', () {
      final d = _draft(payerId: null).withPayerText('a', '10').copyWith(description: 'x');
      expect(d.payerInputs, {'a': '10'});
      expect(d.copyWith(payerId: 'c').payerId, 'c');
    });
  });

  group('typedPayers and payerSum', () {
    // TC-10-01
    test('member order, zeros dropped', () {
      final d = _draft(payerId: null)
          .withPayerText('c', '30')
          .withPayerText('a', '70')
          .withPayerText('b', '0');
      expect(d.typedPayers!.keys.toList(), ['a', 'c']);
      expect(d.typedPayers, {'a': 7000, 'c': 3000});
      expect(d.payerSum, 10000);
    });

    // TC-10-01
    test('ids that are not members are still counted, after the members', () {
      final d = _draft(payerId: null, payers: {'gone': 2500, 'a': 7500});
      expect(d.typedPayers!.keys.toList(), ['a', 'gone']);
      expect(d.payerSum, 10000);
      expect(d.payersCheck, isA<PayersReady>());
    });

    // TC-10-01
    test('invalid text gives null and a zero sum', () {
      final d = _draft(payerId: null).withPayerText('a', 'abc').withPayerText('b', '50');
      expect(d.typedPayers, isNull);
      expect(d.payerSum, 0);
      expect(d.paidFor(10000), isEmpty);
      expect(d.payerIds, isEmpty);
    });
  });

  group('payersCheck', () {
    // TC-10-02
    test('a single payer is ready for the whole total', () {
      expect((_draft().payersCheck as PayersReady).paid, {'a': 10000});
    });

    // TC-10-02
    test('no valid total is AMOUNT_NOT_POSITIVE', () {
      final d = _draft(amount: '', payerId: null);
      expect(_bad(d).code, 'AMOUNT_NOT_POSITIVE');
      expect(_bad(_draft(amount: '0')).code, 'AMOUNT_NOT_POSITIVE');
    });

    // TC-10-02
    test('text that is not an amount is INVALID_INPUT', () {
      final d = _draft(payerId: null).withPayerText('a', '1x');
      expect(_bad(d).code, PayersInvalid.invalidInput);
    });

    // TC-10-02
    test('nobody typed anything is NO_PAYERS with everything remaining', () {
      final d = _draft(payerId: null).withPayerText('a', '');
      final c = _bad(d);
      expect((c.code, c.remaining), (PayersInvalid.noPayers, 10000));
    });

    // TC-10-02
    test('amounts below the total leave a positive remaining', () {
      final d = _draft(payerId: null).withPayerText('a', '60').withPayerText('b', '30');
      final c = _bad(d);
      expect((c.code, c.remaining), ('PAYERS_SUM_MISMATCH', 1000));
      expect(d.payersOk, isFalse);
      expect(d.canSave, isFalse);
    });

    // TC-10-02
    test('amounts above the total give a negative remaining (over)', () {
      final d = _draft(payerId: null).withPayerText('a', '60').withPayerText('b', '50');
      final c = _bad(d);
      expect((c.code, c.remaining), ('PAYERS_SUM_MISMATCH', -1000));
    });

    // TC-10-01
    test('amounts that add up are ready, in member order', () {
      final d = _draft(payerId: null).withPayerText('c', '40').withPayerText('a', '60');
      final ready = d.payersCheck as PayersReady;
      expect(ready.paid, {'a': 6000, 'c': 4000});
      expect(ready.paid.keys.toList(), ['a', 'c']);
      expect(d.paidFor(10000), {'a': 6000, 'c': 4000});
      expect(d.payerIds, ['a', 'c']);
      expect(d.canSave, isTrue);
    });
  });

  group('payerIds and toRow', () {
    // TC-10-01
    test('single payer: paidFor and payerIds', () {
      final d = _draft(payerId: 'b');
      expect(d.paidFor(500), {'b': 500});
      expect(d.payerIds, ['b']);
    });

    // TC-10-01
    test('toRow keeps only people with an amount; payers outside the split are fine', () {
      final d = _draft(
        payerId: null,
        splitMembers: const ['a', 'b'],
      ).withPayerText('b', '30').withPayerText('c', '70');
      expect(d.canSave, isTrue);
      final row = d.toRow();
      expect(row['payers'], {'b': 3000, 'c': 7000});
      expect((row['shares']! as Map).keys, ['a', 'b']);
      expect(row['kind'], 'expense');
      expect(row['total'], 10000);
    });

    // TC-10-02
    test('toRow throws while the payers do not add up', () {
      final d = _draft(payerId: null).withPayerText('a', '10');
      expect(d.toRow, throwsStateError);
    });
  });
}
