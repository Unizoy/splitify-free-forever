// Phase 18 device checks against the DEV project (e2e-a):
//  TC-X1-04 import a 200-row Splitwise file offline through the import screens, go online, sync, and
//           check the server rows, one `import_completed` activity and the balances; then "Delete this
//           import" and check the server again (one undone entry, rows soft-deleted).
//  TC-X3-02 the home-screen widget's values (home_widget shared prefs) follow the local write and the sync.
//   flutter test integration_test/extras_import_widget_test.dart -d emulator-5554 \
//     --dart-define-from-file=secrets/env.dev.json --dart-define=PIN_HOST_IP=<ip> [--dart-define=UI_HOLD=30]
// With UI_HOLD it prints `UI-CAPTURE <name>` and holds each screen for capture_markers.ps1.
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/app/router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/features/app_lock/presentation/security_routes.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/import_splitwise/application/import_providers.dart';
import 'package:splitify/features/import_splitwise/presentation/import_routes.dart';
import 'package:splitify/features/widget/application/home_widget_sync.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'expenses_offline_sync_test.dart' show SwitchableRemote;
import 'support/net_pin.dart';

const _hold = int.fromEnvironment('UI_HOLD');
const _people = ['E2E A', 'Asha', 'Rahul', 'Priya'];

class _Picker implements ImportFilePicker {
  _Picker(this.bytes);

  final Uint8List bytes;

  @override
  Future<PickedFile?> pick() async => (name: 'goa-trip_2026-11-22_export.csv', bytes: bytes);
}

String _plain(int minor) {
  final sign = minor < 0 ? '-' : '';
  final a = minor.abs();
  return '$sign${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
}

/// A Splitwise export with [rows] rows (every 10th a payment, every 7th in USD) and its totals.
({String csv, Map<String, Map<String, int>> totals, int expenses, int payments}) _file(int rows) {
  final totals = <String, Map<String, int>>{};
  final out = StringBuffer('Date,Description,Category,Cost,Currency,${_people.join(',')}\n');
  var expenses = 0;
  var payments = 0;
  for (var i = 0; i < rows; i++) {
    final currency = i % 7 == 3 ? 'USD' : 'INR';
    final day =
        '2026-${(1 + i % 10).toString().padLeft(2, '0')}-${(1 + i % 27).toString().padLeft(2, '0')}';
    final nets = List<int>.filled(_people.length, 0);
    String description;
    String category;
    int cost;
    if (i % 10 == 9) {
      final from = i % 4;
      final to = (i + 1) % 4;
      cost = 5000 + i * 13;
      nets[from] += cost;
      nets[to] -= cost;
      description = '${_people[from]} paid ${_people[to]}';
      category = 'Payment';
      payments++;
    } else {
      final payer = i % 4;
      cost = 10000 + (i * 3779) % 500000;
      final share = cost ~/ 4;
      for (var m = 0; m < 4; m++) {
        final owed = share + (m < cost % 4 ? 1 : 0);
        nets[m] -= owed;
      }
      nets[payer] += cost;
      description = 'Row $i, "quoted" dinner';
      category = i.isEven ? 'Dining out' : 'Utilities - Electricity';
      expenses++;
    }
    final sum = totals.putIfAbsent(currency, () => {for (final p in _people) p: 0});
    for (var m = 0; m < 4; m++) {
      sum[_people[m]] = sum[_people[m]]! + nets[m];
    }
    final quoted = '"${description.replaceAll('"', '""')}"';
    out.writeln('$day,$quoted,$category,${_plain(cost)},$currency,${nets.map(_plain).join(',')}');
  }
  out.writeln();
  for (final c in totals.keys.toList()..sort()) {
    out.writeln(
      '2026-10-27,Total balance,,,$c,${_people.map((p) => _plain(totals[c]![p]!)).join(',')}',
    );
  }
  return (csv: out.toString(), totals: totals, expenses: expenses, payments: payments);
}

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitFor(WidgetTester t, Finder f, {int seconds = 60}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $f');
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _pumpFor(t, const Duration(milliseconds: 500));
}

Future<void> _capture(WidgetTester t, String name) async {
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

  testWidgets(
    'TC-X1-04 / TC-X3-02 import 200 rows offline, sync, widget values, delete the import',
    (t) async {
      final env = Env.load();
      pinHost(Uri.parse(env.supabaseUrl).host); // `--dart-define=PIN_HOST_IP=<ip>` (S-214)
      final remote = await initRemote(env);
      await remote.auth.signInWithPassword(email: 'e2e-a@splitify.test', password: env.e2ePassword);
      final uid = remote.auth.currentUser!.id;
      final client = Supabase.instance.client;
      final server = SwitchableRemote(SupabaseRemoteApi.client(client));
      final db = AppDatabase(NativeDatabase.memory());
      final file = _file(200);
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          remoteApiProvider.overrideWithValue(server),
          authRepositoryProvider.overrideWithValue(remote.auth),
          importFilePickerProvider.overrideWithValue(_Picker(utf8.encode('﻿${file.csv}'))),
        ],
      );
      addTearDown(container.dispose);
      // The app watches this in App.build; here the test does (TC-X3-02).
      container.listen(homeWidgetSyncProvider, (_, _) {});

      final gid = await container
          .read(groupsRepositoryProvider)
          .create(
            name: 'E2E import ${DateTime.now().millisecondsSinceEpoch}',
            ownerName: 'E2E A',
            ownerUserId: uid,
          );
      final router = buildRouter(initialLocation: ImportRoutes.forGroup(gid));
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
          ),
        ),
      );
      await _pumpFor(t, const Duration(seconds: 2));
      await _capture(t, 'import-file');

      // Offline: pick → people (E2E A = me, three new) → preview (totals match) → import.
      await _tap(t, find.byKey(const Key('import-pick')));
      await _waitFor(t, find.byKey(const Key('import-person-Priya')));
      await _capture(t, 'import-people');
      await _tap(t, find.byKey(const Key('import-continue')));
      await _waitFor(t, find.byKey(const Key('import-totals-ok')));
      await _capture(t, 'import-preview');
      await _tap(t, find.byKey(const Key('import-run')));
      await _waitFor(t, find.byKey(const Key('import-done')), seconds: 120);
      await _pumpFor(t, const Duration(seconds: 3));
      await _capture(t, 'import-done');

      final local = await (db.select(db.expenses)..where((e) => e.groupId.equals(gid))).get();
      final localPayments = await (db.select(
        db.payments,
      )..where((p) => p.groupId.equals(gid))).get();
      expect(local, hasLength(file.expenses));
      expect(localPayments, hasLength(file.payments));
      expect(local.every((e) => e.source == 'import'), isTrue);

      // TC-X3-02: the widget shows my local balance, "not synced yet".
      final me = (await container.read(membersRepositoryProvider).watchForGroup(gid).first)
          .firstWhere((m) => m.userId == uid);
      await _pumpFor(t, const Duration(seconds: 2));
      final pending = await t.runAsync(() => HomeWidget.getWidgetData<String>('pending'));
      expect(pending, isNotEmpty, reason: 'widget says not synced yet');
      final line1 = await t.runAsync(() => HomeWidget.getWidgetData<String>('line1'));
      expect(line1, isNotNull);
      expect(line1, isNotEmpty);

      // Online: push everything, pull it back.
      server.online = true;
      final engine = container.read(syncEngineProvider);
      await t.runAsync(() async {
        for (var i = 0; i < 8; i++) {
          await engine.sync();
          final left = await db.select(db.outbox).get();
          if (left.isEmpty) break;
        }
      });
      expect(await db.select(db.outbox).get(), isEmpty, reason: '${engine.lastError}');

      final rows = await t.runAsync(
        () => client.from('expenses').select('id, source').eq('group_id', gid),
      );
      expect(rows, hasLength(file.expenses));
      expect(rows!.every((r) => r['source'] == 'import'), isTrue);
      final pays = await t.runAsync(() => client.from('payments').select('id').eq('group_id', gid));
      expect(pays, hasLength(file.payments));
      final acts = await t.runAsync(
        () => client.from('activity').select('type, data').eq('group_id', gid),
      );
      final types = [for (final a in acts!) a['type'] as String];
      expect(types.where((x) => x == 'import_completed'), hasLength(1));
      expect(types.where((x) => x == 'expense_added' || x == 'payment_added'), isEmpty);
      final done = acts.firstWhere((a) => a['type'] == 'import_completed')['data'] as Map;
      expect(done['expenses'], file.expenses);
      expect(done['payments'], file.payments);

      // Server balances = the file's Total balance rows, per currency and person.
      final members = await container.read(membersRepositoryProvider).watchForGroup(gid).first;
      final idOf = {for (final m in members) (m.userId == uid ? 'E2E A' : m.displayName): m.id};
      final balances = await t.runAsync(
        () => client.rpc<Map<String, dynamic>>('group_balances', params: {'group_id': gid}),
      );
      for (final c in file.totals.keys) {
        final nets = (balances!['currencies'] as Map)[c]['nets'] as Map;
        for (final p in _people) {
          expect((nets[idOf[p]] as num).toInt(), file.totals[c]![p], reason: '$c $p');
        }
      }

      // Widget after the sync: no "not synced yet", my INR balance.
      await _pumpFor(t, const Duration(seconds: 2));
      expect(await t.runAsync(() => HomeWidget.getWidgetData<String>('pending')), '');
      final myInr = file.totals['INR']!['E2E A']!;
      final usd = file.totals['USD']!['E2E A']!;
      final signsDiffer = (myInr > 0) != (usd > 0);
      if (!signsDiffer) {
        expect(
          await t.runAsync(() => HomeWidget.getWidgetData<String>('line1')),
          MoneyFormatter.list.format(myInr.abs(), 'INR'),
        );
      }
      expect(me.id, idOf['E2E A']);

      // "Delete this import" → one undone entry on the server, every record soft-deleted.
      await _tap(t, find.byKey(const Key('import-delete')));
      await _pumpFor(t, const Duration(milliseconds: 1500));
      await _tap(t, find.byKey(const Key('confirm-action')));
      await _waitFor(t, find.byKey(const Key('import-deleted')), seconds: 120);
      await t.runAsync(() async {
        for (var i = 0; i < 8; i++) {
          await engine.sync();
          if ((await db.select(db.outbox).get()).isEmpty) break;
        }
      });
      final live = await t.runAsync(
        () => client.from('expenses').select('id').eq('group_id', gid).isFilter('deleted_at', null),
      );
      expect(live, isEmpty);
      final livePays = await t.runAsync(
        () => client.from('payments').select('id').eq('group_id', gid).isFilter('deleted_at', null),
      );
      expect(livePays, isEmpty);
      final after = await t.runAsync(
        () => client.from('activity').select('type, data').eq('group_id', gid),
      );
      expect(
        after!.where(
          (a) => a['type'] == 'import_completed' && (a['data'] as Map)['undone'] == true,
        ),
        hasLength(1),
      );
      expect(after.where((a) => a['type'] == 'expense_deleted'), isEmpty);

      // Screens for the device UI review (no assertions beyond rendering).
      if (_hold > 0) {
        router.go(SecurityRoutes.widget);
        await _pumpFor(t, const Duration(seconds: 2));
        await _capture(t, 'widget-settings');
        router.go(SecurityRoutes.security);
        await _pumpFor(t, const Duration(seconds: 2));
        await _capture(t, 'security');
      }
    },
  );
}
