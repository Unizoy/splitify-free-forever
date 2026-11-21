// Emulator UI review for phase 10 (gate G5): multi-payer step, receipt on the details step, Record a loan,
// loan/receipt detail, the list with loans and the photo viewer, with sample data (no sign-in, no network).
// Prints `UI-CAPTURE <name>` and holds each screen for `UI_HOLD` seconds while
// `.claude/skills/ui-review/scripts/capture_markers.ps1` takes light, dark and 200 % text screenshots.
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/loan_editor_controller.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';
import 'package:splitify/features/expenses/presentation/loan_screen.dart';
import 'package:splitify/features/photos/presentation/photo_viewer_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../test/features/expenses/expense_fixtures.dart';
import '../test/features/expenses/presentation/loan_screen_test.dart'
    show FixedLoanController, sampleLoan;
import '../test/support/photo_fixtures.dart';
import '../test/support/sample_photo.dart';

/// Seconds each screen stays up for the host captures (`UI_HOLD`, 0 = no hold).
const _hold = int.fromEnvironment('UI_HOLD');

/// Only these screens (comma separated, `UI_ONLY`), for re-captures.
const _only = String.fromEnvironment('UI_ONLY');

const ExpenseEditorArgs _newArgs = (groupId: gid, expenseId: null);
const LoanEditorArgs _loanArgs = (groupId: gid, expenseId: null, withMember: null);
const _receiptPath = 'g-goa/e1/r1.jpg';

List<Override> _editor(ExpenseDraft draft) => [
  expenseEditorProvider(_newArgs).overrideWith(() => FixedEditorController(_newArgs, draft)),
];

LocalExpense _loanRow() => sampleExpense(
  id: 'l1',
  description: 'Cab money',
  date: '2026-11-20',
  total: 50000,
  payers: const {'m1': 50000},
  shares: const {'m2': 50000},
).copyWith(kind: 'iou', category: 'other.general');

class _ListHost extends StatelessWidget {
  const _ListHost();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: ExpenseList(groupId: gid),
      ),
    ),
  );
}

List<(String, Widget, List<Override>)> _screens(File photo) {
  ExpenseEditorScreen editor(EditorStep step) =>
      ExpenseEditorScreen(groupId: gid, initialStep: step);
  final withReceipt = sampleExpense(notes: 'Table by the window, paid by card.')
      .copyWith(receiptPath: const Value(_receiptPath));
  final listViews = [
    sampleView(_loanRow()),
    sampleView(
      sampleExpense(
        id: 'e5',
        description: 'Beach shack',
        category: 'travel.hotel',
        date: '2026-11-19',
        total: 120000,
        payers: const {'m1': 70000, 'm2': 50000},
      ),
    ),
    sampleView(
      sampleExpense(
        id: 'e6',
        description: 'Groceries',
        category: 'groceries.groceries',
        date: '2026-11-18',
        total: 85050,
        payers: const {'m3': 85050},
      ).copyWith(receiptPath: const Value(_receiptPath)),
    ),
  ];
  return [
    (
      'paid-by-multiple',
      editor(EditorStep.paidBy),
      _editor(sampleDraft(expenseId: null).withPayerText('m1', '700').withPayerText('m2', '300')),
    ),
    (
      'details-receipt',
      editor(EditorStep.details),
      _editor(
        sampleDraft(expenseId: null)
            .copyWith(receipt: const ReceiptDraft.none().pick(samplePrepared)),
      ),
    ),
    (
      'review-multiple',
      editor(EditorStep.review),
      _editor(sampleDraft(expenseId: null).withPayerText('m1', '700').withPayerText('m2', '500')),
    ),
    (
      'loan-new',
      const LoanScreen(groupId: gid),
      [
        loanEditorProvider(_loanArgs)
            .overrideWith(() => FixedLoanController(_loanArgs, sampleLoan())),
      ],
    ),
    (
      'loan-filled',
      const LoanScreen(groupId: gid),
      [
        loanEditorProvider(_loanArgs).overrideWith(
          () => FixedLoanController(_loanArgs, sampleLoan(person: 'm2', amount: '500')),
        ),
      ],
    ),
    (
      'list-loans',
      const _ListHost(),
      [
        groupExpenseViewsProvider(gid).overrideWithValue(AsyncData(listViews)),
        ...storedReceipt(_receiptPath, photo),
      ],
    ),
    (
      'detail-loan',
      const ExpenseDetailScreen(expenseId: 'l1'),
      [
        expenseViewProvider('l1').overrideWithValue(AsyncData(sampleView(_loanRow()))),
        expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
      ],
    ),
    (
      'detail-receipt',
      const ExpenseDetailScreen(expenseId: 'e1'),
      [
        expenseViewProvider('e1').overrideWithValue(AsyncData(sampleView(withReceipt))),
        expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
        ...storedReceipt(_receiptPath, photo, pending: true),
      ],
    ),
    (
      'photo-viewer',
      PhotoViewerScreen(
        title: 'Receipt photo',
        bytes: samplePhotoPng,
        onReplace: () async => false,
        onRemove: () async => false,
      ),
      const [],
    ),
  ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI review: phase 10 screens', (t) async {
    final dir = (await t.runAsync(getTemporaryDirectory))!;
    final photo = File('${dir.path}/ui_review_receipt.png');
    await t.runAsync(() => photo.writeAsBytes(samplePhotoPng));
    final only = _only.isEmpty ? null : _only.split(',').toSet();
    for (final (name, screen, overrides) in _screens(photo)) {
      if (only != null && !only.contains(name)) continue;
      await t.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [...baseOverrides(), ...overrides],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            debugShowCheckedModeBanner: false,
            home: screen,
          ),
        ),
      );
      // File images decode on the real event loop.
      for (var i = 0; i < 15; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await t.pump(const Duration(milliseconds: 100));
      }
      debugPrint('UI-CAPTURE $name');
      final end = DateTime.now().add(const Duration(seconds: _hold));
      while (DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await t.pump();
      }
    }
  });
}
