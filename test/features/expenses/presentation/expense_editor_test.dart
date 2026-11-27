// TC-13-01 (validation, Save), TC-13-02 (category + date), TC-10 (payers), TC-14-04 (currency) on the
// one-screen add/edit expense editor (D-032): fields, the Paid by · split sheet, the toolbar sheets,
// discard, edit mode, keyboard types and TalkBack labels.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/domain/rules/recurrence.dart' show RecurrenceInterval;
import 'package:splitify/features/currency/application/currency_providers.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/editor_fields.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/editor/pickers.dart';
import 'package:splitify/features/expenses/presentation/split_editor.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show syncOfflineProvider;
import 'package:splitify/features/recurring/application/repeat_draft.dart';
import 'package:splitify/features/recurring/presentation/repeat_picker.dart';
import 'package:splitify/ui/components/components.dart';

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

ExpenseDraft _multiPayer() {
  final d = sampleDraft();
  return ExpenseDraft(
    groupId: d.groupId,
    groupName: d.groupName,
    expenseId: d.expenseId,
    currency: 'INR',
    members: d.members,
    split: SplitDraft.initial(ids, 2),
    date: d.date,
    payers: const {'m1': 60000, 'm2': 60000},
    amountText: '1200',
    description: 'Dinner',
    category: d.category,
  );
}

Finder _descriptionField() => fieldIn('expense-description');
Finder _amountField() => fieldIn('expense-amount');

String _amountText(WidgetTester t) => t.widget<TextField>(_amountField()).controller!.text;

String _keyboard(WidgetTester t) =>
    (t.testTextInput.setClientArgs!['inputType']! as Map)['name']! as String;

Future<void> _type(WidgetTester t, Finder field, String text) async {
  await t.enterText(field, text);
  await settle(t);
}

Future<void> _save(WidgetTester t) async {
  await t.tap(find.byKey(const Key('expense-save')));
  await settle(t);
}

bool _topSaveEnabled(WidgetTester t) =>
    t.widget<TextButton>(find.byKey(const Key('expense-save-top'))).onPressed != null;

String _chip(WidgetTester t, String key) => t.widget<ToolChip>(find.byKey(Key(key))).label;

void main() {
  final blank = sampleDraft(amount: '', description: '', expenseId: null, canRepeat: true);

  group('one screen', () {
    // TC-13-01
    testWidgets('shows the group, description, amount, the summary pill and the toolbar', (
      t,
    ) async {
      await pumpEditor(t, blank, args: newArgs);
      expect(find.text('Add expense'), findsOneWidget);
      expect(find.text('With you and'), findsOneWidget);
      expect(find.text('Goa trip'), findsOneWidget);
      expect(pillText(t), 'Paid by You\u00A0· split equally');
      expect(pillFooter(t), '3 people');
      for (final key in [
        'expense-date',
        'expense-notes-chip',
        'expense-receipt-chip',
        'expense-repeat-chip',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: key);
      }
      expect(_chip(t, 'expense-date'), 'Today');
      // No steps and no Next any more.
      expect(find.byType(StepHeader), findsNothing);
      expect(find.byKey(const Key('expense-next')), findsNothing);
    });

    // TC-13-01
    testWidgets('a new expense starts on the description with the text keyboard', (t) async {
      await pumpEditor(t, blank, args: newArgs);
      expect(t.testTextInput.isVisible, isTrue);
      final args = t.testTextInput.setClientArgs!;
      expect(_keyboard(t), 'TextInputType.text');
      expect(args['textCapitalization'], 'TextCapitalization.sentences');
      expect(args['inputAction'], 'TextInputAction.next');
    });

    // TC-13-01
    testWidgets('typing fills the draft; the amount becomes minor units and the pill follows', (
      t,
    ) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      await _type(t, _descriptionField(), 'Lunch');
      await _type(t, _amountField(), '1200.5');
      expect(h.draft.description, 'Lunch');
      expect(h.draft.amountText, '1200.5');
      expect(h.draft.total, 120050);
      expect(pillFooter(t), '3 people\u00A0· ₹400.17 each');
    });

    // TC-13-01
    testWidgets('next on the description moves to the amount; done closes the keyboard', (t) async {
      await pumpEditor(t, blank, args: newArgs);
      await t.testTextInput.receiveAction(TextInputAction.next);
      await settle(t);
      expect(_keyboard(t), 'TextInputType.number');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t);
      expect(t.testTextInput.isVisible, isFalse);
    });

    // TC-13-01
    testWidgets('the amount field refuses a third decimal and cleans pasted amounts', (t) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      await _type(t, _amountField(), '1.23');
      await _type(t, _amountField(), '1.234');
      expect(_amountText(t), '1.23');
      await _type(t, _amountField(), '₹1,200.50');
      expect(_amountText(t), '1200.50');
      expect(h.draft.total, 120050);
      await _type(t, _amountField(), '1.2.3');
      expect(_amountText(t), '1200.50');
    });

    // TC-13-01
    testWidgets('a zero or too large amount says so while typing', (t) async {
      await pumpEditor(t, blank, args: newArgs);
      await _type(t, _amountField(), '0');
      expect(find.text('Enter an amount above zero'), findsOneWidget);
      await _type(t, _amountField(), '999999999999');
      expect(find.text('That amount is too large'), findsOneWidget);
      await _type(t, _amountField(), '450');
      expect(find.byKey(const Key('amount-error')), findsNothing);
    });

    // TC-13-01
    testWidgets('a stored amount with too many decimals shows the decimals error', (t) async {
      await pumpEditor(t, sampleDraft(amount: '1.234'));
      expect(find.text('INR allows 2 decimals'), findsOneWidget);
    });

    // TC-14-04
    testWidgets('the currency chip opens the picker; a new currency re-checks the amount', (
      t,
    ) async {
      final h = await pumpEditor(
        t,
        blank.copyWith(amountText: '12.50'),
        args: newArgs,
        overrides: [groupMainCurrencyProvider(gid).overrideWith((ref) => Stream.value('INR'))],
      );
      expect(_amountText(t), '12.50');
      await t.tap(find.text('INR'));
      await settle(t);
      expect(find.text('Currency'), findsOneWidget);
      await t.enterText(find.byKey(const Key('currency-search')), 'yen');
      await settle(t);
      await t.tap(find.byKey(const Key('currency-found-JPY')));
      await settle(t);
      expect(h.draft.currency, 'JPY');
      expect(find.text('JPY'), findsOneWidget);
      // The amount stays and is checked again: yen has no decimals.
      expect(_amountText(t), '12.50');
      expect(find.text('JPY allows no decimals'), findsOneWidget);
      await _type(t, _amountField(), '1250');
      expect(h.draft.total, 1250);
      await _type(t, _amountField(), '1250.');
      expect(_amountText(t), '1250', reason: 'no decimal point for yen');
    });

    // TC-13-01
    testWidgets('titles and the offline note', (t) async {
      await pumpEditor(t, sampleDraft());
      expect(find.text('Edit expense'), findsOneWidget);
      expect(find.byKey(const Key('expense-offline')), findsNothing);
      await pumpEditor(
        t,
        blank,
        args: newArgs,
        overrides: [syncOfflineProvider.overrideWith((ref) => Stream.value(true))],
      );
      expect(find.text('Add expense'), findsOneWidget);
      expect(find.byKey(const Key('expense-offline')), findsOneWidget);
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

  group('save', () {
    // TC-13-01
    testWidgets('default equal split: describe, type the amount, Save saves and closes', (t) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      expect(_topSaveEnabled(t), isFalse);
      await _type(t, _descriptionField(), 'Cab');
      await _type(t, _amountField(), '900');
      expect(_topSaveEnabled(t), isTrue);

      await t.tap(find.byKey(const Key('expense-save')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(h.controller!.saves, 1);
      final row = h.draft.toRow();
      expect(row['shares'], {'m1': 30000, 'm2': 30000, 'm3': 30000});
      expect(row['payers'], {'m1': 90000});
      expect(row['description'], 'Cab');
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
    testWidgets('the app bar Save also saves', (t) async {
      final h = await pumpEditor(t, sampleDraft());
      await t.tap(find.byKey(const Key('expense-save-top')));
      await t.pump();
      expect(h.controller!.saves, 1);
      await settle(t, 12);
    });

    // TC-13-01
    testWidgets('nothing typed: Save shows both errors and focuses the description', (t) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(t);
      await _save(t);
      expect(h.controller!.saves, 0);
      expect(find.text('Add a description'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(t.testTextInput.isVisible, isTrue);
      expect(_keyboard(t), 'TextInputType.text');
    });

    // TC-13-01
    testWidgets('a description over 120 characters is flagged while typing', (t) async {
      await pumpEditor(t, blank, args: newArgs);
      await _type(t, _descriptionField(), 'x' * 121);
      expect(find.text('Use up to 120 characters'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('a save that returns nothing keeps the editor open', (t) async {
      final h = await pumpEditor(t, sampleDraft(), make: _RefusingController.new);
      await t.tap(find.byKey(const Key('expense-save')));
      await t.pump(const Duration(milliseconds: 900));
      expect(h.controller!.saves, 1);
      expect(find.byType(ExpenseEditorScreen), findsOneWidget);
      expect(_topSaveEnabled(t), isTrue);
    });

    // TC-10-02
    testWidgets('payers that do not add up: Save opens the sheet instead', (t) async {
      final h = await pumpEditor(t, _multiPayer().withPayerText('m2', '500'));
      expect(pillFooter(t), '₹1,100 of ₹1,200\u00A0· ₹100 left');
      await _save(t);
      expect(h.controller!.saves, 0);
      expect(find.text('Paid by and split'), findsOneWidget);
      expect(find.byKey(const Key('payer-amounts')), findsOneWidget);
    });

    // TC-13-02
    testWidgets('too long notes: Save opens the notes sheet', (t) async {
      final h = await pumpEditor(t, sampleDraft(notes: 'a' * 1001));
      await _save(t);
      expect(h.controller!.saves, 0);
      expect(find.text('Use up to 1,000 characters'), findsOneWidget);
    });

    // TC-12-04
    testWidgets('a repeat that ends before the date: Save opens the repeat sheet', (t) async {
      final h = await pumpEditor(
        t,
        sampleDraft(
          canRepeat: true,
          repeat: RepeatDraft(interval: RecurrenceInterval.monthly, endsOn: DateTime(2026, 11, 1)),
        ),
      );
      await _save(t);
      expect(h.controller!.saves, 0);
      expect(find.byType(RepeatPicker), findsOneWidget);
    });
  });

  group('Paid by · split sheet', () {
    // TC-13-01
    testWidgets('tapping a person makes them the payer; the pill says so', (t) async {
      final h = await pumpEditor(t, sampleDraft());
      await openPaidSplit(t);
      expect(find.text('Paid by and split'), findsOneWidget);
      await tapKey(t, 'payer-m3');
      expect(h.draft.payerId, 'm3');
      await tapKey(t, 'paid-split-done');
      expect(find.text('Paid by and split'), findsNothing);
      expect(pillText(t), 'Paid by Rahul Mehta\u00A0· split equally');
    });

    // TC-10-01, TC-10-02
    testWidgets('"Multiple people": amounts with the live footer; Save once they add up', (
      t,
    ) async {
      final h = await pumpEditor(t, sampleDraft());
      await openPaidSplit(t);
      expect(find.byKey(const Key('payer-amounts')), findsNothing);
      await tapKey(t, 'payer-multiple');
      expect(h.draft.payerId, isNull);
      expect(find.byKey(const Key('payer-amounts')), findsOneWidget);
      String footer() => t.widget<Text>(find.byKey(const Key('payers-footer-text'))).data!;
      expect(footer(), 'Type at least one amount');

      await t.enterText(fieldIn('payer-amount-m1'), '800');
      await settle(t);
      expect(footer(), '₹800 of ₹1,200\u00A0· ₹400 left');
      await t.enterText(fieldIn('payer-amount-m2'), '500');
      await settle(t);
      expect(footer(), '₹1,300 of ₹1,200\u00A0· ₹100 over');
      await t.enterText(fieldIn('payer-amount-m2'), '400');
      await settle(t);
      expect(footer(), '₹1,200 covered');
      expect((h.draft.payersCheck as PayersReady).paid, {'m1': 80000, 'm2': 40000});

      await tapKey(t, 'paid-split-done');
      expect(pillText(t), '2 people paid\u00A0· split equally');
      expect(_topSaveEnabled(t), isTrue);
    });

    // TC-10-01
    testWidgets('a draft with several payers opens with the amounts prefilled', (t) async {
      await pumpEditor(t, _multiPayer());
      expect(pillText(t), '2 people paid\u00A0· split equally');
      await openPaidSplit(t);
      expect(t.widget<TextField>(fieldIn('payer-amount-m1')).controller!.text, '600');
      expect(t.widget<TextField>(fieldIn('payer-amount-m2')).controller!.text, '600');
      expect(t.widget<Text>(find.byKey(const Key('payers-footer-text'))).data, '₹1,200 covered');
    });

    // TC-13-01
    testWidgets('the pill names the split kind', (t) async {
      final words = {
        SplitKind.exact: 'split exactly',
        SplitKind.percent: 'split by percentages',
        SplitKind.shares: 'split by shares',
        SplitKind.adjust: 'split with adjustments',
      };
      for (final MapEntry(key: kind, value: text) in words.entries) {
        await pumpEditor(t, sampleDraft(kind: kind));
        expect(pillText(t), 'Paid by You\u00A0· $text', reason: kind.name);
      }
    });

    // TC-6-03
    testWidgets('an invalid split shows what is left on the pill; Save opens the sheet', (t) async {
      final bad = sampleDraft(
        split: SplitDraft.initial(ids, 2).withValues(SplitKind.exact, {'m1': 50000}),
      );
      final h = await pumpEditor(t, bad);
      expect(pillFooter(t), '₹500 of ₹1,200\u00A0· ₹700 left');
      expect(_topSaveEnabled(t), isFalse);
      await _save(t);
      expect(h.controller!.saves, 0);
      expect(find.byType(SplitKindPicker), findsOneWidget, reason: 'the sheet opened');
    });
  });

  group('toolbar', () {
    // TC-13-02
    testWidgets('date: the chip opens the calendar sheet; today and yesterday are one tap', (
      t,
    ) async {
      final h = await pumpEditor(t, sampleDraft());
      await tapKey(t, 'expense-date');
      expect(find.byType(MonthCalendar), findsOneWidget);
      await tapKey(t, 'date-yesterday');
      expect(h.draft.date, DateTime(2026, 11, 20));
      expect(_chip(t, 'expense-date'), 'Yesterday');
      await tapKey(t, 'expense-date');
      await tapKey(t, 'date-today');
      expect(h.draft.date, DateTime(2026, 11, 21));
      expect(_chip(t, 'expense-date'), 'Today');
    });

    // TC-13-02
    testWidgets('date: the calendar walks between months and picks a day', (t) async {
      final h = await pumpEditor(t, sampleDraft());
      await tapKey(t, 'expense-date');
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
      expect(_chip(t, 'expense-date'), '15\u00A0Dec');
    });

    // TC-13-02
    testWidgets('date: closing the sheet without a pick keeps the date', (t) async {
      final h = await pumpEditor(t, sampleDraft());
      await tapKey(t, 'expense-date');
      await t.tapAt(const Offset(200, 40));
      await settle(t);
      expect(find.byType(MonthCalendar), findsNothing);
      expect(h.draft.date, fixedToday);
    });

    // TC-13-02
    testWidgets('date: the calendar day cells are labelled', (t) async {
      final handle = t.ensureSemantics();
      await pumpEditor(t, sampleDraft());
      await tapKey(t, 'expense-date');
      expect(find.bySemanticsLabel('21\u00A0Nov\u00A02026'), findsWidgets);
      handle.dispose();
    });

    // TC-13-02
    testWidgets('notes: typed in their sheet, kept, and the chip fills', (t) async {
      final h = await pumpEditor(t, sampleDraft());
      await tapKey(t, 'expense-notes-chip');
      expect(t.testTextInput.isVisible, isTrue, reason: 'the notes field takes the focus');
      await t.enterText(fieldIn('expense-notes'), 'Window table');
      await settle(t);
      await tapKey(t, 'notes-done');
      expect(h.draft.notes, 'Window table');
      expect(t.widget<ToolChip>(find.byKey(const Key('expense-notes-chip'))).active, isTrue);
      // Opening again shows what was typed.
      await tapKey(t, 'expense-notes-chip');
      expect(t.widget<TextField>(fieldIn('expense-notes')).controller!.text, 'Window table');
      await t.enterText(fieldIn('expense-notes'), 'a' * 1001);
      await settle(t);
      expect(find.text('Use up to 1,000 characters'), findsOneWidget);
    });

    // TC-29
    testWidgets('receipt: the chip opens the receipt sheet', (t) async {
      await pumpEditor(t, sampleDraft());
      await tapKey(t, 'expense-receipt-chip');
      expect(find.text('Add receipt photo'), findsWidgets);
      await tapKey(t, 'receipt-done');
      expect(find.byKey(const Key('receipt-add')), findsNothing);
    });

    // TC-12-04
    testWidgets('repeat: the chip opens the picker and then names the interval', (t) async {
      final h = await pumpEditor(t, sampleDraft(canRepeat: true));
      expect(_chip(t, 'expense-repeat-chip'), 'Repeat');
      await tapKey(t, 'expense-repeat-chip');
      await tapText(t, 'Every month');
      expect(h.draft.repeat.interval, RecurrenceInterval.monthly);
      await tapKey(t, 'repeat-done');
      expect(_chip(t, 'expense-repeat-chip'), 'Every month');
    });

    // TC-12-04
    testWidgets('no repeat chip on an expense that cannot repeat', (t) async {
      await pumpEditor(t, sampleDraft());
      expect(find.byKey(const Key('expense-repeat-chip')), findsNothing);
    });
  });

  group('category', () {
    // TC-13-02
    testWidgets('the icon opens the picker: a parent shows its subs, a sub picks and closes', (
      t,
    ) async {
      final h = await pumpEditor(t, sampleDraft());
      await tapKey(t, 'category-button');
      expect(find.byType(CategoryPicker), findsOneWidget);
      await tapKey(t, 'category-travel');
      expect(h.draft.category, 'travel.flights');
      expect(find.byKey(const Key('category-travel.cab_auto')), findsOneWidget, reason: 'open');
      await tapKey(t, 'category-travel.cab_auto');
      expect(h.draft.category, 'travel.cab_auto');
      expect(h.draft.categoryOrigin, CategoryOrigin.manual);
      expect(find.byType(CategoryPicker), findsNothing, reason: 'closed');
    });

    // TC-13-02
    testWidgets('every parent category lists its subs', (t) async {
      final h = await pumpEditor(t, sampleDraft());
      await tapKey(t, 'category-button');
      for (final entry in ExpenseCategories.tree.entries) {
        if (ExpenseCategories.parentOf(h.draft.category) != entry.key) {
          await tapKey(t, 'category-${entry.key}');
        }
        for (final sub in entry.value) {
          expect(find.byKey(Key('category-$sub')), findsOneWidget, reason: sub);
        }
      }
      await tapKey(t, 'category-done');
      expect(find.byType(CategoryPicker), findsNothing);
    });
  });

  group('edit', () {
    // TC-13-01
    testWidgets('opens with the saved values and keeps them and the category', (t) async {
      final h = await pumpEditor(t, sampleDraft(category: 'rent.rent'));
      expect(t.testTextInput.isVisible, isFalse, reason: 'no keyboard when editing');
      expect(t.widget<TextField>(_descriptionField()).controller!.text, 'Dinner at Thalassa');
      expect(_amountText(t), '1200');
      expect(pillFooter(t), '3 people\u00A0· ₹400 each');
      await _type(t, _descriptionField(), 'Swiggy');
      await t.pump(suggestDelay);
      await settle(t);
      expect(h.draft.category, 'rent.rent', reason: 'editing never changes the category');
      await _type(t, _amountField(), '1500');
      await t.tap(find.byKey(const Key('expense-save')));
      await t.pump();
      expect(h.controller!.saves, 1);
      expect(h.draft.toRow()['total'], 150000);
      expect(h.draft.toRow()['category'], 'rent.rent');
      await settle(t, 12);
    });
  });

  group('leaving', () {
    // TC-13-01
    testWidgets('nothing typed: back closes at once', (t) async {
      await pumpEditor(t, blank, args: newArgs);
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.byType(ExpenseEditorScreen), findsNothing);
    });

    // TC-13-01
    testWidgets('something typed: back asks first; Cancel stays, Discard leaves', (t) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      await _type(t, _amountField(), '450');
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.text('Discard this expense?'), findsOneWidget);
      await tapText(t, 'Cancel');
      expect(find.byType(ExpenseEditorScreen), findsOneWidget);
      expect(_amountText(t), '450');
      expect(h.draft.amountText, '450');

      await t.tap(find.byTooltip('Back'));
      await settle(t);
      await tapKey(t, 'confirm-action');
      expect(find.byType(ExpenseEditorScreen), findsNothing);
      expect(h.controller!.saves, 0);
    });

    // TC-13-01
    testWidgets('the system back gesture asks too; edits say "your changes"', (t) async {
      await pumpEditor(t, sampleDraft());
      await _type(t, _descriptionField(), 'Dinner');
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      await nav.maybePop();
      await settle(t);
      expect(find.text('Discard your changes?'), findsOneWidget);
      expect(find.byType(ExpenseEditorScreen), findsOneWidget);
    });
  });

  group('values survive', () {
    // TC-13-01
    testWidgets('rotating the phone and pausing the app', (t) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      await _type(t, _descriptionField(), 'Tea');
      await _type(t, _amountField(), '60');
      t.view.physicalSize = const Size(915, 412);
      await settle(t);
      // Home and back: the platform walks through every state in order.
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        t.binding.handleAppLifecycleStateChanged(s);
        await t.pump();
      }
      t.view.physicalSize = const Size(412, 915);
      await settle(t);
      expect(_amountText(t), '60');
      expect(t.widget<TextField>(_descriptionField()).controller!.text, 'Tea');
      expect(h.draft.total, 6000);
    });

    // TC-13-01
    testWidgets('opening and closing every sheet', (t) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      await _type(t, _descriptionField(), 'Tea');
      await _type(t, _amountField(), '60');
      for (final (open, close) in [
        ('split-summary', 'paid-split-done'),
        ('expense-notes-chip', 'notes-done'),
        ('expense-receipt-chip', 'receipt-done'),
        ('expense-repeat-chip', 'repeat-done'),
        ('category-button', 'category-done'),
      ]) {
        await tapKey(t, open);
        await tapKey(t, close);
        expect(_amountText(t), '60', reason: open);
      }
      expect(h.draft.total, 6000);
      expect(h.draft.description, 'Tea');
    });
  });

  group('TalkBack', () {
    // TC-B3
    testWidgets('fields, the pill and the toolbar chips are labelled', (t) async {
      final handle = t.ensureSemantics();
      await pumpEditor(
        t,
        sampleDraft(category: 'food.takeaway', categoryOrigin: CategoryOrigin.auto),
      );
      expect(
        t.getSemantics(find.byKey(const Key('category-hint'))).label,
        'Category: Takeaway, picked from the description',
      );
      expect(find.bySemanticsLabel(RegExp('^Amount, required')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Description, required')), findsOneWidget);
      expect(find.bySemanticsLabel('Paid by You\u00A0· split equally'), findsOneWidget);
      expect(find.bySemanticsLabel('Date: 21\u00A0Nov\u00A02026'), findsOneWidget);
      expect(find.bySemanticsLabel('Add receipt photo'), findsOneWidget);
      expect(find.bySemanticsLabel('Currency INR'), findsOneWidget);
      handle.dispose();
    });
  });
}
