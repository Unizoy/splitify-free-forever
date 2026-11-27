// D-032 end to end on the emulator against the DEV project: add an expense on the one-screen editor
// from a group page (real keyboards for the description and the amount), split it by shares in the Paid by ·
// split sheet, pick the date, save, and see it in the group list with the right amount and balance — phone
// = server. The test group is soft-deleted at the end.
//   flutter test integration_test/simple_expense_test.dart -d emulator-5554 \
//     --dart-define-from-file=secrets/env.dev.json --dart-define=PIN_HOST_IP=<ip resolved on the PC>
// With --dart-define=UI_HOLD=8 it prints `UI-CAPTURE <name>` and holds each state for the host screenshots
// (tool/e2e/capture_simple_expense.ps1). Build it side by side with an installed store build:
// SPLITIFY_APP_ID_SUFFIX=.qa (android/app/build.gradle.kts, S-310).
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
import 'package:splitify/core/money/money_formatter.dart';
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
  await _pumpFor(t, const Duration(milliseconds: 500));
}

Future<void> _waitFor(WidgetTester t, Finder f, {String reason = ''}) =>
    pumpUntil(t, () => f.evaluate().isNotEmpty, reason: reason.isEmpty ? '$f' : reason);

/// Holds the screen for the host captures (real-time waits, S-086).
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

Map<String, int> _ints(Object? json) {
  final m = json is String ? jsonDecode(json) as Map<String, Object?> : json! as Map;
  return {for (final e in m.entries) e.key as String: (e.value as num).toInt()};
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D-032: add an expense on one screen; the group shows its amount and balance', (
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

    // A separate test group (never the owner's sample groups): me, Asha and Rahul.
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
    await sync();
    // Tidy up the dev project even when a check fails: soft-delete the test group (restorable).
    addTearDown(() async {
      await groups.delete(gid, gid);
      await sync();
    });

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
    await _waitFor(t, find.byKey(const Key('group-add-expense')), reason: 'group page');
    await _pumpFor(t, const Duration(seconds: 1));

    // 1. The one screen, empty (the description has the focus; the test keyboard stands in).
    await _tap(t, find.byKey(const Key('group-add-expense')));
    await _waitFor(t, find.byKey(const Key('expense-amount')), reason: 'editor');
    FocusManager.instance.primaryFocus?.unfocus();
    await _capture(t, 'empty');

    // 2. Save with nothing typed: both inline errors, nothing saved, nothing lost.
    await _tap(t, find.byKey(const Key('expense-save')));
    FocusManager.instance.primaryFocus?.unfocus();
    expect(find.text('Add a description'), findsOneWidget);
    expect(find.text('Enter an amount'), findsOneWidget);
    await _capture(t, 'validation-error');

    // 3. The phone's real keyboards (bug 2): the description gets only the text keyboard, the amount only
    // the number keyboard — no custom pad on top. The test keyboard steps aside for these two shots.
    binding.testTextInput.unregister();
    await t.tap(_field('expense-description'));
    await _pumpFor(t, const Duration(seconds: 2));
    expect(find.byKey(const Key('key-d1')), findsNothing);
    await _capture(t, 'keyboard-description');
    await t.tap(_field('expense-amount'));
    await _pumpFor(t, const Duration(seconds: 2));
    expect(find.byKey(const Key('key-d1')), findsNothing);
    await _capture(t, 'keyboard-amount');
    FocusManager.instance.primaryFocus?.unfocus();
    await _pumpFor(t, const Duration(seconds: 2));
    binding.testTextInput.register();

    // 4. Filled: description (auto-category), amount and the summary pill.
    await t.enterText(_field('expense-description'), 'Dinner at Thalassa');
    await t.enterText(_field('expense-amount'), '1250.50');
    await _pumpFor(t, const Duration(milliseconds: 800));
    FocusManager.instance.primaryFocus?.unfocus();
    expect(find.text('Paid by You · split equally'), findsOneWidget);
    await _capture(t, 'filled');
    await _capture(t, 'filled-dark');

    // 5. The Paid by · split sheet with a non-equal split: me 2 shares, Asha and Rahul 1 each.
    await _tap(t, find.byKey(const Key('split-summary')));
    await _waitFor(t, find.byKey(const Key('split-kind')));
    await _tap(
      t,
      find.descendant(of: find.byKey(const Key('split-kind')), matching: find.text('1:2')),
    );
    await _tap(
      t,
      find.descendant(of: find.byKey(ValueKey('shares-$me')), matching: find.byIcon(AppIcons.plus)),
    );
    expect(t.widget<Text>(find.byKey(const Key('split-footer'))).data, '4 shares in total');
    await _capture(t, 'paid-split-sheet');
    await _tap(t, find.byKey(const Key('paid-split-done')));
    expect(find.text('Paid by You · split by shares'), findsOneWidget);

    // 6. The date picker (today, IST on this phone).
    await _tap(t, find.byKey(const Key('expense-date')));
    await _waitFor(t, find.byKey(const Key('date-today')));
    await _capture(t, 'date-picker');
    await _tap(t, find.byKey(const Key('date-today')));

    // 7. Save: back on the group page, offline first, then synced.
    await _tap(t, find.byKey(const Key('expense-save')));
    await _waitFor(t, find.byKey(const Key('group-add-expense')), reason: 'back on the group');
    final saved = await (db.select(db.expenses)..where((e) => e.groupId.equals(gid))).getSingle();
    expect(saved.total, 125050);
    expect(saved.splitKind, 'shares');
    expect(_ints(saved.payers), {me: 125050});
    final shares = _ints(saved.shares);
    expect(shares.keys.toSet(), {me, asha, rahul});
    expect(shares.values.fold<int>(0, (a, b) => a + b), 125050);
    expect(shares[me], 62525);
    await sync();
    final synced = await (db.select(db.expenses)..where((e) => e.id.equals(saved.id))).getSingle();
    expect(synced.syncState, SyncState.synced, reason: '${engine.lastError}');

    // Phone = server: the row and my balance.
    final row = (await t.runAsync(
      () => client.from('expenses').select().eq('id', saved.id).single(),
    ))!;
    expect((row['total'] as num).toInt(), 125050);
    expect(_ints(row['shares']), shares);
    final net = 125050 - shares[me]!;
    final balances = (await t.runAsync(
      () => client.rpc<Map<String, dynamic>>('group_balances', params: {'group_id': gid}),
    ))!;
    expect(_ints((balances['currencies'] as Map)['INR']['nets'])[me], net);

    // The group list shows the expense with its amount, and the group says I am owed the rest.
    await _pumpFor(t, const Duration(seconds: 2));
    expect(find.text('Dinner at Thalassa'), findsWidgets);
    expect(find.textContaining('1,250.50'), findsWidgets);
    expect(find.byKey(const Key('group-status-owed')), findsOneWidget);
    expect(find.textContaining(MoneyFormatter.list.format(net, 'INR')), findsWidgets);
    await _capture(t, 'saved-list');

    await _tap(t, find.byKey(ValueKey('expense-${saved.id}')));
    await _waitFor(t, find.text('Dinner at Thalassa'));
    await _pumpFor(t, const Duration(seconds: 1));
    expect(find.textContaining('1,250.50'), findsWidgets);
    await _capture(t, 'saved-detail');

    debugPrint('D-032-SIMPLE-EXPENSE OK net=$net');
  });
}
