import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/domain/rules/default_split.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';

const _m = ['a', 'b', 'c'];

Map<String, int> _ready(SplitCheck c) => (c as SplitReady).shares;

void main() {
  group('SplitDraft (TC-5..9-03 logic)', () {
    test('equal between all, then without one', () {
      final d = SplitDraft.initial(_m, 2);
      expect(_ready(d.check(10000)), {'a': 3334, 'b': 3333, 'c': 3333});
      final two = d.toggle('c');
      expect(_ready(two.check(10000)), {'a': 5000, 'b': 5000});
      expect(two.toggle('c').participants, _m);
      expect(d.toggle('a').toggle('b').toggle('c').check(100), isA<SplitInvalid>());
      expect(d.check(null), isA<SplitInvalid>());
      expect(d.storedValues, isNull);
    });

    test('exact: live remaining and over', () {
      var d = SplitDraft.initial(_m, 2).switchTo(SplitKind.exact, total: 10000);
      expect(_ready(d.check(10000)), {'a': 3334, 'b': 3333, 'c': 3333});
      d = d.setText('a', '40').setText('b', '30').setText('c', '');
      final c = d.check(10000) as SplitInvalid;
      expect((c.code, c.amount), ('SUM_MISMATCH', 3000));
      expect(d.valueSum, 7000);
      d = d.setText('c', '40');
      expect((d.check(10000) as SplitInvalid).amount, -1000);
      expect(d.setText('c', 'x').check(10000), isA<SplitInvalid>());
      expect(d.setText('c', 'x').valueSum, 0);
      expect(d.setText('c', '30').storedValues, {'a': 4000, 'b': 3000, 'c': 3000});
    });

    test('exact without a total starts empty', () {
      final d = SplitDraft.initial(_m, 2).switchTo(SplitKind.exact);
      expect(d.text, isEmpty);
    });

    test('percent: equal percentages, sum mismatch in bps', () {
      var d = SplitDraft.initial(_m, 2).switchTo(SplitKind.percent);
      expect(d.text, {'a': '33.34', 'b': '33.33', 'c': '33.33'});
      expect(_ready(d.check(10000)), {'a': 3334, 'b': 3333, 'c': 3333});
      d = d.setText('c', '30');
      final c = d.check(100) as SplitInvalid;
      expect((c.code, c.amount), ('PERCENT_SUM_MISMATCH', 333));
    });

    test('shares: one each, steppers, none = error', () {
      var d = SplitDraft.initial(_m, 2).toggle('c').switchTo(SplitKind.shares);
      expect(d.shareUnits, {'a': 1000, 'b': 1000});
      d = d.setShareUnits('b', 2000);
      expect(_ready(d.check(300)), {'a': 100, 'b': 200, 'c': 0});
      expect(d.chosen, ['a', 'b']);
      d = d.setShareUnits('a', -5).setShareUnits('b', 0);
      expect((d.check(300) as SplitInvalid).code, 'NO_SHARES');
      expect(d.chosen, _m);
    });

    test('adjust: rest split equally, over total', () {
      var d = SplitDraft.initial(_m, 2).switchTo(SplitKind.adjust);
      d = d.setText('a', '10');
      expect(_ready(d.check(4000)), {'a': 2000, 'b': 1000, 'c': 1000});
      d = d.setText('a', '50');
      final c = d.check(4000) as SplitInvalid;
      expect((c.code, c.amount), ('ADJUSTMENTS_EXCEED_TOTAL', -1000));
      expect(d.setText('b', '-20').check(4000), isA<SplitInvalid>());
    });

    test('switching keeps chosen people; same kind is a no-op', () {
      final d = SplitDraft.initial(_m, 2).toggle('b');
      expect(d.switchTo(SplitKind.equal), same(d));
      final p = d.switchTo(SplitKind.percent);
      expect(p.text.keys, ['a', 'c']);
      expect(p.switchTo(SplitKind.equal).participants, ['a', 'c']);
    });

    test('stored reopens the same editor state (TC-5..9-03 edit)', () {
      final d = SplitDraft.stored(
        members: ['a', 'b'],
        exponent: 2,
        kind: SplitKind.percent,
        participants: ['a', 'b', 'gone'],
        values: {'a': 6000, 'b': 2000, 'gone': 2000},
      );
      expect(d.members, ['a', 'b', 'gone']);
      expect(d.text, {'a': '60', 'b': '20', 'gone': '20'});
      expect(_ready(d.check(1000)), {'a': 600, 'b': 200, 'gone': 200});
      final e = SplitDraft.stored(
        members: _m,
        exponent: 2,
        kind: SplitKind.equal,
        participants: ['a', 'b'],
      );
      expect(e.participants, ['a', 'b']);
    });
  });

  group('DefaultSplit (TC-35-01)', () {
    test('decode / encode', () {
      expect(DefaultSplit.decode(null), isNull);
      expect(DefaultSplit.decode(''), isNull);
      expect(DefaultSplit.decode('nope'), isNull);
      expect(DefaultSplit.decode('{"kind":"exact","values":{}}'), isNull);
      final d = DefaultSplit.decode('{"kind":"percent","values":{"a":6000,"b":4000}}')!;
      expect(d.kind, SplitKind.percent);
      expect(d.values, {'a': 6000, 'b': 4000});
      expect(d.toJson(), {
        'kind': 'percent',
        'values': {'a': 6000, 'b': 4000},
      });
      expect(DefaultSplit.decode('{"kind":"equal"}')!.values, isEmpty);
    });

    test('falls back to equal when members changed or values are invalid', () {
      const d = DefaultSplit(SplitKind.percent, {'a': 6000, 'b': 4000});
      expect(d.resolve(['a', 'b']), same(d));
      expect(d.resolve(['a', 'b', 'c']), isNull);
      expect(d.resolve(['a', 'c']), isNull);
      expect(d.resolve([]), isNull);
      expect(
        const DefaultSplit(SplitKind.percent, {'a': 6000, 'b': 3000}).resolve(['a', 'b']),
        isNull,
      );
      const eq = DefaultSplit(SplitKind.equal);
      expect(eq.resolve(['x']), same(eq));
    });

    test('prefills the split draft (TC-35-02 logic)', () {
      const d = DefaultSplit(SplitKind.shares, {'a': 2000, 'b': 1000});
      final s = SplitDraft.initial(['a', 'b'], 2, preset: d);
      expect(_ready(s.check(300)), {'a': 200, 'b': 100});
    });
  });

  group('ExpenseCategories', () {
    test('keys and parents', () {
      expect(ExpenseCategories.isKnown('food.snacks'), isTrue);
      expect(ExpenseCategories.isKnown('food.unknown'), isFalse);
      expect(ExpenseCategories.parentOf('zzz.y'), 'other');
      expect(ExpenseCategories.normalize('zzz'), ExpenseCategories.defaultKey);
      expect(ExpenseCategories.normalize('rent.rent'), 'rent.rent');
      expect(ExpenseCategories.tree.values.expand((v) => v), hasLength(30));
    });
  });

  group('ExpenseDraft (TC-13-01 logic)', () {
    ExpenseDraft draft() => ExpenseDraft(
      groupId: 'g',
      groupName: 'Goa',
      currency: 'INR',
      members: const [(id: 'a', name: 'Asha', isMe: true), (id: 'b', name: 'Ravi', isMe: false)],
      split: SplitDraft.initial(['a', 'b'], 2),
      date: DateTime(2026, 11, 3),
      payerId: 'a',
      payers: const {},
    );

    test('validation', () {
      final d = draft();
      expect(d.canSave, isFalse);
      expect(d.descriptionProblem, DescriptionProblem.missing);
      expect(d.copyWith(description: 'x' * 121).descriptionProblem, DescriptionProblem.tooLong);
      final ok = d.copyWith(amountText: '450+50', description: ' Dinner ');
      expect(ok.fastPathReady, isTrue);
      expect(ok.canSave, isTrue);
      expect(ok.copyWith(notes: 'n' * 1001).canSave, isFalse);
      expect(() => d.toRow(), throwsStateError);
      expect(ok.member('b')!.name, 'Ravi');
      expect(ok.member('z'), isNull);
      expect(ok.isEdit, isFalse);
    });

    test('row for the repository', () {
      final row = draft().copyWith(amountText: '100', description: 'Dinner', notes: ' hi ').toRow();
      expect(row['total'], 10000);
      expect(row['payers'], {'a': 10000});
      expect(row['shares'], {'a': 5000, 'b': 5000});
      expect(row['date'], '2026-11-03');
      expect(row['notes'], 'hi');
      expect(row['split_kind'], 'equal');
      expect(row['split_values'], isNull);
      expect(draft().copyWith(amountText: '1', description: 'x').toRow()['notes'], isNull);
    });

    test('multi-payer expense keeps its payers', () {
      final d = ExpenseDraft(
        groupId: 'g',
        groupName: 'Goa',
        currency: 'INR',
        members: const [],
        split: SplitDraft.initial(['a', 'b'], 2),
        date: DateTime(2026),
        payers: const {'a': 6000, 'b': 4000},
        amountText: '100',
        description: 'x',
      );
      expect(d.payersOk, isTrue);
      expect(d.copyWith(amountText: '90').payersOk, isFalse);
      expect(d.copyWith(amountText: '').payersOk, isFalse);
    });

    test('dates and kinds', () {
      expect(parseIsoDate('2026-01-05'), DateTime(2026, 1, 5));
      expect(parseIsoDate('2026-01-05T10:00:00Z'), DateTime(2026, 1, 5));
      expect(splitKindOf('shares'), SplitKind.shares);
      expect(splitKindOf('weird'), SplitKind.equal);
    });
  });
}
