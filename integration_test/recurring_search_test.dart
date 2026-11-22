// Phase 16 (TC-34-02 integ, #12 offline template creation syncs): offline, add a monthly "Flat rent" through
// the editor's Repeat picker, see its repeat on the detail screen, find it with the offline search by
// description, notes, person and amount ("1,200"), then go online: the server stores the template with its
// own next_date and the activity; "Stop repeating" from the repeat sheet syncs too. Runs against the DEV
// project as e2e-a:
//   flutter test integration_test/recurring_search_test.dart -d emulator-5554 \
//     --dart-define-from-file=secrets/env.dev.json --dart-define=PIN_HOST_IP=<ip resolved on the PC>
// With --dart-define=UI_HOLD=30 it prints `UI-CAPTURE <name>` and holds each reviewed screen
// (.claude/skills/ui-review/scripts/capture_markers.ps1 takes light/dark/200 % shots).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/rules/recurrence.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/search/presentation/search_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/net_pin.dart';

/// Seconds each reviewed screen stays up for the host captures (`UI_HOLD`, 0 = no hold).
const _hold = int.fromEnvironment('UI_HOLD');

/// The real server, switched off while "offline" (every call fails like a dropped network).
class SwitchableRemote implements RemoteApi {
  SwitchableRemote(this.inner);

  final RemoteApi inner;
  bool online = false;

  void _check() {
    if (!online) throw const NetworkException('offline (test)');
  }

  @override
  Future<ApplyResponse> applyMutations(List<Map<String, Object?>> batch) {
    _check();
    return inner.applyMutations(batch);
  }

  @override
  Future<PullPage> pullChanges({
    required Map<String, int> cursors,
    required int userSeq,
    int pageSize = 500,
  }) {
    _check();
    return inner.pullChanges(cursors: cursors, userSeq: userSeq, pageSize: pageSize);
  }

  @override
  Future<void> refreshSession() => inner.refreshSession();
}

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
  await _pumpFor(t, const Duration(milliseconds: 400));
}

/// Prints the capture marker and holds without starving Android's input (LEARNINGS phase 07).
Future<void> _capture(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(milliseconds: 600));
  debugPrint('UI-CAPTURE $name');
  if (_hold <= 0) return;
  final end = DateTime.now().add(const Duration(seconds: _hold));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await t.pump();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // TC-34-02, #12 (offline creation of templates syncs)
  testWidgets('repeat a bill offline, find it with search, sync, stop repeating', (t) async {
    final env = Env.load();
    pinHost(Uri.parse(env.supabaseUrl).host);
    final remote = await initRemote(env);
    await remote.auth.signInWithPassword(email: 'e2e-a@splitify.test', password: env.e2ePassword);
    final uid = remote.auth.currentUser!.id;
    final client = Supabase.instance.client;
    final server = SwitchableRemote(SupabaseRemoteApi.client(client));
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        remoteApiProvider.overrideWithValue(server),
        authRepositoryProvider.overrideWithValue(remote.auth),
      ],
    );
    addTearDown(container.dispose);
    final engine = container.read(syncEngineProvider);

    Future<void> syncAll() async {
      await t.runAsync(() async {
        for (var i = 0; i < 4; i++) {
          await engine.sync();
          if ((await db.select(db.outbox).get()).isEmpty) break;
        }
      });
      expect(
        await t.runAsync(() => db.select(db.outbox).get()),
        isEmpty,
        reason: 'outbox not empty: ${engine.lastError}',
      );
    }

    // a) Offline: a group with Asha (name-only).
    final groups = container.read(groupsRepositoryProvider);
    final members = container.read(membersRepositoryProvider);
    final gid = await groups.create(
      name: 'E2E Flat ${DateTime.now().millisecondsSinceEpoch}',
      ownerName: 'E2E A',
      ownerUserId: uid,
    );
    await members.addNameOnly(gid, 'Asha');

    final router = buildRouter(initialLocation: ExpenseRoutes.add(gid));
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
    await _pumpFor(t, const Duration(seconds: 2));

    // b) The editor: ₹1,200 "Flat rent", split equally, Every month, a note.
    for (final ch in '1200'.split('')) {
      await _tap(t, find.byKey(Key('key-d$ch')));
    }
    await t.enterText(
      find.descendant(
        of: find.byKey(const Key('expense-description')),
        matching: find.byType(TextField),
      ),
      'Flat rent',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await _pumpFor(t, const Duration(milliseconds: 400));
    for (var i = 0; i < 3; i++) {
      await _tap(t, find.byKey(const Key('expense-next'))); // → Paid by → Split → Details
    }
    await _tap(t, find.byKey(const Key('repeat-monthly')));
    expect(find.byKey(const Key('repeat-hint')), findsOneWidget);
    await t.enterText(
      find.descendant(of: find.byKey(const Key('expense-notes')), matching: find.byType(TextField)),
      'maintenance included',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await t.ensureVisible(find.byKey(const Key('repeat-monthly')));
    await _capture(t, 'repeat-picker');
    await _tap(t, find.byKey(const Key('expense-save')));
    await _pumpFor(t, const Duration(seconds: 2));

    final expense = await (db.select(
      db.expenses,
    )..where((e) => e.description.equals('Flat rent'))).getSingle();
    final eid = expense.id;
    final template = await (db.select(
      db.recurringTemplates,
    )..where((r) => r.expenseId.equals(eid))).getSingle();
    expect(template.interval, 'monthly');
    expect(template.anchorDate, expense.date);
    expect(template.syncState, SyncState.pending);
    final queued = await db.select(db.outbox).get();
    expect(queued.map((o) => o.entity), containsAll(['expense', 'recurring']));

    // c) Detail: "Repeats · Every month"; the sheet shows the pending marker and the next copy.
    router.go(ExpenseRoutes.detail(eid));
    await _pumpFor(t, const Duration(seconds: 2));
    final tile = find.byKey(const Key('expense-recurring'));
    await t.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Every month'), findsOneWidget);
    await _capture(t, 'expense-repeat-detail');
    await _tap(t, tile);
    await _pumpFor(t, const Duration(milliseconds: 1500));
    expect(find.byKey(const Key('recurring-stop')), findsOneWidget);
    await _capture(t, 'repeat-sheet');
    Navigator.of(t.element(find.byKey(const Key('recurring-stop')))).pop();
    await _pumpFor(t, const Duration(seconds: 1));

    // d) Offline search finds it by each field (TC-34-02).
    router.go(SearchRoutes.search());
    await _pumpFor(t, const Duration(seconds: 1));
    final row = find.byKey(ValueKey('expense-$eid'));
    for (final q in ['flat ren', 'maintenance', 'asha', '1,200', '1200', 'rent 1200']) {
      await t.enterText(find.byKey(const Key('search-field')), q);
      await _pumpFor(t, const Duration(milliseconds: 800));
      expect(row, findsOneWidget, reason: 'search "$q"');
    }
    await t.enterText(find.byKey(const Key('search-field')), 'rent');
    FocusManager.instance.primaryFocus?.unfocus();
    await _pumpFor(t, const Duration(milliseconds: 800));
    await _capture(t, 'search-results');
    await t.enterText(find.byKey(const Key('search-field')), '1201');
    await _pumpFor(t, const Duration(milliseconds: 800));
    expect(row, findsNothing);
    expect(find.byKey(const Key('search-empty')), findsOneWidget);
    await t.enterText(find.byKey(const Key('search-field')), 'rent');
    await _pumpFor(t, const Duration(milliseconds: 600));
    await _tap(t, find.byKey(const Key('search-filter-group')));
    await _pumpFor(t, const Duration(milliseconds: 1500));
    await _capture(t, 'search-group-sheet');
    await _tap(t, find.byKey(Key('search-group-$gid')));
    await _pumpFor(t, const Duration(seconds: 1));
    expect(row, findsOneWidget, reason: 'group filter');

    // e) Online: the server stores the template with its own next_date and the activity.
    server.online = true;
    await syncAll();
    final rule = Recurrence.parse(interval: 'monthly', anchor: expense.date);
    final serverTemplate = await t.runAsync(
      () => client.from('recurring_templates').select().eq('id', template.id).single(),
    );
    expect(serverTemplate!['interval'], 'monthly');
    expect(serverTemplate['anchor_date'], expense.date);
    expect(serverTemplate['expense_id'], eid);
    expect(serverTemplate['active'], isTrue);
    expect(serverTemplate['next_date'], formatIsoDate(rule.firstCopy!));
    expect((serverTemplate['template'] as Map)['total'], 120000);
    final created = await t.runAsync(
      () => client
          .from('activity')
          .select()
          .eq('type', 'recurring_created')
          .eq('target_id', template.id),
    );
    expect(created, hasLength(1));
    final synced = await (db.select(
      db.recurringTemplates,
    )..where((r) => r.id.equals(template.id))).getSingle();
    expect(synced.syncState, SyncState.synced);
    expect(synced.nextDate, formatIsoDate(rule.firstCopy!));

    // f) Stop repeating from the sheet; it syncs.
    router.go(ExpenseRoutes.detail(eid));
    await _pumpFor(t, const Duration(seconds: 2));
    await t.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
    await _tap(t, tile);
    await _pumpFor(t, const Duration(milliseconds: 1500));
    await _tap(t, find.byKey(const Key('recurring-stop')));
    await _pumpFor(t, const Duration(milliseconds: 1500));
    await _tap(t, find.byKey(const Key('confirm-action')));
    await _pumpFor(t, const Duration(seconds: 1));
    await syncAll();
    final stopped = await t.runAsync(
      () => client.from('recurring_templates').select().eq('id', template.id).single(),
    );
    expect(stopped!['active'], isFalse);
    final stoppedRows = await t.runAsync(
      () => client
          .from('activity')
          .select()
          .eq('type', 'recurring_stopped')
          .eq('target_id', template.id),
    );
    expect(stoppedRows, hasLength(1));
    expect(find.text('Stopped'), findsOneWidget);

    // g) Tidy up the dev project: soft-delete the test group (creator only, restorable).
    await groups.delete(gid, gid);
    await t.runAsync(engine.sync);
  });
}
