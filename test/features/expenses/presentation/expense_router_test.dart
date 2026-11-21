import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/features/expenses/application/default_split_controller.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/default_split_screen.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../expense_fixtures.dart';

/// The real app router: the phase 08 routes resolve next to phase 07's nested `/groups/:id` routes.
void main() {
  Future<void> pumpAt(WidgetTester t, String location) async {
    const ExpenseEditorArgs newArgs = (groupId: gid, expenseId: null);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(),
          expenseEditorProvider(newArgs)
              .overrideWith(() => FixedEditorController(newArgs, sampleDraft(expenseId: null))),
          defaultSplitProvider(gid).overrideWith(
            () => FixedDefaultSplitController(
              gid,
              DefaultSplitState(
                groupName: 'Goa trip',
                members: people,
                split: SplitDraft.initial(
                  ids,
                  2,
                ).withValues(SplitKind.shares, {'m1': 1000, 'm2': 1000, 'm3': 1000, 'm4': 1000}),
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: buildRouter(initialLocation: location),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('/groups/:id/default-split opens the default split editor', (t) async {
    await pumpAt(t, ExpenseRoutes.defaultSplit(gid));
    expect(find.byType(DefaultSplitScreen), findsOneWidget);
  });

  testWidgets('/expense/new?group= opens the stepper for that group', (t) async {
    await pumpAt(t, ExpenseRoutes.add(gid));
    expect(find.byType(ExpenseEditorScreen), findsOneWidget);
    expect(find.text('Goa trip'), findsOneWidget);
  });
}
