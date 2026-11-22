// TC-20-03: the edit-history timeline (expense and payment), its pending / offline / empty / not-found states.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/history/application/history_providers.dart';
import 'package:splitify/features/history/presentation/history_screen.dart';
import 'package:splitify/ui/components/components.dart';

import '../../expenses/expense_fixtures.dart';
import '../../expenses/presentation/presentation_harness.dart';
import 'history_fixtures.dart';

/// Opens [HistoryScreen] on a tall phone so the whole timeline is built.
Future<void> _pump(
  WidgetTester t,
  AsyncValue<HistoryView?> view, {
  HistoryTarget target = expenseTarget,
  Future<int> Function()? fetch,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(412, 3000);
  addTearDown(t.view.reset);
  await t.pumpWidget(const SizedBox());
  final overrides = <Override>[
    historyViewProvider(target).overrideWithValue(view),
    historyFetchProvider(target).overrideWith((ref) => (fetch ?? () async => 0)()),
  ];
  await t.pumpWidget(
    expenseApp(
      HistoryScreen(target: target),
      overrides: overrides,
      size: const Size(412, 3000),
    ),
  );
  await settle(t);
}

void main() {
  group('HistoryScreen expense', () {
    // TC-20-03
    testWidgets('lists every version newest first with who did what', (t) async {
      await _pump(t, AsyncData(historyView(versions: fullExpenseVersions())));
      expect(find.text('Edit history'), findsOneWidget);
      expect(find.text('Dinner at Thalassa\u00A0· ₹2,400.00'), findsOneWidget);
      expect(find.text("Rahul Mehta's edit"), findsOneWidget);
      expect(find.text('Asha Rao restored this'), findsOneWidget);
      expect(find.text('You deleted this'), findsOneWidget);
      expect(find.text('Asha Rao edited this'), findsOneWidget);
      expect(find.text('You added this'), findsOneWidget);
      // Newest first: the conflict entry sits above the creation.
      expect(
        t.getTopLeft(find.byKey(const Key('history-entry-5'))).dy,
        lessThan(t.getTopLeft(find.byKey(const Key('history-entry-1'))).dy),
      );
      expect(find.byKey(const Key('history-pending')), findsNothing);
      expect(find.byKey(const Key('history-offline-note')), findsNothing);
    });

    // TC-20-03
    testWidgets('an edit shows old and new values per field, per member for the split', (t) async {
      await _pump(t, AsyncData(historyView(versions: fullExpenseVersions())));
      final edit = find.byKey(const Key('history-entry-2'));
      Finder within(Finder f) => find.descendant(of: edit, matching: f);
      expect(within(find.text('AMOUNT')), findsOneWidget);
      expect(within(find.textContaining('₹2,400.00')), findsWidgets); // amount + paid by
      expect(within(find.textContaining('₹2,000.00')), findsWidgets);
      expect(within(find.textContaining('Dinner at Thalassa (4 people)')), findsOneWidget);
      expect(within(find.text('SPLIT')), findsOneWidget);
      // My share went 600 -> 800, the others 600 -> 400.
      expect(within(find.text('You')), findsWidgets);
      expect(within(find.text('Asha Rao')), findsWidgets);
      expect(within(find.textContaining('₹800.00')), findsOneWidget);
      expect(within(find.textContaining('₹400.00')), findsNWidgets(3));
      expect(within(find.text('SPLIT TYPE')), findsOneWidget);
      expect(within(find.textContaining('Exact amounts')), findsOneWidget);
      // The first version lists what was filled in, with no old values.
      final first = find.byKey(const Key('history-entry-1'));
      expect(find.descendant(of: first, matching: find.textContaining('₹2,400.00')), findsWidgets);
      expect(find.descendant(of: first, matching: find.text('DESCRIPTION')), findsOneWidget);
    });

    // TC-20-03
    testWidgets('a version that lost a conflict is labelled "Not applied (a newer edit won)"', (
      t,
    ) async {
      await _pump(t, AsyncData(historyView(versions: fullExpenseVersions())));
      final lost = find.byKey(const Key('history-entry-5'));
      expect(
        find.descendant(of: lost, matching: find.text('Not applied (a newer edit won)')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('history-not-applied')), findsOneWidget);
      // Its change is still listed (against the applied version, not against itself).
      expect(find.descendant(of: lost, matching: find.textContaining('₹1,800.00')), findsWidgets);
    });

    // TC-20-03
    testWidgets('a change row is read out as "field: old to new"', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, AsyncData(historyView(versions: fullExpenseVersions())));
      expect(find.bySemanticsLabel('Amount: ₹2,400.00 to ₹2,000.00'), findsOneWidget);
      handle.dispose();
    });

    // TC-20-03
    testWidgets('a record with unsynced changes says so', (t) async {
      await _pump(
        t,
        AsyncData(historyView(versions: [expenseVersion(1, 'insert')], pending: true)),
      );
      expect(find.byKey(const Key('history-pending')), findsOneWidget);
      expect(find.text("Your latest change shows here once it's synced."), findsOneWidget);
      expect(find.byType(SyncMarker), findsOneWidget);
    });

    // TC-20-03
    testWidgets('a failed refresh with saved entries keeps them and adds the offline note', (
      t,
    ) async {
      await _pump(
        t,
        AsyncData(historyView(versions: fullExpenseVersions())),
        fetch: () async => throw Exception('offline'),
      );
      expect(find.byKey(const Key('history-offline-note')), findsOneWidget);
      expect(find.text('Showing saved history. Connect to see newer changes.'), findsOneWidget);
      expect(find.byKey(const Key('history-offline')), findsNothing);
      expect(find.text('You added this'), findsOneWidget);
    });

    // TC-20-03
    testWidgets('offline with nothing saved shows the state, and Try again re-runs the fetch', (
      t,
    ) async {
      var calls = 0;
      await _pump(
        t,
        AsyncData(historyView()),
        fetch: () async {
          calls++;
          if (calls == 1) throw Exception('offline');
          return 0;
        },
      );
      expect(calls, 1);
      expect(find.byKey(const Key('history-offline')), findsOneWidget);
      expect(find.text('History needs internet'), findsOneWidget);
      expect(find.byKey(const Key('history-empty')), findsNothing);

      await tapKey(t, 'history-retry');
      expect(calls, 2);
      expect(find.byKey(const Key('history-offline')), findsNothing);
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
    });

    // TC-20-03
    testWidgets('online with no versions yet shows the empty state', (t) async {
      await _pump(t, AsyncData(historyView()));
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
      expect(find.text('No history yet'), findsOneWidget);
    });

    // TC-20-03
    testWidgets('a pending record with no versions shows both the note and the empty state', (
      t,
    ) async {
      await _pump(t, AsyncData(historyView(pending: true)));
      expect(find.byKey(const Key('history-pending')), findsOneWidget);
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
    });

    // TC-20-03
    testWidgets('a record that is not on this phone says so', (t) async {
      await _pump(t, const AsyncData(null));
      expect(find.text("This item isn't on this phone"), findsOneWidget);
      expect(find.text('Edit history'), findsNothing);
    });

    // TC-20-03
    testWidgets('loading shows the pulse and a back arrow', (t) async {
      await _pump(t, const AsyncLoading());
      expect(find.byType(DotsPulse), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
    });

    // TC-20-03
    testWidgets('an unknown editor reads "A former member"', (t) async {
      final v = historyView(versions: [expenseVersion(1, 'insert', by: 'u9')]);
      await _pump(t, AsyncData(v));
      expect(find.text('A former member added this'), findsOneWidget);
    });
  });

  group('HistoryScreen payment', () {
    // TC-20-03
    testWidgets('names who paid whom and shows method and amount edits', (t) async {
      await _pump(
        t,
        AsyncData(historyView(target: paymentTarget, versions: paymentVersions())),
        target: paymentTarget,
      );
      expect(find.text('Rahul Mehta paid Asha Rao\u00A0· ₹600.00'), findsOneWidget);
      expect(find.text('Asha Rao edited this'), findsOneWidget);
      expect(find.text('Rahul Mehta added this'), findsOneWidget);
      final edit = find.byKey(const Key('history-entry-2'));
      expect(find.descendant(of: edit, matching: find.text('PAID WITH')), findsOneWidget);
      expect(find.descendant(of: edit, matching: find.textContaining('Cash')), findsOneWidget);
      expect(find.descendant(of: edit, matching: find.textContaining('UPI')), findsOneWidget);
      expect(find.descendant(of: edit, matching: find.textContaining('₹500.00')), findsOneWidget);
      expect(find.descendant(of: edit, matching: find.textContaining('₹600.00')), findsOneWidget);
    });
  });
}
