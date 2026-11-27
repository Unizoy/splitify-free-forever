// TC-13-01 (form validation, fast-path Save), TC-13-02 (category + date), paid by, review and
// stepper navigation of the add/edit expense screen.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/features/currency/application/currency_providers.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/pickers.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/domain/rules/recurrence.dart' show RecurrenceInterval;
import 'package:splitify/features/recurring/application/repeat_draft.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show syncOfflineProvider;

import '../expense_fixtures.dart';
import 'presentation_harness.dart';

/// Editor that never finishes loading.
class _LoadingController extends FixedEditorController {
  _LoadingController(super.args, super.draft);

  @override
  Future<ExpenseDraft> build() => Completer<ExpenseDraft>().future;
}

/// Editor whose expense is not on this phone.
class _MissingController extends FixedEditorController {
  _MissingController(super.args, super.draft);

  @override
  Future<ExpenseDraft> build() async => throw const ExpenseNotFound();
}

/// Editor whose save finds nothing to save.
class _RefusingController extends FixedEditorController {
  _RefusingController(super.args, super.draft);

  @override
  Future<String?> save() async {
    saves++;
    return null;
  }
}

ExpenseDraft _draftWith({
  required String currency,
  SplitDraft? split,
  String? payerId,
  Map<String, int> payers = const {},
  String amountText = '1200',
  String description = 'Dinner',
}) {
  final d = sampleDraft();
  return ExpenseDraft(
    groupId: d.groupId,
    groupName: d.groupName,
    expenseId: d.expenseId,
    currency: currency,
    members: d.members,
    split: split ?? d.split,
    date: d.date,
    payerId: payerId,
    payers: payers,
    amountText: amountText,
    description: description,
    category: d.category,
  );
}

ExpenseDraft _multiPayer() => _draftWith(
  currency: 'INR',
  payers: const {'m1': 60000, 'm2': 60000},
  split: SplitDraft.initial(ids, 2),
);

Finder _descriptionField() => find.descendant(
  of: find.byKey(const Key('expense-description')),
  matching: find.byType(TextField),
);

String _amount(WidgetTester t) => t.widget<Text>(find.byKey(const Key('amount-display'))).data!;

Future<void> _type(WidgetTester t, List<String> keys) async {
  for (final k in keys) {
    await tapKey(t, 'key-$k');
  }
}

/// Runs the tap handler of the sentence part whose text is [part].
void _tapSentence(WidgetTester t, String part) {
  final rich = t.widget<RichText>(
    find.descendant(of: find.byKey(const Key('review-sentence')), matching: find.byType(RichText)),
  );
  TextSpan? found;
  rich.text.visitChildren((s) {
    if (s is TextSpan && s.text == part) {
      found = s;
      return false;
    }
    return true;
  });
  (found!.recognizer! as TapGestureRecognizer).onTap!();
}

void main() {
  final blank = sampleDraft(amount: '', description: '', expenseId: null);

  group('amount step', () {
    // TC-13-01
    testWidgets('keypad typing builds the amount; sums show the = result', (t) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      expect(_amount(t), '₹0');
      await _type(t, ['d1', 'd2', 'd0', 'd0']);
      expect(_amount(t), '₹1,200');
      expect(h.draft.amountText, '1200');
      await _type(t, ['plus', 'd3', 'd0', 'd0']);
      expect(_amount(t), '₹1,200 + 300');
      expect(find.text('= ₹1,500'), findsOneWidget);
      await _type(t, ['times', 'd2']);
      // × binds tighter than +: 1,200 + 300 × 2.
      expect(find.text('= ₹1,800'), findsOneWidget);
      expect(h.draft.total, 180000);
    });

    // TC-13-01
    testWidgets('delete removes the last key and a long press clears everything', (t) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      await _type(t, ['d4', 'd5', 'delete']);
      expect(h.draft.amountText, '4');
      await _type(t, ['d5', 'dot', 'd5']);
      expect(h.draft.amountText, '45.5');
      await t.longPress(find.byKey(const Key('key-delete')));
      await settle(t);
      expect(h.draft.amountText, '');
    });

    // TC-13-01
    testWidgets('a third decimal is rejected by the keypad and by the error line', (t) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      await _type(t, ['d1', 'dot', 'd2', 'd3', 'd4']);
      expect(h.draft.amountText, '1.23');
      expect(find.byKey(const Key('amount-error')), findsNothing);
    });

    // TC-13-01
    testWidgets('an amount with too many decimals shows the decimals error', (t) async {
      await pumpEditor(t, sampleDraft(amount: '1.234'));
      expect(find.byKey(const Key('amount-error')), findsOneWidget);
      expect(find.text('INR allows 2 decimals'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('dividing by zero shows its own error', (t) async {
      await pumpEditor(t, blank, args: newArgs);
      await _type(t, ['d5', 'divide', 'd0']);
      expect(find.text("You can't divide by 0"), findsOneWidget);
    });

    // TC-13-01
    testWidgets('currencies without decimals disable the decimal point', (t) async {
      final h = await pumpEditor(
        t,
        _draftWith(
          currency: 'JPY',
          split: SplitDraft.initial(ids, 0),
          payerId: me,
          amountText: '',
          description: '',
        ),
      );
      await _type(t, ['d5', 'dot']);
      expect(h.draft.amountText, '5');
    });

    // TC-14-04
    testWidgets('the currency chip opens the picker; a new currency re-checks the amount', (
      t,
    ) async {
      final h = await pumpEditor(
        t,
        blank,
        args: newArgs,
        overrides: [groupMainCurrencyProvider(gid).overrideWith((ref) => Stream.value('INR'))],
      );
      await t.tap(find.text('INR'));
      await settle(t);
      expect(find.text('Currency'), findsOneWidget);
      await t.enterText(find.byKey(const Key('currency-search')), 'yen');
      await settle(t);
      await t.tap(find.byKey(const Key('currency-found-JPY')));
      await settle(t);
      expect(h.draft.currency, 'JPY');
      expect(find.text('JPY'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('Next is blocked until amount and description are set', (t) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      expect(find.text('Add a short description'), findsNothing);
      await tapKey(t, 'expense-next');
      expect(find.text('Add a short description'), findsOneWidget);
      expect(find.text('How much was it?'), findsOneWidget);

      await _type(t, ['d1', 'd2', 'd0', 'd0']);
      await tapKey(t, 'expense-next');
      expect(find.text('How much was it?'), findsOneWidget);

      await t.enterText(_descriptionField(), 'Lunch');
      await settle(t);
      expect(h.draft.description, 'Lunch');
      expect(find.text('Add a short description'), findsNothing);
      await tapKey(t, 'expense-next');
      expect(find.text('Who paid?'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('Save is disabled until the draft is valid, then saves and closes', (t) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      expect(buttonEnabled(t, 'expense-save'), isFalse);
      await _type(t, ['d9', 'd0', 'd0']);
      expect(buttonEnabled(t, 'expense-save'), isFalse);
      await t.enterText(_descriptionField(), 'Cab');
      await settle(t);
      expect(buttonEnabled(t, 'expense-save'), isTrue);

      await t.tap(find.byKey(const Key('expense-save')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(h.controller!.saves, 1);
      // The success check shows first...
      expect(find.text('Expense saved'), findsWidgets);
      expect(find.byType(ExpenseEditorScreen), findsOneWidget);
      // ...then the editor closes and the snackbar stays.
      await t.pump(const Duration(milliseconds: 800));
      await settle(t);
      expect(find.byType(ExpenseEditorScreen), findsNothing);
      expect(find.text('Expense saved'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('a save that returns nothing keeps the editor open', (t) async {
      final h = await pumpEditor(t, sampleDraft(), make: _RefusingController.new);
      await t.tap(find.byKey(const Key('expense-save')));
      await t.pump(const Duration(milliseconds: 900));
      expect(h.controller!.saves, 1);
      expect(find.byType(ExpenseEditorScreen), findsOneWidget);
      expect(buttonEnabled(t, 'expense-save'), isTrue);
    });

    // TC-13-01
    testWidgets('the keypad keys are labelled for screen readers', (t) async {
      final handle = t.ensureSemantics();
      await pumpEditor(t, blank, args: newArgs);
      for (final label in [
        '1',
        '5',
        '9',
        '0',
        'Delete',
        'Plus',
        'Minus',
        'Times',
        'Divided by',
        'Decimal point',
      ]) {
        expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
      }
      handle.dispose();
    });

    // TC-13-01
    testWidgets('the header says whether you are editing or offline', (t) async {
      await pumpEditor(t, sampleDraft());
      expect(find.text('Editing\u00A0· Goa trip'), findsOneWidget);
      await pumpEditor(
        t,
        blank,
        args: newArgs,
        overrides: [syncOfflineProvider.overrideWith((ref) => Stream.value(true))],
      );
      expect(find.text('Goa trip\u00A0· saved offline'), findsOneWidget);
    });
  });

  group('paid by', () {
    // TC-13-01
    testWidgets('tapping a person selects them', (t) async {
      final h = await pumpEditor(t, sampleDraft(), step: EditorStep.paidBy);
      expect(find.text('Who paid?'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      await tapKey(t, 'payer-m3');
      expect(h.draft.payerId, 'm3');
      await tapKey(t, 'payer-m1');
      expect(h.draft.payerId, 'm1');
    });

    // TC-10-01
    testWidgets('"Multiple people" shows the amounts card and the live footer', (t) async {
      final h = await pumpEditor(t, sampleDraft(), step: EditorStep.paidBy);
      expect(find.byKey(const Key('payer-amounts')), findsNothing);
      expect(find.byKey(const Key('payers-footer')), findsNothing);
      await tapKey(t, 'payer-multiple');
      expect(find.byKey(const Key('payer-amounts')), findsOneWidget);
      expect(find.byKey(const Key('payers-footer')), findsOneWidget);
      expect(h.draft.payerId, isNull);
      expect(find.text('Coming soon'), findsNothing);
      expect(footerText(t), 'Type at least one amount');
    });

    // TC-10-02
    testWidgets('typing amounts updates the footer; Save enables only when they add up', (t) async {
      final h = await pumpEditor(t, sampleDraft(), step: EditorStep.paidBy);
      await tapKey(t, 'payer-multiple');
      expect(buttonEnabled(t, 'expense-save'), isFalse);

      await t.enterText(fieldIn('payer-amount-m1'), '800');
      await settle(t);
      expect(footerText(t), '₹800 of ₹1,200\u00A0· ₹400 left');
      expect(buttonEnabled(t, 'expense-save'), isFalse);

      await t.enterText(fieldIn('payer-amount-m2'), '500');
      await settle(t);
      expect(footerText(t), '₹1,300 of ₹1,200\u00A0· ₹100 over');
      expect(buttonEnabled(t, 'expense-save'), isFalse);

      await t.enterText(fieldIn('payer-amount-m2'), '400');
      await settle(t);
      expect(footerText(t), '₹1,200 covered');
      expect(buttonEnabled(t, 'expense-save'), isTrue);
      expect(h.draft.payersCheck, isA<PayersReady>());
      expect((h.draft.payersCheck as PayersReady).paid, {'m1': 80000, 'm2': 40000});
    });

    // TC-10-01
    testWidgets('a draft with several payers shows the amounts card prefilled', (t) async {
      await pumpEditor(t, _multiPayer(), step: EditorStep.paidBy);
      expect(find.byKey(const Key('payer-amounts')), findsOneWidget);
      expect(t.widget<TextField>(fieldIn('payer-amount-m1')).controller!.text, '600');
      expect(t.widget<TextField>(fieldIn('payer-amount-m2')).controller!.text, '600');
      expect(footerText(t), '₹1,200 covered');
      expect(find.textContaining('Several people paid for this one'), findsNothing);
    });

    // TC-13-01
    testWidgets('a single payer has no note', (t) async {
      await pumpEditor(t, sampleDraft(), step: EditorStep.paidBy);
      expect(find.textContaining('Several people paid for this one'), findsNothing);
    });
  });

  group('details step', () {
    // TC-13-02
    testWidgets('a parent selects its first sub category, a sub selects itself', (t) async {
      final h = await pumpEditor(t, sampleDraft(), step: EditorStep.details);
      expect(find.text('A few details'), findsOneWidget);
      await tapKey(t, 'category-travel');
      expect(h.draft.category, 'travel.flights');
      expect(find.byKey(const Key('category-travel.cab_auto')), findsOneWidget);
      await tapKey(t, 'category-travel.cab_auto');
      expect(h.draft.category, 'travel.cab_auto');
      // The chosen parent again changes nothing.
      await tapKey(t, 'category-travel');
      expect(h.draft.category, 'travel.cab_auto');
      await tapKey(t, 'category-rent');
      expect(h.draft.category, 'rent.rent');
    });

    // TC-13-02
    testWidgets('every parent category lists its subs with names', (t) async {
      final h = await pumpEditor(t, sampleDraft(), step: EditorStep.details);
      for (final entry in ExpenseCategories.tree.entries) {
        await tapKey(t, 'category-${entry.key}');
        for (final sub in entry.value) {
          expect(find.byKey(Key('category-$sub')), findsOneWidget, reason: sub);
        }
        expect(h.draft.category, entry.value.first);
      }
    });

    // TC-13-02
    testWidgets('today and yesterday chips set the date', (t) async {
      final h = await pumpEditor(t, sampleDraft(), step: EditorStep.details);
      await tapKey(t, 'date-yesterday');
      expect(h.draft.date, DateTime(2026, 11, 20));
      await tapKey(t, 'date-today');
      expect(h.draft.date, DateTime(2026, 11, 21));
    });

    // TC-13-02
    testWidgets('the calendar sheet picks a day and walks between months', (t) async {
      final h = await pumpEditor(t, sampleDraft(), step: EditorStep.details);
      expect(find.text('Pick a date'), findsOneWidget);
      await tapKey(t, 'date-pick');
      expect(find.byType(MonthCalendar), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);

      await t.tap(find.byTooltip('Previous month'));
      await settle(t);
      expect(find.text('October 2026'), findsOneWidget);
      await t.tap(find.byTooltip('Next month'));
      await t.tap(find.byTooltip('Next month'));
      await settle(t);
      expect(find.text('December 2026'), findsOneWidget);

      await t.tap(find.descendant(of: find.byType(MonthCalendar), matching: find.text('15')));
      await settle(t);
      expect(find.byType(MonthCalendar), findsNothing);
      expect(h.draft.date, DateTime(2026, 12, 15));
      // The calendar chip now shows the chosen date.
      expect(find.text('15\u00A0Dec\u00A02026'), findsOneWidget);
    });

    // TC-13-02
    testWidgets('closing the calendar without a pick keeps the date', (t) async {
      final h = await pumpEditor(t, sampleDraft(), step: EditorStep.details);
      await tapKey(t, 'date-pick');
      await t.tapAt(const Offset(200, 40));
      await settle(t);
      expect(h.draft.date, fixedToday);
    });

    // TC-13-02
    testWidgets('the calendar day cells are labelled', (t) async {
      final handle = t.ensureSemantics();
      await pumpEditor(t, sampleDraft(), step: EditorStep.details);
      await tapKey(t, 'date-pick');
      expect(find.bySemanticsLabel('21\u00A0Nov\u00A02026'), findsWidgets);
      handle.dispose();
    });

    // TC-13-02
    testWidgets('notes go into the draft; too long notes block Save', (t) async {
      final h = await pumpEditor(t, sampleDraft(), step: EditorStep.details);
      final field = find.descendant(
        of: find.byKey(const Key('expense-notes')),
        matching: find.byType(TextField),
      );
      await reveal(t, field);
      await t.enterText(field, 'Window table');
      await settle(t);
      expect(h.draft.notes, 'Window table');
      expect(buttonEnabled(t, 'expense-save'), isTrue);
      await t.enterText(field, 'a' * 1001);
      await settle(t);
      expect(find.text('Use up to 1,000 characters'), findsOneWidget);
      expect(buttonEnabled(t, 'expense-save'), isFalse);
    });
  });

  group('review step', () {
    // TC-13-01
    testWidgets('shows the summary, the sentence and each person', (t) async {
      await pumpEditor(t, sampleDraft(), step: EditorStep.review);
      expect(find.text('All good?'), findsOneWidget);
      expect(find.text('Dinner at Thalassa'), findsOneWidget);
      expect(find.text('₹1,200.00'), findsWidgets);
      expect(find.textContaining('21\u00A0Nov\u00A02026'), findsOneWidget);
      final sentence = t.widget<Text>(find.byKey(const Key('review-sentence')));
      expect(sentence.textSpan!.toPlainText(), 'Paid by you and split equally between 3 people');
      expect(find.text('share ₹400.00'), findsNWidgets(3));
      expect(find.text('paid ₹1,200.00'), findsOneWidget);
      // Priya is not part of it.
      expect(find.text('Priya Nair'), findsNothing);
      // No Next on the last step; the bar says Save expense and the summary line.
      expect(find.byKey(const Key('expense-next')), findsNothing);
      expect(find.text('Save expense'), findsOneWidget);
      expect(find.text('₹1,200\u00A0· 3 people'), findsOneWidget);
    });

    // Final QA: the repeat is shown before Save.
    testWidgets('a repeating expense says how often; a one-off has no repeat line', (t) async {
      await pumpEditor(
        t,
        sampleDraft().withRepeat(const RepeatDraft(interval: RecurrenceInterval.monthly)),
        step: EditorStep.review,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('review-repeat')),
          matching: find.text('Every month'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a one-off expense has no repeat line', (t) async {
      await pumpEditor(t, sampleDraft(), step: EditorStep.review);
      expect(find.byKey(const Key('review-repeat')), findsNothing);
    });

    // TC-13-01
    testWidgets('the tappable sentence parts jump to Paid by and Split', (t) async {
      await pumpEditor(t, sampleDraft(), step: EditorStep.review);
      _tapSentence(t, 'you');
      await settle(t);
      expect(find.text('Who paid?'), findsOneWidget);
      await tapText(t, 'Review');
      _tapSentence(t, 'equally between 3 people');
      await settle(t);
      expect(find.text('How should it be split?'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('names the other payer and the split kind', (t) async {
      final d = sampleDraft(kind: SplitKind.percent);
      final h = await pumpEditor(t, d, step: EditorStep.paidBy);
      await tapKey(t, 'payer-m2');
      await tapText(t, 'Review');
      expect(h.draft.payerId, 'm2');
      final sentence = t.widget<Text>(find.byKey(const Key('review-sentence')));
      expect(sentence.textSpan!.toPlainText(), 'Paid by Asha Rao and split by percentages');
    });

    // TC-13-01
    testWidgets('several payers: names both payers and a paid line for each', (t) async {
      await pumpEditor(t, _multiPayer(), step: EditorStep.review);
      final sentence = t.widget<Text>(find.byKey(const Key('review-sentence')));
      expect(sentence.textSpan!.toPlainText(), startsWith('Paid by you and Asha Rao'));
      expect(find.text('paid ₹600.00'), findsNWidgets(2));
    });

    // TC-13-01
    testWidgets('every split kind has its sentence wording', (t) async {
      final words = {
        SplitKind.exact: 'by exact amounts',
        SplitKind.shares: 'by shares',
        SplitKind.adjust: 'with adjustments',
      };
      for (final (kind, text) in words.entries.map((e) => (e.key, e.value))) {
        await pumpEditor(t, sampleDraft(kind: kind), step: EditorStep.review);
        final s = t.widget<Text>(find.byKey(const Key('review-sentence')));
        expect(s.textSpan!.toPlainText(), endsWith(text), reason: kind.name);
      }
    });

    // TC-13-01
    testWidgets('an invalid split shows the problem instead of the person lines', (t) async {
      final bad = sampleDraft(
        split: SplitDraft.initial(ids, 2).withValues(SplitKind.exact, {'m1': 50000}),
      );
      await pumpEditor(t, bad, step: EditorStep.review);
      expect(find.text('₹500 of ₹1,200\u00A0· ₹700 left'), findsOneWidget);
      expect(find.textContaining('share ₹'), findsNothing);
    });

    // TC-13-01
    testWidgets('no amount yet shows a dash and no summary', (t) async {
      await pumpEditor(t, sampleDraft(amount: ''), step: EditorStep.review);
      expect(find.text('—'), findsOneWidget);
      expect(buttonEnabled(t, 'expense-save'), isFalse);
    });
  });

  group('stepper navigation', () {
    // TC-13-01
    testWidgets('Next walks through all five steps; Save on Review saves', (t) async {
      final h = await pumpEditor(t, sampleDraft());
      for (final q in ['Who paid?', 'How should it be split?', 'A few details', 'All good?']) {
        await tapKey(t, 'expense-next');
        expect(find.text(q), findsOneWidget, reason: q);
      }
      await t.tap(find.byKey(const Key('expense-save')));
      await t.pump(const Duration(milliseconds: 900));
      await settle(t);
      expect(h.controller!.saves, 1);
    });

    // TC-13-01
    testWidgets('Save on a later step closes the editor like the fast path does', (t) async {
      await pumpEditor(t, sampleDraft(), step: EditorStep.review);
      await t.tap(find.byKey(const Key('expense-save')));
      await t.pump(const Duration(milliseconds: 900));
      await settle(t);
      expect(find.byType(ExpenseEditorScreen), findsNothing);
    });

    // TC-13-01
    testWidgets('step labels jump to their step', (t) async {
      await pumpEditor(t, sampleDraft());
      await t.tap(stepLabel('Details'));
      await settle(t);
      expect(find.text('A few details'), findsOneWidget);
      await t.tap(stepLabel('Paid by'));
      await settle(t);
      expect(find.text('Who paid?'), findsOneWidget);
      // Tapping the current step does nothing.
      await t.tap(stepLabel('Paid by'));
      await settle(t);
      expect(find.text('Who paid?'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('the back arrow goes to the previous step, then closes', (t) async {
      await pumpEditor(t, sampleDraft(), step: EditorStep.split);
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.text('Who paid?'), findsOneWidget);
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.text('How much was it?'), findsOneWidget);
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.byType(ExpenseEditorScreen), findsNothing);
    });

    // TC-13-01
    testWidgets('the system back gesture also steps back', (t) async {
      await pumpEditor(t, sampleDraft(), step: EditorStep.details);
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      await nav.maybePop();
      await settle(t);
      expect(find.text('How should it be split?'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('loading shows the pulse, a missing expense says so', (t) async {
      await pumpEditor(t, sampleDraft(), make: _LoadingController.new);
      expect(find.byType(DotsPulse), findsOneWidget);
      expect(find.byKey(const Key('expense-save')), findsNothing);

      await pumpEditor(t, sampleDraft(), make: _MissingController.new);
      expect(find.text("This expense isn't here"), findsOneWidget);
      expect(find.byType(DotsPulse), findsNothing);
    });
  });
}
