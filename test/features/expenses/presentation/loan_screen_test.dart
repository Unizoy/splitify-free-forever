// TC-11-02 [widget]: the "Record a loan" screen (direction copy, validation, save, empty and edit states).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/loan_draft.dart';
import 'package:splitify/features/expenses/application/loan_editor_controller.dart';
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
  String self = me,
  bool selfIsMe = true,
  String? expenseId,
  List<EditorMember> members = people,
}) => LoanDraft(
  groupId: gid,
  groupName: 'Goa trip',
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
);

Future<FixedLoanController> pumpLoan(
  WidgetTester tester,
  LoanDraft draft, {
  LoanEditorArgs args = newLoan,
}) async {
  usePhone(tester);
  late FixedLoanController controller;
  await tester.pumpWidget(
    expenseApp(
      PushHost(
        LoanScreen(groupId: args.groupId, expenseId: args.expenseId, withMember: args.withMember),
      ),
      overrides: [
        loanEditorProvider(args).overrideWith(() => controller = FixedLoanController(args, draft)),
      ],
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await settle(tester);
  return controller;
}

String? _text(String key) => textOf(find.byKey(Key(key)));

void main() {
  group('Loan screen', () {
    // TC-11-02
    testWidgets('lent: sentence and result name the person and the amount', (t) async {
      await pumpLoan(t, sampleLoan(person: 'm2', amount: '500'));
      expect(_text('loan-sentence'), 'You lent Asha Rao ₹500');
      expect(_text('loan-result'), 'Asha Rao will owe you ₹500');
      expect(find.text('TO WHOM?'), findsOneWidget);
    });

    // TC-11-02
    testWidgets('tapping "I borrowed" flips the copy and the section label', (t) async {
      await pumpLoan(t, sampleLoan(person: 'm2', amount: '500'));
      await t.tap(
        find.descendant(
          of: find.byKey(const Key('loan-direction')),
          matching: find.text('I borrowed'),
        ),
      );
      await settle(t);
      expect(_text('loan-sentence'), 'Asha Rao lent you ₹500');
      expect(_text('loan-result'), 'You will owe Asha Rao ₹500');
      expect(find.text('FROM WHOM?'), findsOneWidget);
      expect(find.text('TO WHOM?'), findsNothing);
      await t.tap(
        find.descendant(of: find.byKey(const Key('loan-direction')), matching: find.text('I lent')),
      );
      await settle(t);
      expect(_text('loan-sentence'), 'You lent Asha Rao ₹500');
      expect(find.text('TO WHOM?'), findsOneWidget);
    });

    // TC-11-02
    testWidgets('keypad keys edit the amount and picking a person fills the sentence', (t) async {
      final c = await pumpLoan(t, sampleLoan());
      expect(_text('loan-amount'), '₹0');
      expect(_text('loan-sentence'), 'Choose a person');
      await tapKey(t, 'key-d5');
      await tapKey(t, 'key-d0');
      await tapKey(t, 'key-d0');
      expect(_text('loan-amount'), '₹500');
      expect(_text('loan-sentence'), 'Choose a person');
      await tapKey(t, 'loan-person-m3');
      expect(c.state.value!.personId, 'm3');
      expect(_text('loan-sentence'), 'You lent Rahul Mehta ₹500');
    });

    // TC-11-02
    testWidgets('Save without person and amount shows both errors and does not save', (t) async {
      final c = await pumpLoan(t, sampleLoan());
      expect(find.byKey(const Key('loan-person-error')), findsNothing);
      await tapKey(t, 'loan-save');
      expect(find.byKey(const Key('loan-amount-error')), findsOneWidget);
      await reveal(t, find.byKey(const Key('loan-person-error')));
      expect(find.byKey(const Key('loan-person-error')), findsOneWidget);
      expect(c.saves, 0);
      expect(find.byType(LoanScreen), findsOneWidget);
    });

    // TC-11-02
    testWidgets('a valid Save closes the screen and says "Loan saved"', (t) async {
      final c = await pumpLoan(t, sampleLoan(person: 'm2', amount: '500'));
      await tapKey(t, 'loan-save');
      expect(c.saves, 1);
      expect(find.byType(LoanScreen), findsNothing);
      expect(find.text('Loan saved'), findsOneWidget);
    });

    // TC-11-02
    testWidgets('no other member: empty state, no keypad, no Save', (t) async {
      await pumpLoan(t, sampleLoan(members: const [(id: 'm1', name: 'Mohit Bindal', isMe: true)]));
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Add someone to this group first.'), findsOneWidget);
      expect(find.byKey(const Key('loan-save')), findsNothing);
      expect(find.byKey(const Key('key-d5')), findsNothing);
    });

    // TC-11-02
    testWidgets('editing a loan between two others uses their names', (t) async {
      await pumpLoan(
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
      expect(find.text('Edit loan'), findsWidgets);
      expect(find.text('Asha Rao lent'), findsOneWidget);
      expect(find.text('Asha Rao borrowed'), findsOneWidget);
      expect(_text('loan-sentence'), 'Asha Rao lent Rahul Mehta ₹300');
      expect(find.byKey(const Key('loan-result')), findsNothing);
      await t.tap(find.text('Asha Rao borrowed'));
      await settle(t);
      expect(_text('loan-sentence'), 'Rahul Mehta lent Asha Rao ₹300');
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
