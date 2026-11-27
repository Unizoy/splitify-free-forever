// D-034 B1: the batch form (Record a payment for everything with one friend) — prefilled with the total, the
// "Across 2 groups" breakdown follows the amount (biggest group first), more than the total is an inline error and
// saves nothing, Save records one payment per group, the celebration when everything is settled, and one
// Pay-via-UPI link for the total (recorded only on "Mark as paid", method UPI).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show syncOfflineProvider;
import 'package:splitify/features/payments/application/settle_all_controller.dart';
import 'package:splitify/features/payments/application/settle_controller.dart' show SettleNotFound;
import 'package:splitify/features/payments/application/upi_providers.dart';
import 'package:splitify/features/payments/presentation/settle_all_screen.dart';

import '../../expenses/presentation/presentation_harness.dart';
import '../settle_all_fixtures.dart';

class _FakeUpiLauncher implements UpiLauncher {
  final uris = <String>[];

  @override
  Future<bool> launch(String uri) async {
    uris.add(uri);
    return true;
  }
}

class _NotFound extends SettleAllController {
  _NotFound(super.args);

  @override
  Future<SettleAllDraft> build() async => throw const SettleNotFound();
}

class _Rig {
  FixedSettleAllController? controller;
  final upi = _FakeUpiLauncher();

  SettleAllDraft get draft => controller!.state.value!;
}

const _screen = SettleAllScreen(friendKey: 'u:u2', currency: 'INR');

Future<_Rig> _pump(
  WidgetTester t, {
  SettleAllDraft? draft,
  String? vpa,
  bool offline = false,
  List<Override> extra = const [],
}) async {
  usePhone(t);
  final rig = _Rig();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => PushHost(
          offline
              ? ProviderScope(
                  overrides: [syncOfflineProvider.overrideWith((ref) => Stream.value(true))],
                  child: _screen,
                )
              : _screen,
        ),
      ),
      stubRoute('/friends'),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    routerApp(
      router,
      overrides: [
        settleAllProvider(settleAllArgs).overrideWith(() {
          final c = FixedSettleAllController(settleAllArgs, draft ?? sampleSettleAllDraft());
          rig.controller = c;
          return c;
        }),
        upiIdProvider('u2').overrideWith((ref) => Stream.value(vpa)),
        upiLauncherProvider.overrideWithValue(rig.upi),
        ...extra,
      ],
    ),
  );
  await tapKey(t, 'open');
  return rig;
}

String _field(WidgetTester t) => t.widget<TextField>(fieldIn('settle-amount')).controller!.text;

Future<void> _type(WidgetTester t, String text) async {
  await t.enterText(fieldIn('settle-amount'), text);
  await t.pump();
}

void main() {
  testWidgets('prefilled with the whole balance: Asha pays me ₹455 across 2 groups', (t) async {
    await _pump(t);
    expect(_field(t), '455');
    expect(find.text('Asha Rao paid you'), findsOneWidget);
    expect(find.text('With'), findsOneWidget);
    expect(find.text('Across 2 groups'), findsOneWidget);
    expect(find.text('Settles all of ₹455'), findsOneWidget);
    expect(find.text('Record cash payment'), findsOneWidget);
    expect(find.byKey(const Key('settle-upi')), findsNothing, reason: 'I am the one paid');
    expect(
      find.byKey(const Key('settle-swap')),
      findsNothing,
      reason: 'the direction follows the balance',
    );
  });

  testWidgets('the breakdown shows each group and what this payment pays there, biggest first', (
    t,
  ) async {
    await _pump(t);
    await _type(t, '300');
    expect(find.text('Part of the ₹455 owed'), findsOneWidget);
    expect(find.text('₹155 left after this'), findsOneWidget);
    await tapKey(t, 'settle-all-across');
    expect(find.byKey(const Key('settle-all-breakdown')), findsOneWidget);
    expect(find.text('Just you two'), findsOneWidget);
    expect(find.text('This payment: ₹255'), findsOneWidget);
    expect(find.text('This payment: ₹45'), findsOneWidget);
    expect(
      t.getTopLeft(find.byKey(const Key('settle-all-group-g3'))).dy,
      lessThan(t.getTopLeft(find.byKey(const Key('settle-all-group-g1'))).dy),
    );
  });

  testWidgets('a small amount leaves a group out of the payment', (t) async {
    await _pump(t);
    await _type(t, '100');
    await tapKey(t, 'settle-all-across');
    expect(find.text('This payment: ₹100'), findsOneWidget);
    expect(find.text('Not in this payment'), findsOneWidget);
  });

  testWidgets('more than the total is an inline error and Save records nothing', (t) async {
    final rig = await _pump(t);
    await _type(t, '500');
    expect(find.text('More than the ₹455 owed'), findsOneWidget);
    expect(
      find.text("One payment can't be more than what's owed in these groups."),
      findsOneWidget,
    );
    await tapKey(t, 'settle-save');
    expect(rig.controller!.saved, isEmpty);
    expect(_field(t), '500', reason: 'the typed amount stays');
    await tapKey(t, 'settle-use-owed');
    expect(_field(t), '455');
  });

  testWidgets('Save records one payment per group, says so, and celebrates everything settled', (
    t,
  ) async {
    final rig = await _pump(t);
    await tapKey(t, 'settle-save');
    await settle(t, 10);
    expect(rig.controller!.saved.single.parts, hasLength(2));
    expect(find.text('2 payments recorded'), findsOneWidget);
    expect(find.byKey(const Key('settled-celebration')), findsOneWidget);
  });

  testWidgets('part of it: no celebration', (t) async {
    final rig = await _pump(t);
    await _type(t, '300');
    await tapKey(t, 'settle-save');
    await settle(t, 10);
    expect(
      [for (final p in rig.controller!.saved.single.parts) (p.groupId, p.amount)],
      [('g3', 25500), ('g1', 4500)],
    );
    expect(find.byKey(const Key('settled-celebration')), findsNothing);
  });

  testWidgets(
    'I owe in rupees and Asha has a UPI ID: one link with the total, recorded on Mark as paid',
    (t) async {
      final rig = await _pump(
        t,
        draft: sampleSettleAllDraft(groups: iOweAshaGroups),
        vpa: 'asha@okaxis',
      );
      expect(find.text('You paid Asha Rao'), findsOneWidget);
      expect(find.text('Pay ₹455 via UPI'), findsOneWidget);
      await tapKey(t, 'settle-upi');
      await settle(t);
      expect(rig.upi.uris, hasLength(1));
      expect(rig.upi.uris.single, contains('pa=asha@okaxis'));
      expect(rig.upi.uris.single, contains('am=455.00&cu=INR'));
      expect(
        rig.controller!.saved,
        isEmpty,
        reason: 'nothing recorded before "Mark as paid" (rule 13)',
      );
      await tapKey(t, 'upi-mark-paid');
      await settle(t, 10);
      final saved = rig.controller!.saved.single;
      expect(saved.method, 'upi');
      expect(
        [for (final p in saved.parts) (p.groupId, p.friendPays, p.amount)],
        [('g3', false, 25500), ('g1', false, 20000)],
      );
    },
  );

  testWidgets('offline: the "not synced yet" marker sits next to the friend', (t) async {
    await _pump(t, offline: true);
    expect(find.byKey(const Key('money-offline')), findsOneWidget);
  });

  testWidgets('nothing to settle: a friendly empty state', (t) async {
    usePhone(t);
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const PushHost(_screen))],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(
      routerApp(
        router,
        overrides: [settleAllProvider(settleAllArgs).overrideWith(() => _NotFound(settleAllArgs))],
      ),
    );
    await tapKey(t, 'open');
    expect(
      find.text('There is nothing to settle with this friend in this currency right now.'),
      findsOneWidget,
    );
  });
}
