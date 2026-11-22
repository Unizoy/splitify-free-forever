// Phase 15: a group card is marked while any row of the group is not on the server yet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/components/components.dart';

import '../../support/group_fakes.dart';
import '../../support/group_harness.dart';

void main() {
  // TC-OFF-MARKER: the group row is synced, but an expense of the group is not.
  testWidgets('card shows the marker when its id is in unsyncedGroupIdsProvider', (tester) async {
    await pumpGroups(
      tester,
      '/groups',
      overrides: [
        ...fixedGroupData(
          groups: [
            sampleGroup(id: 'g1', name: 'Goa trip'),
            sampleGroup(id: 'g2', name: 'Flat 4B'),
          ],
          // Feeds `unsyncedGroupIdsProvider` (the group rows themselves are synced).
          unsynced: {'g2'},
        ),
      ],
    );
    await settle(tester);
    final g1 = find.byKey(const Key('group-card-g1'));
    final g2 = find.byKey(const Key('group-card-g2'));
    expect(g1, findsOneWidget);
    expect(find.descendant(of: g1, matching: find.byType(SyncMarker)), findsNothing);
    expect(find.descendant(of: g2, matching: find.byType(SyncMarker)), findsOneWidget);
  });
}
