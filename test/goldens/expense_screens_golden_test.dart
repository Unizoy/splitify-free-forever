import 'dart:convert';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/core/money/split.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/expenses/application/default_split_controller.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/default_split_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/expenses/expense_fixtures.dart';
import 'golden_support.dart';

/// One golden scenario: the screen and the overrides that feed it.
typedef _Case = (String name, Widget screen, List<Override> overrides);

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

List<_Case> _cases() {
  final views = sampleViews();
  return [
    (
      'expense_list',
      const _ListHost(),
      [groupExpenseViewsProvider(gid).overrideWithValue(AsyncData(views))],
    ),
    (
      'expense_list_empty',
      const _ListHost(),
      [groupExpenseViewsProvider(gid).overrideWithValue(const AsyncData([]))],
    ),
    (
      'expense_list_loading',
      const _ListHost(),
      [groupExpenseViewsProvider(gid).overrideWithValue(const AsyncLoading())],
    ),
    (
      'expense_detail',
      const ExpenseDetailScreen(expenseId: 'e1'),
      [
        noRepeat('e1'),
        expenseViewProvider('e1').overrideWithValue(
          AsyncData(sampleView(sampleExpense(notes: 'Table by the window, paid by card.'))),
        ),
        expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
        commentThreadProvider((groupId: gid, targetType: 'expense', targetId: 'e1'))
            .overrideWithValue(const AsyncData([])),
      ],
    ),
    (
      'expense_detail_unsynced',
      const ExpenseDetailScreen(expenseId: 'e2'),
      [
        noRepeat('e2'),
        expenseViewProvider('e2').overrideWithValue(AsyncData(views.first)),
        expenseGroupProvider(gid).overrideWith((ref) => Stream.value(null)),
        commentThreadProvider((groupId: gid, targetType: 'expense', targetId: 'e2'))
            .overrideWithValue(const AsyncData([])),
      ],
    ),
    (
      'default_split',
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
              ).withValues(SplitKind.percent, {'m1': 4000, 'm2': 4000, 'm3': 1000, 'm4': 500}),
            ),
          ),
        ),
      ],
    ),
  ];
}

void main() {
  // TC-35-02 (+ list/detail states): the expense list, detail and default split in light and dark at
  // text scale 1.0 and 2.0. The add/edit editor (TC-5..9-04, TC-13-02) is in expense_editor_golden_test.dart.
  for (final (name, screen, overrides) in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'expense screen $name ${mode.name} $suffix',
          fileName: 'expense_${name}_${mode.name}_$suffix',
          pumpBeforeTest: pumpFixedFrames,
          builder: () => expenseApp(screen, overrides: overrides, mode: mode, scale: scale),
        );
      }
    }
  }

  test('fixtures stay consistent', () {
    expect(jsonDecode(sampleExpense().shares), hasLength(4));
  });
}
