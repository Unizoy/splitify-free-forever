// #12 recurring bills on the expense detail and the list: the "Repeats" row and sheet, the copy pill
// and line, Stop / Repeat again, deleting the expense a repeat started from, the list chip.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/domain/rules/recurrence.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';
import 'package:splitify/features/groups/application/groups_providers.dart' as groups;
import 'package:splitify/ui/components/components.dart';

import '../../data/sync/sync_fakes.dart' show FakeRemoteApi;
import '../../support/fakes.dart' show testDb;
import '../expenses/expense_fixtures.dart';
import '../expenses/presentation/presentation_harness.dart';

/// Records delete instead of touching the expense (the template side is the real repository).
class _RecordingActions extends ExpenseActions {
  _RecordingActions(super.ref);

  final calls = <String>[];

  @override
  Future<void> delete(LocalExpense e) async => calls.add('delete ${e.id}');

  @override
  Future<void> restore(LocalExpense e) async => calls.add('restore ${e.id}');
}

class _Screen {
  _Screen(this.db, this.container, this.router);

  final AppDatabase db;
  final ProviderContainer container;
  final GoRouter router;

  _RecordingActions get actions => container.read(expenseActionsProvider) as _RecordingActions;
}

LocalExpense _copy() => sampleExpense(
  id: 'c1',
  description: 'Rent',
  date: '2026-12-20',
).copyWith(source: 'recurring', recurringId: const Value('t1'));

Future<_Screen> _pump(
  WidgetTester t,
  LocalExpense expense, {
  bool seed = true,
  Future<void> Function(ProviderContainer c, AppDatabase db)? prepare,
  bool archived = false,
}) async {
  usePhone(t);
  final db = testDb();
  final group = archived
      ? sampleGroup().copyWith(archivedAt: const Value('2026-11-01T00:00:00Z'))
      : sampleGroup();
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (_, _) => PushHost(ExpenseDetailScreen(expenseId: expense.id)),
      ),
      stubRoute('/expense/:id/edit'),
      stubRoute('/expense/:id/history'),
      stubRoute('/recurring/:id/edit'),
    ],
  );
  final List<Override> overrides = [
    appDatabaseProvider.overrideWithValue(db),
    remoteApiProvider.overrideWithValue(FakeRemoteApi()),
    groups.currentUserIdProvider.overrideWithValue('u1'),
    expenseViewProvider(expense.id).overrideWithValue(AsyncData(sampleView(expense))),
    expenseGroupProvider(gid).overrideWith((ref) => Stream.value(group)),
    commentThreadProvider((groupId: gid, targetType: 'expense', targetId: expense.id))
        .overrideWithValue(const AsyncData([])),
    expenseActionsProvider.overrideWith(_RecordingActions.new),
  ];
  await t.pumpWidget(routerApp(router, overrides: overrides));
  await settle(t, 2);
  final container = ProviderScope.containerOf(t.element(find.byType(PushHost)));
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await t.runAsync(db.close);
  });
  if (seed) {
    await t.runAsync(() async {
      await container
          .read(recurringRepositoryProvider)
          .create(
            groupId: gid,
            expenseId: 'e1',
            rule: Recurrence(
              interval: RecurrenceInterval.monthly,
              anchor: DateTime.utc(2026, 11, 20),
              endsOn: DateTime.utc(2027, 1, 31),
            ),
            template: {'description': 'Rent', 'total': 240000},
          );
      // The copy's template id is fixed so the tests can name it.
      await db.customStatement("UPDATE recurring_templates SET id = 't1'");
    });
  }
  if (prepare != null) await t.runAsync(() => prepare(container, db));
  await tapKey(t, 'open');
  await settleReal(t);
  return _Screen(db, container, router);
}

Future<void> settleReal(WidgetTester t, [int rounds = 2]) async {
  for (var i = 0; i < rounds; i++) {
    await settle(t, 2);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await settle(t);
}

Future<LocalRecurring> _template(WidgetTester t, AppDatabase db) async =>
    (await t.runAsync(() => db.select(db.recurringTemplates).getSingle()))!;

Future<void> _openSheet(WidgetTester t) async {
  await reveal(t, find.byKey(const Key('expense-recurring')));
  await t.tap(find.byKey(const Key('expense-recurring')));
  await settleReal(t, 4);
}

void main() {
  group('Repeats row and sheet', () {
    testWidgets('the expense a repeat started from shows Repeats · Every month', (t) async {
      await _pump(t, sampleExpense());
      await reveal(t, find.byKey(const Key('expense-recurring')));
      expect(find.text('Repeats'), findsOneWidget);
      expect(find.text('Every month'), findsOneWidget);
      // Not a copy: no pill and no line.
      expect(find.byKey(const Key('expense-recurring-pill')), findsNothing);
      expect(find.byKey(const Key('expense-recurring-line')), findsNothing);
    });

    testWidgets('an expense that does not repeat has no Repeats row', (t) async {
      await _pump(t, sampleExpense(), seed: false);
      expect(find.byKey(const Key('expense-recurring')), findsNothing);
    });

    testWidgets('the sheet shows the next copy, the end date, the pending marker and buttons', (
      t,
    ) async {
      await _pump(t, sampleExpense());
      await _openSheet(t);
      expect(find.text('Next copy on 20 Dec 2026'), findsOneWidget);
      expect(find.text('Ends on 31 Jan 2027'), findsOneWidget);
      expect(find.byType(SyncMarker), findsWidgets);
      expect(find.byKey(const Key('recurring-edit-future')), findsOneWidget);
      expect(find.byKey(const Key('recurring-stop')), findsOneWidget);
      expect(find.byKey(const Key('recurring-resume')), findsNothing);
    });

    testWidgets('no end date says so; a synced template has no pending marker', (t) async {
      await _pump(
        t,
        sampleExpense(),
        prepare: (c, db) => db.customStatement(
          "UPDATE recurring_templates SET ends_on = NULL, sync_state = 'synced'",
        ),
      );
      await _openSheet(t);
      expect(find.text('No end date'), findsOneWidget);
      expect(find.text('Next copy on 20 Dec 2026'), findsOneWidget);
      expect(find.byType(SyncMarker), findsNothing);
    });

    testWidgets('a template with no copies left says "No more copies"', (t) async {
      await _pump(
        t,
        sampleExpense(),
        prepare: (c, db) => db.customStatement('UPDATE recurring_templates SET next_date = NULL'),
      );
      await reveal(t, find.byKey(const Key('expense-recurring')));
      expect(find.text('No more copies'), findsOneWidget);
      await _openSheet(t);
      expect(find.text('No more copies'), findsWidgets);
    });

    testWidgets('read-only (archived group) shows the rule without buttons', (t) async {
      await _pump(t, sampleExpense(), archived: true);
      await _openSheet(t);
      expect(find.text('Next copy on 20 Dec 2026'), findsOneWidget);
      expect(find.byKey(const Key('recurring-edit-future')), findsNothing);
      expect(find.byKey(const Key('recurring-stop')), findsNothing);
      expect(find.byKey(const Key('recurring-resume')), findsNothing);
    });

    testWidgets('Edit future copies opens the template editor route', (t) async {
      await _pump(t, sampleExpense());
      await _openSheet(t);
      await tapKey(t, 'recurring-edit-future');
      expect(find.text('at /recurring/t1/edit'), findsOneWidget);
    });
  });

  group('copy made by a repeat', () {
    testWidgets('shows the Repeats pill, the explanation line and the Repeats row', (t) async {
      await _pump(t, _copy());
      expect(find.byKey(const Key('expense-recurring-pill')), findsOneWidget);
      expect(find.text('Repeats'), findsWidgets);
      await reveal(t, find.byKey(const Key('expense-recurring-line')));
      expect(find.text('Added automatically from a repeating expense'), findsOneWidget);
      expect(find.byKey(const Key('expense-recurring')), findsOneWidget);
      expect(find.text('Every month'), findsOneWidget);
    });
  });

  group('Stop and Repeat again', () {
    testWidgets('Stop repeating asks first; Keep repeating changes nothing', (t) async {
      final s = await _pump(t, sampleExpense());
      await _openSheet(t);
      await tapKey(t, 'recurring-stop');
      await settleReal(t);
      expect(find.byKey(const Key('confirm-action')), findsOneWidget);
      expect(find.text('Stop repeating “Rent”?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await settleReal(t);
      expect((await _template(t, s.db)).active, isTrue);
    });

    testWidgets('confirming stops the template through the outbox and says so', (t) async {
      final s = await _pump(t, sampleExpense());
      await _openSheet(t);
      await tapKey(t, 'recurring-stop');
      await settleReal(t);
      await t.tap(find.byKey(const Key('confirm-action')));
      await settleReal(t, 4);
      expect((await _template(t, s.db)).active, isFalse);
      expect(find.text('Stopped repeating'), findsOneWidget);
      await reveal(t, find.byKey(const Key('expense-recurring')));
      expect(find.text('Stopped'), findsOneWidget);
    });

    testWidgets('a stopped template offers only Repeat again, which restarts it', (t) async {
      final s = await _pump(
        t,
        sampleExpense(),
        prepare: (c, db) async {
          final t0 = await db.select(db.recurringTemplates).getSingle();
          await c.read(recurringRepositoryProvider).stop(t0);
        },
      );
      await _openSheet(t);
      expect(find.text('Stopped repeating. Copies already added stay.'), findsOneWidget);
      expect(find.byKey(const Key('recurring-stop')), findsNothing);
      expect(find.byKey(const Key('recurring-edit-future')), findsNothing);
      await tapKey(t, 'recurring-resume');
      await settleReal(t, 4);
      final row = await _template(t, s.db);
      expect(row.active, isTrue);
      expect(row.nextDate!.substring(0, 10), '2026-12-20');
      expect(find.text('Repeats again from today'), findsOneWidget);
    });
  });

  group('deleting the expense a repeat started from', () {
    testWidgets('also stops the repeat and tells the user', (t) async {
      final s = await _pump(t, sampleExpense());
      await tapKey(t, 'expense-delete');
      await settleReal(t, 4);
      expect(s.actions.calls, ['delete e1']);
      expect((await _template(t, s.db)).active, isFalse);
      expect(find.text('Deleted. It won’t repeat any more.'), findsOneWidget);
    });

    testWidgets('deleting a copy leaves the repeat running', (t) async {
      final s = await _pump(t, _copy());
      await tapKey(t, 'expense-delete');
      await settleReal(t, 4);
      expect(s.actions.calls, ['delete c1']);
      expect((await _template(t, s.db)).active, isTrue);
      expect(find.text('Expense deleted'), findsOneWidget);
      expect(find.text('Deleted. It won’t repeat any more.'), findsNothing);
    });
  });

  group('expense list', () {
    testWidgets('copies get a Repeats chip, other rows do not', (t) async {
      usePhone(t);
      final copy = sampleView(
        sampleExpense(
          id: 'c9',
          description: 'Rent',
          date: '2026-11-19',
        ).copyWith(source: 'recurring'),
      );
      await t.pumpWidget(
        routerApp(
          GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(
                  body: SingleChildScrollView(child: ExpenseList(groupId: gid)),
                ),
              ),
              stubRoute('/expense/:id'),
            ],
          ),
          overrides: [
            groupExpenseViewsProvider(gid)
                .overrideWithValue(AsyncData([copy, sampleView(sampleExpense())])),
          ],
        ),
      );
      await settle(t);
      expect(find.byKey(const ValueKey('recurring-chip-c9')), findsOneWidget);
      expect(find.byKey(const ValueKey('recurring-chip-e1')), findsNothing);
    });
  });
}
