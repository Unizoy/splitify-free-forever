// Shared helpers for the expense widget tests: an editor host with a handle on the fixed
// controller, and small finders.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../expense_fixtures.dart';

const ExpenseEditorArgs editArgs = (groupId: null, expenseId: 'e1');
const ExpenseEditorArgs newArgs = (groupId: gid, expenseId: null);

/// A 412 x 915 dp phone screen for this test.
void usePhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
}

/// Handle on the controller the editor screen is using.
class EditorHandle {
  FixedEditorController? controller;

  ExpenseDraft get draft => controller!.state.value!;
}

/// Home screen with one button that pushes [screen] (so the screen can pop like in the app).
class PushHost extends StatelessWidget {
  const PushHost(this.screen, {super.key});

  final Widget screen;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        key: const Key('open'),
        onPressed: () =>
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen)),
        child: const Text('open'),
      ),
    ),
  );
}

/// Opens the editor on [step] with [draft]; returns the controller handle.
Future<EditorHandle> pumpEditor(
  WidgetTester tester,
  ExpenseDraft draft, {
  EditorStep step = EditorStep.amount,
  ExpenseEditorArgs args = editArgs,
  List<Override> overrides = const [],
  FixedEditorController Function(ExpenseEditorArgs args, ExpenseDraft draft)? make,
}) async {
  usePhone(tester);
  await tester.pumpWidget(const SizedBox());
  final handle = EditorHandle();
  final editor = args.expenseId == null
      ? ExpenseEditorScreen(groupId: args.groupId, initialStep: step)
      : ExpenseEditorScreen(expenseId: args.expenseId, initialStep: step);
  // [overrides] apply to the editor route only (the app scope already has the base overrides).
  final screen = overrides.isEmpty ? editor : ProviderScope(overrides: overrides, child: editor);
  await tester.pumpWidget(
    expenseApp(
      PushHost(screen),
      overrides: [
        expenseEditorProvider(args).overrideWith(() {
          final c = (make ?? FixedEditorController.new)(args, draft);
          handle.controller = c;
          return c;
        }),
      ],
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await settle(tester);
  return handle;
}

/// Pumps frames until transitions and state changes are done (never `pumpAndSettle`: the
/// screens have endless animations).
Future<void> settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await reveal(tester, f);
  await tester.tap(f);
  await settle(tester);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await settle(tester);
}

String footerText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('split-footer'))).data!;

bool buttonEnabled(WidgetTester tester, String key) =>
    tester.widget<PillButton>(find.byKey(Key(key))).onPressed != null;

Finder fieldIn(String key) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));

String? textOf(Finder f) => (f.evaluate().single.widget as Text).data;

/// The StepHeader label of step [name].
Finder stepLabel(String name) =>
    find.descendant(of: find.byType(StepHeader), matching: find.text(name));

/// Scrolls the first scrollable until [finder] is built and visible.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.pump();
}

/// Like expenseApp but driven by a [GoRouter]; the router is built inside [build] so each test
/// gets its own.
Widget routerApp(GoRouter router, {List<Override> overrides = const []}) => ProviderScope(
  overrides: [...baseOverrides(), ...overrides],
  child: MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light(),
    debugShowCheckedModeBanner: false,
  ),
);

/// A route that just prints where it is.
GoRoute stubRoute(String path) => GoRoute(
  path: path,
  builder: (context, state) => Scaffold(
    body: Center(child: Text('at ${state.uri}', key: const Key('stub'))),
  ),
);

/// Taps a segment of the split-kind pill by its symbol (`=`, `1.23`, `%`, `1:2`, `±`).
Future<void> tapKind(WidgetTester tester, String symbol) async {
  await tester.tap(
    find.descendant(of: find.byKey(const Key('split-kind')), matching: find.text(symbol)),
  );
  await settle(tester);
}
