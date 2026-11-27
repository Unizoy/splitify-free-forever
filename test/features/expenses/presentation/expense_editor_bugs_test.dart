// D-032 regressions (owner report 2026-11-27). Both failed on the old 5-step editor:
// 1. "When I don't add a description and press Next … it doesn't save the amount and doesn't show the
//    amount." Cause: a missing amount showed no error at all (only the description error was wired to the
//    Next/Save attempt), the step header let you skip to Review with Save disabled and the amount "—", and
//    with the keyboard up the typed digits went into the description.
// 2. "When I tap the description it shows the keyboard AND the number pad on top of it." Cause: the
//    keypad hid itself on `MediaQuery.viewInsets`, which the Scaffold removes from its body, so it never
//    saw the keyboard.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/expenses/presentation/amount_keypad.dart';

import '../expense_fixtures.dart';
import 'presentation_harness.dart';

Finder _descriptionField() => fieldIn('expense-description');
Finder _amountField() => fieldIn('expense-amount');

String _amountText(WidgetTester t) => t.widget<TextField>(_amountField()).controller!.text;

bool _focused(WidgetTester t, Finder field) => t
    .widget<EditableText>(find.descendant(of: field, matching: find.byType(EditableText)))
    .focusNode
    .hasFocus;

Map<String, Object?> _keyboard(WidgetTester t) =>
    (t.testTextInput.setClientArgs!['inputType']! as Map).cast<String, Object?>();

void main() {
  final blank = sampleDraft(amount: '', description: '', expenseId: null);

  group('bug 2: only one keyboard', () {
    testWidgets('the description opens the text keyboard, the amount the number keyboard', (
      t,
    ) async {
      await pumpEditor(t, blank, args: newArgs);
      expect(find.byType(AmountKeypad), findsNothing, reason: 'no custom number pad at all');

      await t.tap(_descriptionField());
      await t.pump();
      expect(t.testTextInput.isVisible, isTrue);
      expect(_keyboard(t)['name'], 'TextInputType.text');
      // The phone's keyboard now covers the bottom 300 dp.
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(t.view.resetViewInsets);
      await settle(t);
      expect(find.byType(AmountKeypad), findsNothing);
      expect(find.byKey(const Key('key-d1')), findsNothing);

      await t.tap(_amountField());
      await t.pump();
      expect(_keyboard(t)['name'], 'TextInputType.number');
      expect(_keyboard(t)['decimal'], isTrue);
      expect(find.byType(AmountKeypad), findsNothing);
    });

    testWidgets('Save and the toolbar stay above the keyboard', (t) async {
      await pumpEditor(t, blank, args: newArgs);
      await t.tap(_amountField());
      t.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(t.view.resetViewInsets);
      await settle(t);
      final top = 915 - 320.0;
      expect(t.getRect(find.byKey(const Key('expense-save'))).bottom, lessThanOrEqualTo(top));
      expect(t.getRect(find.byKey(const Key('expense-date'))).bottom, lessThanOrEqualTo(top));
      expect(t.getRect(_amountField()).bottom, lessThanOrEqualTo(top));
    });
  });

  group('bug 1: the amount is never lost', () {
    testWidgets('no description: Save keeps and shows the amount, asks for one, then saves it', (
      t,
    ) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      await t.enterText(_amountField(), '500');
      await settle(t);

      await t.tap(find.byKey(const Key('expense-save')));
      await settle(t);
      expect(h.controller!.saves, 0);
      expect(find.text('Add a description'), findsOneWidget);
      expect(_focused(t, _descriptionField()), isTrue, reason: 'the description gets the focus');
      expect(_amountText(t), '500', reason: 'the amount is still on screen');
      expect(h.draft.total, 50000);

      // Opening and closing the Paid by · split sheet keeps it too.
      await tapKey(t, 'split-summary');
      await tapKey(t, 'paid-split-done');
      expect(_amountText(t), '500');
      expect(find.text('Paid by You · split equally'), findsOneWidget);

      await t.enterText(_descriptionField(), 'Lunch');
      await settle(t);
      expect(find.text('Add a description'), findsNothing);
      await t.tap(find.byKey(const Key('expense-save')));
      await t.pump();
      expect(h.controller!.saves, 1);
      expect(h.draft.total, 50000);
      expect(h.draft.description, 'Lunch');
      await settle(t, 12);
    });

    testWidgets('digits typed into the description: Save says the amount is missing', (t) async {
      final h = await pumpEditor(t, blank, args: newArgs);
      await t.enterText(_descriptionField(), '500');
      await settle(t);
      await t.tap(find.byKey(const Key('expense-save')));
      await settle(t);
      expect(h.controller!.saves, 0);
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(_focused(t, _amountField()), isTrue);
    });
  });
}
