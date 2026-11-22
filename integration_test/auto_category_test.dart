// Auto-category on the device (D-028, TC-X5-07): the real editor with a new expense in a sample group; typing
// "Swiggy" picks Food · Takeaway after the pause with the "Auto" tag, a manual pick sticks, the keyword list is read
// from the app bundle. Prints `UI-CAPTURE <name>` and holds each state for `UI_HOLD` seconds so
// `.claude/skills/ui-review/scripts/capture_markers.ps1` can take light, dark and 200 % text screenshots.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../test/features/expenses/expense_fixtures.dart';

const _hold = int.fromEnvironment('UI_HOLD');
const ExpenseEditorArgs _newArgs = (groupId: gid, expenseId: null);

Future<void> _wait(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await t.pump();
  }
}

Future<void> _capture(WidgetTester t, String name) async {
  debugPrint('UI-CAPTURE $name');
  await _wait(t, const Duration(seconds: _hold));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('auto-category in the editor', (t) async {
    late FixedEditorController controller;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(),
          expenseEditorProvider(_newArgs).overrideWith(
            () => controller = FixedEditorController(
              _newArgs,
              sampleDraft(
                amount: '450',
                description: '',
                category: 'other.general',
                categoryOrigin: CategoryOrigin.initial,
                expenseId: null,
              ),
            ),
          ),
        ],
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
          home: const ExpenseEditorScreen(groupId: gid),
        ),
      ),
    );
    await _wait(t, const Duration(seconds: 2));
    ExpenseDraft draft() => controller.state.value!;
    expect(draft().category, 'other.general');

    // Type like a person: one letter at a time, faster than the pause.
    final field = find.descendant(
      of: find.byKey(const Key('expense-description')),
      matching: find.byType(TextField),
    );
    await t.tap(field);
    var typed = '';
    for (final ch in 'Swiggy'.split('')) {
      typed += ch;
      await t.enterText(field, typed);
      await _wait(t, const Duration(milliseconds: 80));
    }
    expect(draft().category, 'other.general', reason: 'still typing');
    await _wait(t, const Duration(milliseconds: 600));
    expect(draft().category, 'food.takeaway');
    expect(draft().categoryIsAuto, isTrue);
    expect(find.text('Takeaway'), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await _wait(t, const Duration(seconds: 1));
    await _capture(t, 'x5-editor-auto');

    await t.tap(field);
    await _wait(t, const Duration(milliseconds: 300));
    await t.enterText(field, 'Uber to the airport');
    await _wait(t, const Duration(milliseconds: 600));
    expect(draft().category, 'travel.cab_auto');
    FocusManager.instance.primaryFocus?.unfocus();
    await _wait(t, const Duration(seconds: 1));
    await t.tap(
      find.descendant(
        of: find.byKey(const Key('category-hint')),
        matching: find.text('Cab & auto'),
      ),
    );
    await _wait(t, const Duration(seconds: 1));
    expect(find.byKey(const Key('category-travel.cab_auto')), findsOneWidget);
    await _capture(t, 'x5-details-auto');

    await t.tap(find.byKey(const Key('category-travel.hotel')));
    await _wait(t, const Duration(milliseconds: 500));
    expect(draft().categoryOrigin, CategoryOrigin.manual);
    expect(find.byKey(const Key('category-auto')), findsNothing);
    await _capture(t, 'x5-details-manual');
    debugPrint('X5-AUTO-CATEGORY OK');
  });
}
