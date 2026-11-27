// D-033 end to end on the emulator against the DEV project: the + of the tab bar opens the one-screen editor at
// once (no "Add to which group?" sheet), "With you and" picks the test group through its search, the expense
// is saved and synced (phone = server); then the Account settings list: Appearance and the home-screen widget
// as sheets, Notifications and Security pages, Sign out asks first, Delete account asks to type DELETE.
//   flutter test integration_test/minimal_entry_test.dart -d emulator-5554 --no-uninstall \
//     --dart-define-from-file=secrets/env.dev.json --dart-define=PIN_HOST_IP=<ip resolved on the PC>
// Build it side by side with the installed store build: SPLITIFY_APP_ID_SUFFIX=.qa (S-310). The test group is
// soft-deleted at the end; nothing is signed out or deleted.
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
import 'package:splitify/features/account/application/theme_mode_controller.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

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
  await _pumpFor(t, const Duration(milliseconds: 700));
}

Future<void> _tapKey(WidgetTester t, String key) => _tap(t, find.byKey(Key(key)));

Future<void> _waitFor(WidgetTester t, Finder f, {String reason = ''}) =>
    pumpUntil(t, () => f.evaluate().isNotEmpty, reason: reason.isEmpty ? '$f' : reason);

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await _pumpFor(t, const Duration(milliseconds: 900));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D-033: + opens the editor, With you and picks the group, saved; settings flows', (
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

    // A separate test group with a findable name (never the owner's sample groups).
    final tag = 'Entry${DateTime.now().millisecondsSinceEpoch % 100000}';
    final groups = container.read(groupsRepositoryProvider);
    final members = container.read(membersRepositoryProvider);
    final gid = await groups.create(
      name: 'Chai club $tag',
      ownerName: 'Mohit',
      ownerUserId: uid,
      type: 'other',
    );
    await members.addNameOnly(gid, 'Asha');
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
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
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
            themeMode: ref.watch(themeModeControllerProvider),
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
    await pumpUntil(
      t,
      () => find.byKey(Key('group-card-$gid')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 90),
      reason: 'home',
    );
    await _pumpFor(t, const Duration(seconds: 1));

    // 1. The + opens the editor at once: no which-group sheet, nobody picked yet.
    await _tapKey(t, 'nav-add');
    await _waitFor(t, find.byKey(const Key('expense-amount')), reason: 'editor');
    expect(find.text('Add to which group?'), findsNothing);
    expect(find.byKey(const Key('expense-with-choose')), findsOneWidget);

    // 2. Typing first is fine; the description and amount stay when the group is picked.
    await t.enterText(_field('expense-description'), 'Chai $tag');
    await t.enterText(_field('expense-amount'), '240');
    await _pumpFor(t, const Duration(milliseconds: 600));
    FocusManager.instance.primaryFocus?.unfocus();
    await _tapKey(t, 'expense-with-choose');
    await _waitFor(t, find.byKey(const Key('with-picker')), reason: 'picker');
    await t.enterText(find.byKey(const Key('with-search')), tag);
    await _pumpFor(t, const Duration(milliseconds: 600));
    await _tapKey(t, 'with-target-$gid');
    await _waitFor(t, find.byKey(const Key('expense-with-chip')), reason: 'picked');
    expect(find.text('Chai club $tag'), findsOneWidget);
    expect(find.text('Chai $tag'), findsOneWidget);
    expect(find.text('Paid by You · split equally'), findsOneWidget);

    // 3. Save: offline first, then on the server with the right group and amount.
    await _tapKey(t, 'expense-save');
    await pumpUntil(
      t,
      () => find.byKey(const Key('expense-amount')).evaluate().isEmpty,
      reason: 'editor closed',
    );
    final saved = await (db.select(db.expenses)..where((e) => e.groupId.equals(gid))).getSingle();
    expect(saved.description, 'Chai $tag');
    expect(saved.total, 24000);
    await sync();
    final synced = await (db.select(db.expenses)..where((e) => e.id.equals(saved.id))).getSingle();
    expect(synced.syncState, SyncState.synced, reason: '${engine.lastError}');
    final row = (await t.runAsync(
      () => client.from('expenses').select().eq('id', saved.id).single(),
    ))!;
    expect(row['group_id'], gid);
    expect((row['total'] as num).toInt(), 24000);

    // 4. Settings on the Account tab: no gear, the list itself.
    router.go(Routes.account);
    await _waitFor(t, find.byKey(const Key('account-settings')), reason: 'account');
    expect(find.byTooltip('Account settings'), findsNothing);

    // Appearance is a sheet: Dark applies at once and the sheet closes; back to System.
    await _tapKey(t, 'settings-appearance');
    await _waitFor(t, find.byKey(const Key('appearance-mode')));
    await _tap(t, find.text('Dark'));
    expect(find.byKey(const Key('appearance-mode')), findsNothing);
    expect(
      Theme.of(t.element(find.byKey(const Key('settings-appearance')))).brightness,
      Brightness.dark,
    );
    await _tapKey(t, 'settings-appearance');
    await _tap(t, find.text('System'));
    expect(prefs.getString('theme_mode'), 'system');

    // Notifications: one page of grouped switches.
    await _tapKey(t, 'settings-notifications');
    await _waitFor(t, find.byKey(const Key('notif-section-push')));
    expect(find.byKey(const Key('notif-section-inapp')), findsOneWidget);
    await _back(t);

    // Security: one screen with the app lock switch.
    await _tapKey(t, 'settings-security');
    await _waitFor(t, find.byKey(const Key('security-app-lock')));
    await _back(t);

    // Home-screen widget: a sheet with "Hide amounts"; the row says so; then back on.
    await _tapKey(t, 'settings-widget');
    await _waitFor(t, find.byKey(const Key('widget-hide-amounts')));
    await _tap(t, find.byType(Switch).last);
    await _back(t);
    expect(find.text('Amounts hidden'), findsOneWidget);
    await _tapKey(t, 'settings-widget');
    await _tap(t, find.byType(Switch).last);
    await _back(t);
    expect(find.text('Amounts hidden'), findsNothing);

    // Sign out asks first (cancelled here).
    await _tapKey(t, 'settings-sign-out');
    await _waitFor(t, find.byKey(const Key('sign-out-confirm')));
    await _tap(t, find.text('Cancel'));
    expect(find.byKey(const Key('sign-out-confirm')), findsNothing);
    expect(services.auth.currentUser?.id, uid);

    // Delete account asks to type DELETE before its button works (not pressed here).
    await _tapKey(t, 'settings-delete-account');
    await _waitFor(t, find.byKey(const Key('delete-confirm')));
    await t.enterText(_field('delete-confirm'), 'DELETE');
    await _pumpFor(t, const Duration(milliseconds: 500));
    expect(find.byKey(const Key('delete-account')), findsOneWidget);
    await _back(t);

    debugPrint('D-033-MINIMAL-ENTRY OK expense=${saved.id}');
  });
}
