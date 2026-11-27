// D-033 minimal pass (home, entry points, shell, account & settings): device screenshots of the screens
// this pass changes, against the DEV project. It only navigates and scrolls (no checks of the new flows;
// those are in minimal_entry_test.dart), so the same file captures the screens before and after the change.
//   powershell -Command ". tool\env.ps1; & tool\e2e\capture_minimal_entry.ps1 -Prefix after"
// With --dart-define=UI_HOLD=8 it prints `UI-CAPTURE <name>` and holds each state for the host screenshots;
// names ending in -dark are taken with the emulator in dark mode. Built side by side as
// com.unizoy.splitify.qa (SPLITIFY_APP_ID_SUFFIX, S-310). The test group is soft-deleted at the end.
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
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

/// Seconds each state stays up for the host captures (`UI_HOLD`, 0 = no hold).
const _hold = int.fromEnvironment('UI_HOLD');

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _capture(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(milliseconds: 900));
  if (_hold == 0) return;
  debugPrint('UI-CAPTURE $name');
  final end = DateTime.now().add(const Duration(seconds: _hold));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await t.pump();
  }
}

/// A slow drag up from the middle of the screen (no fling): the page scrolls by about [by] px.
Future<void> _scroll(WidgetTester t, double by) async {
  final size = t.view.physicalSize / t.view.devicePixelRatio;
  await t.timedDragFrom(
    Offset(size.width / 2, size.height * 0.62),
    Offset(0, -by),
    const Duration(milliseconds: 900),
  );
  await _pumpFor(t, const Duration(milliseconds: 900));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D-033 entry/shell/account screens for the before/after screenshots', (t) async {
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

    final groups = container.read(groupsRepositoryProvider);
    final members = container.read(membersRepositoryProvider);
    final gid = await groups.create(
      name: 'Goa trip (E2E ${DateTime.now().millisecondsSinceEpoch % 100000})',
      ownerName: 'Mohit',
      ownerUserId: uid,
      type: 'trip',
    );
    await members.addNameOnly(gid, 'Asha');
    await members.addNameOnly(gid, 'Rahul');
    await sync();
    addTearDown(() async {
      await groups.delete(gid, gid);
      await sync();
    });

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
    await pumpUntil(
      t,
      () => find.byKey(Key('group-card-$gid')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 90),
      reason: 'home',
    );
    await _pumpFor(t, const Duration(seconds: 2));

    // Groups home: top, then scrolled so the hero reaches the status bar.
    await _capture(t, 'home');
    await _scroll(t, 160);
    await _capture(t, 'home-scrolled');
    await _capture(t, 'home-scrolled-dark');

    // The "+" in the nav: before = which-group sheet, after = the editor with "With you and".
    await t.tap(find.bySemanticsLabel('Add expense').last);
    await _pumpFor(t, const Duration(seconds: 2));
    FocusManager.instance.primaryFocus?.unfocus();
    await _capture(t, 'fab');
    await _capture(t, 'fab-dark');
    // After D-033: the "With you and" picker on the editor.
    final choose = find.byKey(const Key('expense-with-choose'));
    if (choose.evaluate().isNotEmpty) {
      await t.tap(choose);
      await _pumpFor(t, const Duration(seconds: 2));
      await _capture(t, 'fab-picker');
      await _capture(t, 'fab-picker-dark');
      await t.binding.handlePopRoute();
      await _pumpFor(t, const Duration(seconds: 1));
    }
    await t.binding.handlePopRoute();
    await _pumpFor(t, const Duration(seconds: 1));

    // Group page: top and scrolled.
    router.go(Routes.group(gid));
    await _pumpFor(t, const Duration(seconds: 3));
    await _capture(t, 'group');
    await _scroll(t, 200);
    await _capture(t, 'group-scrolled');
    await _capture(t, 'group-scrolled-dark');

    for (final tab in ['activity', 'friends']) {
      router.go('/$tab');
      await _pumpFor(t, const Duration(seconds: 3));
      await _capture(t, tab);
      await _scroll(t, 200);
      await _capture(t, '$tab-scrolled');
      await _capture(t, '$tab-scrolled-dark');
    }

    // Account and its settings (before: the gear's sheet; after: the list on the tab).
    router.go(Routes.account);
    await _pumpFor(t, const Duration(seconds: 3));
    await _capture(t, 'account');
    await _capture(t, 'account-dark');
    final gear = find.byTooltip('Account settings');
    if (gear.evaluate().isNotEmpty) {
      await t.tap(gear.first);
      await _pumpFor(t, const Duration(seconds: 2));
      await _capture(t, 'settings');
      await _capture(t, 'settings-dark');
      await t.binding.handlePopRoute();
      await _pumpFor(t, const Duration(seconds: 1));
    } else {
      await _scroll(t, 700);
      await _capture(t, 'settings');
      await _capture(t, 'settings-dark');
    }

    for (final (name, path) in [
      ('notif-settings', '/account/notifications'),
      ('security', '/account/security'),
      ('insights', '/insights?mode=me'),
      ('search', '/search'),
    ]) {
      router.go(Routes.account);
      await _pumpFor(t, const Duration(seconds: 1));
      router.push(path).ignore();
      await _pumpFor(t, const Duration(seconds: 3));
      FocusManager.instance.primaryFocus?.unfocus();
      await _capture(t, name);
      await _capture(t, '$name-dark');
      if (name == 'insights') {
        await _scroll(t, 220);
        await _capture(t, 'insights-scrolled');
        await _capture(t, 'insights-scrolled-dark');
      }
    }
    debugPrint('D-033-ENTRY-CAPTURE OK');
  });
}
