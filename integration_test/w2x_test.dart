// W2-X end to end on the emulator against the DEV project (e2e-a + a fresh second account):
//   F11 "With you and" several friends: a linked friend + a name-only friend → a hidden ad-hoc group made
//       offline, synced, the friend's account linked by the server, visible to them only (RLS), they get the
//       notification; the Groups grid hides it; each friend's page shows it.
//   F15 "From contacts" opens the system contact picker (the PC-side watcher presses Back: nothing is added).
//   P-10 "Save as group default" in the paid/split sheet: the next expense starts with that payer.
//   P-9 "Show in INR" on the Home card from a saved conversion.
//   flutter test integration_test/w2x_test.dart -d emulator-5554 --no-uninstall \
//     --dart-define-from-file=secrets/env.dev.json --dart-define=PIN_HOST_IP=<ip>
// Built as the .qa copy (SPLITIFY_APP_ID_SUFFIX=.qa). Prints `W2X-SHOT <name>` (the watcher takes a screenshot)
// and `W2X-CONTACTS-OPEN` (the watcher presses Back). Test groups are soft-deleted at the end.
import 'package:drift/drift.dart' show BooleanExpressionOperators;
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
import 'package:splitify/features/friends/application/friend_identity.dart';
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

Future<void> _waitFor(WidgetTester t, Finder f, {String reason = '', int seconds = 30}) =>
    pumpUntil(
      t,
      () => f.evaluate().isNotEmpty,
      timeout: Duration(seconds: seconds),
      reason: reason.isEmpty ? '$f' : reason,
    );

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

/// Asks the PC-side watcher (tool/e2e/capture_w2x.ps1) for screenshots: light, then dark (the watcher switches
/// the emulator's dark mode; the app follows the system).
Future<void> _shot(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(milliseconds: 900));
  debugPrint('W2X-SHOT $name');
  await _pumpFor(t, const Duration(seconds: 5));
  debugPrint('W2X-SHOT $name-dark');
  await _pumpFor(t, const Duration(seconds: 9));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('W2-X: several friends, contacts, default payer, show in INR', (t) async {
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

    // A trip with two name-only people; the second account then claims Bina.
    final stamp = DateTime.now().millisecondsSinceEpoch % 1000000;
    final tag = 'W2x$stamp';
    final groups = container.read(groupsRepositoryProvider);
    final members = container.read(membersRepositoryProvider);
    final tripId = await groups.create(
      name: 'Trip $tag',
      ownerName: 'Mohit',
      ownerUserId: uid,
      type: 'trip',
    );
    final binaId = await members.addNameOnly(tripId, 'Bina $tag');
    final rahulId = await members.addNameOnly(tripId, 'Rahul $tag');
    await sync();
    final made = <String>[tripId];
    addTearDown(() async {
      for (final g in made) {
        await groups.delete(g, g);
      }
      await sync();
    });
    final bina = (await t.runAsync(() => HarnessUser.signIn(env, 'e2e-w2x-$stamp')))!;
    addTearDown(() => t.runAsync(bina.dispose));
    final code =
        (await t.runAsync(
              () => client.from('groups').select('invite_code').eq('id', tripId).single(),
            ))!['invite_code']!
            as String;
    final joined = (await t.runAsync(
      () => bina.rpc('join_group', {'code': code, 'claim_member_id': binaId}),
    ))!;
    expect(joined['group_id'], tripId, reason: '$joined');
    await sync();

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
    await _waitFor(t, find.byKey(Key('group-card-$tripId')), reason: 'home', seconds: 90);
    debugPrint('UI-READY');
    await _pumpFor(t, const Duration(seconds: 4));

    // ---- F11: the + → Bina (an account) → "+" → Rahul (name only) → one hidden group of the three.
    await _tapKey(t, 'nav-add');
    await _waitFor(t, find.byKey(const Key('expense-amount')), reason: 'editor');
    await t.enterText(_field('expense-description'), 'Dinner $tag');
    await t.enterText(_field('expense-amount'), '900');
    await _pumpFor(t, const Duration(milliseconds: 600));
    FocusManager.instance.primaryFocus?.unfocus();
    await _tapKey(t, 'expense-with-choose');
    await _waitFor(t, find.byKey(const Key('with-picker')), reason: 'picker');
    await t.enterText(find.byKey(const Key('with-search')), 'Bina $tag');
    await _pumpFor(t, const Duration(milliseconds: 600));
    final binaKey = 'u:${bina.id}';
    await _tapKey(t, 'with-friend-$binaKey');
    // A linked friend's own group is made on the server once (S-120).
    await _waitFor(
      t,
      find.byKey(const Key('expense-with-add')),
      reason: 'Bina picked',
      seconds: 60,
    );
    await _tapKey(t, 'expense-with-add');
    await _waitFor(t, find.byKey(const Key('with-contacts')), reason: 'add person sheet');
    await _shot(t, 'add-person');

    // F15: the system contact picker opens; the watcher presses Back and nothing is added.
    await _tap(t, find.byKey(const Key('with-contacts')));
    debugPrint('W2X-CONTACTS-OPEN');
    await _pumpFor(t, const Duration(seconds: 6));
    expect(find.byKey(const Key('with-contacts')), findsOneWidget, reason: 'back from the picker');

    await t.enterText(find.byKey(const Key('with-search')), 'Rahul $tag');
    await _pumpFor(t, const Duration(milliseconds: 600));
    await _tapKey(t, 'with-friend-m:$rahulId');
    await _waitFor(t, find.byKey(Key('expense-with-remove-m:$rahulId')), reason: 'three people');
    expect(find.byKey(Key('expense-with-person-$binaKey')), findsOneWidget);
    expect(find.text('Dinner $tag'), findsOneWidget);
    await _shot(t, 'editor-people');
    await _tapKey(t, 'expense-save');
    await pumpUntil(
      t,
      () => find.byKey(const Key('expense-amount')).evaluate().isEmpty,
      reason: 'editor closed',
    );
    final saved = await (db.select(
      db.expenses,
    )..where((e) => e.description.equals('Dinner $tag'))).getSingle();
    final adhocId = saved.groupId;
    made.insert(0, adhocId);
    final adhoc = await (db.select(db.groups)..where((g) => g.id.equals(adhocId))).getSingle();
    expect(adhoc.type, 'adhoc');
    final adhocMembers = await (db.select(
      db.groupMembers,
    )..where((m) => m.groupId.equals(adhocId))).get();
    expect(adhocMembers.length, 3);
    expect(
      adhocMembers.map((m) => m.id),
      containsAll([derivedMemberId(binaId, adhocId), derivedMemberId(rahulId, adhocId)]),
    );
    await sync();
    final synced = await (db.select(db.expenses)..where((e) => e.id.equals(saved.id))).getSingle();
    expect(synced.syncState, SyncState.synced, reason: '${engine.lastError}');
    expect(
      (await (db.select(db.groups)..where((g) => g.id.equals(adhocId))).getSingle()).type,
      'adhoc',
    );

    // The server: one hidden group, Bina linked to her account; she sees it and got the notification.
    final row = (await t.runAsync(
      () => client.from('groups').select('type, is_adhoc').eq('id', adhocId).single(),
    ))!;
    expect(row['is_adhoc'], isTrue);
    expect(row['type'], 'other');
    final binaRow = (await t.runAsync(
      () => client
          .from('group_members')
          .select('user_id')
          .eq('id', derivedMemberId(binaId, adhocId))
          .single(),
    ))!;
    expect(binaRow['user_id'], bina.id);
    final seen = (await t.runAsync(
      () => bina.client.from('groups').select('id, is_adhoc').eq('id', adhocId),
    ))!;
    expect(seen.length, 1, reason: 'Bina sees the ad-hoc group');
    final told = (await t.runAsync(
      () => bina.client
          .from('notifications')
          .select('type, title')
          .eq('group_id', adhocId)
          .eq('type', 'expense_added'),
    ))!;
    expect(told.length, 1, reason: 'Bina is told about the expense');

    // The Groups grid never shows it; Rahul's page shows the trip and the three of us.
    router.go(Routes.groups);
    await _waitFor(t, find.byKey(Key('group-card-$tripId')), reason: 'home again');
    expect(find.byKey(Key('group-card-$adhocId')), findsNothing);
    router.go('/friends/m:$rahulId');
    await _waitFor(t, find.byKey(ValueKey('friend-group-$adhocId')), reason: 'Rahul page');
    expect(find.byKey(ValueKey('friend-group-$tripId')), findsOneWidget);
    expect(find.textContaining('You, Bina $tag & Rahul $tag'), findsWidgets);
    await _shot(t, 'friend-adhoc');

    // ---- P-10: Bina paid, "Save as group default"; the next expense starts with Bina paying.
    router.go('/expense/new?group=$tripId');
    await _waitFor(t, find.byKey(const Key('expense-amount')), reason: 'trip editor');
    await t.enterText(_field('expense-description'), 'Taxi $tag');
    await t.enterText(_field('expense-amount'), '300');
    await _pumpFor(t, const Duration(milliseconds: 600));
    FocusManager.instance.primaryFocus?.unfocus();
    await _tapKey(t, 'split-summary');
    await _waitFor(t, find.byKey(Key('payer-$binaId')), reason: 'paid/split sheet');
    await _tapKey(t, 'payer-$binaId');
    await _tapKey(t, 'paid-split-save-default');
    await _shot(t, 'save-default');
    await _tapKey(t, 'paid-split-done');
    await _tapKey(t, 'expense-save');
    await pumpUntil(
      t,
      () => find.byKey(const Key('expense-amount')).evaluate().isEmpty,
      reason: 'saved',
    );
    await sync();
    final def =
        (await t.runAsync(
              () => client.from('groups').select('default_split').eq('id', tripId).single(),
            ))!['default_split']!
            as Map;
    expect(def['payer'], binaId);
    router.go('/expense/new?group=$tripId');
    await _waitFor(t, find.byKey(const Key('split-summary')), reason: 'next editor');
    expect(find.textContaining('Paid by Bina $tag'), findsOneWidget);
    await t.binding.handlePopRoute();
    await _pumpFor(t, const Duration(seconds: 1));

    // ---- P-9: a dollar expense with its saved conversion; "Show in INR" on Home counts it.
    final tripMembers = await _members(db, tripId);
    final meTrip = _meIn(tripMembers, uid);
    await container.read(expensesRepositoryProvider).save(tripId, {
      'description': 'Museum $tag',
      'date': '2026-11-27',
      'currency': 'USD',
      'total': 2000,
      'split_kind': 'equal',
      'payers': {meTrip: 2000},
      'shares': _equal(tripMembers, 2000),
      'fx_rate': '84.000000',
      'fx_rate_date': '2026-11-27',
      'fx_source': 'manual',
      'fx_currency': 'INR',
      'fx_total': 168000,
      'fx_payers': {meTrip: 168000},
      'fx_shares': _equal(tripMembers, 168000),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await sync();
    router.go(Routes.groups);
    await _waitFor(t, find.byKey(const Key('show-in-currency')), reason: 'show in INR chip');
    await _tapKey(t, 'show-in-currency');
    await _waitFor(t, find.byKey(const Key('groups-overall-converted')), reason: 'converted total');
    expect(find.text('In INR · saved rates'), findsOneWidget);
    await _shot(t, 'home-inr');
    await _tapKey(t, 'show-in-currency');
    expect(find.byKey(const Key('groups-overall-converted')), findsNothing);

    debugPrint('W2X-E2E OK adhoc=$adhocId expense=${saved.id}');
  });
}

Future<List<LocalMember>> _members(AppDatabase db, String groupId) async {
  final ms =
      await (db.select(db.groupMembers)..where(
            (m) => m.groupId.equals(groupId) & m.status.equals('active') & m.deletedAt.isNull(),
          ))
          .get();
  ms.sort((a, b) => a.position.compareTo(b.position));
  return ms;
}

String _meIn(List<LocalMember> ms, String uid) => ms.firstWhere((m) => m.userId == uid).id;

/// [total] split equally in fixed order (leftover units to the first people, rule 2).
Map<String, int> _equal(List<LocalMember> ms, int total) {
  final n = ms.length;
  final base = total ~/ n;
  final left = total - base * n;
  return {for (var i = 0; i < n; i++) ms[i].id: base + (i < left ? 1 : 0)};
}
