// D-032 one-screen editor, application side: what stops Save and in which order, the amount typing rules,
// integer minor units, split sums, and that every draft change keeps the typed amount.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/domain/rules/recurrence.dart' show RecurrenceInterval;
import 'package:splitify/features/expenses/application/amount_input.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/paid_split_sheet.dart';
import 'package:splitify/features/recurring/application/repeat_draft.dart';
import 'package:splitify/l10n/app_localizations.dart';

const _people = <EditorMember>[
  (id: 'a', name: 'Asha', isMe: true),
  (id: 'b', name: 'Ravi', isMe: false),
  (id: 'c', name: 'Meera', isMe: false),
];

ExpenseDraft _draft({
  String amount = '',
  String description = '',
  String currency = 'INR',
  String groupType = 'trip',
  int exponent = 2,
}) => ExpenseDraft(
  groupId: 'g',
  groupName: 'Goa',
  groupType: groupType,
  currency: currency,
  members: _people,
  split: SplitDraft.initial(['a', 'b', 'c'], exponent),
  date: DateTime(2026, 11, 27),
  payerId: 'a',
  payers: const {},
  amountText: amount,
  description: description,
  canRepeat: true,
);

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  group('what stops Save (firstProblem)', () {
    test('blank: the description first, then the amount', () {
      final d = _draft();
      expect(d.firstProblem, EditorProblem.description);
      expect(d.canSave, isFalse);
      expect(d.copyWith(description: 'Tea').firstProblem, EditorProblem.amount);
      expect(d.copyWith(amountText: '60').firstProblem, EditorProblem.description);
    });

    test('a description of spaces is missing; over 120 characters is too long', () {
      expect(_draft(amount: '60', description: '   ').firstProblem, EditorProblem.description);
      expect(
        _draft(amount: '60', description: 'x' * 121).descriptionProblem,
        DescriptionProblem.tooLong,
      );
      expect(_draft(amount: '60', description: 'x' * 120).firstProblem, isNull);
    });

    test('an amount that is not valid is an amount problem, but not "missing"', () {
      for (final text in ['0', '1.234', '9999999999999']) {
        final d = _draft(amount: text, description: 'Tea');
        expect(d.firstProblem, EditorProblem.amount, reason: text);
        expect(d.amountMissing, isFalse, reason: text);
      }
      expect(_draft(description: 'Tea').amountMissing, isTrue);
      expect(_draft(amount: '  ', description: 'Tea').amountMissing, isTrue);
    });

    test('payers or split that do not add up point at the sheet', () {
      final ok = _draft(amount: '900', description: 'Cab');
      expect(ok.firstProblem, isNull);
      expect(
        ok.withMultiplePayers().withPayerText('a', '100').firstProblem,
        EditorProblem.paidSplit,
      );
      expect(
        ok.copyWith(split: ok.split.withValues(SplitKind.exact, {'a': 10000})).firstProblem,
        EditorProblem.paidSplit,
      );
      expect(
        ok.copyWith(split: ok.split.toggle('a').toggle('b').toggle('c')).firstProblem,
        EditorProblem.paidSplit,
      );
    });

    test('then too long notes, then a repeat ending before the date', () {
      final ok = _draft(amount: '900', description: 'Cab');
      expect(ok.copyWith(notes: 'n' * 1001).firstProblem, EditorProblem.notes);
      final early = ok.withRepeat(
        RepeatDraft(interval: RecurrenceInterval.monthly, endsOn: DateTime(2026, 11, 1)),
      );
      expect(early.firstProblem, EditorProblem.repeat);
      expect(
        ok.withRepeat(const RepeatDraft(interval: RecurrenceInterval.monthly)).canSave,
        isTrue,
      );
    });
  });

  group('integer minor units', () {
    test('typed text becomes minor units for the currency', () {
      expect(_draft(amount: '1200.5').total, 120050);
      expect(_draft(amount: '0.01').total, 1);
      expect(_draft(amount: '1250', currency: 'JPY', exponent: 0).total, 1250);
      expect(_draft(amount: '1.234', currency: 'KWD', exponent: 3).total, 1234);
      expect(_draft(amount: '12.5', currency: 'JPY', exponent: 0).total, isNull);
    });

    test('equal split leftovers go one each in fixed order and sum to the total', () {
      final d = _draft(amount: '100', description: 'x');
      final shares = (d.splitCheck as SplitReady).shares;
      expect(shares, {'a': 3334, 'b': 3333, 'c': 3333});
      expect(shares.values.fold<int>(0, (a, b) => a + b), 10000);
      final row = d.toRow();
      expect(row['total'], 10000);
      expect(row['payers'], {'a': 10000});
    });
  });

  group('the typed amount is never lost', () {
    test('every change keeps amountText', () {
      final d = _draft(amount: '450.75', description: 'Dinner');
      final changed = [
        d.withCurrency('USD'),
        d.withRepeat(const RepeatDraft(interval: RecurrenceInterval.weekly)),
        d.pickCategory('food.takeaway'),
        d.withSuggestedCategory('food.takeaway'),
        d.withSinglePayer('b'),
        d.withMultiplePayers(),
        d.withPayerText('b', '100'),
        d.copyWith(split: d.split.toggle('c')),
        d.copyWith(description: ''),
        d.copyWith(notes: 'n'),
        d.copyWith(date: DateTime(2026, 11, 1)),
        d.copyWith(receipt: const ReceiptDraft.none()),
      ];
      for (final (i, x) in changed.indexed) {
        expect(x.amountText, '450.75', reason: 'change $i');
        expect(x.groupType, 'trip', reason: 'change $i');
      }
    });
  });

  group('friend expenses', () {
    test('a direct group names the friend', () {
      final d = _draft(groupType: 'direct');
      expect(d.isDirect, isTrue);
      expect(d.friend?.name, 'Ravi');
      expect(_draft().friend, isNull);
    });
  });

  group('AmountInput.accept', () {
    test('digits and one decimal point within the currency decimals', () {
      expect(AmountInput.accept('1200', 2), '1200');
      expect(AmountInput.accept('1200.5', 2), '1200.5');
      expect(AmountInput.accept('1200.50', 2), '1200.50');
      expect(AmountInput.accept('1200.505', 2), isNull);
      expect(AmountInput.accept('1.2.3', 2), isNull);
      expect(AmountInput.accept('.5', 2), '.5');
      expect(AmountInput.accept('', 2), '');
    });

    test('no decimal point for currencies without decimals; three for KWD', () {
      expect(AmountInput.accept('125.', 0), isNull);
      expect(AmountInput.accept('125', 0), '125');
      expect(AmountInput.accept('1.234', 3), '1.234');
    });

    test('pasted text loses grouping, spaces and signs; too many digits are refused', () {
      expect(AmountInput.accept('₹1,200.50', 2), '1200.50');
      expect(AmountInput.accept(' 4 500 ', 2), '4500');
      expect(AmountInput.accept('-500', 2), '500');
      expect(AmountInput.accept('1' * 12, 2), '1' * 12);
      expect(AmountInput.accept('1' * 13, 2), isNull);
    });
  });

  group('summary pill text', () {
    test('who paid and how it is split', () {
      final d = _draft(amount: '1200', description: 'x');
      expect(paidSplitSummary(l, d), 'Paid by You\u00A0· split equally');
      expect(paidSplitSummary(l, d.withSinglePayer('b')), 'Paid by Ravi\u00A0· split equally');
      final shares = d.copyWith(
        split: d.split.withValues(SplitKind.shares, {'a': 1000, 'b': 2000, 'c': 0}),
      );
      expect(paidSplitSummary(l, shares), 'Paid by You\u00A0· split by shares');
      final two = d.withMultiplePayers().withPayerText('a', '700').withPayerText('b', '500');
      expect(paidSplitSummary(l, two), '2 people paid\u00A0· split equally');
      expect(
        paidSplitSummary(l, d.withMultiplePayers()),
        'Several people paid\u00A0· split equally',
      );
      final exact = d.copyWith(split: d.split.withValues(SplitKind.exact, {'a': 120000}));
      expect(paidSplitSummary(l, exact), 'Paid by You\u00A0· split exactly');
    });

    test('the line under it: people and each share, or what is left in red', () {
      final d = _draft(amount: '1200', description: 'x');
      expect(splitSheetFooter(l, _draft()), (text: '3 people', error: false));
      expect(splitSheetFooter(l, d), (text: '3 people\u00A0· ₹400 each', error: false));
      final left = d.copyWith(split: d.split.withValues(SplitKind.exact, {'a': 50000}));
      expect(splitSheetFooter(l, left), (text: '₹500 of ₹1,200\u00A0· ₹700 left', error: true));
      final payers = d.withMultiplePayers().withPayerText('a', '700');
      expect(splitSheetFooter(l, payers).text, '₹700 of ₹1,200\u00A0· ₹500 left');
      expect(splitSheetFooter(l, payers, payers: false).text, '3 people\u00A0· ₹400 each');
    });
  });
}
