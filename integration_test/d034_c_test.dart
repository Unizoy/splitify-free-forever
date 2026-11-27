// D-034 WP-C device e2e (TC-D34C-06) on emulator-5554 against the DEV project as e2e-a, with e2e-b as the
// second person through the harness:
//   - the group page shows who owes whom from my side (C1);
//   - trip dates + weekly settle-up reminders saved on the form reach the server (C4);
//   - the group notes edited with REAL airplane mode on are kept in the outbox ("not synced yet"), sync when the
//     network is back and e2e-b reads them (and gets an in-app notification, never a push) (C5);
//   - a trip-end nudge, forced on dev by running `private.send_settle_nudges()` when the test prints
//     `E2E-NUDGE <group>`, reaches my bell and the group's activity (C4). The .qa build has no FCM (S-310): push
//     delivery is checked on the server row (`push_status`), not in `dumpsys notification`;
//   - the Groups filter is kept across a restart (new container + widget tree on the same preferences) (C3);
//   - after everyone paid, the Expenses tab folds the settled history (C2); the search icon opens group search (C6).
// Run under the emulator lock with the host script (airplane mode on `E2E-NET off|on`, light + dark screenshots
// on `UI-CAPTURE <name>`, the nudge on `E2E-NUDGE`):
//   powershell -Command ". tool\env.ps1; & tool\e2e\capture_d034_c.ps1"
// Built side by side as com.unizoy.splitify.qa with --no-uninstall (S-310, S-329). The group is deleted at the end.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:splitify/data/sync/network_status.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/groups/application/group_extras_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/domain/group_extras.dart';
import 'package:splitify/features/search/presentation/search_screen.dart' show SearchScreen;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

/// Seconds each state stays up for the host's light + dark captures (`UI_HOLD`, 0 = none).
const _hold = int.fromEnvironment('UI_HOLD');

final _network = ConnectivityNetworkStatus();

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _capture(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(milliseconds: 1200));
  if (_hold == 0) return;
  debugPrint('UI-CAPTURE $name');
  await _pumpFor(t, const Duration(seconds: _hold));
}

/// Asks the host to switch airplane mode and waits until the phone sees it.
Future<void> _net(WidgetTester t, {required bool on}) async {
  debugPrint('E2E-NET ${on ? 'on' : 'off'}');
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    final now = (await t.runAsync(_network.isOnline))!;
    if (now == on) {
      debugPrint('network is ${on ? 'on' : 'off'}');
      return;
    }
    await _pumpFor(t, const Duration(milliseconds: 500));
  }
  fail('network did not turn ${on ? 'on' : 'off'}');
}

Future<void> _until(
  WidgetTester t,
  bool Function() ok,
  String reason, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('Timed out: $reason');
    await _pumpFor(t, const Duration(milliseconds: 200));
  }
}

Future<void> _tap(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
  }
  await t.ensureVisible(f);
  await _pumpFor(t, const Duration(milliseconds: 300));
  await t.tap(f);
  await _pumpFor(t, const Duration(milliseconds: 1200));
}

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D-034 WP-C lines, trip dates, notes offline -> e2e-b, nudge, filter restart, settled',
    (t) async {
      final env = devEnv();
      final services = await initRemote(env);
      await services.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
      final uid = services.auth.currentUser!.id;
      final client = Supabase.instance.client;
      final b = (await t.runAsync(() => HarnessUser.signIn(env, 'e2e-b')))!;
      addTearDown(() => t.runAsync(b.dispose));
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      // The phone's real preferences (the filter must survive the "restart" below).
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(GroupFilterController.storageKey);
      addTearDown(() => prefs.remove(GroupFilterController.storageKey));

      ProviderContainer newContainer() => ProviderContainer(
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
      var container = newContainer();
      addTearDown(() => container.dispose());
      Future<void> sync() => t.runAsync(() async {
        final engine = container.read(syncEngineProvider);
        await engine.sync();
        await engine.sync();
      });

      // ---- The test group: me, Asha (name only) and e2e-b (joins with the code).
      final groups = container.read(groupsRepositoryProvider);
      final members = container.read(membersRepositoryProvider);
      final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
      final name = 'Goa (E2E D034C $stamp)';
      final gid = (await t.runAsync(
        () => groups.create(name: name, ownerName: 'Mohit', ownerUserId: uid, type: 'trip'),
      ))!;
      final asha = (await t.runAsync(() => members.addNameOnly(gid, 'Asha')))!;
      await sync();
      addTearDown(() async {
        await t.runAsync(() => container.read(groupsRepositoryProvider).delete(gid, gid));
        await sync();
      });
      final code = (await t.runAsync(
        () => (db.select(db.groups)..where((g) => g.id.equals(gid))).getSingle(),
      ))!.inviteCode;
      expect(code, isNotNull, reason: 'the group reached the server');
      final joined = (await t.runAsync(() => b.rpc('join_group', {'code': code})))!;
      expect(joined['group_id'], gid);
      await sync();
      final rows = (await t.runAsync(
        () => (db.select(db.groupMembers)..where((m) => m.groupId.equals(gid))).get(),
      ))!;
      final me = rows.singleWhere((m) => m.userId == uid).id;
      final bina = rows.singleWhere((m) => m.userId == b.id).id;
      final expenses = container.read(expensesRepositoryProvider);
      final today = DateTime.now();
      await t.runAsync(
        () => expenses.save(gid, {
          'kind': 'expense',
          'description': 'Beach shack dinner',
          'category': 'food.dining_out',
          'date': _day(today.subtract(const Duration(days: 2))),
          'currency': 'INR',
          'total': 90000,
          'payers': {me: 90000},
          'shares': {me: 30000, asha: 30000, bina: 30000},
          'split_kind': 'equal',
        }),
      );
      // Trip dates (the trip ended yesterday) and weekly reminders, as the form saves them.
      await t.runAsync(
        () => container
            .read(groupActionsProvider)
            .update(
              gid,
              name: name,
              type: 'trip',
              currency: 'INR',
              tripStartsOn: today.subtract(const Duration(days: 4)),
              tripEndsOn: today.subtract(const Duration(days: 1)),
              reminder: SettleReminder.weekly,
            ),
      );
      await sync();
      expect(await t.runAsync(() => db.select(db.outbox).get()), isEmpty, reason: 'synced');
      final server = (await t.runAsync(
        () => b.client
            .from('groups')
            .select('trip_starts_on, trip_ends_on, settle_reminder')
            .eq('id', gid)
            .single(),
      ))!;
      expect(server['trip_ends_on'], _day(today.subtract(const Duration(days: 1))));
      expect(server['settle_reminder'], 'weekly');

      Future<GoRouterLike> app(String location) async {
        final router = buildRouter(initialLocation: location);
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              debugShowCheckedModeBanner: false,
            ),
          ),
        );
        await _pumpFor(t, const Duration(seconds: 2));
        return GoRouterLike(router);
      }

      // ---- C1: who owes whom on the group page.
      var r = await app('/groups/$gid');
      await _until(
        t,
        () => find.byKey(Key('group-line-INR-$asha')).evaluate().isNotEmpty,
        'the lines',
        timeout: const Duration(seconds: 60),
      );
      expect(find.byKey(Key('group-line-INR-$bina')), findsOneWidget);
      expect(find.byKey(const Key('group-trip-dates')), findsOneWidget);
      await _capture(t, 'group-lines');

      // ---- C4: the form's trip dates and reminders.
      r.push('/groups/$gid/edit');
      await _pumpFor(t, const Duration(seconds: 2));
      FocusManager.instance.primaryFocus?.unfocus();
      await t.scrollUntilVisible(
        find.byKey(const Key('group-reminder-next')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('trip-end')), findsOneWidget);
      await _capture(t, 'form-trip');
      r.pop();
      await _pumpFor(t, const Duration(seconds: 1));

      // ---- C5: the notes, edited offline.
      const notes = 'Villa Sol, 12 Beach Road\nWi-Fi: VillaSol-5G / goa2026';
      await _net(t, on: false);
      try {
        r.push('/groups/$gid/settings');
        await _pumpFor(t, const Duration(seconds: 2));
        await _tap(t, find.byKey(const Key('settings-notes')));
        expect(find.text('Group notes'), findsWidgets);
        await t.enterText(find.byKey(const Key('board-text')), notes);
        await _pumpFor(t, const Duration(milliseconds: 500));
        FocusManager.instance.primaryFocus?.unfocus();
        await _tap(t, find.byKey(const Key('board-save')));
        final queued = (await t.runAsync(() => db.select(db.outbox).get()))!;
        expect(queued.map((o) => (o.entity, o.recordId)), contains(('group', gid)));
        expect(queued.last.payload, contains('whiteboard'));
        // Reopened offline: my edit, not synced yet.
        await _tap(t, find.byKey(const Key('settings-notes')));
        expect(find.textContaining('Last edited by you'), findsOneWidget);
        expect(find.text('Not synced yet'), findsOneWidget);
        await _capture(t, 'notes-offline');
        r.pop();
        await _pumpFor(t, const Duration(seconds: 1));
        await _capture(t, 'settings-notes');
        r.pop();
      } finally {
        await _net(t, on: true);
      }
      await sync();
      expect(await t.runAsync(() => db.select(db.outbox).get()), isEmpty, reason: 'notes synced');
      final seen = (await t.runAsync(
        () => b.client.from('groups').select('whiteboard').eq('id', gid).single(),
      ))!;
      expect(seen['whiteboard'], notes, reason: 'e2e-b reads the notes');
      final bNote = (await t.runAsync(
        () => b.client
            .from('notifications')
            .select('type, body, inapp, push_status')
            .eq('group_id', gid)
            .eq('type', 'whiteboard_updated'),
      ))!;
      expect(bNote, hasLength(1));
      expect(bNote.single['push_status'], 'skipped', reason: 'notes edits are never pushed');

      // ---- C4: the trip-end nudge (the host runs private.send_settle_nudges() on dev).
      debugPrint('E2E-NUDGE $gid');
      List<Map<String, dynamic>> nudges = const [];
      final end = DateTime.now().add(const Duration(minutes: 8));
      while (nudges.isEmpty && DateTime.now().isBefore(end)) {
        await _pumpFor(t, const Duration(seconds: 5));
        nudges = (await t.runAsync(
          () => client
              .from('notifications')
              .select('type, kind, body, push_status')
              .eq('group_id', gid)
              .eq('type', 'settle_nudge'),
        ))!;
      }
      expect(nudges, hasLength(1), reason: 'the nudge reached my bell');
      expect(nudges.single['kind'], 'reminders');
      expect(nudges.single['body'], "Your trip is over. Time to settle up: you're owed ₹600");
      final bNudge = (await t.runAsync(
        () => b.client
            .from('notifications')
            .select('body')
            .eq('group_id', gid)
            .eq('type', 'settle_nudge'),
      ))!;
      expect(bNudge.single['body'], 'Your trip is over. Time to settle up: you owe ₹300');
      debugPrint('NUDGE-OK ${nudges.single['push_status']}');
      await sync();
      r.go('/notifications');
      await _pumpFor(t, const Duration(seconds: 3));
      await _capture(t, 'nudge-bell');
      r.go('/groups/$gid');
      await _pumpFor(t, const Duration(seconds: 2));
      await t.scrollUntilVisible(
        find.text('The trip is over: reminder to settle up sent'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await _capture(t, 'nudge-activity');

      // ---- C3: the filter, kept across a restart.
      r.go('/groups');
      await _pumpFor(t, const Duration(seconds: 2));
      await _tap(t, find.byKey(const Key('groups-filter')));
      await _capture(t, 'filter-sheet');
      await _tap(t, find.byKey(const Key('groups-filter-owedToMe')));
      expect(find.byKey(Key('group-card-$gid')), findsOneWidget);
      await _capture(t, 'groups-filtered');
      expect(prefs.getString(GroupFilterController.storageKey), 'owedToMe');
      await t.pumpWidget(const SizedBox());
      await _pumpFor(t, const Duration(seconds: 1));
      container.dispose();
      container = newContainer();
      r = await app('/groups');
      await _until(
        t,
        () => find.byKey(Key('group-card-$gid')).evaluate().isNotEmpty,
        'home after restart',
        timeout: const Duration(seconds: 60),
      );
      expect(container.read(groupFilterProvider), GroupFilter.owedToMe);
      expect(find.bySemanticsLabel('Filter: Owe me'), findsOneWidget);

      // ---- C2: everyone pays; the history folds. C6: search from the group.
      final payments = container.read(paymentsRepositoryProvider);
      for (final from in [asha, bina]) {
        await t.runAsync(
          () => payments.save(gid, {
            'from_member': from,
            'to_member': me,
            'amount': 30000,
            'currency': 'INR',
            'date': _day(today),
            'method': 'cash',
          }),
        );
      }
      await sync();
      r.go('/groups/$gid');
      await _pumpFor(t, const Duration(seconds: 3));
      final settled = find.byKey(const Key('expenses-settled'));
      await t.scrollUntilVisible(settled, 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Show 3 settled expenses'), findsOneWidget);
      await _capture(t, 'settled');
      await _tap(t, settled);
      expect(find.text('Hide settled expenses'), findsOneWidget);
      // Back to the top of the page: the hero's search icon must be on screen, not just built inside the
      // cache extent above it (final QA: the tap missed while the icon sat under the status-bar band).
      t.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
      await _pumpFor(t, const Duration(milliseconds: 800));
      await t.tap(find.byKey(const Key('group-search')));
      await _pumpFor(t, const Duration(milliseconds: 1500));
      // A pushed page: the router's base location stays the group, so read the search page's own state.
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(
        GoRouterState.of(t.element(find.byType(SearchScreen))).uri.toString(),
        '/search?group=$gid',
      );
    },
  );
}

/// The few router calls the test needs, and where it is now.
class GoRouterLike {
  GoRouterLike(this.router);

  final GoRouter router;

  void push(String location) => unawaited(router.push<Object?>(location));
  void go(String location) => router.go(location);
  void pop() => router.pop();
  String get location => router.routerDelegate.currentConfiguration.uri.toString();
}
