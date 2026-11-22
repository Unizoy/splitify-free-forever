// TC-20-04: the group's deleted items (restore for any member, offline-capable, disabled when archived).
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/history/application/deleted_items_providers.dart';
import 'package:splitify/features/history/presentation/deleted_items_screen.dart';
import 'package:splitify/ui/components/components.dart';

import '../../expenses/expense_fixtures.dart';
import '../../expenses/presentation/presentation_harness.dart';
import 'history_fixtures.dart';

/// Records restores instead of touching the database.
class _RecordingActions extends DeletedItemActions {
  _RecordingActions(super.ref);

  final restored = <String>[];

  @override
  Future<void> restore(DeletedItem item) async => restored.add(item.id);
}

const _none = AsyncData<DeletedItemsView>((items: [], memberNames: {}, meMemberId: null));

Future<_RecordingActions> _pump(
  WidgetTester t,
  AsyncValue<DeletedItemsView> view, {
  bool archived = false,
  double scale = 1,
}) async {
  usePhone(t);
  await t.pumpWidget(const SizedBox());
  final group = archived
      ? sampleGroup().copyWith(archivedAt: const Value('2026-11-20T00:00:00Z'))
      : sampleGroup();
  final overrides = <Override>[
    deletedItemsProvider(gid).overrideWithValue(view),
    groupProvider(gid).overrideWith((ref) => Stream.value(group)),
    deletedItemActionsProvider.overrideWith(_RecordingActions.new),
  ];
  await t.pumpWidget(
    expenseApp(
      const DeletedItemsScreen(groupId: gid),
      overrides: overrides,
      scale: scale,
    ),
  );
  await settle(t);
  final container = ProviderScope.containerOf(t.element(find.byType(DeletedItemsScreen)));
  return container.read(deletedItemActionsProvider) as _RecordingActions;
}

void main() {
  // TC-20-04
  testWidgets('lists deleted expenses and payments, newest delete first', (t) async {
    await _pump(t, AsyncData(sampleDeleted()));
    expect(find.text('Deleted items'), findsOneWidget);
    expect(find.text('Rahul Mehta paid Asha Rao'), findsOneWidget);
    expect(find.text('Dinner at Thalassa'), findsOneWidget);
    expect(find.text('₹2,400.00'), findsOneWidget);
    expect(find.text('₹600.00'), findsOneWidget);
    expect(find.text('Deleted by Asha Rao\u00A0· 20\u00A0Nov\u00A02026'), findsOneWidget);
    expect(find.text('Deleted by you\u00A0· 21\u00A0Nov\u00A02026'), findsOneWidget);
    // The payment was deleted last, so it comes first.
    expect(
      t.getTopLeft(find.byKey(const Key('restore-p1'))).dy,
      lessThan(t.getTopLeft(find.byKey(const Key('restore-e1'))).dy),
    );
    // Only the unsynced (payment) delete carries the marker.
    expect(find.byType(SyncMarker), findsOneWidget);
    expect(find.byKey(const Key('deleted-empty')), findsNothing);
    expect(find.byKey(const Key('deleted-archived-note')), findsNothing);
  });

  // TC-20-04
  testWidgets('Restore hands the item to the actions and confirms', (t) async {
    final actions = await _pump(t, AsyncData(sampleDeleted()));
    await tapKey(t, 'restore-e1');
    expect(actions.restored, ['e1']);
    expect(find.text('Restored'), findsOneWidget);
    await tapKey(t, 'restore-p1');
    expect(actions.restored, ['e1', 'p1']);
  });

  // TC-20-04
  testWidgets('nothing deleted shows the empty state', (t) async {
    await _pump(t, _none);
    expect(find.byKey(const Key('deleted-empty')), findsOneWidget);
    expect(find.text('Nothing deleted'), findsOneWidget);
    expect(find.byType(PillButton), findsNothing);
  });

  // TC-20-04
  testWidgets('an archived group shows the note and disables Restore', (t) async {
    final actions = await _pump(t, AsyncData(sampleDeleted()), archived: true);
    expect(find.byKey(const Key('deleted-archived-note')), findsOneWidget);
    expect(find.text('Unarchive the group to restore items.'), findsOneWidget);
    expect(buttonEnabled(t, 'restore-e1'), isFalse);
    expect(buttonEnabled(t, 'restore-p1'), isFalse);
    await t.tap(find.byKey(const Key('restore-e1')), warnIfMissed: false);
    await settle(t);
    expect(actions.restored, isEmpty);
  });

  // TC-20-04
  testWidgets('an archived group with nothing deleted shows no note', (t) async {
    await _pump(t, _none, archived: true);
    expect(find.byKey(const Key('deleted-archived-note')), findsNothing);
    expect(find.byKey(const Key('deleted-empty')), findsOneWidget);
  });

  // TC-20-04
  testWidgets('loading shows the pulse', (t) async {
    await _pump(t, const AsyncLoading());
    expect(find.byType(DotsPulse), findsOneWidget);
    expect(find.byKey(const Key('deleted-empty')), findsNothing);
  });

  // TC-20-04
  testWidgets('at large text the button moves under the text and still works', (t) async {
    final actions = await _pump(t, AsyncData(sampleDeleted()), scale: 2);
    await tapKey(t, 'restore-e1');
    expect(actions.restored, ['e1']);
  });
}
