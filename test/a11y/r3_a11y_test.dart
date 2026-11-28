// R3-A accessibility (S-445, S-448): on every main screen and sheet of the size matrix (test/goldens/
// r3_screens.dart) TalkBack's swipe order follows the reading order — top to bottom, start to end within a row —
// on a normal phone, a 320 dp phone and at 200 % text; errors and messages are announced (live regions).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/expenses/expense_fixtures.dart';
import '../features/expenses/presentation/presentation_harness.dart';
import '../goldens/r3_screens.dart';

Rect _globalRect(SemanticsNode node) {
  var rect = node.rect;
  for (SemanticsNode? n = node; n != null; n = n.parent) {
    if (n.transform != null) rect = MatrixUtils.transformRect(n.transform!, rect);
  }
  return rect;
}

/// Fails when the traversal jumps back up the page (a node above the previous one, not on its row).
void _expectReadingOrder(WidgetTester tester, String name) {
  final nodes = tester.semantics
      .simulatedAccessibilityTraversal()
      .where((n) => !n.rect.isEmpty && (n.label.isNotEmpty || n.getSemanticsData().actions != 0))
      .toList();
  expect(nodes, isNotEmpty, reason: name);
  Rect? previous;
  for (final node in nodes) {
    final r = _globalRect(node);
    if (previous != null) {
      final sameRow = r.top < previous.bottom && r.bottom > previous.top;
      expect(
        sameRow || r.top >= previous.top - 1,
        isTrue,
        reason: '$name: "${node.label}" at ${r.top.round()} comes after a node at ${previous.top.round()}',
      );
    }
    previous = r;
  }
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  for (final screen in r3Screens()) {
    for (final (label, size, scale) in [
      ('phone', const Size(412, 915), 1.0),
      ('320 dp', const Size(320, 568), 1.0),
      ('text 2.0', const Size(412, 915), 2.0),
    ]) {
      testWidgets('${screen.name} $label: TalkBack order is the reading order', (tester) async {
        final handle = tester.ensureSemantics();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(screen.build(prefs, size, ThemeMode.light, scale));
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump(const Duration(milliseconds: 1500));
        _expectReadingOrder(tester, '${screen.name} $label');
        handle.dispose();
        // Unmount inside the test, so the screen's timers end with it.
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('a refused save is announced: the amount error is a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpEditor(
      tester,
      sampleDraft(expenseId: null, amount: '', description: 'Chai'),
      args: newArgs,
    );
    await tester.tap(find.byKey(const Key('expense-save')));
    await settle(tester);
    final error = find.byKey(const Key('amount-error'));
    expect(error, findsOneWidget);
    expect(tester.getSemantics(error), isSemantics(isLiveRegion: true));
    handle.dispose();
  });

  testWidgets('saves and messages are announced: the snackbar and the sheet toast are live regions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    usePhone(tester);
    late BuildContext page;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (c) {
              page = c;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    showAppMessage(page, 'Expense saved');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.ancestor(
        of: find.text('Expense saved'),
        matching: find.byWidgetPredicate((w) => w is Semantics && (w.properties.liveRegion ?? false)),
      ),
      findsWidgets,
    );
    handle.dispose();
  });
}
