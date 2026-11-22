// Phase 15 e2e on the emulator with REAL airplane mode and REAL app restarts (TC-27-11, TC-27-12, phase 10
// receipt scenario S-113/S-114) plus the conflict UX (TC-27-13). The stages run one per app launch, driven
// by `tool/e2e/airplane.ps1`, which switches airplane mode when a stage prints `E2E-NET off|on`, force-stops
// the app on `E2E-KILL` and takes screenshots on `UI-CAPTURE <name>`. The app's on-disk database, photo
// files and Supabase session carry over between stages like on a real phone. Run only through the script:
//   powershell -File tool\e2e\airplane.ps1            (holds the emulator lock itself)
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/repositories/history_repository.dart';
import 'package:splitify/data/sync/network_status.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/currency/application/currency_providers.dart'
    show fxAutoRefreshProvider;
import 'package:splitify/features/photos/application/photo_compression.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/ui/components/sync_marker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'expenses_offline_sync_test.dart' show SwitchableRemote;
import 'support/harness.dart';

/// Only the script runs these (they wait for airplane mode switched from the PC).
const _staged = bool.fromEnvironment('E2E_AIRPLANE');
const _hold = int.fromEnvironment('UI_HOLD', defaultValue: 6);

const _stateKey = 'e2e_airplane_state';
const _killKey = 'e2e_kill_state';

final _network = ConnectivityNetworkStatus();

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [check] (run on the real event loop) is true.
Future<void> _until(
  WidgetTester t,
  Future<bool> Function() check, {
  required String reason,
  Duration timeout = const Duration(seconds: 90),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if ((await t.runAsync(check)) ?? false) return;
    await t.pump(const Duration(milliseconds: 300));
  }
  fail('Timed out: $reason');
}

/// Asks the script to switch airplane mode and waits until the phone sees it.
Future<void> _net(WidgetTester t, {required bool on}) async {
  debugPrint('E2E-NET ${on ? 'on' : 'off'}');
  await _until(
    t,
    () async => await _network.isOnline() == on,
    reason: 'network ${on ? 'on' : 'off'}',
  );
  debugPrint('network is ${on ? 'on' : 'off'}');
}

/// Holds the screen while the script takes screenshots.
Future<void> _capture(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(seconds: 2));
  debugPrint('UI-CAPTURE $name');
  await _pumpFor(t, const Duration(seconds: _hold));
}

/// The real app wiring (bootstrap) with connectivity; no WorkManager inside a test build.
Future<(ProviderContainer, RemoteServices)> _app(WidgetTester t, Env env) async {
  final prefs = (await t.runAsync(SharedPreferences.getInstance))!;
  final remote = (await t.runAsync(() => initRemote(env)))!;
  final container = ProviderContainer(
    overrides: [
      ...appOverrides(env: env, prefs: prefs, remote: remote, network: _network),
      // Exchange rates are not part of these scenarios; their download would outlive the stage.
      fxAutoRefreshProvider.overrideWith((ref) {}),
    ],
  );
  addTearDown(container.dispose);
  return (container, remote);
}

/// Unmounts the app and lets in-flight work (notifications refresh, sync) finish before the container and
/// its database close.
Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await _pumpFor(t, const Duration(seconds: 3));
}

Future<void> _show(WidgetTester t, ProviderContainer c, [String? location]) async {
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const App()));
  await _pumpFor(t, const Duration(seconds: 2));
  if (location != null) {
    c.read(routerProvider).go(location);
    await _pumpFor(t, const Duration(seconds: 2));
  }
}

Future<int> _count(AppDatabase db, String sql, [List<Object> args = const []]) async =>
    (await db.customSelect(sql, variables: [for (final a in args) Variable<Object>(a)]).getSingle())
        .read<int>('n');

String get _today => DateTime.now().toIso8601String().substring(0, 10);

Map<String, Object?> _expense(String description, int total, String me, String bina) => {
  'kind': 'expense',
  'description': description,
  'notes': null,
  'category': 'food.dining_out',
  'date': _today,
  'currency': 'INR',
  'total': total,
  'payers': {me: total},
  'shares': {me: total ~/ 2, bina: total - total ~/ 2},
  'split_kind': 'equal',
  'split_values': null,
  'created_at': DateTime.now().toUtc().toIso8601String(),
};

/// A noisy 1800 × 1200 photo, compressed by the real platform encoder.
Future<PreparedImage> _photo() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final r = Random(3);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 1800, 1200), Paint()..color = const Color(0xFFEFE8DA));
  for (var i = 0; i < 3000; i++) {
    canvas.drawRect(
      Rect.fromLTWH(r.nextDouble() * 1800, r.nextDouble() * 1200, 4 + r.nextDouble() * 30, 4),
      Paint()..color = Color(0xFF000000 | r.nextInt(0xFFFFFF)),
    );
  }
  final image = await recorder.endRecording().toImage(1800, 1200);
  final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  image.dispose();
  return preparePhoto(png, encode: platformJpeg, sizeOf: readImageSize);
}

Future<void> _signIn(WidgetTester t, RemoteServices remote, Env env) async {
  if (remote.auth.currentUser != null) return;
  await t.runAsync(
    () => remote.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword),
  );
}

Map<String, Object?> _load(SharedPreferences prefs, String key) =>
    (jsonDecode(prefs.getString(key) ?? '{}') as Map).cast<String, Object?>();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------- TC-27-11 + phase 10 receipts offline
  testWidgets('A1 online setup: group, Bina claimed by B', skip: !_staged, (t) async {
    final env = devEnv();
    final (c, remote) = await _app(t, env);
    await _signIn(t, remote, env);
    final uid = remote.auth.currentUser!.id;
    await _show(t, c);
    final gid = (await t.runAsync(
      () => c
          .read(groupsRepositoryProvider)
          .create(
            name: 'E2E airplane ${DateTime.now().millisecondsSinceEpoch}',
            ownerName: 'E2E A',
            ownerUserId: uid,
          ),
    ))!;
    final bina = (await t.runAsync(
      () => c.read(membersRepositoryProvider).addNameOnly(gid, 'Bina'),
    ))!;
    final db = c.read(appDatabaseProvider);
    await _until(
      t,
      () async => await _count(db, 'SELECT COUNT(*) AS n FROM outbox') == 0,
      reason: 'setup pushed',
    );
    final me = (await t.runAsync(() => c.read(membersRepositoryProvider).watchForGroup(gid).first))!
        .firstWhere((m) => m.userId == uid)
        .id;
    final client = Supabase.instance.client;
    final code = (await t.runAsync(
      () => client.from('groups').select('invite_code').eq('id', gid).single(),
    ))!['invite_code'];
    final b = (await t.runAsync(() => HarnessUser.signIn(env, 'e2e-b')))!;
    await t.runAsync(() => b.rpc('join_group', {'code': code, 'claim_member_id': bina}));
    await t.runAsync(b.dispose);
    final prefs = c.read(sharedPreferencesProvider);
    await t.runAsync(
      () => prefs.setString(_stateKey, jsonEncode({'gid': gid, 'me': me, 'bina': bina})),
    );
    debugPrint('E2E-GID $gid');
    await _finish(t);
  });

  testWidgets(
    'A2 airplane: 5 expenses (1 with receipt), edit, delete, payment, comment',
    skip: !_staged,
    (t) async {
      final env = devEnv();
      final (c, remote) = await _app(t, env);
      final s = _load(c.read(sharedPreferencesProvider), _stateKey);
      final gid = s['gid']! as String;
      final me = s['me']! as String;
      final bina = s['bina']! as String;
      final uid = remote.auth.currentUser!.id;
      await _net(t, on: false);
      final photo = (await t.runAsync(_photo))!;
      await _show(t, c);

      final expenses = c.read(expensesRepositoryProvider);
      final ids = <String>[];
      await t.runAsync(() async {
        final first = newId();
        await c
            .read(mediaRepositoryProvider)
            .saveExpenseWithReceipt(
              gid,
              first,
              _expense('Airplane lunch', 120000, me, bina),
              photo,
            );
        ids.add(first);
        for (final (d, total) in [
          ('Taxi', 20050),
          ('Snacks', 33334),
          ('Tea', 4500),
          ('Hotel', 99998),
        ]) {
          ids.add(await expenses.save(gid, _expense(d, total, me, bina)));
        }
        await expenses.save(gid, _expense('Taxi to airport', 30000, me, bina), id: ids[1]);
        await expenses.delete(ids[2], gid);
        final pid = await c.read(paymentsRepositoryProvider).save(gid, {
          'from_member': bina,
          'to_member': me,
          'amount': 5000,
          'currency': 'INR',
          'date': _today,
          'method': 'cash',
          'note': null,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        await c
            .read(commentsRepositoryProvider)
            .add(
              groupId: gid,
              targetType: 'expense',
              targetId: ids.first,
              body: 'Paid at the counter',
              authorId: uid,
            );
        final prefs = c.read(sharedPreferencesProvider);
        await prefs.setString(_stateKey, jsonEncode({...s, 'expenses': ids, 'payment': pid}));
      });
      await _pumpFor(t, const Duration(seconds: 3)); // the debounced sync runs and fails offline

      final db = c.read(appDatabaseProvider);
      expect(await t.runAsync(() => _count(db, 'SELECT COUNT(*) AS n FROM outbox')), 9);
      expect(await t.runAsync(() => _count(db, 'SELECT COUNT(*) AS n FROM pending_uploads')), 1);
      expect(c.read(syncEngineProvider).phase, SyncPhase.offline);

      // Markers on the group card and the overall balance; Sync & storage lists the waiting photo.
      expect(
        find.descendant(of: find.byKey(Key('group-card-$gid')), matching: find.byType(SyncMarker)),
        findsOneWidget,
      );
      await _capture(t, 'airplane-groups');
      c.read(routerProvider).go(Routes.syncStorage);
      await _pumpFor(t, const Duration(seconds: 2));
      expect(find.text('You are offline'), findsOneWidget);
      expect(find.text('9'), findsOneWidget, reason: 'waiting count');
      expect(find.byKey(const Key('sync-uploads-card')), findsOneWidget);
      await _capture(t, 'airplane-sync');
      debugPrint('A2 done: 9 changes and 1 photo waiting; the script now kills the app');
      await _finish(t);
    },
  );

  testWidgets(
    'A3 relaunch offline: data kept; airplane off: syncs by itself, B sees it',
    skip: !_staged,
    (t) async {
      final env = devEnv();
      final (c, remote) = await _app(t, env);
      final s = _load(c.read(sharedPreferencesProvider), _stateKey);
      final gid = s['gid']! as String;
      final ids = (s['expenses']! as List).cast<String>();
      final pid = s['payment']! as String;
      expect(await _network.isOnline(), isFalse, reason: 'still in airplane mode');
      expect(remote.auth.currentUser, isNotNull, reason: 'session restored offline');
      final db = c.read(appDatabaseProvider);

      // After the kill: everything is still on the phone, still waiting.
      expect(await t.runAsync(() => _count(db, 'SELECT COUNT(*) AS n FROM outbox')), 9);
      expect(await t.runAsync(() => _count(db, 'SELECT COUNT(*) AS n FROM pending_uploads')), 1);
      expect(
        await t.runAsync(
          () => _count(
            db,
            "SELECT COUNT(*) AS n FROM expenses WHERE group_id = ? AND sync_state <> 'synced'",
            [gid],
          ),
        ),
        5,
      );
      await _show(t, c);
      expect(
        find.descendant(of: find.byKey(Key('group-card-$gid')), matching: find.byType(SyncMarker)),
        findsOneWidget,
      );

      // Airplane mode off: the connectivity trigger syncs (no "Sync now"), photos go up after their rows.
      final started = DateTime.now();
      await _net(t, on: true);
      await _until(
        t,
        () async =>
            await _count(db, 'SELECT COUNT(*) AS n FROM outbox') == 0 &&
            await _count(db, 'SELECT COUNT(*) AS n FROM pending_uploads') == 0 &&
            await _count(
                  db,
                  "SELECT COUNT(*) AS n FROM expenses WHERE group_id = ? AND sync_state <> 'synced'",
                  [gid],
                ) ==
                0,
        reason: 'automatic sync after airplane mode',
      );
      debugPrint('synced ${DateTime.now().difference(started).inMilliseconds} ms after network on');
      await _pumpFor(t, const Duration(seconds: 2));
      expect(
        find.descendant(of: find.byKey(Key('group-card-$gid')), matching: find.byType(SyncMarker)),
        findsNothing,
        reason: 'markers cleared',
      );
      await _capture(t, 'airplane-synced');

      // Harness B sees exactly the phone's rows.
      final b = (await t.runAsync(() => HarnessUser.signIn(env, 'e2e-b')))!;
      final server = (await t.runAsync(
        () => b.client.from('expenses').select().eq('group_id', gid),
      ))!;
      final local = await t.runAsync(
        () => (db.select(db.expenses)..where((e) => e.groupId.equals(gid))).get(),
      );
      expect(server.map((r) => r['id']).toSet(), ids.toSet());
      for (final l in local!) {
        final r = server.firstWhere((x) => x['id'] == l.id);
        expect(
          (r['description'], r['total'], r['deleted_at'] != null, r['receipt_path']),
          (l.description, l.total, l.deletedAt != null, l.receiptPath),
          reason: l.description,
        );
      }
      final byId = {for (final r in server) r['id']: r};
      expect(byId[ids[1]]!['description'], 'Taxi to airport');
      expect(byId[ids[1]]!['total'], 30000);
      expect(byId[ids[2]]!['deleted_at'], isNotNull);
      final payments = (await t.runAsync(
        () => b.client.from('payments').select().eq('group_id', gid),
      ))!;
      expect(payments.single['id'], pid);
      expect(payments.single['amount'], 5000);
      final comments = (await t.runAsync(
        () => b.client.from('comments').select().eq('target_id', ids.first),
      ))!;
      expect(comments.single['body'], 'Paid at the counter');
      final receipt = byId[ids.first]!['receipt_path']! as String;
      final url = (await t.runAsync(
        () => b.client.storage.from(MediaBuckets.receipts).createSignedUrl(receipt, 60),
      ))!;
      final bytes = (await t.runAsync(() => SupabaseMediaRemote.httpGet(Uri.parse(url))))!;
      expect(bytes.sublist(0, 2), [0xFF, 0xD8], reason: 'B downloads the JPEG');
      debugPrint(
        'B sees ${server.length} expenses, 1 payment, 1 comment, receipt ${bytes.length} B',
      );
      await t.runAsync(b.dispose);

      // Tidy: soft-delete the test group (restorable).
      await t.runAsync(() => c.read(groupsRepositoryProvider).delete(gid, gid));
      await _until(
        t,
        () async => await _count(db, 'SELECT COUNT(*) AS n FROM outbox') == 0,
        reason: 'tidy pushed',
      );
      await _finish(t);
    },
  );

  // ---------------------------------------------------------------- TC-27-12 kill during a 300-change push
  testWidgets('K1 300 changes offline, airplane off, killed mid-push', skip: !_staged, (t) async {
    final env = devEnv();
    final (c, remote) = await _app(t, env);
    await _signIn(t, remote, env);
    final uid = remote.auth.currentUser!.id;
    await _show(t, c);
    final db = c.read(appDatabaseProvider);
    await _until(
      t,
      () async => await _count(db, 'SELECT COUNT(*) AS n FROM outbox') == 0,
      reason: 'earlier changes pushed',
    );
    final gid = (await t.runAsync(
      () => c
          .read(groupsRepositoryProvider)
          .create(
            name: 'E2E kill ${DateTime.now().millisecondsSinceEpoch}',
            ownerName: 'E2E A',
            ownerUserId: uid,
          ),
    ))!;
    final bina = (await t.runAsync(
      () => c.read(membersRepositoryProvider).addNameOnly(gid, 'Bina'),
    ))!;
    await _until(
      t,
      () async => await _count(db, 'SELECT COUNT(*) AS n FROM outbox') == 0,
      reason: 'group pushed',
    );
    final me = (await t.runAsync(() => c.read(membersRepositoryProvider).watchForGroup(gid).first))!
        .firstWhere((m) => m.userId == uid)
        .id;
    await _net(t, on: false);
    final ids = <String>[];
    final expenses = c.read(expensesRepositoryProvider);
    await t.runAsync(() async {
      for (var i = 1; i <= 300; i++) {
        ids.add(
          await expenses.save(
            gid,
            _expense('Kill ${'$i'.padLeft(3, '0')}', 1000 + 2 * i, me, bina),
          ),
        );
      }
      await c
          .read(sharedPreferencesProvider)
          .setString(_killKey, jsonEncode({'gid': gid, 'expenses': ids}));
    });
    expect(await t.runAsync(() => _count(db, 'SELECT COUNT(*) AS n FROM outbox')), 300);
    await _net(t, on: true);
    // The first batch is on its way: ask the script to kill the app now.
    await _until(
      t,
      () async =>
          await _count(db, "SELECT COUNT(*) AS n FROM outbox WHERE status = 'in_flight'") > 0 ||
          await _count(db, 'SELECT COUNT(*) AS n FROM outbox') < 300,
      reason: 'push started',
      timeout: const Duration(seconds: 60),
    );
    debugPrint('E2E-KILL');
    for (var i = 0; i < 100; i++) {
      final n = await t.runAsync(() => _count(db, 'SELECT COUNT(*) AS n FROM outbox'));
      debugPrint('E2E-OUTBOX $n');
      await _pumpFor(t, const Duration(milliseconds: 200));
    }
    fail('the app was not killed');
  });

  testWidgets('K2 relaunch: rest pushed, no duplicates, order kept', skip: !_staged, (t) async {
    final env = devEnv();
    final (c, _) = await _app(t, env);
    final s = _load(c.read(sharedPreferencesProvider), _killKey);
    final gid = s['gid']! as String;
    final ids = (s['expenses']! as List).cast<String>();
    final db = c.read(appDatabaseProvider);
    final left = await t.runAsync(() => _count(db, 'SELECT COUNT(*) AS n FROM outbox'));
    debugPrint('after the kill: $left of 300 still queued');
    expect(left, inExclusiveRange(0, 300), reason: 'the kill landed mid-push');
    await _show(t, c); // app start syncs
    await _until(
      t,
      () async => await _count(db, 'SELECT COUNT(*) AS n FROM outbox') == 0,
      reason: 'rest pushed after relaunch',
    );
    final client = Supabase.instance.client;
    final rows = (await t.runAsync(
      () => client.from('expenses').select('id, description, seq').eq('group_id', gid).order('seq'),
    ))!;
    expect(rows, hasLength(300));
    expect(rows.map((r) => r['id']).toList(), ids, reason: 'server order = phone order');
    final versions = (await t.runAsync(
      () => client
          .from('record_versions')
          .select('record_id, op')
          .eq('group_id', gid)
          .eq('table_name', 'expenses'),
    ))!;
    expect(versions, hasLength(300), reason: 'each change applied exactly once');
    expect(versions.map((v) => v['op']).toSet(), {'insert'});
    debugPrint('K2: 300 rows, 300 versions, order kept');
    await t.runAsync(() => c.read(groupsRepositoryProvider).delete(gid, gid));
    await _until(
      t,
      () async => await _count(db, 'SELECT COUNT(*) AS n FROM outbox') == 0,
      reason: 'tidy pushed',
    );
    await _finish(t);
  });

  // ---------------------------------------------------------------- TC-27-13 conflict UX
  testWidgets(
    'C1 older offline edit loses: snackbar, history shows both versions',
    skip: !_staged,
    (t) async {
      final env = devEnv();
      final prefs = (await t.runAsync(SharedPreferences.getInstance))!;
      final real = (await t.runAsync(() => initRemote(env)))!;
      if (real.auth.currentUser == null) {
        await t.runAsync(
          () => real.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword),
        );
      }
      final uid = real.auth.currentUser!.id;
      final net = SwitchableRemote(real.api)..online = true;
      final remote = RemoteServices(
        auth: real.auth,
        profiles: real.profiles,
        api: net,
        groups: real.groups,
        media: real.media,
        history: real.history,
        balances: real.balances,
        friends: real.friends,
        fxRates: real.fxRates,
        notifications: real.notifications,
        nudges: real.nudges,
      );
      final db = AppDatabase(NativeDatabase.memory());
      final c = ProviderContainer(
        overrides: [
          ...appOverrides(env: env, prefs: prefs, remote: remote, network: _network),
          fxAutoRefreshProvider.overrideWith((ref) {}),
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(c.dispose);
      await _show(t, c);
      final gid = (await t.runAsync(
        () => c
            .read(groupsRepositoryProvider)
            .create(
              name: 'E2E conflict ${DateTime.now().millisecondsSinceEpoch}',
              ownerName: 'E2E A',
              ownerUserId: uid,
            ),
      ))!;
      final bina = (await t.runAsync(
        () => c.read(membersRepositoryProvider).addNameOnly(gid, 'Bina'),
      ))!;
      final me = (await t.runAsync(
        () => c.read(membersRepositoryProvider).watchForGroup(gid).first,
      ))!.firstWhere((m) => m.userId == uid).id;
      final eid = (await t.runAsync(
        () => c.read(expensesRepositoryProvider).save(gid, _expense('Dinner', 80000, me, bina)),
      ))!;
      await t.runAsync(c.read(syncRepositoryProvider).syncNow);
      final code = (await t.runAsync(
        () => Supabase.instance.client.from('groups').select('invite_code').eq('id', gid).single(),
      ))!['invite_code'];
      final b = (await t.runAsync(() => HarnessUser.signIn(env, 'e2e-b')))!;
      await t.runAsync(() => b.rpc('join_group', {'code': code, 'claim_member_id': bina}));

      // A edits offline; B edits the same expense later, online; A comes back.
      net.online = false;
      await t.runAsync(
        () => c
            .read(expensesRepositoryProvider)
            .save(gid, _expense('A offline edit', 80000, me, bina), id: eid),
      );
      await _pumpFor(t, const Duration(seconds: 2));
      final bTime = DateTime.now().toUtc().add(const Duration(seconds: 1)).toIso8601String();
      final applied = (await t.runAsync(
        () => b.rpc('apply_mutations', {
          'batch': [
            {
              'mutation_id': newId(),
              'entity': 'expense',
              'op': 'upsert',
              'id': eid,
              'group_id': gid,
              'base_seq': null,
              'client_updated_at': bTime,
              'source': 'app',
              'data': {'description': 'B later edit'},
            },
          ],
        }),
      ))!;
      expect(((applied['results']! as List).single! as Map)['status'], 'applied');
      net.online = true;
      await t.runAsync(c.read(syncRepositoryProvider).syncNow);
      await _pumpFor(t, const Duration(milliseconds: 600));
      expect(find.byKey(const Key('sync-superseded')), findsOneWidget);
      expect(find.textContaining("Someone else's newer edit was kept"), findsOneWidget);
      await _capture(t, 'conflict-snackbar');

      c.read(routerProvider).go('/expense/$eid/history');
      await _pumpFor(t, const Duration(seconds: 4));
      expect(find.textContaining('B later edit', skipOffstage: false), findsWidgets);
      expect(find.textContaining('A offline edit', skipOffstage: false), findsWidgets);
      expect(find.text('Not applied (a newer edit won)', skipOffstage: false), findsOneWidget);
      await _capture(t, 'conflict-history');

      await t.runAsync(() => b.client.rpc<Object?>('leave_group', params: {'group_id': gid}));
      await t.runAsync(b.dispose);
      await t.runAsync(() => c.read(groupsRepositoryProvider).delete(gid, gid));
      await t.runAsync(c.read(syncRepositoryProvider).syncNow);
      await _finish(t);
    },
  );
}
