// D-032 one-screen add/edit expense: empty, filled (auto category), the Paid by · split sheet with a
// non-equal split, the validation error, an edit with several payers, a friend expense and "edit future
// copies" — light and dark at text 1.0 and 2.0, plus a small phone (360 × 640).
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/domain/rules/recurrence.dart' show RecurrenceInterval;
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/editor/paid_split_sheet.dart';
import 'package:splitify/features/recurring/application/repeat_draft.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/expenses/expense_fixtures.dart';
import 'golden_support.dart';

const ExpenseEditorArgs _editArgs = (groupId: null, expenseId: 'e1');
const ExpenseEditorArgs _newArgs = (groupId: gid, expenseId: null);

List<Override> _editor(ExpenseDraft Function() draft) => [
  for (final a in [_editArgs, _newArgs])
    expenseEditorProvider(a).overrideWith(() => FixedEditorController(a, draft())),
  templateEditorProvider('t1').overrideWith(() => FixedEditorController(_newArgs, draft())),
];

/// Pumps like [pumpFixedFrames], runs [act] (open a sheet, press Save) and lets it settle.
Future<void> Function(WidgetTester) _after(Future<void> Function(WidgetTester t) act) => (t) async {
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await act(t);
  await t.pump();
  await t.pump(const Duration(milliseconds: 1500));
  await t.pump(const Duration(milliseconds: 100));
  await expectA11y(t);
};

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pump();
}

typedef _Case = (
  String name,
  Widget screen,
  ExpenseDraft Function() draft,
  Future<void> Function(WidgetTester)? pump,
);

ExpenseDraft _new({
  String amount = '',
  String description = '',
  String category = 'other.general',
  CategoryOrigin origin = CategoryOrigin.initial,
  SplitDraft? split,
}) => sampleDraft(
  amount: amount,
  description: description,
  category: category,
  categoryOrigin: origin,
  expenseId: null,
  canRepeat: true,
  split: split,
);

ExpenseDraft _severalPayers() {
  final d = sampleDraft();
  return ExpenseDraft(
    groupId: d.groupId,
    groupName: d.groupName,
    expenseId: d.expenseId,
    currency: d.currency,
    members: d.members,
    split: d.split,
    date: DateTime(2026, 11, 18),
    payers: const {'m1': 70000, 'm2': 50000},
    amountText: '1200',
    description: d.description,
    category: d.category,
    notes: 'Table by the window',
  );
}

ExpenseDraft _friend() {
  final d = sampleDraft(expenseId: null, amount: '640', description: 'Movie tickets');
  return ExpenseDraft(
    groupId: d.groupId,
    groupName: 'Asha Rao',
    groupType: 'direct',
    currency: d.currency,
    members: people.take(2).toList(),
    split: SplitDraft.initial(['m1', 'm2'], 2),
    date: d.date,
    payerId: me,
    payers: const {},
    amountText: d.amountText,
    description: d.description,
    category: 'entertainment.movies',
    categoryOrigin: CategoryOrigin.auto,
    canRepeat: true,
  );
}

List<_Case> _cases() {
  const add = ExpenseEditorScreen(groupId: gid);
  const edit = ExpenseEditorScreen(expenseId: 'e1');
  final shares = SplitDraft.initial(
    ids,
    2,
  ).withValues(SplitKind.shares, {'m1': 2000, 'm2': 1000, 'm3': 1000, 'm4': 0});
  final exactLeft = SplitDraft.initial(
    ids,
    2,
  ).withValues(SplitKind.exact, {'m1': 50000, 'm2': 30000});
  return [
    ('empty', add, _new, null),
    (
      'filled',
      add,
      () => _new(
        amount: '1250.50',
        description: 'Swiggy dinner',
        category: 'food.takeaway',
        origin: CategoryOrigin.auto,
      ),
      null,
    ),
    (
      'sheet_shares',
      _PaidSplitHost(_new(amount: '1200', description: 'Groceries', split: shares)),
      _new,
      null,
    ),
    (
      'sheet_exact_left',
      _PaidSplitHost(_new(amount: '1200', description: 'Dinner', split: exactLeft)),
      _new,
      null,
    ),
    (
      'sheet_payers',
      _PaidSplitHost(
        _new(amount: '1200', description: 'Dinner').withMultiplePayers().withPayerText('m1', '700'),
      ),
      _new,
      null,
    ),
    ('error', add, _new, _after((t) => _tap(t, 'expense-save'))),
    ('edit_payers', edit, _severalPayers, null),
    ('friend', add, _friend, null),
    (
      'template',
      const ExpenseEditorScreen(templateId: 't1'),
      () => sampleDraft(
        expenseId: null,
        templateId: 't1',
        repeat: const RepeatDraft(interval: RecurrenceInterval.monthly),
      ),
      null,
    ),
  ];
}

/// The Paid by · split sheet at the bottom of a dimmed screen, like the real modal sheet.
class _PaidSplitHost extends StatelessWidget {
  const _PaidSplitHost(this.draft);

  final ExpenseDraft draft;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.scrim,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AppSheet(
        title: AppLocalizations.of(context).expPaidSplitTitle,
        child: PaidSplitPanel(
          draft: draft,
          onPayer: (_) {},
          onMultiple: () {},
          onPayerText: (_, _) {},
          onSplit: (_) {},
          onDone: () {},
        ),
      ),
    ),
  );
}

void main() {
  for (final (name, screen, draft, pump) in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'expense editor $name ${mode.name} $suffix',
          fileName: 'expense_editor_${name}_${mode.name}_$suffix',
          pumpBeforeTest: pump ?? pumpFixedFrames,
          builder: () => expenseApp(screen, overrides: _editor(draft), mode: mode, scale: scale),
        );
      }
    }
  }

  // A small phone: everything still fits or scrolls, Save stays on screen.
  for (final name in ['empty', 'filled', 'sheet_shares', 'error']) {
    final (_, screen, draft, pump) = _cases().firstWhere((c) => c.$1 == name);
    goldenTest(
      'expense editor $name small phone',
      fileName: 'expense_editor_${name}_small_light_text100',
      pumpBeforeTest: pump ?? pumpFixedFrames,
      builder: () => expenseApp(screen, overrides: _editor(draft), size: const Size(360, 640)),
    );
  }
}
