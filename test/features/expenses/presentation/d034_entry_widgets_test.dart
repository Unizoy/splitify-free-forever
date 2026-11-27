// D-034 WP-A smart entry, widgets.
// TC-D034-A1-02 the two-person sheet (2 people vs 3, live lines, one tap picks and closes)
// TC-D034-A2-04 the Items editor (add/remove a line, assign people, live remaining, errors, use total)
// TC-D034-A3-06 the scan review sheet (found / nothing found / offline) and the scan flow in the editor
// TC-D034-A4-01 the deleted-expense page (Deleted pill, Restore, read-only)
// TC-D034-A5-02 focus back to the description / amount after a "With you and" pick
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/domain/rules/receipt_text_parser.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/itemize_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/application/two_person.dart';
import 'package:splitify/features/expenses/presentation/editor/with_picker.dart'
    show withTargetsProvider;
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show syncOfflineProvider;
import 'package:splitify/features/receipt_scan/application/receipt_ocr.dart';
import 'package:splitify/features/receipt_scan/presentation/scan_review_sheet.dart';

import '../../../support/sample_photo.dart';
import '../expense_fixtures.dart';
import 'presentation_harness.dart';

final _png = samplePhotoPng;

/// Two people: me and Asha (a friend expense).
ExpenseDraft _friend({String amount = '300'}) {
  final d = sampleDraft(expenseId: null, amount: amount, description: 'Cab');
  return ExpenseDraft(
    groupId: d.groupId,
    groupName: 'Asha Rao',
    groupType: 'direct',
    currency: 'INR',
    members: people.take(2).toList(),
    split: SplitDraft.initial(const ['m1', 'm2'], 2),
    date: d.date,
    payerId: me,
    payers: const {},
    amountText: amount,
    description: 'Cab',
    canRepeat: true,
  );
}

ExpenseDraft _group({String amount = '1200'}) => sampleDraft(
  expenseId: null,
  amount: amount,
  split: SplitDraft.initial(ids, 2),
  canRepeat: true,
);

/// OCR lines of the restaurant fixture, one per row (no boxes).
List<OcrLine> _restaurantLines() => [
  for (final row in const [
    'HOTEL SARAVANA BHAVAN',
    'Date: 21/11/2026',
    'Masala Dosa  2  90.00  180.00',
    'Ghee Roast  1  140.00  140.00',
    'Sub Total  320.00',
    'CGST @ 2.5%  8.00',
    'SGST @ 2.5%  8.00',
    'Grand Total  Rs. 336.00',
  ])
    OcrLine(row),
];

List<Override> _scanOverrides({required List<OcrLine> lines}) => [
  receiptImagePickerProvider.overrideWithValue((_) async => 'unused.jpg'),
  receiptOcrProvider.overrideWithValue((_) async => lines),
  receiptPhotoPreparerProvider.overrideWithValue(
    (_) async => PreparedImage(full: _png, thumb: _png),
  ),
];

class _FakeActions extends ExpenseActions {
  _FakeActions(super.ref);

  final restored = <String>[];

  @override
  Future<void> restore(LocalExpense e) async => restored.add(e.id);
}

void main() {
  group('two-person answers sheet', () {
    testWidgets('two people: the pill opens four answers with live lines; one tap picks', (
      t,
    ) async {
      final h = await pumpEditor(t, _friend(), args: newArgs);
      await tapKey(t, 'split-summary');
      expect(find.byKey(const Key('two-person')), findsOneWidget);
      expect(find.text('You paid, split equally'), findsOneWidget);
      // (₹150 is also the pill's line under the sheet.)
      expect(find.text('Asha Rao owes you ₹150'), findsWidgets);
      expect(find.text('Asha Rao owes you ₹300'), findsOneWidget);
      expect(find.text('You owe Asha Rao ₹150'), findsOneWidget);
      expect(find.text('You owe Asha Rao ₹300'), findsOneWidget);
      expect(find.byKey(const Key('answer-more')), findsOneWidget);

      await tapKey(t, 'answer-youOwedFull');
      expect(find.byKey(const Key('two-person')), findsNothing, reason: 'one tap closes');
      expect(h.draft.twoPersonAnswer, TwoPersonAnswer.youOwedFull);
      expect(h.draft.toRow()['shares'], {'m1': 0, 'm2': 30000});
      expect(find.text('Paid by You · Asha Rao owes the full amount'), findsOneWidget);
      expect(find.text('Asha Rao owes you ₹300'), findsOneWidget, reason: 'the pill line');

      // The amount changes: "the full amount" follows.
      await t.enterText(fieldIn('expense-amount'), '450');
      await settle(t);
      expect(h.draft.toRow()['shares'], {'m1': 0, 'm2': 45000});
      expect(find.text('Asha Rao owes you ₹450'), findsOneWidget);
    });

    testWidgets('without an amount the lines say half / all of it', (t) async {
      await pumpEditor(t, _friend(amount: ''), args: newArgs);
      await tapKey(t, 'split-summary');
      expect(find.text('Asha Rao owes you half'), findsOneWidget);
      expect(find.text('You owe Asha Rao all of it'), findsOneWidget);
    });

    testWidgets('More options opens the full sheet', (t) async {
      await pumpEditor(t, _friend(), args: newArgs);
      await tapKey(t, 'split-summary');
      await tapKey(t, 'answer-more');
      expect(find.byKey(const Key('two-person')), findsNothing);
      expect(find.byKey(const Key('paid-split-done')), findsOneWidget);
    });

    testWidgets('three or more people: the full sheet at once', (t) async {
      await pumpEditor(t, _group(), args: newArgs);
      await tapKey(t, 'split-summary');
      expect(find.byKey(const Key('two-person')), findsNothing);
      expect(find.byKey(const Key('paid-split-done')), findsOneWidget);
    });
  });

  group('Items editor', () {
    testWidgets('lines, people, live remaining, errors and "Use items total"', (t) async {
      final h = await pumpEditor(t, _group(amount: ''), args: newArgs);
      await tapKey(t, 'split-summary');
      await tapKey(t, 'split-items');
      expect(find.byKey(const Key('items-editor')), findsOneWidget);
      expect(h.draft.split.isItems, isTrue);
      final first = h.draft.split.items!.items.single.key;

      await t.enterText(fieldIn('item-amount-$first'), '400');
      await settle(t);
      expect(find.text('Items come to ₹400'), findsWidgets);
      expect(find.byKey(const Key('items-use-total')), findsOneWidget);

      // Only Mohit had the first line.
      for (final id in ['m2', 'm3', 'm4']) {
        await tapKey(t, 'item-$first-person-$id');
      }
      expect(h.draft.split.items!.items.single.members, {'m1'});

      await tapKey(t, 'item-add');
      final second = h.draft.split.items!.items.last.key;
      await t.enterText(fieldIn('item-amount-$second'), '600');
      await settle(t);
      await tapKey(t, 'items-use-total');
      expect(h.draft.amountText, '1000');
      expect(find.text('₹1,000 · done'), findsWidgets);
      final shares = h.draft.toRow()['shares']! as Map<String, int>;
      expect(shares, {'m1': 55000, 'm2': 15000, 'm3': 15000, 'm4': 15000});

      // A different amount: what is left.
      await t.enterText(fieldIn('expense-amount'), '1100');
      await settle(t);
      expect(find.textContaining('₹100 left'), findsWidgets);

      // Extras: ₹100 tax shared in proportion closes the gap.
      await tapKey(t, 'items-extras');
      await t.enterText(fieldIn('extra-field-tax'), '100');
      await settle(t);
      expect(h.draft.canSave, isTrue);

      // A line without anyone on it.
      for (final id in ['m1', 'm2', 'm3', 'm4']) {
        await tapKey(t, 'item-$second-person-$id');
      }
      expect(find.text('Every item needs at least one person'), findsWidgets);

      await tapKey(t, 'item-remove-$second');
      expect(h.draft.split.items!.items.length, 1);
    });
  });

  group('scan review', () {
    Widget review(ScanOutcome o, ExpenseDraft d, {List<ScanDecision>? out}) => expenseApp(
      Scaffold(
        body: SingleChildScrollView(
          child: ScanReviewPanel(outcome: o, draft: d, onDone: (x) => out?.add(x), onRetry: () {}),
        ),
      ),
    );

    final photo = PreparedImage(full: _png, thumb: _png);

    testWidgets('found: amount, date and description ticked; items; Use these', (t) async {
      usePhone(t);
      final out = <ScanDecision>[];
      final o = (scan: parseReceipt([for (final l in _restaurantLines()) l.text]), photo: photo);
      await t.pumpWidget(
        review(
          o,
          _group(amount: '').copyWith(description: ''),
          out: out,
        ),
      );
      await settle(t);
      expect(find.text('₹336.00'), findsOneWidget);
      expect(find.text('21 Nov 2026'), findsOneWidget);
      expect(find.text('Hotel Saravana Bhavan'), findsOneWidget);
      expect(find.text('2 items found'), findsOneWidget);
      expect(find.byKey(const Key('scan-itemize')), findsOneWidget);
      await tapKey(t, 'scan-date');
      await tapKey(t, 'scan-use');
      expect(out.single.choice, (amount: true, date: false, description: true));
      expect(out.single.itemize, isFalse);
    });

    testWidgets('a typed amount is not replaced unless ticked ("Replaces ₹500")', (t) async {
      usePhone(t);
      final out = <ScanDecision>[];
      final o = (scan: const ReceiptScan(total: 33600), photo: photo);
      await t.pumpWidget(review(o, _group(amount: '500'), out: out));
      await settle(t);
      expect(find.text('Replaces ₹500'), findsOneWidget);
      await tapKey(t, 'scan-use');
      expect(out.single.choice.amount, isFalse);
    });

    testWidgets('nothing found: keep the photo or try again', (t) async {
      usePhone(t);
      final out = <ScanDecision>[];
      await t.pumpWidget(review((scan: const ReceiptScan(), photo: photo), _group(), out: out));
      await settle(t);
      expect(find.byKey(const Key('scan-nothing')), findsOneWidget);
      expect(find.text("Couldn't read this receipt"), findsOneWidget);
      await tapKey(t, 'scan-keep-photo');
      expect(out.single.itemize, isFalse);
    });

    testWidgets('no group yet: itemize asks for who it is with first', (t) async {
      usePhone(t);
      final unpicked = ExpenseDraft(
        groupId: '',
        groupName: '',
        currency: 'INR',
        members: const [],
        split: SplitDraft.initial(const [], 2),
        date: fixedToday,
        payers: const {},
      );
      final o = (scan: parseReceipt([for (final l in _restaurantLines()) l.text]), photo: photo);
      await t.pumpWidget(review(o, unpicked));
      await settle(t);
      expect(find.byKey(const Key('scan-itemize')), findsNothing);
      expect(find.byKey(const Key('scan-itemize-needs-group')), findsOneWidget);
    });

    testWidgets('the editor: Receipt → Scan → gallery → Use these fills the fields, offline too', (
      t,
    ) async {
      final h = await pumpEditor(
        t,
        _group(amount: '').copyWith(description: ''),
        args: newArgs,
        overrides: [
          ..._scanOverrides(lines: _restaurantLines()),
          syncOfflineProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      await tapKey(t, 'expense-receipt-chip');
      await tapKey(t, 'receipt-scan');
      await tapKey(t, 'scan-gallery');
      await settle(t);
      expect(find.byKey(const Key('scan-review')), findsOneWidget);
      expect(find.textContaining('uploads when you\'re online'), findsOneWidget);
      await tapKey(t, 'scan-use');
      expect(h.draft.amountText, '336');
      expect(h.draft.description, 'Hotel Saravana Bhavan');
      expect(h.draft.receipt.hasPhoto, isTrue);
      expect(h.controller!.saves, 0, reason: 'a scan never saves');
      expect(t.widget<TextField>(fieldIn('expense-amount')).controller!.text, '336');
      expect(
        t.widget<TextField>(fieldIn('expense-description')).controller!.text,
        'Hotel Saravana Bhavan',
      );
    });

    testWidgets('Split by items opens the Items editor with the found lines', (t) async {
      final h = await pumpEditor(
        t,
        _group(amount: '').copyWith(description: ''),
        args: newArgs,
        overrides: _scanOverrides(lines: _restaurantLines()),
      );
      await tapKey(t, 'expense-receipt-chip');
      await tapKey(t, 'receipt-scan');
      await tapKey(t, 'scan-gallery');
      await settle(t);
      await tapKey(t, 'scan-itemize');
      await settle(t);
      expect(find.byKey(const Key('items-editor')), findsOneWidget);
      final items = h.draft.split.items!;
      expect([for (final i in items.items) i.name], ['Masala Dosa', 'Ghee Roast']);
      expect(items.extras[ItemExtra.tax], '16');
      expect(h.draft.canSave, isTrue);
    });
  });

  group('deleted expense page', () {
    testWidgets('Deleted pill, Restore, no edit/delete, read-only', (t) async {
      usePhone(t);
      final deleted = sampleExpense().copyWith(deletedAt: const Value('2026-11-21T09:00:00Z'));
      late _FakeActions actions;
      await t.pumpWidget(
        expenseApp(
          const ExpenseDetailScreen(expenseId: 'e1'),
          overrides: [
            expenseViewProvider('e1').overrideWithValue(AsyncData(sampleView(deleted))),
            expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
            noRepeat('e1'),
            expenseActionsProvider.overrideWith((ref) => actions = _FakeActions(ref)),
          ],
        ),
      );
      await settle(t);
      expect(find.byKey(const Key('expense-deleted-pill')), findsOneWidget);
      expect(find.byKey(const Key('expense-edit')), findsNothing);
      expect(find.byKey(const Key('expense-delete')), findsNothing);
      expect(find.byKey(const Key('expense-restore-top')), findsOneWidget);
      expect(find.byKey(const Key('expense-deleted-note')), findsOneWidget);
      await tapKey(t, 'expense-restore');
      expect(actions.restored, ['e1']);
      expect(find.text('Expense restored'), findsOneWidget);
    });

    testWidgets('a live expense keeps Edit and Delete', (t) async {
      usePhone(t);
      await t.pumpWidget(
        expenseApp(
          const ExpenseDetailScreen(expenseId: 'e1'),
          overrides: [
            expenseViewProvider('e1').overrideWithValue(AsyncData(sampleView(sampleExpense()))),
            expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
            noRepeat('e1'),
          ],
        ),
      );
      await settle(t);
      expect(find.byKey(const Key('expense-edit')), findsOneWidget);
      expect(find.byKey(const Key('expense-deleted-pill')), findsNothing);
    });
  });

  group('focus after a "With you and" pick', () {
    testWidgets('description empty → description; filled → amount', (t) async {
      final unpicked = ExpenseDraft(
        groupId: '',
        groupName: '',
        currency: 'INR',
        members: const [],
        split: SplitDraft.initial(const [], 2),
        date: fixedToday,
        payers: const {},
        canRepeat: true,
      );
      await pumpEditor(
        t,
        unpicked,
        args: (groupId: null, expenseId: null),
        make: _PickingController.new,
        overrides: [withTargetsProvider.overrideWithValue(sampleTargets())],
      );
      // Type a description first, then pick a quick suggestion: the amount gets the cursor.
      await t.enterText(fieldIn('expense-description'), 'Chai');
      await settle(t);
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(t);
      await tapText(t, 'Goa trip');
      await settle(t);
      final amount = t.widget<TextField>(fieldIn('expense-amount'));
      expect(amount.focusNode!.hasFocus, isTrue);
    });
  });
}

/// "With you and" pick without a database: the sample group's people.
class _PickingController extends FixedEditorController {
  _PickingController(super.args, super.draft);

  @override
  Future<void> pickGroup(String groupId, {bool keepCurrency = false}) async {
    final now = state.value!;
    state = AsyncData(
      sampleDraft(
        expenseId: null,
        amount: '',
        description: '',
        canRepeat: true,
      ).carriedFrom(now, keepCurrency: keepCurrency),
    );
  }
}
