// D-034 WP-A smart entry, end to end on the emulator against the DEV project (TC-D034-A-E2E):
//   1. two people: "You are owed the full amount" in one tap → saved offline first, then the server shares;
//   2. an itemized expense (400 A, 350 A+B, 150 B, ₹100 tax) saved offline first, then synced: the server takes
//      it (no SPLIT_SUM_MISMATCH), shares add up to 100000 paise, split_values.itemized has the lines; reopens in
//      the Items editor;
//   3. receipt scan with the real on-device text model: every fixture picture (pushed with adb by
//      tool/e2e/capture_d034_a.ps1) → the right total on ≥ 7 of 8; then Receipt → Scan → review → Use these
//      fills the amount (the picker is replaced by the pushed file: the system photo picker is not driven here);
//   4. delete, then Activity → the deleted expense → Restore → `expense_restored` on the server.
// Prints `UI-CAPTURE <name>` and holds UI_HOLD seconds so the script takes the screenshots.
//   powershell -Command ". tool\env.ps1; & tool\e2e\capture_d034_a.ps1"
// The app is the side-by-side .qa build with --no-uninstall (S-310 / S-329). The test groups are soft-deleted
// at the end; nothing is signed out.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/rules/receipt_text_parser.dart';
import 'package:splitify/features/account/application/theme_mode_controller.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/receipt_scan/application/receipt_ocr.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

const _hold = int.fromEnvironment('UI_HOLD');

/// The eight acceptance receipts and their totals (minor units).
const _receipts = <String, int>{
  'restaurant_gst': 99200,
  'grocery': 117400,
  'fuel': 200000,
  'pharmacy': 34560,
  'cab': 31200,
  'handwritten': 19000,
  'hotel_en': 1050100,
  'upi_screenshot': 25000,
};

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

/// Screenshot points for the host script: light, then dark (the script flips the emulator's night mode).
/// Real-time waits between pumps, so the engine presents the frames the host captures (a tight
/// `pump(duration)` loop leaves the screen black).
Future<void> _capture(WidgetTester t, String name, {bool dark = true}) async {
  await _pumpFor(t, const Duration(milliseconds: 900));
  if (_hold <= 0) return;
  Future<void> hold(int seconds) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await t.pump();
    }
  }

  debugPrint('UI-CAPTURE $name');
  await hold(_hold);
  if (!dark) return;
  debugPrint('UI-CAPTURE $name-dark');
  await hold(_hold + 2);
}

/// The real server, with a switch that makes the phone "offline" (every call fails like a dropped network),
/// so a save provably happens on the phone first and syncs later.
class _Switchable implements RemoteApi {
  _Switchable(this.inner);

  final RemoteApi inner;
  bool offline = false;

  void _check() {
    if (offline) throw const NetworkException('offline (test)');
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

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await _pumpFor(t, const Duration(milliseconds: 900));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D-034 A: two-person answer, itemize, receipt scan, restore from Activity', (
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
    // The app's own files folder: the capture script copies the pictures in with `run-as` (files adb puts in
    // Android/data are owned by shell and hidden from the app on Android 11+).
    final files = (await t.runAsync(getApplicationSupportDirectory))!;
    final receiptDir = '${files.path}/receipts';
    final remote = _Switchable(SupabaseRemoteApi.client(client));
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        remoteApiProvider.overrideWithValue(remote),
        balancesRemoteProvider.overrideWithValue(SupabaseBalancesRemote.fromClient(client)),
        groupsRemoteProvider.overrideWithValue(services.groups),
        authRepositoryProvider.overrideWithValue(services.auth),
        profileRemoteProvider.overrideWithValue(services.profiles),
        // The pushed picture instead of the system photo picker; the text model is the real one.
        receiptImagePickerProvider.overrideWithValue((_) async => '$receiptDir/restaurant_gst.jpg'),
      ],
    );
    addTearDown(container.dispose);
    final engine = container.read(syncEngineProvider);
    Future<void> sync() => t.runAsync(() async {
      await engine.sync();
      await engine.sync();
    });

    final tag = 'D34a${DateTime.now().millisecondsSinceEpoch % 100000}';
    final groups = container.read(groupsRepositoryProvider);
    final members = container.read(membersRepositoryProvider);
    final duo = await groups.create(
      name: 'Duo $tag',
      ownerName: 'Mohit',
      ownerUserId: uid,
      type: 'other',
    );
    await members.addNameOnly(duo, 'Asha');
    final trip = await groups.create(
      name: 'Dinner club $tag',
      ownerName: 'Mohit',
      ownerUserId: uid,
      type: 'trip',
    );
    await members.addNameOnly(trip, 'Asha');
    await members.addNameOnly(trip, 'Ravi');
    await sync();
    addTearDown(() async {
      await groups.delete(duo, duo);
      await groups.delete(trip, trip);
      await sync();
    });
    Future<Map<String, String>> ids(String gid) async => {
      for (final m in await (db.select(db.groupMembers)..where((m) => m.groupId.equals(gid))).get())
        (m.userId == uid ? 'me' : m.displayName): m.id,
    };
    final duoIds = await ids(duo);
    final tripIds = await ids(trip);

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
      () => find.byKey(Key('group-card-$trip')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 90),
      reason: 'home',
    );
    // The capture script brings a freshly installed window to the front once (it can stay black).
    if (_hold > 0) {
      debugPrint('UI-READY');
      await _pumpFor(t, const Duration(seconds: 4));
    }

    // ------------------------------------------------------------------ 1. two people (A1)
    router.push(ExpenseRoutes.add(duo));
    await _waitFor(t, find.byKey(const Key('expense-amount')), reason: 'editor');
    await t.enterText(_field('expense-description'), 'Cab $tag');
    await t.enterText(_field('expense-amount'), '300');
    await _pumpFor(t, const Duration(milliseconds: 600));
    FocusManager.instance.primaryFocus?.unfocus();
    await _tapKey(t, 'split-summary');
    await _waitFor(t, find.byKey(const Key('two-person')), reason: 'two-person sheet');
    expect(find.text('Asha owes you ₹300'), findsOneWidget);
    await _capture(t, 'two-person');
    await _tapKey(t, 'answer-youOwedFull');
    expect(find.byKey(const Key('two-person')), findsNothing);
    expect(find.textContaining('Asha owes the full amount'), findsOneWidget);
    await _capture(t, 'two-person-picked', dark: false);
    await _tapKey(t, 'expense-save');
    await pumpUntil(t, () => find.byKey(const Key('expense-amount')).evaluate().isEmpty);
    final cab = await (db.select(db.expenses)..where((e) => e.groupId.equals(duo))).getSingle();
    await sync();
    final cabRow = (await t.runAsync(
      () => client.from('expenses').select().eq('id', cab.id).single(),
    ))!;
    expect(cabRow['kind'], 'expense');
    expect(cabRow['split_kind'], 'exact');
    expect(Map<String, Object?>.from(cabRow['shares'] as Map), {
      duoIds['me']: 0,
      duoIds['Asha']: 30000,
    });
    debugPrint('D034-A1 OK ${cab.id}');

    // ------------------------------------------------------------------ 2. itemize (A2), offline first
    remote.offline = true;
    router.push(ExpenseRoutes.add(trip));
    await _waitFor(t, find.byKey(const Key('expense-amount')), reason: 'editor 2');
    await t.enterText(_field('expense-description'), 'Dinner $tag');
    await _pumpFor(t, const Duration(milliseconds: 600));
    FocusManager.instance.primaryFocus?.unfocus();
    await _tapKey(t, 'split-summary');
    await _waitFor(t, find.byKey(const Key('split-items')), reason: 'full sheet');
    await _tapKey(t, 'split-items');
    await _waitFor(t, find.byKey(const Key('items-editor')));
    final me = tripIds['me']!;
    final asha = tripIds['Asha']!;
    final ravi = tripIds['Ravi']!;
    Future<void> line(int key, String amount, String name, Set<String> off) async {
      await t.enterText(_field('item-name-$key'), name);
      await t.enterText(_field('item-amount-$key'), amount);
      await _pumpFor(t, const Duration(milliseconds: 300));
      for (final id in off) {
        await _tapKey(t, 'item-$key-person-$id');
      }
    }

    await line(0, '400', 'Paneer', {asha, ravi});
    await _tapKey(t, 'item-add');
    await line(1, '350', 'Naan', {ravi});
    await _tapKey(t, 'item-add');
    await line(2, '150', 'Lassi', {me, ravi});
    await _tapKey(t, 'items-extras');
    await t.enterText(_field('extra-field-tax'), '100');
    await _pumpFor(t, const Duration(milliseconds: 500));
    FocusManager.instance.primaryFocus?.unfocus();
    await _tapKey(t, 'items-use-total');
    await _capture(t, 'items');
    await _tapKey(t, 'paid-split-done');
    expect(find.textContaining('split by items'), findsOneWidget);
    await _tapKey(t, 'expense-save');
    await pumpUntil(t, () => find.byKey(const Key('expense-amount')).evaluate().isEmpty);
    final dinner = await (db.select(db.expenses)..where((e) => e.groupId.equals(trip))).getSingle();
    expect(dinner.total, 100000);
    // Offline: the sync attempt fails, the row waits on the phone with its outbox mutation.
    await sync();
    final waiting = await (db.select(
      db.expenses,
    )..where((e) => e.id.equals(dinner.id))).getSingle();
    expect(waiting.syncState, isNot(SyncState.synced), reason: 'offline: saved on the phone only');
    expect((await db.select(db.outbox).get()).where((o) => o.recordId == dinner.id), isNotEmpty);
    debugPrint('D034-A2 offline pending ok');
    remote.offline = false;
    await sync();
    final synced = await (db.select(db.expenses)..where((e) => e.id.equals(dinner.id))).getSingle();
    expect(synced.syncState, SyncState.synced, reason: '${engine.lastError}');
    final row = (await t.runAsync(
      () => client.from('expenses').select().eq('id', dinner.id).single(),
    ))!;
    final shares = Map<String, Object?>.from(row['shares'] as Map);
    expect(shares, {me: 63889, asha: 36111, ravi: 0});
    expect(shares.values.fold<int>(0, (a, v) => a + (v! as num).toInt()), 100000);
    final itemized = (row['split_values'] as Map)['itemized'] as Map;
    expect((itemized['items'] as List).length, 3);
    debugPrint('D034-A2 OK ${dinner.id} shares=$shares');

    // Reopens in the Items editor with the lines.
    router.push(ExpenseRoutes.edit(dinner.id));
    await _waitFor(t, find.byKey(const Key('expense-amount')), reason: 'edit');
    await _tapKey(t, 'split-summary');
    await _waitFor(t, find.byKey(const Key('items-editor')), reason: 'items reopen');
    expect(find.text('Paneer'), findsOneWidget);
    await _tapKey(t, 'paid-split-done');
    await _back(t);

    // ------------------------------------------------------------------ 3. receipt scan (A3)
    final results = <String>[];
    var right = 0;
    for (final MapEntry(key: name, value: want) in _receipts.entries) {
      final path = '$receiptDir/$name.jpg';
      expect(File(path).existsSync(), isTrue, reason: 'push the fixtures first ($path)');
      final lines = (await t.runAsync(() => mlKitOcr(path)))!;
      final rows = receiptRows(lines);
      final scan = parseReceipt(rows, today: DateTime.now());
      if (scan.total == want) {
        right++;
      } else {
        // What the text model read, for the parser fixtures.
        debugPrint('D034-A3 ROWS $name: ${rows.join(' ¦ ')}');
      }
      results.add('$name: ${scan.total} (want $want)');
    }
    debugPrint('D034-A3 OCR ${results.join(' | ')}');
    debugPrint('D034-A3 OCR right $right of ${_receipts.length}');

    router.push(ExpenseRoutes.add(trip));
    await _waitFor(t, find.byKey(const Key('expense-amount')), reason: 'editor 3');
    FocusManager.instance.primaryFocus?.unfocus();
    await _pumpFor(t, const Duration(milliseconds: 600));
    await _tapKey(t, 'expense-receipt-chip');
    await _waitFor(t, find.byKey(const Key('receipt-scan')));
    await _capture(t, 'receipt-sheet');
    await _tapKey(t, 'receipt-scan');
    await _tapKey(t, 'scan-gallery');
    await _waitFor(t, find.byKey(const Key('scan-review')), reason: 'scan review', seconds: 60);
    expect(find.text('₹992.00'), findsOneWidget);
    await _capture(t, 'scan-review');
    await _tapKey(t, 'scan-use');
    expect(t.widget<TextField>(_field('expense-amount')).controller!.text, '992');
    expect(
      t.widget<TextField>(_field('expense-description')).controller!.text,
      'Hotel Saravana Bhavan',
    );
    await _capture(t, 'scan-filled');
    debugPrint('D034-A3 UI OK');
    // Leave without saving (a scan never saves).
    await t.binding.handlePopRoute();
    await _pumpFor(t, const Duration(milliseconds: 900));
    await _tap(t, find.text('Discard'));

    // ------------------------------------------------------------------ 4. delete → Activity → Restore (A4)
    router.push(ExpenseRoutes.detail(dinner.id));
    await _waitFor(t, find.byKey(const Key('expense-delete')), reason: 'detail');
    await _capture(t, 'itemized-detail');
    await _tapKey(t, 'expense-delete');
    await _pumpFor(t, const Duration(seconds: 1));
    await sync();
    router.go(Routes.activity);
    final deletedRow = find.ancestor(
      of: find.textContaining('Dinner $tag'),
      matching: find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('activity-'),
      ),
    );
    await _waitFor(t, deletedRow, reason: 'activity row', seconds: 60);
    // Newest first: the "deleted" line opens the group (Activity is WP-C's), the older "added" line opens the
    // expense itself, which is now deleted.
    await _tap(t, deletedRow.last);
    await _waitFor(t, find.byKey(const Key('expense-deleted-pill')), reason: 'deleted page');
    expect(find.byKey(const Key('expense-edit')), findsNothing);
    await _capture(t, 'deleted');
    await _tapKey(t, 'expense-restore');
    await _waitFor(t, find.byKey(const Key('expense-edit')), reason: 'restored page');
    await sync();
    final back = (await t.runAsync(
      () => client.from('expenses').select().eq('id', dinner.id).single(),
    ))!;
    expect(back['deleted_at'], isNull);
    final restored = (await t.runAsync(
      () => client
          .from('activity')
          .select('type')
          .eq('target_id', dinner.id)
          .eq('type', 'expense_restored'),
    ))!;
    expect(restored, isNotEmpty);
    await _capture(t, 'restored', dark: false);
    debugPrint('D034-A4 OK');
    // Acceptance, checked last so the screens above are still captured: ≥ 7 of 8 receipts read right.
    expect(right, greaterThanOrEqualTo(7), reason: results.join('\n'));
    debugPrint('D034-A-E2E OK');
  });
}
