// TC-13-01 (list + detail), TC-13-03 (delete with undo): the group's Expenses tab and the
// expense detail screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';
import 'package:splitify/ui/components/components.dart';

import '../expense_fixtures.dart';
import 'presentation_harness.dart';

class _ListHost extends StatelessWidget {
  const _ListHost();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(child: ExpenseList(groupId: gid)),
    ),
  );
}

/// Records delete / restore instead of touching the database.
class _RecordingActions extends ExpenseActions {
  _RecordingActions(super.ref);

  final calls = <String>[];

  @override
  Future<void> delete(LocalExpense e) async => calls.add('delete ${e.id}');

  @override
  Future<void> restore(LocalExpense e) async => calls.add('restore ${e.id}');
}

Future<void> _pumpList(
  WidgetTester t,
  AsyncValue<List<ExpenseView>> views, {
  GoRouter? router,
}) async {
  usePhone(t);
  await t.pumpWidget(const SizedBox());
  final r =
      router ??
      GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const _ListHost()),
          stubRoute('/expense/:id'),
          stubRoute('/expense/new'),
        ],
      );
  await t.pumpWidget(
    routerApp(r, overrides: [groupExpenseViewsProvider(gid).overrideWithValue(views)]),
  );
  await settle(t);
}

void main() {
  group('ExpenseList', () {
    // TC-13-01
    testWidgets('groups rows under month headers, newest first', (t) async {
      await _pumpList(t, AsyncData(sampleViews()));
      expect(find.text('NOVEMBER 2026'), findsOneWidget);
      expect(find.text('OCTOBER 2026'), findsOneWidget);
      expect(find.byType(AmountRow), findsNWidgets(4));
      expect(find.text('Cab to airport'), findsOneWidget);
      expect(find.text('Rahul Mehta paid ₹1,200 · 21 Nov'), findsOneWidget);
      expect(find.text('You and Asha Rao paid ₹18,000 · 25 Oct'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('shows what you lent, borrowed or were not involved in', (t) async {
      await _pumpList(t, AsyncData(sampleViews()));
      // e1: you paid 2,400 and owe 600; e4 (2 payers): you paid 9,000 and owe 4,500.
      expect(find.text('you lent'), findsNWidgets(2));
      expect(find.textContaining('₹1,800'), findsOneWidget);
      expect(find.textContaining('₹4,500'), findsOneWidget);
      // e2: Rahul paid 1,200, you owe 300.
      expect(find.text('you borrowed'), findsOneWidget);
      expect(find.textContaining('₹300'), findsOneWidget);
      // e3: Asha paid, Asha and Rahul owe.
      expect(find.text('not involved'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('an expense that nets to zero for you says no balance', (t) async {
      final even = sampleView(
        sampleExpense(total: 40000, payers: const {'m1': 40000}, shares: const {'m1': 40000}),
      );
      await _pumpList(t, AsyncData([even]));
      expect(find.text('no balance'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('only pending rows carry the not-synced marker', (t) async {
      await _pumpList(t, AsyncData(sampleViews()));
      expect(find.byType(SyncMarker), findsOneWidget);
    });

    // TC-13-01
    testWidgets('empty list shows the first-expense prompt; its button opens the editor', (
      t,
    ) async {
      await _pumpList(t, const AsyncData([]));
      expect(find.text('No expenses yet'), findsOneWidget);
      await tapKey(t, 'expenses-empty-add');
      expect(find.text('at /expense/new?group=$gid'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('a failed load says so, without rows', (t) async {
      await _pumpList(t, AsyncError(Exception('db'), StackTrace.empty));
      expect(find.text("Couldn't load expenses"), findsOneWidget);
      expect(find.byType(AmountRow), findsNothing);
    });

    // TC-13-01
    testWidgets('loading shows a skeleton', (t) async {
      final handle = t.ensureSemantics();
      await _pumpList(t, const AsyncLoading());
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      expect(find.byType(AmountRow), findsNothing);
      handle.dispose();
    });

    // TC-13-01
    testWidgets('tapping a row opens the expense', (t) async {
      await _pumpList(t, AsyncData(sampleViews()));
      await t.tap(find.byKey(const ValueKey('expense-e1')));
      await settle(t);
      expect(find.text('at /expense/e1'), findsOneWidget);
    });
  });

  group('ExpenseDetailScreen', () {
    List<Override> viewOverrides(AsyncValue<ExpenseView?> view, {String id = 'e1'}) => [
      expenseViewProvider(id).overrideWithValue(view),
      expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
    ];

    Future<_RecordingActions> pumpDetail(
      WidgetTester t,
      AsyncValue<ExpenseView?> view, {
      String id = 'e1',
      GoRouter? router,
    }) async {
      usePhone(t);
      await t.pumpWidget(const SizedBox());
      final r =
          router ??
          GoRouter(
            initialLocation: '/start',
            routes: [
              GoRoute(
                path: '/start',
                builder: (_, _) => PushHost(ExpenseDetailScreen(expenseId: id)),
              ),
              stubRoute('/expense/:id/edit'),
            ],
          );
      await t.pumpWidget(
        routerApp(
          r,
          overrides: [
            ...viewOverrides(view, id: id),
            expenseActionsProvider.overrideWith(_RecordingActions.new),
          ],
        ),
      );
      await tapKey(t, 'open');
      final container = ProviderScope.containerOf(t.element(find.byType(ExpenseDetailScreen)));
      return container.read(expenseActionsProvider) as _RecordingActions;
    }

    // TC-13-01
    testWidgets('shows the amount, who paid, the split, details and notes', (t) async {
      await pumpDetail(
        t,
        AsyncData(sampleView(sampleExpense(notes: 'Table by the window, paid by card.'))),
      );
      expect(find.text('Dinner at Thalassa'), findsOneWidget);
      expect(textOf(find.byKey(const Key('expense-detail-amount'))), '₹2,400.00');
      expect(find.text('You lent ₹1,800.00'), findsOneWidget);
      expect(find.text('PAID BY'), findsOneWidget);
      expect(find.text('SPLIT · EQUALLY'), findsOneWidget);
      expect(find.text('owes ₹600.00'), findsNWidgets(4));
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('Dining out'), findsOneWidget);
      expect(find.text('20 Nov 2026'), findsOneWidget);
      expect(find.text('Table by the window, paid by card.'), findsOneWidget);
      expect(find.text('Added by Mohit Bindal on 20 Nov 2026'), findsOneWidget);
      expect(find.text('Comments arrive in a later update.'), findsOneWidget);
      expect(find.byType(SyncMarker), findsNothing);
    });

    // TC-13-01
    testWidgets('several payers are listed, an unsynced expense is marked', (t) async {
      final beach = sampleViews()[3];
      await pumpDetail(t, AsyncData(beach), id: 'e4');
      expect(find.text('₹9,000.00'), findsNWidgets(2));
      await pumpDetail(t, AsyncData(sampleViews().first), id: 'e2');
      expect(find.byType(SyncMarker), findsOneWidget);
      expect(find.text('You borrowed ₹300.00'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('not involved and no balance have their own wording', (t) async {
      await pumpDetail(t, AsyncData(sampleViews()[2]), id: 'e3');
      expect(find.text("You're not involved"), findsOneWidget);
      expect(find.text('SPLIT · EXACT AMOUNTS'), findsOneWidget);
      await pumpDetail(
        t,
        AsyncData(
          sampleView(
            sampleExpense(total: 40000, payers: const {'m1': 40000}, shares: const {'m1': 40000}),
          ),
        ),
      );
      expect(find.text("You're even on this one"), findsOneWidget);
    });

    // TC-13-01
    testWidgets('the history row says coming soon', (t) async {
      await pumpDetail(t, AsyncData(sampleView(sampleExpense())));
      await tapKey(t, 'expense-history');
      expect(find.text('Coming soon'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('not found and loading states', (t) async {
      await pumpDetail(t, const AsyncData(null));
      expect(find.text("This expense isn't here"), findsOneWidget);
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.byType(ExpenseDetailScreen), findsNothing);

      await pumpDetail(t, const AsyncLoading());
      expect(find.byType(DotsPulse), findsOneWidget);
    });

    // TC-13-03
    testWidgets('delete soft-deletes, closes the screen and offers Undo', (t) async {
      final actions = await pumpDetail(t, AsyncData(sampleView(sampleExpense())));
      await tapKey(t, 'expense-delete');
      expect(actions.calls, ['delete e1']);
      expect(find.byType(ExpenseDetailScreen), findsNothing);
      expect(find.text('Expense deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      await t.tap(find.text('Undo'));
      await settle(t);
      expect(actions.calls, ['delete e1', 'restore e1']);
    });

    // TC-13-01
    testWidgets('the edit button opens the editor route', (t) async {
      await pumpDetail(t, AsyncData(sampleView(sampleExpense())));
      await tapKey(t, 'expense-edit');
      expect(find.text('at /expense/e1/edit'), findsOneWidget);
    });

    // TC-13-01
    testWidgets('the back button returns to the previous screen', (t) async {
      await pumpDetail(t, AsyncData(sampleView(sampleExpense())));
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.byType(ExpenseDetailScreen), findsNothing);
    });
  });
}
