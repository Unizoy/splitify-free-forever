import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/entities/profile.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/loan_draft.dart';
import 'package:splitify/features/expenses/application/loan_editor_controller.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';
import 'package:splitify/features/expenses/presentation/loan_screen.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_form_screen.dart';
import 'package:splitify/features/photos/presentation/photo_viewer_screen.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/expenses/expense_fixtures.dart';
import '../features/expenses/presentation/loan_screen_test.dart'
    show FixedLoanController, sampleLoan;
import '../support/photo_fixtures.dart';
import '../support/sample_photo.dart';
import 'golden_support.dart';

/// One golden scenario: the screen and the overrides that feed it.
typedef _Case = (String name, Widget screen, List<Override> overrides);

const ExpenseEditorArgs _newArgs = (groupId: gid, expenseId: null);
const LoanEditorArgs _loanArgs = (groupId: gid, expenseId: null, withMember: null);
const _receiptPath = 'g-goa/e1/r1.jpg';
const _coverPath = 'g-goa/c1.jpg';

List<Override> _editor(ExpenseDraft Function() draft) => [
  expenseEditorProvider(_newArgs).overrideWith(() => FixedEditorController(_newArgs, draft())),
];

List<Override> _loan(LoanDraft draft) => [
  loanEditorProvider(_loanArgs).overrideWith(() => FixedLoanController(_loanArgs, draft)),
];

class _ListHost extends StatelessWidget {
  const _ListHost();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: const ExpenseList(groupId: gid),
      ),
    ),
  );
}

class _FixedProfile extends ProfileController {
  @override
  Future<Profile?> build() async => null;
}

LocalExpense _loanRow() => sampleExpense(
  id: 'l1',
  description: 'Cab money',
  date: '2026-11-20',
  total: 50000,
  payers: const {'m1': 50000},
  shares: const {'m2': 50000},
).copyWith(kind: 'iou', category: 'other.general');

List<_Case> _cases(File photo) {
  ExpenseEditorScreen editor(EditorStep step) =>
      ExpenseEditorScreen(groupId: gid, initialStep: step);
  ExpenseDraft multi(String a, String b) =>
      sampleDraft(expenseId: null).withPayerText('m1', a).withPayerText('m2', b);
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
    sampleView(
      sampleExpense(
        id: 'e7',
        description: 'Boat trip',
        category: 'travel.cab_auto',
        date: '2026-11-17',
        total: 120000,
        payers: const {'m1': 40000, 'm2': 40000, 'm3': 40000},
      ),
    ),
  ];
  final goa = sampleGroup().copyWith(coverKind: 'photo', coverPath: const Value(_coverPath));
  return [
    ('editor_paid_by_multiple', editor(EditorStep.paidBy), _editor(() => multi('700', '500'))),
    ('editor_paid_by_multiple_left', editor(EditorStep.paidBy), _editor(() => multi('700', '300'))),
    (
      'editor_details_receipt_empty',
      editor(EditorStep.details),
      _editor(() => sampleDraft(expenseId: null)),
    ),
    (
      'editor_details_receipt_photo',
      editor(EditorStep.details),
      _editor(
        () =>
            sampleDraft(expenseId: null)
                .copyWith(receipt: const ReceiptDraft.none().pick(samplePrepared)),
      ),
    ),
    (
      'loan_new_lent',
      const LoanScreen(groupId: gid),
      _loan(sampleLoan(person: 'm2', amount: '500')),
    ),
    (
      'loan_borrowed',
      const LoanScreen(groupId: gid),
      _loan(sampleLoan(direction: LoanDirection.borrowed, person: 'm2', amount: '500')),
    ),
    (
      'loan_no_others',
      const LoanScreen(groupId: gid),
      _loan(sampleLoan(members: const [(id: 'm1', name: 'Mohit Bindal', isMe: true)])),
    ),
    (
      'expense_list_loans',
      const _ListHost(),
      [
        groupExpenseViewsProvider(gid).overrideWithValue(AsyncData(listViews)),
        ...storedReceipt(_receiptPath, photo, ready: _ready),
      ],
    ),
    (
      'expense_detail_loan',
      const ExpenseDetailScreen(expenseId: 'l1'),
      [
        commentThreadProvider((groupId: gid, targetType: 'expense', targetId: 'l1'))
            .overrideWithValue(const AsyncData([])),
        expenseViewProvider('l1').overrideWithValue(AsyncData(sampleView(_loanRow()))),
        expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
      ],
    ),
    (
      'expense_detail_receipt',
      const ExpenseDetailScreen(expenseId: 'e1'),
      [
        commentThreadProvider((groupId: gid, targetType: 'expense', targetId: 'e1'))
            .overrideWithValue(const AsyncData([])),
        noRepeat('e1'),
        expenseViewProvider('e1').overrideWithValue(AsyncData(sampleView(withReceipt))),
        expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
        ...storedReceipt(_receiptPath, photo, ready: _ready),
      ],
    ),
    (
      'photo_viewer',
      PhotoViewerScreen(
        title: 'Receipt photo',
        bytes: samplePhotoPng,
        onReplace: () async => false,
        onRemove: () async => false,
      ),
      const [],
    ),
    (
      'group_form_photo_cover',
      const GroupFormScreen(groupId: gid),
      [
        profileProvider.overrideWith(_FixedProfile.new),
        groupProvider.overrideWith((ref, id) => Stream.value(goa)),
        storedGroupCover(_coverPath, photo, ready: _ready),
      ],
    ),
  ];
}

/// Stored photos wait for this until the file is decoded (a load started in fake time never finishes).
// Created lazily inside the test body: a completer made in setUp would flush outside fake time.
Completer<void>? _decoded;

Future<void> _ready() => (_decoded ??= Completer<void>()).future;

/// [pumpFixedFrames] while stored photos are held back, then the file is read and decoded on the real event
/// loop (into the image cache) and released: the next frame shows it at once.
Future<void> _pumpWithImages(WidgetTester tester) async {
  await pumpFixedFrames(tester);
  final context = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(() async {
    for (final width in [412, 1000]) {
      await precacheImage(ResizeImage(FileImage(_photo), width: width), context);
    }
  });
  (_decoded ??= Completer<void>()).complete();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

late File _photo;

/// Cases whose receipt is below the first screen.
const _tall = {
  'editor_details_receipt_empty',
  'editor_details_receipt_photo',
  'expense_detail_receipt',
};

void main() {
  setUp(() => _decoded = null);
  // TC-10-02, TC-11-02, TC-29 UI: the phase 10 screens in light and dark at text scale 1.0 and 2.0.
  final dir = Directory.systemTemp.createTempSync('splitify_golden_photo');
  final photo = _photo = File('${dir.path}/p.png')..writeAsBytesSync(samplePhotoPng);
  tearDownAll(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps the image file open a little longer; the OS clears the temp folder later.
    }
  });
  for (final (name, screen, overrides) in _cases(photo)) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'phase 10 $name ${mode.name} $suffix',
          fileName: 'phase10_${name}_${mode.name}_$suffix',
          pumpBeforeTest: _pumpWithImages,
          builder: () => expenseApp(
            screen,
            overrides: overrides,
            mode: mode,
            scale: scale,
            // The receipt sits below the fold: give those screens a taller phone.
            size: _tall.contains(name)
                ? Size(goldenWidth, scale > 1 ? 2300 : 1300)
                : const Size(goldenWidth, 915),
          ),
        );
      }
    }
  }
}
