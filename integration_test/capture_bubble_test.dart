// Phase 18b e2e on the emulator (TC-X4-03…07): the real native capture services, the real bubble and the real
// app. Driven by `tool/e2e/capture_e2e.ps1`, which grants the accesses on `E2E-GRANT`, then on `E2E-READY` posts
// UPI notifications (fake UPI app), bank SMS (`adb emu sms send`), ignore cases (adb shell notifications), runs
// the fake app's pay → PIN → success screens, checks the bubble and finally taps its **Add to Splitify**. This
// test then picks the group on the capture screen, checks the prefilled editor, saves and checks the dev server
// row (`source = 'capture'`). Run only through the script (it waits for the PC):
//   powershell -File tool\e2e\capture_e2e.ps1
import 'dart:async';

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
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/domain/entities/payment_capture.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/capture/application/capture_providers.dart';
import 'package:splitify/features/capture/presentation/capture_routes.dart';
import 'package:splitify/features/currency/application/currency_providers.dart'
    show fxAutoRefreshProvider;
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

const _staged = bool.fromEnvironment('E2E_CAPTURE');
const _hold = int.fromEnvironment('UI_HOLD', defaultValue: 16);

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitFor(
  WidgetTester t,
  Finder f, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    // In the background (UPI app, home screen) no frames come and a pump would never return: wait in real
    // time until Android brings the app back, then pump.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      continue;
    }
    await t.pump(const Duration(milliseconds: 200));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $f');
}

Future<void> _capture(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(seconds: 1));
  debugPrint('UI-CAPTURE $name');
  await _pumpFor(t, const Duration(seconds: _hold));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC-X4-03..07 payment bubble: alerts, SMS, smart capture, ignores, Add → saved', (
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
        friendsRemoteProvider.overrideWithValue(SupabaseFriendsRemote.fromClient(client)),
        authRepositoryProvider.overrideWithValue(services.auth),
        profileRemoteProvider.overrideWithValue(services.profiles),
        fxAutoRefreshProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
    final engine = container.read(syncEngineProvider);
    Future<void> sync() => t.runAsync(() async {
      await engine.sync();
      await engine.sync();
    });

    // A fresh group for this run (its name shows as a chip on the bubble).
    final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
    final gid = (await t.runAsync(
      () => container
          .read(groupsRepositoryProvider)
          .create(name: 'Bubble $stamp', ownerName: 'E2E A', ownerUserId: uid),
    ))!;
    await sync();

    // The feature on, every source on; old captures on this phone forgotten.
    final bridge = container.read(captureBridgeProvider);
    expect(bridge.supported, isTrue, reason: 'run on the Android emulator');
    await t.runAsync(() async {
      await bridge.reset();
      await bridge.saveSettings(
        const CaptureSettings(enabled: true, smart: true, duringPayment: true),
      );
    });
    debugPrint('E2E-GRANT');
    // The script grants notification access, display over apps and accessibility with adb.
    final grantEnd = DateTime.now().add(const Duration(minutes: 2));
    var perms = const CapturePermissions();
    while (DateTime.now().isBefore(grantEnd)) {
      perms = (await t.runAsync(bridge.permissions))!;
      // Allowed and actually bound by Android (an app update re-binds them with a delay).
      if (perms.notifications &&
          perms.overlay &&
          perms.accessibility &&
          perms.listening &&
          perms.smartConnected) {
        break;
      }
      await _pumpFor(t, const Duration(seconds: 1));
    }
    expect(
      [
        perms.notifications,
        perms.overlay,
        perms.accessibility,
        perms.listening,
        perms.smartConnected,
      ],
      [true, true, true, true, true],
    );

    // The app on the Groups tab (shell + CaptureBinding: imports on resume, writes the chips).
    final router = buildRouter(initialLocation: Routes.groups);
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
    await _pumpFor(t, const Duration(seconds: 3));
    debugPrint('E2E-READY');

    // The PC runs the native scenarios and taps "Add to Splitify" on the last bubble (the SMS-only payment).
    await _waitFor(
      t,
      find.byKey(const Key('capture-summary')),
      timeout: const Duration(minutes: 8),
    );
    await _capture(t, 'capture-screen');
    final captures = await t.runAsync(() => db.select(db.paymentCaptures).get());
    debugPrint(
      'E2E-CAPTURES ${captures!.map((c) => '${c.amount}:${c.payee}:${c.source}').join(',')}',
    );
    // TC-X4-02: notification + SMS of the same payment = one capture; the dismissed smart capture is gone.
    expect(captures.where((c) => c.amount == 42000), hasLength(1));
    expect(captures.where((c) => c.amount == 42000).single.ref, '612345678920');
    expect(captures.where((c) => c.amount == 25000), isEmpty);
    final chai = captures.singleWhere((c) => c.amount == 9900);
    expect(chai.payee, 'Chai Point');
    expect(chai.source, 'sms');

    await t.tap(find.byKey(Key('capture-place-$gid')));
    await _pumpFor(t, const Duration(seconds: 2));
    // TC-X4-06: the editor opens prefilled.
    final provider = captureEditorProvider((groupId: gid, captureId: chai.id));
    final editorEnd = DateTime.now().add(const Duration(seconds: 30));
    while (!container.read(provider).hasValue && DateTime.now().isBefore(editorEnd)) {
      await _pumpFor(t, const Duration(milliseconds: 300));
    }
    await _capture(t, 'capture-editor');
    final draft = container.read(provider).value!;
    expect(draft.amountText, '99');
    expect(draft.description, 'Chai Point');
    expect(draft.notes, 'From a bank SMS · UPI ref 612345678922');
    expect(draft.currency, 'INR');
    final id = (await t.runAsync(() => container.read(provider.notifier).save()))!;
    expect(id, isNotNull);
    await _pumpFor(t, const Duration(seconds: 2));
    await sync();

    final row = (await t.runAsync(
      () => client.from('expenses').select('source,total,description,notes').eq('id', id).single(),
    ))!;
    debugPrint(
      'E2E-RESULT source=${row['source']} total=${row['total']} description=${row['description']}',
    );
    expect(row['source'], 'capture');
    expect(row['total'], 9900);
    expect(await t.runAsync(() => db.select(db.paymentCaptures).get()), hasLength(1));

    // Device UI review (light, dark, 200 %): Groups hero pill, Activity section, settings.
    router.go(Routes.groups);
    await _waitFor(t, find.byKey(const Key('payments-to-add-pill')));
    await _capture(t, 'groups-pill');
    router.go(Routes.activity);
    await _waitFor(t, find.byKey(const Key('payments-to-add-section')));
    await _capture(t, 'activity-section');
    unawaited(router.push(CaptureRoutes.settings));
    await _waitFor(t, find.byKey(const Key('capture-master')));
    await _capture(t, 'bubble-settings');

    // Leave the switches on for the script's screenshot stage; the next run resets the store.
    debugPrint('E2E-DONE');
    await t.pumpWidget(const SizedBox());
    await _pumpFor(t, const Duration(seconds: 1));
  }, skip: !_staged);
}
