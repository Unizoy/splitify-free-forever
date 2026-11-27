// D-033 end to end on the emulator against the DEV project: the minimal money-movement flows.
//  1. Group page → Settle up → the balance sheet (mine first, biggest first) → Record a payment prefilled
//     with what I owe Asha; the phone's number keyboard (no custom pad), a part payment, the discard
//     question, the method sheet and a note → "Record cash payment" → phone = server (row and balances).
//  2. The compact payment detail; edit opens the same one screen.
//  3. Settle the rest: prefilled with what is left → the short celebration → my balance is 0 on the server.
//  4. Record a loan on one screen (I lent Rahul ₹500 for a cab) → an IOU row on the server.
//  5. Group settings → Default split is a sheet: shares, saved on the server.
//   SPLITIFY_APP_ID_SUFFIX=.qa flutter test integration_test/minimal_pay_test.dart -d emulator-5554 \
//     --dart-define-from-file=secrets/env.dev.json --dart-define=PIN_HOST_IP=<ip resolved on the PC>
// With --dart-define=UI_HOLD=<s> it prints `UI-CAPTURE <name>` and holds each state for the host screenshots
// (tool/e2e/capture_minimal_pay.ps1). The test group is soft-deleted at the end.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

/// Seconds each reviewed state stays up for the host captures (`UI_HOLD`, 0 = no hold).
const _hold = int.fromEnvironment('UI_HOLD');

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _pumpFor(t, const Duration(milliseconds: 600));
}

Future<void> _waitFor(WidgetTester t, Finder f, {String reason = ''}) =>
    pumpUntil(t, () => f.evaluate().isNotEmpty, reason: reason.isEmpty ? '$f' : reason);

Future<void> _capture(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(milliseconds: 800));
  if (_hold == 0) return;
  debugPrint('UI-CAPTURE $name');
  final end = DateTime.now().add(const Duration(seconds: _hold));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await t.pump();
  }
}

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

String _pill(String key) =>
    (find
                .descendant(
                  of: find.byKey(Key(key)),
                  matching: find.byKey(const Key('form-pill-title')),
                )
                .evaluate()
                .single
                .widget
            as Text)
        .data!;

Map<String, int> _ints(Object? json) {
  final m = json is String ? jsonDecode(json) as Map<String, Object?> : json! as Map;
  return {for (final e in m.entries) e.key as String: (e.value as num).toInt()};
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D-033: settle up, payment detail, loan and default split on the minimal screens', (
    t,
  ) async {
    final env = devEnv();
    final services = await initRemote(env);
    await services.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
    final uid = services.auth.currentUser!.id;
    final client = Supabase.instance.client;
    final db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        remoteApiProvider.overrideWithValue(SupabaseRemoteApi.client(client)),
        balancesRemoteProvider.overrideWithValue(SupabaseBalancesRemote.fromClient(client)),
        groupsRemoteProvider.overrideWithValue(services.groups),
        authRepositoryProvider.overrideWithValue(services.auth),
        profileRemoteProvider.overrideWithValue(services.profiles),
      ],
    );
    addTearDown(container.dispose);
    final engine = container.read(syncEngineProvider);
    Future<void> sync() => t.runAsync(() async {
      await engine.sync();
      await engine.sync();
    });
    // A separate test group (never the owner's groups): me, Asha and Rahul (name-only).
    final groups = container.read(groupsRepositoryProvider);
    final members = container.read(membersRepositoryProvider);
    final gid = await groups.create(
      name: 'Goa trip (E2E ${DateTime.now().millisecondsSinceEpoch % 100000})',
      ownerName: 'Mohit',
      ownerUserId: uid,
      type: 'trip',
    );
    final asha = await members.addNameOnly(gid, 'Asha');
    final rahul = await members.addNameOnly(gid, 'Rahul');
    final me = (await members.watchForGroup(gid).first).firstWhere((m) => m.userId == uid).id;
    Future<Map<String, int>> serverNets() async {
      final b = (await t.runAsync(
        () => client.rpc<Map<String, dynamic>>('group_balances', params: {'group_id': gid}),
      ))!;
      return _ints((b['currencies'] as Map)['INR']['nets']);
    }

    // Asha paid ₹1,200 for the three of us: I owe her ₹400, so does Rahul.
    await container.read(expensesRepositoryProvider).save(gid, {
      'kind': 'expense',
      'description': 'Beach shack dinner',
      'notes': null,
      'category': 'food.restaurant',
      'date': '2026-11-26',
      'currency': 'INR',
      'total': 120000,
      'payers': {asha: 120000},
      'shares': {me: 40000, asha: 40000, rahul: 40000},
      'split_kind': 'equal',
      'split_values': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await sync();
    addTearDown(() async {
      await groups.delete(gid, gid);
      await sync();
    });
    expect((await serverNets())[me], -40000);

    final router = buildRouter(initialLocation: Routes.group(gid));
    addTearDown(router.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
          darkTheme: AppTheme.dark(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    await _waitFor(t, find.byKey(const Key('group-settle')), reason: 'group page');
    await _pumpFor(t, const Duration(seconds: 1));

    // 1. Settle up → the balances: mine (I owe Asha ₹400) above Rahul's.
    await _tap(t, find.byKey(const Key('group-settle')));
    await _waitFor(t, find.byKey(const Key('settle-picker')));
    final mine = find.byKey(Key('settle-pick-INR-$me-$asha'));
    final theirs = find.byKey(Key('settle-pick-INR-$rahul-$asha'));
    expect(mine, findsOneWidget);
    expect(theirs, findsOneWidget);
    expect(t.getTopLeft(mine).dy, lessThan(t.getTopLeft(theirs).dy));
    expect(find.text('you owe ₹400'), findsOneWidget);
    await _capture(t, 'picker');
    await _capture(t, 'picker-dark');

    await _tap(t, mine);
    await _waitFor(t, find.byKey(const Key('settle-amount')), reason: 'record a payment');
    expect(find.text('Record a payment'), findsOneWidget);
    expect(t.widget<TextField>(_field('settle-amount')).controller!.text, '400');
    expect(_pill('settle-summary'), 'Settles all of ₹400');
    expect(find.text('Record cash payment'), findsOneWidget);
    await _capture(t, 'settle');
    await _capture(t, 'settle-dark');

    // The phone's own number keyboard for the amount, and no custom pad on top: one keyboard only.
    binding.testTextInput.unregister();
    await t.tap(_field('settle-amount'));
    await _pumpFor(t, const Duration(seconds: 2));
    expect(find.byKey(const Key('key-d1')), findsNothing);
    expect(find.byKey(const Key('settle-save')), findsOneWidget, reason: 'Save above the keyboard');
    await _capture(t, 'settle-keyboard');
    FocusManager.instance.primaryFocus?.unfocus();
    await _pumpFor(t, const Duration(seconds: 2));
    binding.testTextInput.register();

    // A part payment: the pill says what is left.
    await t.enterText(_field('settle-amount'), '150');
    await _pumpFor(t, const Duration(milliseconds: 500));
    FocusManager.instance.primaryFocus?.unfocus();
    expect(_pill('settle-summary'), 'Part of the ₹400 owed');
    expect(find.text('₹250 left after this'), findsOneWidget);
    await _capture(t, 'settle-partial');

    // Back with a change asks first; Cancel keeps the typed amount.
    await _tap(t, find.byTooltip('Back'));
    await _waitFor(t, find.text('Discard this payment?'));
    await _capture(t, 'settle-discard');
    await _tap(t, find.text('Cancel'));
    expect(t.widget<TextField>(_field('settle-amount')).controller!.text, '150');

    // The method sheet and a note.
    await _tap(t, find.byKey(const Key('settle-method')));
    await _waitFor(t, find.byKey(const Key('settle-methods')));
    await _capture(t, 'settle-method-sheet');
    await _tap(t, find.byKey(const Key('method-cash')));
    await _tap(t, find.byKey(const Key('settle-note-chip')));
    await t.enterText(_field('settle-note'), 'Half now');
    await _tap(t, find.byKey(const Key('text-sheet-done')));

    // Record cash payment: back on the group page, offline first, then synced; phone = server.
    await _tap(t, find.byKey(const Key('settle-save')));
    await _waitFor(t, find.byKey(const Key('group-settle')), reason: 'back on the group');
    expect(find.byKey(const Key('settled-celebration')), findsNothing, reason: 'part payment');
    final first = await (db.select(db.payments)..where((p) => p.groupId.equals(gid))).getSingle();
    expect((first.fromMember, first.toMember, first.amount), (me, asha, 15000));
    expect((first.currency.trim(), first.method, first.note), ('INR', 'cash', 'Half now'));
    await sync();
    final synced = await (db.select(db.payments)..where((p) => p.id.equals(first.id))).getSingle();
    expect(synced.syncState, SyncState.synced, reason: '${engine.lastError}');
    final row = (await t.runAsync(
      () => client.from('payments').select().eq('id', first.id).single(),
    ))!;
    expect((row['amount'] as num).toInt(), 15000);
    expect(
      (row['method'], row['note'], row['from_member'], row['to_member']),
      ('cash', 'Half now', me, asha),
    );
    expect((await serverNets())[me], -25000);

    // 2. The compact payment detail, and edit opens the same one screen.
    await _pumpFor(t, const Duration(seconds: 1));
    await _tap(t, find.byKey(ValueKey('payment-${first.id}')));
    await _waitFor(t, find.byKey(const Key('payment-detail-amount')));
    expect(find.text('You paid Asha'), findsOneWidget);
    expect(find.text('Half now'), findsOneWidget);
    await _capture(t, 'payment-detail');
    await _capture(t, 'payment-detail-dark');
    await _tap(t, find.byKey(const Key('payment-edit')));
    await _waitFor(t, find.text('Edit payment'));
    expect(t.widget<TextField>(_field('settle-amount')).controller!.text, '150');
    expect(find.byKey(const Key('settle-upi')), findsNothing);
    await _capture(t, 'payment-edit');
    await _tap(t, find.byTooltip('Back'));
    await _tap(t, find.byTooltip('Back'));
    await _waitFor(t, find.byKey(const Key('group-settle')));

    // 3. Settle the rest: prefilled with ₹250, the short celebration, my balance is 0.
    await _tap(t, find.byKey(const Key('group-settle')));
    await _waitFor(t, mine);
    await _tap(t, mine);
    await _waitFor(t, find.byKey(const Key('settle-amount')));
    expect(t.widget<TextField>(_field('settle-amount')).controller!.text, '250');
    await _tap(t, find.byKey(const Key('settle-save')));
    await _waitFor(t, find.byKey(const Key('settled-celebration')), reason: 'celebration');
    expect(find.text('You and Asha are square.'), findsOneWidget);
    await _capture(t, 'celebration');
    await pumpUntil(
      t,
      () => find.byKey(const Key('settled-celebration')).evaluate().isEmpty,
      timeout: const Duration(seconds: 10),
      reason: 'the celebration closes itself',
    );
    await sync();
    expect((await serverNets())[me], 0);

    // 4. Record a loan: I lent Rahul ₹500 for a cab.
    await _tap(t, find.byKey(const Key('group-loan')));
    await _waitFor(t, find.byKey(const Key('loan-amount')), reason: 'loan screen');
    FocusManager.instance.primaryFocus?.unfocus();
    await _capture(t, 'loan');
    await t.enterText(_field('loan-note'), 'Cab money');
    await t.enterText(_field('loan-amount'), '500');
    await _pumpFor(t, const Duration(milliseconds: 500));
    FocusManager.instance.primaryFocus?.unfocus();
    await _tap(t, find.byKey(const Key('loan-who')));
    await _waitFor(t, find.byKey(const Key('loan-who-sheet')));
    await _capture(t, 'loan-who-sheet');
    await _tap(t, find.byKey(Key('loan-person-$rahul')));
    expect(_pill('loan-who'), 'You lent Rahul');
    expect(find.text('Rahul will owe you ₹500'), findsOneWidget);
    await _capture(t, 'loan-filled');
    await _capture(t, 'loan-filled-dark');
    await _tap(t, find.byKey(const Key('loan-save')));
    await _waitFor(t, find.byKey(const Key('group-settle')), reason: 'back on the group');
    final loan =
        await (db.select(db.expenses)
              ..where((e) => e.groupId.equals(gid))
              ..where((e) => e.kind.equals('iou')))
            .getSingle();
    expect((loan.total, loan.description), (50000, 'Cab money'));
    expect(_ints(loan.payers), {me: 50000});
    expect(_ints(loan.shares), {rahul: 50000});
    await sync();
    final loanRow = (await t.runAsync(
      () => client.from('expenses').select().eq('id', loan.id).single(),
    ))!;
    expect((loanRow['kind'], (loanRow['total'] as num).toInt()), ('iou', 50000));
    expect(_ints(loanRow['shares']), {rahul: 50000});
    expect((await serverNets())[me], 50000);

    // 5. Group settings → Default split is a sheet: shares, saved on the server.
    router.push(Routes.groupSettings(gid));
    await _waitFor(t, find.byKey(const Key('settings-default-split')));
    await _tap(t, find.byKey(const Key('settings-default-split')));
    await _waitFor(t, find.byKey(const Key('default-split-sheet')));
    await _tap(
      t,
      find.descendant(of: find.byKey(const Key('split-kind')), matching: find.text('1:2')),
    );
    await _capture(t, 'default-split');
    await _capture(t, 'default-split-dark');
    await _tap(t, find.byKey(const Key('default-split-save')));
    await _waitFor(t, find.text('Default split saved'));
    final group = await (db.select(db.groups)..where((g) => g.id.equals(gid))).getSingle();
    expect(group.defaultSplit, contains('shares'));
    await sync();
    final groupRow = (await t.runAsync(
      () => client.from('groups').select('default_split').eq('id', gid).single(),
    ))!;
    expect(jsonEncode(groupRow['default_split']), contains('shares'));

    debugPrint('D-033-MINIMAL-PAY OK');
  });
}
