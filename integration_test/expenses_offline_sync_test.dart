// Phase 08 T7 (TC-5..9 integ): add one expense of each split type offline through the stepper, go
// online, sync, and check that the server rows, the server balances and another member's view all
// match the phone. Runs against the DEV project with the e2e test users:
//   flutter test integration_test/expenses_offline_sync_test.dart -d emulator-5554 \
//     --dart-define-from-file=secrets/env.dev.json
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Optional IP for the Supabase host, resolved on the PC and passed with
/// `--dart-define=SUPABASE_PINNED_IP=<ip>`: on this network the emulator's DNS answers `*.supabase.co`
/// with an ISP block address. Test-only; the app itself never pins.
const _pinnedIp = String.fromEnvironment('SUPABASE_PINNED_IP');

class _PinnedHost extends HttpOverrides {
  _PinnedHost(this.host, this.ip);

  final String host;
  final String ip;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context)
      ..connectionFactory = (uri, proxyHost, proxyPort) async {
        final secure = uri.scheme == 'https' || uri.scheme == 'wss';
        final port = uri.hasPort ? uri.port : (secure ? 443 : 80);
        final target = uri.host == host ? ip : uri.host;
        final task = await Socket.startConnect(target, port);
        return ConnectionTask.fromSocket(
          task.socket.then<Socket>(
            (s) => secure ? SecureSocket.secure(s, host: uri.host, context: context) : s,
          ),
          task.cancel,
        );
      };
    return client;
  }
}

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

Map<String, int> _ints(Object? json) {
  final m = json is String ? jsonDecode(json) as Map<String, Object?> : json! as Map;
  return {for (final e in m.entries) e.key as String: (e.value as num).toInt()};
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
  await _pumpFor(t, const Duration(milliseconds: 350));
}

Future<void> _type(WidgetTester t, Key row, String text) async {
  final field = find.descendant(of: find.byKey(row), matching: find.byType(TextField));
  await t.ensureVisible(field);
  await t.enterText(field, text);
  await t.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('one expense of each split type offline, then sync: server = phone = other member', (
    t,
  ) async {
    final env = Env.load();
    if (_pinnedIp.isNotEmpty) {
      HttpOverrides.global = _PinnedHost(Uri.parse(env.supabaseUrl).host, _pinnedIp);
    }
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

    // Offline: a new group with three name-only members.
    final groups = container.read(groupsRepositoryProvider);
    final members = container.read(membersRepositoryProvider);
    final gid = await groups.create(
      name: 'E2E split types ${DateTime.now().millisecondsSinceEpoch}',
      ownerName: 'E2E A',
      ownerUserId: uid,
    );
    final asha = await members.addNameOnly(gid, 'Asha');
    final rahul = await members.addNameOnly(gid, 'Rahul');
    final priya = await members.addNameOnly(gid, 'Priya');
    final me = (await members.watchForGroup(gid).first).firstWhere((m) => m.userId == uid).id;

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
        ),
      ),
    );
    await _pumpFor(t, const Duration(seconds: 2));

    Future<void> addExpense(
      String description,
      String amount,
      String? kindSymbol,
      Future<void> Function() configure,
    ) async {
      router.go(ExpenseRoutes.add(gid));
      await _pumpFor(t, const Duration(seconds: 1));
      for (final ch in amount.split('')) {
        await _tap(t, find.byKey(Key('key-${ch == '.' ? 'dot' : 'd$ch'}')));
      }
      await t.enterText(
        find.descendant(
          of: find.byKey(const Key('expense-description')),
          matching: find.byType(TextField),
        ),
        description,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await _pumpFor(t, const Duration(milliseconds: 400));
      await _tap(t, find.byKey(const Key('expense-next'))); // → Paid by (you)
      await _tap(t, find.byKey(const Key('expense-next'))); // → Split
      if (kindSymbol != null) {
        await _tap(
          t,
          find.descendant(of: find.byKey(const Key('split-kind')), matching: find.text(kindSymbol)),
        );
      }
      await configure();
      FocusManager.instance.primaryFocus?.unfocus();
      await _pumpFor(t, const Duration(milliseconds: 400));
      await _tap(t, find.byKey(const Key('expense-save')));
      await _pumpFor(t, const Duration(seconds: 2));
    }

    await addExpense('Equal dinner', '1000', null, () => _tap(t, find.byKey(Key('tick-$priya'))));
    await addExpense('Exact groceries', '1200', '1.23', () async {
      await _type(t, Key('exact-$me'), '500');
      await _type(t, Key('exact-$asha'), '300');
      await _type(t, Key('exact-$rahul'), '250');
      await _type(t, Key('exact-$priya'), '150');
    });
    await addExpense('Percent hotel', '999.99', '%', () async {
      await _type(t, Key('percent-$me'), '40');
      await _type(t, Key('percent-$asha'), '30');
      await _type(t, Key('percent-$rahul'), '20');
      await _type(t, Key('percent-$priya'), '10');
    });
    await addExpense('Shares cab', '700', '1:2', () async {
      await _tap(
        t,
        find.descendant(of: find.byKey(Key('shares-$me')), matching: find.byIcon(AppIcons.plus)),
      );
      await _tap(
        t,
        find.descendant(
          of: find.byKey(Key('shares-$priya')),
          matching: find.byIcon(AppIcons.minus),
        ),
      );
    });
    await addExpense('Adjusted fuel', '1150', '±', () async {
      await _type(t, Key('adjust-$me'), '100');
      await _type(t, Key('adjust-$asha'), '-50');
    });

    // Still offline: five pending rows with the expected kinds.
    final local = await (db.select(db.expenses)..where((e) => e.groupId.equals(gid))).get();
    expect(local, hasLength(5));
    expect(local.map((e) => e.splitKind).toSet(), {
      'equal',
      'exact',
      'percent',
      'shares',
      'adjust',
    });
    expect(local.every((e) => e.syncState != SyncState.synced), isTrue);

    // Online: push + pull.
    server.online = true;
    final engine = container.read(syncEngineProvider);
    await t.runAsync(() async {
      await engine.sync();
      await engine.sync();
    });
    final synced = await (db.select(db.expenses)..where((e) => e.groupId.equals(gid))).get();
    expect(
      synced.every((e) => e.syncState == SyncState.synced),
      isTrue,
      reason: '${engine.lastError}',
    );

    // Server rows equal the phone's rows.
    final rows = await t.runAsync(
      () => client.from('expenses').select().eq('group_id', gid).isFilter('deleted_at', null),
    );
    final byId = {for (final r in rows!) r['id'] as String: r};
    expect(byId.keys.toSet(), synced.map((e) => e.id).toSet());
    for (final e in synced) {
      final r = byId[e.id]!;
      expect(r['split_kind'], e.splitKind, reason: e.description);
      expect((r['total'] as num).toInt(), e.total, reason: e.description);
      expect(_ints(r['shares']), _ints(e.shares), reason: e.description);
      expect(_ints(r['payers']), _ints(e.payers), reason: e.description);
      if (e.splitValues != null) {
        expect(_ints(r['split_values']), _ints(e.splitValues), reason: e.description);
      }
    }

    // Server balances equal local balances.
    final order = [for (final m in await members.watchForGroup(gid).first) m.id];
    final localNets = nets(order, [
      for (final e in synced)
        ExpenseFlow(currency: e.currency, paid: _ints(e.payers), shares: _ints(e.shares)),
    ], const []);
    final balances = await t.runAsync(
      () => client.rpc<Map<String, dynamic>>('group_balances', params: {'group_id': gid}),
    );
    final serverNets = _ints((balances!['currencies'] as Map)['INR']['nets']);
    for (final m in order) {
      expect(serverNets[m] ?? 0, localNets[m] ?? 0, reason: 'net of $m');
    }

    // Another member (e2e-b claims Asha) sees identical shares.
    final code = await t.runAsync(
      () => client.from('groups').select('invite_code').eq('id', gid).single(),
    );
    final other = SupabaseClient(env.supabaseUrl, env.supabasePublishableKey);
    await t.runAsync(() async {
      await other.auth.signInWithPassword(email: 'e2e-b@splitify.test', password: env.e2ePassword);
      await other.rpc<Object?>(
        'join_group',
        params: {'code': code!['invite_code'], 'claim_member_id': asha},
      );
    });
    final seenByB = await t.runAsync(
      () => other.from('expenses').select().eq('group_id', gid).isFilter('deleted_at', null),
    );
    expect(seenByB, hasLength(5));
    for (final r in seenByB!) {
      final e = synced.firstWhere((x) => x.id == r['id']);
      expect(_ints(r['shares']), _ints(e.shares), reason: 'B sees ${e.description}');
    }

    // Tidy up the dev project: soft-delete the test group (creator only, restorable).
    await groups.delete(gid, gid);
    await t.runAsync(engine.sync);
    await t.runAsync(other.dispose);
  });
}
