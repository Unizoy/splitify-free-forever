// Emulator UI review for phase 08 (gate G5): shows every expense screen with sample data (no sign-in,
// no network), prints `UI-CAPTURE <name>` and holds it for `UI_HOLD` seconds while
// `.claude/skills/ui-review/scripts/capture_markers.ps1` takes light, dark and 200 % text screenshots
// (it flips the emulator's dark mode and font scale; the app follows both).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/features/expenses/application/default_split_controller.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/default_split_screen.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../test/features/expenses/expense_fixtures.dart';

/// Seconds each screen stays up for the host captures (`UI_HOLD`, 0 = no hold).
const _hold = int.fromEnvironment('UI_HOLD');

const ExpenseEditorArgs _editArgs = (groupId: null, expenseId: 'e1');
const ExpenseEditorArgs _newArgs = (groupId: gid, expenseId: null);

List<Override> _editor(ExpenseDraft draft) => [
  for (final a in [_editArgs, _newArgs])
    expenseEditorProvider(a).overrideWith(() => FixedEditorController(a, draft)),
];

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

List<(String, Widget, List<Override>)> _screens() {
  final views = sampleViews();
  return [
    (
      'editor-amount',
      const ExpenseEditorScreen(groupId: gid),
      _editor(sampleDraft(amount: '1200+450.5', expenseId: null)),
    ),
    (
      'editor-paid-by',
      const ExpenseEditorScreen(expenseId: 'e1', initialStep: EditorStep.paidBy),
      _editor(sampleDraft()),
    ),
    for (final k in SplitKind.values)
      (
        'editor-split-${k.name}',
        const ExpenseEditorScreen(expenseId: 'e1', initialStep: EditorStep.split),
        _editor(sampleDraft(kind: k)),
      ),
    (
      'editor-split-error',
      const ExpenseEditorScreen(expenseId: 'e1', initialStep: EditorStep.split),
      _editor(
        sampleDraft(
          split: SplitDraft.initial(ids, 2).withValues(SplitKind.exact, {'m1': 50000, 'm2': 30000}),
        ),
      ),
    ),
    (
      'editor-details',
      const ExpenseEditorScreen(expenseId: 'e1', initialStep: EditorStep.details),
      _editor(sampleDraft(notes: 'Table by the window, paid by card.')),
    ),
    (
      'editor-review',
      const ExpenseEditorScreen(expenseId: 'e1', initialStep: EditorStep.review),
      _editor(sampleDraft()),
    ),
    (
      'expense-list',
      const _ListHost(),
      [groupExpenseViewsProvider(gid).overrideWithValue(AsyncData(views))],
    ),
    (
      'expense-list-empty',
      const _ListHost(),
      [groupExpenseViewsProvider(gid).overrideWithValue(const AsyncData([]))],
    ),
    (
      'expense-detail',
      const ExpenseDetailScreen(expenseId: 'e1'),
      [
        expenseViewProvider('e1').overrideWithValue(
          AsyncData(sampleView(sampleExpense(notes: 'Table by the window, paid by card.'))),
        ),
        expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
      ],
    ),
    (
      'expense-detail-unsynced',
      const ExpenseDetailScreen(expenseId: 'e2'),
      [
        expenseViewProvider('e2').overrideWithValue(AsyncData(views.first)),
        expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
      ],
    ),
    (
      'default-split',
      const DefaultSplitScreen(groupId: gid),
      [
        defaultSplitProvider(gid).overrideWith(
          () => FixedDefaultSplitController(
            gid,
            DefaultSplitState(
              groupName: 'Goa trip',
              members: people,
              split: SplitDraft.initial(
                ids,
                2,
              ).withValues(SplitKind.shares, {'m1': 2000, 'm2': 1000, 'm3': 1000, 'm4': 1000}),
            ),
          ),
        ),
      ],
    ),
  ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI review: expense screens', (t) async {
    for (final (name, screen, overrides) in _screens()) {
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
      for (var i = 0; i < 15; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      debugPrint('UI-CAPTURE $name');
      // Keep pumping while the host flips dark mode and font scale.
      final end = DateTime.now().add(const Duration(seconds: _hold));
      while (DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await t.pump();
      }
    }
  });
}
