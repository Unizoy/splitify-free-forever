// TC-X4-07 (payments to add: Groups pill, Activity section, sheet list, Dismiss) and TC-X4-06 (the capture
// screen that picks where a payment goes, then opens the prefilled editor).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/capture/presentation/capture_routes.dart';
import 'package:splitify/features/capture/presentation/payments_to_add.dart';

import '../../support/capture_fakes.dart';
import '../../support/fakes.dart' show testDb;
import '../expenses/presentation/presentation_harness.dart';
import 'capture_harness.dart';

Finder _key(String k) => find.byKey(Key(k));

class _Rig {
  _Rig() : db = testDb(), bridge = FakeCaptureBridge();

  final AppDatabase db;
  final FakeCaptureBridge bridge;

  Future<List<Override>> overrides() async => [
    appDatabaseProvider.overrideWithValue(db),
    ...await captureOverrides(bridge),
  ];

  Future<void> addGroup(String id, String name, String created, {String type = 'other'}) =>
      db.customStatement('INSERT INTO "groups" (id, name, type, created_at) VALUES (?, ?, ?, ?)', [
        id,
        name,
        type,
        created,
      ]);

  Future<void> addMember(String id, String groupId, String name, {String? userId}) =>
      db.customStatement(
        'INSERT INTO group_members (id, group_id, user_id, display_name, position) VALUES (?, ?, ?, ?, 0)',
        [id, groupId, userId, name],
      );
}

void main() {
  late _Rig rig;

  setUp(() => rig = _Rig());
  tearDown(() => rig.db.close());

  final captures = [
    sampleCapture(
      id: captureId1,
      amount: 50000,
      payee: 'Rahul',
      at: DateTime.utc(2026, 11, 21, 4, 30),
    ),
    sampleCapture(
      id: captureId2,
      amount: 125050,
      payee: 'Cafe Mocha',
      appName: 'PhonePe',
      at: DateTime.utc(2026, 11, 20, 12),
    ),
    sampleCapture(id: captureId3, amount: 9900, payee: null, at: DateTime.utc(2026, 11, 19, 12)),
    sampleCapture(id: captureId4, amount: 4500, payee: 'Chai', at: DateTime.utc(2026, 11, 18, 12)),
  ];

  Future<void> store(int n) async {
    for (final c in captures.take(n)) {
      await storeCapture(rig.db, c);
    }
  }

  Future<void> pumpHost(WidgetTester t, Widget child, {GoRouter? router}) async {
    final overrides = await rig.overrides();
    usePhone(t);
    t.view.physicalSize = const Size(412, 1800);
    await t.pumpWidget(const SizedBox());
    final r =
        router ??
        GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(body: SingleChildScrollView(child: child)),
            ),
            stubRoute('/capture'),
          ],
        );
    await t.pumpWidget(routerApp(r, overrides: overrides));
    await settle(t);
  }

  group('Groups pill', () {
    // TC-X4-07
    testWidgets('hidden with no captures', (t) async {
      await pumpHost(t, const PaymentsToAddPill());
      expect(_key('payments-to-add-pill'), findsNothing);
    });

    // TC-X4-07
    testWidgets('hidden when the platform has no capture support', (t) async {
      await store(2);
      rig.bridge.supported = false;
      await pumpHost(t, const PaymentsToAddPill());
      expect(_key('payments-to-add-pill'), findsNothing);
    });

    // TC-X4-07
    testWidgets("shows '2 payments to add' and opens the list in a sheet", (t) async {
      await store(2);
      await pumpHost(t, const PaymentsToAddPill());
      expect(find.text('2 payments to add'), findsOneWidget);

      await t.tap(_key('payments-to-add-pill'));
      await settle(t, 20);
      expect(_key('payments-to-add-list'), findsOneWidget);
      expect(_key('capture-$captureId1'), findsOneWidget);
      expect(_key('capture-$captureId2'), findsOneWidget);
      expect(find.text('Rahul'), findsOneWidget);
      expect(find.text('Cafe Mocha'), findsOneWidget);
    });

    // TC-X4-07
    testWidgets("Add in the sheet closes it and opens the capture screen", (t) async {
      await store(1);
      await pumpHost(t, const PaymentsToAddPill());
      await t.tap(_key('payments-to-add-pill'));
      await settle(t, 20);
      await t.tap(_key('capture-add-$captureId1'));
      await settle(t, 20);
      expect(find.text('at /capture?id=$captureId1'), findsOneWidget);
      expect(_key('payments-to-add-list'), findsNothing);
    });

    // TC-X4-07
    testWidgets('the pill follows the list: it disappears with the last dismissal', (t) async {
      await store(1);
      await pumpHost(t, const Column(children: [PaymentsToAddPill(), PaymentsToAddSection()]));
      expect(_key('payments-to-add-pill'), findsOneWidget);
      await t.tap(_key('capture-dismiss-$captureId1'));
      await settle(t);
      expect(_key('payments-to-add-pill'), findsNothing);
    });
  });

  group('Activity section', () {
    // TC-X4-07
    testWidgets('nothing waiting: nothing shown', (t) async {
      await pumpHost(t, const PaymentsToAddSection());
      expect(_key('payments-to-add-section'), findsNothing);
    });

    // TC-X4-07
    testWidgets('three or fewer: all tiles, no See all', (t) async {
      await store(3);
      await pumpHost(t, const PaymentsToAddSection());
      expect(find.byType(CaptureTile), findsNWidgets(3));
      expect(_key('payments-to-add-all'), findsNothing);
      expect(find.text('3 PAYMENTS TO ADD'), findsOneWidget);
    });

    // TC-X4-07
    testWidgets("more than three: at most 3 tiles (newest first) and 'See all'", (t) async {
      await store(4);
      await pumpHost(t, const PaymentsToAddSection());
      expect(find.byType(CaptureTile), findsNWidgets(3));
      expect(_key('capture-$captureId4'), findsNothing); // the oldest
      expect(_key('payments-to-add-all'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);

      await t.tap(_key('payments-to-add-all'));
      await settle(t, 20);
      expect(_key('payments-to-add-list'), findsOneWidget);
      expect(
        find.descendant(of: _key('payments-to-add-list'), matching: find.byType(CaptureTile)),
        findsNWidgets(4),
      );
    });

    // TC-X4-07
    testWidgets('tiles list newest first', (t) async {
      await store(3);
      await pumpHost(t, const PaymentsToAddSection());
      final ys = [
        for (final id in [captureId1, captureId2, captureId3]) t.getTopLeft(_key('capture-$id')).dy,
      ];
      expect(ys, [...ys]..sort());
    });

    // TC-X4-07
    testWidgets("Dismiss removes the row, tells the bridge and shows 'Payment dismissed'", (
      t,
    ) async {
      await store(2);
      await pumpHost(t, const PaymentsToAddSection());
      await t.tap(_key('capture-dismiss-$captureId1'));
      await settle(t);
      expect(_key('capture-$captureId1'), findsNothing);
      expect(_key('capture-$captureId2'), findsOneWidget);
      expect(rig.bridge.dismissed, [captureId1]);
      expect(await rig.db.select(rig.db.paymentCaptures).get(), hasLength(1));
      expect(find.text('Payment dismissed'), findsOneWidget);
    });

    // TC-X4-07
    testWidgets('a tile shows payee, amount, app and source', (t) async {
      await store(1);
      await pumpHost(t, const PaymentsToAddSection());
      expect(find.text('Rahul'), findsOneWidget);
      expect(find.text('₹500'), findsOneWidget);
      expect(find.textContaining('Google Pay'), findsOneWidget);
      expect(find.textContaining('App alert'), findsOneWidget);
    });

    // TC-X4-07
    testWidgets('a payment without a payee is titled by the app', (t) async {
      await storeCapture(rig.db, captures[2]);
      await pumpHost(t, const PaymentsToAddSection());
      expect(
        find.descendant(of: _key('capture-$captureId3'), matching: find.text('Google Pay')),
        findsOneWidget,
      );
    });
  });

  group('capture screen', () {
    Future<GoRouter> pumpScreen(WidgetTester t, String location) async {
      await rig.addGroup('g-trip', 'Goa trip', '2026-11-20T00:00:00Z');
      await rig.addGroup('g-flat', 'Flat 4B', '2026-11-05T00:00:00Z');
      await rig.addGroup('g-asha', 'Asha and me', '2026-11-10T00:00:00Z', type: 'direct');
      await rig.addMember('m1', 'g-asha', 'Mohit', userId: 'u1');
      await rig.addMember('m2', 'g-asha', 'Asha');
      await store(1);
      final router = GoRouter(
        initialLocation: location,
        routes: [...captureRoutes(), stubRoute('/expense/new'), stubRoute('/groups/new')],
      );
      await pumpHost(t, const SizedBox(), router: router);
      return router;
    }

    // TC-X4-06
    testWidgets("unknown id shows 'This payment is no longer here'", (t) async {
      await pumpScreen(t, CaptureRoutes.add(captureId2));
      expect(_key('capture-gone'), findsOneWidget);
      expect(find.text('This payment is no longer here'), findsOneWidget);
      expect(_key('capture-summary'), findsNothing);
    });

    // TC-X4-06
    testWidgets('a malformed id is treated as gone', (t) async {
      await pumpScreen(t, '/capture?id=not-a-uuid');
      expect(_key('capture-gone'), findsOneWidget);
    });

    // TC-X4-06
    testWidgets('known id: summary card, groups and friends sections', (t) async {
      await pumpScreen(t, CaptureRoutes.add(captureId1));
      expect(_key('capture-gone'), findsNothing);
      expect(_key('capture-summary'), findsOneWidget);
      expect(
        find.descendant(of: _key('capture-summary'), matching: find.text('₹500')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _key('capture-summary'), matching: find.text('Rahul')),
        findsOneWidget,
      );
      expect(_key('capture-place-g-trip'), findsOneWidget);
      expect(_key('capture-place-g-flat'), findsOneWidget);
      expect(_key('capture-place-g-asha'), findsOneWidget);
      expect(find.text('Asha'), findsOneWidget); // the direct group is named by the friend
      expect(find.text('GROUPS'), findsOneWidget);
      expect(find.text('FRIENDS'), findsOneWidget);
      // Most recently used first; the friend sits in its own section below the groups.
      expect(
        t.getTopLeft(_key('capture-place-g-trip')).dy,
        lessThan(t.getTopLeft(_key('capture-place-g-flat')).dy),
      );
      expect(
        t.getTopLeft(_key('capture-place-g-flat')).dy,
        lessThan(t.getTopLeft(_key('capture-place-g-asha')).dy),
      );
    });

    // TC-X4-06
    testWidgets('tapping a place opens the prefilled editor in that group', (t) async {
      await pumpScreen(t, CaptureRoutes.add(captureId1));
      await t.tap(_key('capture-place-g-flat'));
      await settle(t);
      expect(find.text('at /expense/new?group=g-flat&capture=$captureId1'), findsOneWidget);
    });

    // TC-X4-06
    testWidgets('a group in the link skips the picker and goes straight to the editor', (t) async {
      await pumpScreen(t, CaptureRoutes.add(captureId1, groupId: 'g-trip'));
      expect(find.text('at /expense/new?group=g-trip&capture=$captureId1'), findsOneWidget);
    });

    // TC-X4-06
    testWidgets('a group that is not on this phone keeps the picker open', (t) async {
      await pumpScreen(t, CaptureRoutes.add(captureId1, groupId: 'g-unknown'));
      expect(_key('capture-summary'), findsOneWidget);
      expect(_key('stub'), findsNothing);
    });

    // TC-X4-06
    testWidgets('no groups at all offers to create one', (t) async {
      await store(1);
      final router = GoRouter(
        initialLocation: CaptureRoutes.add(captureId1),
        routes: [...captureRoutes(), stubRoute('/groups/new')],
      );
      await pumpHost(t, const SizedBox(), router: router);
      expect(_key('capture-summary'), findsOneWidget);
      expect(_key('capture-new-group'), findsOneWidget);
      await t.tap(_key('capture-new-group'));
      await settle(t);
      expect(find.text('at /groups/new'), findsOneWidget);
    });
  });
}
