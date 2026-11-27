// TC-11-02 [widget]: "Record a loan" on one screen (D-033): who-lent-whom pill and sheet, the amount on the
// phone's number keyboard, optional what-for, date / notes chips, inline validation, discard confirm,
// empty and edit states.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/currency/application/currency_providers.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/loan_draft.dart';
import 'package:splitify/features/expenses/application/loan_editor_controller.dart';
import 'package:splitify/features/expenses/presentation/editor/editor_fields.dart' show ToolChip;
import 'package:splitify/features/expenses/presentation/loan_screen.dart';
import 'package:splitify/ui/components/components.dart';

import '../expense_fixtures.dart';
import 'presentation_harness.dart';

const LoanEditorArgs newLoan = (groupId: gid, expenseId: null, withMember: null);
const LoanEditorArgs editLoan = (groupId: null, expenseId: 'l1', withMember: null);

/// Loan editor whose build returns [draft] (no database).
class FixedLoanController extends LoanEditorController {
  FixedLoanController(super.args, this.draft);

  final LoanDraft draft;
  int saves = 0;

  @override
  Future<LoanDraft> build() async => draft;

  @override
  Future<String?> save({required String defaultDescription}) async {
    final d = state.value;
    if (d == null || !d.canSave) return null;
    saves++;
    return 'new-id';
  }
}

class FailingLoanController extends LoanEditorController {
  FailingLoanController(super.args, this.error);

  final Object error;

  @override
  Future<LoanDraft> build() async => throw error;
}

LoanDraft sampleLoan({
  LoanDirection direction = LoanDirection.lent,
  String? person,
  String amount = '',
  String note = '',
  String notes = '',
  String self = me,
  bool selfIsMe = true,
  String? expenseId,
  List<EditorMember> members = people,
}) => LoanDraft(
  groupId: gid,
  groupName: 'Goa trip',
  groupType: 'trip',
  currency: 'INR',
  members: members,
  selfId: self,
  selfIsMe: selfIsMe,
  expenseId: expenseId,
  date: fixedToday,
  direction: direction,
  personId: person,
  amountText: amount,
  note: note,
  notes: notes,
);

Future<FixedLoanController> pumpLoan(
  WidgetTester tester,
  LoanDraft draft, {
  LoanEditorArgs args = newLoan,
  double scale = 1,
}) async {
  usePhone(tester);
  if (scale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  late FixedLoanController controller;
  await tester.pumpWidget(
    expenseApp(
      PushHost(
        LoanScreen(groupId: args.groupId, expenseId: args.expenseId, withMember: args.withMember),
      ),
      overrides: [
        loanEditorProvider(args).overrideWith(() => controller = FixedLoanController(args, draft)),
        groupMainCurrencyProvider(gid).overrideWith((ref) => Stream.value('INR')),
        recentCurrenciesProvider.overrideWith((ref) => Stream.value(const <String>['USD'])),
      ],
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await settle(tester);
  return controller;
}

Finder _amount() => fieldIn('loan-amount');

String _pillTitle(WidgetTester t) => textOf(
  find.descendant(
    of: find.byKey(const Key('loan-who')),
    matching: find.byKey(const Key('form-pill-title')),
  ),
)!;

String? _pillSub(WidgetTester t) {
  final f = find.descendant(
    of: find.byKey(const Key('loan-who')),
    matching: find.byKey(const Key('form-pill-subtitle')),
  );
  return f.evaluate().isEmpty ? null : textOf(f);
}

Map<String, Object?> _keyboard(WidgetTester t) =>
    (t.testTextInput.setClientArgs!['inputType']! as Map).cast<String, Object?>();

void main() {
  group('Loan screen (one screen, D-033)', () {
    testWidgets('a new loan opens with the amount focused on the number keyboard', (t) async {
      await pumpLoan(t, sampleLoan());
      expect(find.text('Record a loan'), findsOneWidget);
      expect(find.byKey(const Key('money-group')), findsOneWidget);
      expect(find.text('Goa trip'), findsOneWidget);
      final field = t.widget<TextField>(_amount());
      expect(field.focusNode!.hasFocus, isTrue);
      expect(_keyboard(t)['name'], 'TextInputType.number');
      expect(_keyboard(t)['decimal'], isTrue);
      // No custom number pad anywhere: one keyboard only.
      expect(find.byKey(const Key('key-d1')), findsNothing);
      expect(_pillTitle(t), 'I lent');
      expect(_pillSub(t), 'Choose a person');
    });

    testWidgets('an edit opens without a keyboard', (t) async {
      await pumpLoan(
        t,
        sampleLoan(person: 'm2', amount: '500', expenseId: 'l1'),
        args: editLoan,
      );
      expect(find.text('Edit loan'), findsOneWidget);
      expect(t.widget<TextField>(_amount()).focusNode!.hasFocus, isFalse);
      expect(t.testTextInput.isVisible, isFalse);
    });

    testWidgets('what for uses the text keyboard; the amount keeps digits and one point', (
      t,
    ) async {
      final c = await pumpLoan(t, sampleLoan(person: 'm2'));
      await t.tap(fieldIn('loan-note'));
      await t.pump();
      expect(_keyboard(t)['name'], 'TextInputType.text');
      await t.enterText(fieldIn('loan-note'), 'Cab money');
      await t.enterText(_amount(), '1,250.505');
      await t.pump();
      // The third decimal is refused, the pasted comma dropped.
      expect(c.state.value!.amountText, isNot(contains(',')));
      await t.enterText(_amount(), '1250.50');
      await t.pump();
      expect(c.state.value!.total, 125050);
      expect(c.state.value!.note, 'Cab money');
    });

    // TC-11-02
    testWidgets('lent: the pill names the person and what they will owe', (t) async {
      await pumpLoan(t, sampleLoan(person: 'm2', amount: '500'));
      expect(_pillTitle(t), 'You lent Asha Rao');
      expect(_pillSub(t), 'Asha Rao will owe you ₹500');
    });

    // TC-11-02
    testWidgets('the who sheet flips the direction and picking a person closes it', (t) async {
      final c = await pumpLoan(t, sampleLoan(person: 'm2', amount: '500'));
      await tapKey(t, 'loan-who');
      expect(find.byKey(const Key('loan-who-sheet')), findsOneWidget);
      expect(find.text('Who lent whom?'), findsOneWidget);
      expect(find.text('To whom?'), findsOneWidget);
      await t.tap(
        find.descendant(
          of: find.byKey(const Key('loan-direction')),
          matching: find.text('I borrowed'),
        ),
      );
      await settle(t);
      expect(find.text('From whom?'), findsOneWidget);
      expect(c.state.value!.direction, LoanDirection.borrowed);
      await tapKey(t, 'loan-person-m3');
      expect(find.byKey(const Key('loan-who-sheet')), findsNothing);
      expect(c.state.value!.personId, 'm3');
      expect(_pillTitle(t), 'Rahul Mehta lent you');
      expect(_pillSub(t), 'You will owe Rahul Mehta ₹500');
    });

    testWidgets('Done closes the who sheet and keeps what was picked', (t) async {
      final c = await pumpLoan(t, sampleLoan(person: 'm2', amount: '500'));
      await tapKey(t, 'loan-who');
      await t.tap(
        find.descendant(
          of: find.byKey(const Key('loan-direction')),
          matching: find.text('I borrowed'),
        ),
      );
      await settle(t);
      await tapKey(t, 'loan-who-done');
      expect(find.byKey(const Key('loan-who-sheet')), findsNothing);
      expect(c.state.value!.direction, LoanDirection.borrowed);
      expect(_pillTitle(t), 'Asha Rao lent you');
    });

    // TC-11-02
    testWidgets('Save with nothing: the amount error, focus on the amount, nothing saved', (
      t,
    ) async {
      final c = await pumpLoan(t, sampleLoan());
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(t);
      await tapKey(t, 'loan-save');
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(t.widget<TextField>(_amount()).focusNode!.hasFocus, isTrue);
      expect(c.saves, 0);
      expect(find.byType(LoanScreen), findsOneWidget);
    });

    testWidgets('Save with an amount but nobody picked opens the who sheet with its error', (
      t,
    ) async {
      final c = await pumpLoan(t, sampleLoan(amount: '500'));
      await tapKey(t, 'loan-save');
      expect(find.byKey(const Key('loan-who-sheet')), findsOneWidget);
      expect(find.byKey(const Key('loan-person-error')), findsOneWidget);
      expect(c.saves, 0);
      await tapKey(t, 'loan-person-m2');
      expect(_pillTitle(t), 'You lent Asha Rao');
      await tapKey(t, 'loan-save');
      expect(c.saves, 1);
    });

    testWidgets('a typed amount is never lost by a failed Save', (t) async {
      final c = await pumpLoan(t, sampleLoan());
      await t.enterText(_amount(), '750');
      await t.pump();
      await tapKey(t, 'loan-save');
      // Nobody picked: the sheet opens; close it and the amount is still there.
      await tapKey(t, 'loan-who-done');
      expect(t.widget<TextField>(_amount()).controller!.text, '750');
      expect(c.state.value!.amountText, '750');
    });

    // TC-11-02
    testWidgets('a valid Save closes the screen and says "Loan saved"', (t) async {
      final c = await pumpLoan(t, sampleLoan(person: 'm2', amount: '500'));
      await tapKey(t, 'loan-save');
      expect(c.saves, 1);
      expect(find.byType(LoanScreen), findsNothing);
      expect(find.text('Loan saved'), findsOneWidget);
    });

    testWidgets('what for over the limit shows its error and blocks saving', (t) async {
      final c = await pumpLoan(t, sampleLoan(person: 'm2', amount: '500'));
      await t.enterText(fieldIn('loan-note'), 'x' * (maxDescription + 1));
      await t.pump();
      expect(find.text('Use up to $maxDescription characters'), findsOneWidget);
      await tapKey(t, 'loan-save');
      expect(c.saves, 0);
    });

    testWidgets('the notes chip opens its sheet; notes go into the draft', (t) async {
      final c = await pumpLoan(t, sampleLoan(person: 'm2', amount: '500'));
      expect(t.widget<ToolChip>(find.byKey(const Key('loan-notes-chip'))).active, isFalse);
      await tapKey(t, 'loan-notes-chip');
      await t.enterText(fieldIn('loan-notes'), 'Pay back by Friday');
      await t.pump();
      await tapKey(t, 'text-sheet-done');
      expect(c.state.value!.notes, 'Pay back by Friday');
      expect(t.widget<ToolChip>(find.byKey(const Key('loan-notes-chip'))).active, isTrue);
    });

    testWidgets('the date chip opens the date sheet: yesterday', (t) async {
      final c = await pumpLoan(t, sampleLoan(person: 'm2', amount: '500'));
      expect(
        find.descendant(of: find.byKey(const Key('loan-date')), matching: find.text('Today')),
        findsOneWidget,
      );
      await tapKey(t, 'loan-date');
      await tapKey(t, 'date-yesterday');
      expect(c.state.value!.date, DateTime(2026, 11, 20));
      expect(
        find.descendant(of: find.byKey(const Key('loan-date')), matching: find.text('Yesterday')),
        findsOneWidget,
      );
    });

    testWidgets('the currency chip picks another currency', (t) async {
      final c = await pumpLoan(t, sampleLoan(person: 'm2', amount: '20'));
      await tapKey(t, 'loan-currency');
      await tapKey(t, 'currency-recent-USD');
      expect(c.state.value!.currency, 'USD');
      expect(_pillSub(t), r'Asha Rao will owe you $20');
    });

    testWidgets('back with nothing changed closes at once', (t) async {
      await pumpLoan(t, sampleLoan(person: 'm2'));
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.byType(LoanScreen), findsNothing);
    });

    testWidgets('back after typing asks first: Cancel stays, Discard closes', (t) async {
      final c = await pumpLoan(t, sampleLoan(person: 'm2'));
      await t.enterText(_amount(), '300');
      await t.pump();
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.text('Discard this loan?'), findsOneWidget);
      await tapText(t, 'Cancel');
      expect(find.byType(LoanScreen), findsOneWidget);
      expect(c.state.value!.amountText, '300');

      // The system back does the same.
      await t.binding.handlePopRoute();
      await settle(t);
      expect(find.text('Discard this loan?'), findsOneWidget);
      await tapKey(t, 'confirm-action');
      expect(find.byType(LoanScreen), findsNothing);
      expect(c.saves, 0);
    });

    testWidgets('an edit asks "Discard your changes?"', (t) async {
      await pumpLoan(
        t,
        sampleLoan(person: 'm2', amount: '500', expenseId: 'l1'),
        args: editLoan,
      );
      await t.enterText(_amount(), '600');
      await t.pump();
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.text('Discard your changes?'), findsOneWidget);
      expect(find.text('The loan stays as it was last saved.'), findsOneWidget);
    });

    // TC-11-02
    testWidgets('no other member: empty state with invite, no amount, no Save', (t) async {
      await pumpLoan(t, sampleLoan(members: const [(id: 'm1', name: 'Mohit Bindal', isMe: true)]));
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Add someone to this group first.'), findsOneWidget);
      expect(find.byKey(const Key('loan-invite')), findsOneWidget);
      expect(find.byKey(const Key('loan-save')), findsNothing);
      expect(find.byKey(const Key('loan-amount')), findsNothing);
    });

    // TC-11-02
    testWidgets('editing a loan between two others uses their names', (t) async {
      final c = await pumpLoan(
        t,
        sampleLoan(
          self: 'm2',
          selfIsMe: false,
          person: 'm3',
          amount: '300',
          expenseId: 'l1',
          note: 'Cab money',
        ),
        args: editLoan,
      );
      expect(_pillTitle(t), 'Asha Rao lent Rahul Mehta');
      expect(_pillSub(t), 'Rahul Mehta will owe Asha Rao ₹300');
      await tapKey(t, 'loan-who');
      expect(find.text('Asha Rao lent'), findsOneWidget);
      await t.tap(find.text('Asha Rao borrowed'));
      await settle(t);
      await tapKey(t, 'loan-who-done');
      expect(c.state.value!.direction, LoanDirection.borrowed);
      expect(_pillTitle(t), 'Rahul Mehta lent Asha Rao');
      expect(_pillSub(t), 'Asha Rao will owe Rahul Mehta ₹300');
    });

    testWidgets('large text: the form scrolls and nothing overflows', (t) async {
      final c = await pumpLoan(t, sampleLoan(person: 'm2', amount: '500'), scale: 2);
      expect(t.takeException(), isNull);
      await tapKey(t, 'loan-who');
      expect(t.takeException(), isNull);
      await tapKey(t, 'loan-who-done');
      await tapKey(t, 'loan-save');
      expect(c.saves, 1);
    });

    // TC-11-02
    testWidgets('a viewer who is not a member gets the "add someone" message', (t) async {
      usePhone(t);
      await t.pumpWidget(
        expenseApp(
          const LoanScreen(groupId: gid),
          overrides: [
            loanEditorProvider(newLoan)
                .overrideWith(() => FailingLoanController(newLoan, const LoanNotPossible())),
          ],
        ),
      );
      await settle(t);
      expect(find.text('Add someone to this group first.'), findsOneWidget);
    });

    // TC-11-02
    testWidgets('a missing loan shows "not found"', (t) async {
      usePhone(t);
      await t.pumpWidget(
        expenseApp(
          const LoanScreen(expenseId: 'l1'),
          overrides: [
            loanEditorProvider(editLoan)
                .overrideWith(() => FailingLoanController(editLoan, StateError('gone'))),
          ],
        ),
      );
      await settle(t);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Add someone to this group first.'), findsNothing);
    });
  });
}
