// TC-35-02 (default split sheet, D-033: a sheet from group settings, no page) and the expense routes /
// "+" entry point.
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:splitify/data/repositories/repositories.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/expenses/application/default_split_controller.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/default_split_sheet.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';

import '../expense_fixtures.dart';
import 'presentation_harness.dart';

class _MissingDefault extends FixedDefaultSplitController {
  _MissingDefault(super.groupId, super.initial);

  @override
  Future<DefaultSplitState> build() async => throw const ExpenseNotFound();
}

class _RefusingDefault extends FixedDefaultSplitController {
  _RefusingDefault(super.groupId, super.initial);

  @override
  Future<bool> save() async {
    saves++;
    return false;
  }
}

/// A groups repository that only knows `watchAll`.
class _FakeGroups implements GroupsRepository {
  _FakeGroups(this.groups);

  final List<LocalGroup> groups;

  @override
  Stream<List<LocalGroup>> watchAll() => Stream.value(groups);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DefaultSplitState _state({SplitKind kind = SplitKind.percent, Map<String, int>? values}) {
  final base = SplitDraft.initial(ids, 2);
  return DefaultSplitState(
    groupName: 'Goa trip',
    members: people,
    split: switch (kind) {
      SplitKind.percent => base.withValues(
        SplitKind.percent,
        values ?? {'m1': 4000, 'm2': 4000, 'm3': 1000, 'm4': 500},
      ),
      _ => base,
    },
  );
}

void main() {
  group('Default split sheet', () {
    late FixedDefaultSplitController controller;

    Future<void> pumpScreen(
      WidgetTester t,
      DefaultSplitState state, {
      FixedDefaultSplitController Function(String, DefaultSplitState)? make,
    }) async {
      usePhone(t);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        expenseApp(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  key: const Key('open'),
                  onPressed: () => showDefaultSplitSheet(context, gid),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          overrides: [
            defaultSplitProvider(gid).overrideWith(() {
              controller = (make ?? FixedDefaultSplitController.new)(gid, state);
              return controller;
            }),
          ],
        ),
      );
      await tapKey(t, 'open');
    }

    // TC-35-02
    testWidgets('shows the saved split; Save waits until the percentages reach 100 %', (t) async {
      await pumpScreen(t, _state());
      expect(find.byKey(const Key('default-split-sheet')), findsOneWidget);
      expect(find.text('Default split'), findsOneWidget);
      expect(find.textContaining('start with this split'), findsOneWidget);
      expect(t.widget<TextField>(fieldIn('percent-m1')).controller!.text, '40');
      expect(t.widget<TextField>(fieldIn('percent-m4')).controller!.text, '5');
      expect(footerText(t), '95% of 100%\u00A0· 5% left');
      expect(buttonEnabled(t, 'default-split-save'), isFalse);

      await t.enterText(fieldIn('percent-m4'), '10');
      await settle(t);
      expect(footerText(t), '100%\u00A0· done');
      expect(buttonEnabled(t, 'default-split-save'), isTrue);
    });

    // TC-35-02
    testWidgets('Save stores the split, shows "Default split saved" and closes', (t) async {
      await pumpScreen(t, _state(values: {'m1': 4000, 'm2': 4000, 'm3': 1000, 'm4': 1000}));
      await tapKey(t, 'default-split-save');
      expect(controller.saves, 1);
      await settle(t);
      expect(find.byType(DefaultSplitSheet), findsNothing);
      expect(find.text('Default split saved'), findsOneWidget);
    });

    // TC-35-02
    testWidgets('a save that fails keeps the sheet open', (t) async {
      await pumpScreen(
        t,
        _state(values: {'m1': 4000, 'm2': 4000, 'm3': 1000, 'm4': 1000}),
        make: _RefusingDefault.new,
      );
      await tapKey(t, 'default-split-save');
      expect(controller.saves, 1);
      expect(find.byType(DefaultSplitSheet), findsOneWidget);
      expect(find.text('Default split saved'), findsNothing);
    });

    // TC-35-02
    testWidgets('only equal, percent and shares are offered; switching works', (t) async {
      await pumpScreen(t, _state());
      Finder segment(String s) =>
          find.descendant(of: find.byKey(const Key('split-kind')), matching: find.text(s));
      expect(segment('='), findsOneWidget);
      expect(segment('%'), findsOneWidget);
      expect(segment('1:2'), findsOneWidget);
      expect(find.text('1.23'), findsNothing);
      expect(find.text('±'), findsNothing);

      await tapKind(t, '1:2');
      expect(footerText(t), '4 shares in total');
      expect(buttonEnabled(t, 'default-split-save'), isTrue);

      await tapKind(t, '=');
      // Equal means everyone: no ticks to change.
      expect(footerText(t), '4 people');
      expect(find.byKey(const ValueKey('tick-m1')), findsNothing);
      expect(buttonEnabled(t, 'default-split-save'), isTrue);

      await tapKind(t, '%');
      expect(footerText(t), '100%\u00A0· done');
    });

    // TC-35-02
    testWidgets('shares at zero for everyone cannot be saved', (t) async {
      await pumpScreen(t, _state(kind: SplitKind.equal));
      await tapKind(t, '1:2');
      for (final id in ids) {
        final minus = find.descendant(
          of: find.byKey(ValueKey('shares-$id')),
          matching: find.byTooltip('Decrease'),
        );
        await reveal(t, minus);
        await t.tap(minus);
        await t.pump();
      }
      await settle(t);
      expect(footerText(t), 'Give someone at least one share');
      expect(buttonEnabled(t, 'default-split-save'), isFalse);
    });

    // TC-35-02
    testWidgets('a missing group says so; Back closes the sheet and keeps the saved split', (
      t,
    ) async {
      await pumpScreen(t, _state(), make: _MissingDefault.new);
      expect(find.text("Couldn't load expenses"), findsOneWidget);
      await t.binding.handlePopRoute();
      await settle(t);
      expect(find.byType(DefaultSplitSheet), findsNothing);
    });

    // TC-35-02
    testWidgets('percentages use the number keyboard inside the sheet; nothing overflows', (
      t,
    ) async {
      await pumpScreen(t, _state());
      await t.tap(fieldIn('percent-m4'));
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(t.view.resetViewInsets);
      await settle(t);
      expect(t.takeException(), isNull);
      await t.enterText(fieldIn('percent-m4'), '10');
      await settle(t);
      expect(buttonEnabled(t, 'default-split-save'), isTrue);
    });
  });

  group('routes', () {
    test('path helpers', () {
      expect(ExpenseRoutes.add('g1'), '/expense/new?group=g1');
      expect(ExpenseRoutes.detail('e1'), '/expense/e1');
      expect(ExpenseRoutes.edit('e1'), '/expense/e1/edit');
    });

    List<Override> screens() => [
      expenseEditorProvider(newArgs).overrideWith(
        () => FixedEditorController(
          newArgs,
          sampleDraft(amount: '', description: '', expenseId: null),
        ),
      ),
      expenseEditorProvider(editArgs)
          .overrideWith(() => FixedEditorController(editArgs, sampleDraft())),
      expenseViewProvider('e1').overrideWithValue(AsyncData(sampleView(sampleExpense()))),
      expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
      defaultSplitProvider(gid).overrideWith(() => FixedDefaultSplitController(gid, _state())),
    ];

    Future<GoRouter> open(WidgetTester t, String location) async {
      usePhone(t);
      final router = GoRouter(
        initialLocation: location,
        routes: [stubRoute('/groups'), ...expenseRoutes()],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(routerApp(router, overrides: screens()));
      await settle(t);
      return router;
    }

    // TC-13-01
    testWidgets('/expense/new?group= opens the add editor for that group', (t) async {
      await open(t, ExpenseRoutes.add(gid));
      expect(find.byType(ExpenseEditorScreen), findsOneWidget);
      expect(find.text('Add expense'), findsOneWidget);
      expect(find.text('Goa trip'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('/expense/:id opens the detail, /expense/:id/edit the editor', (t) async {
      final router = await open(t, ExpenseRoutes.detail('e1'));
      expect(find.byType(ExpenseDetailScreen), findsOneWidget);
      await tapKey(t, 'expense-edit');
      expect(find.byType(ExpenseEditorScreen), findsOneWidget);
      expect(find.text('Edit expense'), findsWidgets);
      expect(router.state.uri.path, '/expense/e1/edit');
    });

    // TC-13-01
    testWidgets('closing or leaving an editor that has nothing to go back to opens Groups', (
      t,
    ) async {
      final router = await open(t, ExpenseRoutes.add(gid));
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(router.state.uri.path, '/groups');
      expect(find.text('at /groups'), findsOneWidget);
    });
  });

  group('startAddExpense', () {
    LocalGroup group(String id, {bool archived = false}) => sampleGroup().copyWith(
      id: id,
      name: 'Group $id',
      archivedAt: Value(archived ? '2026-01-01' : null),
    );

    Future<GoRouter> pump(WidgetTester t, List<LocalGroup> groups) async {
      usePhone(t);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    key: const Key('plus'),
                    onPressed: () => startAddExpense(context),
                    child: const Text('+'),
                  ),
                ),
              ),
            ),
          ),
          stubRoute('/expense/new'),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(
        routerApp(
          router,
          overrides: [groupsRepositoryProvider.overrideWithValue(_FakeGroups(groups))],
        ),
      );
      await tapKey(t, 'plus');
      return router;
    }

    // TC-13-01
    testWidgets('no group yet: asks to create one first', (t) async {
      await pump(t, []);
      expect(find.text('Create a group first, then add expenses to it.'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('archived groups do not count', (t) async {
      await pump(t, [group('g1', archived: true)]);
      expect(find.text('Create a group first, then add expenses to it.'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('one group: goes straight to its editor', (t) async {
      await pump(t, [group('g1'), group('g0', archived: true)]);
      expect(find.text('at /expense/new?group=g1'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('several groups: asks which one', (t) async {
      await pump(t, [group('g1'), group('g2'), group('g3', archived: true)]);
      expect(find.text('Add to which group?'), findsOneWidget);
      expect(find.byKey(const Key('pick-group-g1')), findsOneWidget);
      expect(find.byKey(const Key('pick-group-g3')), findsNothing);
      await tapKey(t, 'pick-group-g2');
      await settle(t);
      expect(find.text('at /expense/new?group=g2'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('dismissing the group sheet adds nothing', (t) async {
      await pump(t, [group('g1'), group('g2')]);
      await t.tapAt(const Offset(200, 40));
      await settle(t);
      expect(find.text('Add to which group?'), findsNothing);
      expect(find.textContaining('at /expense/new'), findsNothing);
    });
  });
}
