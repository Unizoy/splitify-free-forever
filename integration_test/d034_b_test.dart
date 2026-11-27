// D-034 WP-B (Settle and friends) on the emulator against the DEV project. A (e2e-a) uses the app; F is a FRESH
// harness account each run (so no old balances leak in), with a UPI ID:
//  1. Friend code: Add friend shows "Show my code" (A's code from the server); F's code arrives as the deep link
//     `splitify://friend?code=…` (sent with `adb shell am start` by tool/e2e/capture_d034_b.ps1 when it sees
//     `UI-DEEPLINK`, else through the router) → "Add a friend by code" → Add friend → F's page; the server has
//     one direct group with both accounts linked, and F sees it too.
//  2. Batch settle offline, then online: F owes A ₹200 in a shared group and ₹255 in the friend group. With the
//     server unreachable, Settle up → "Everything with F · ₹455 · 2 groups" → Record: two pending payments queued
//     in the documented order (biggest first), nothing on the server; back online they arrive, both pairs are
//     settled on the server and Activity has both. The friend page then collapses the settled history.
//  3. Restore from the payment page: a deleted payment shows "Deleted" + Restore; restoring reaches the server.
//  4. Pay via UPI for a batch (A owes F ₹150 across both groups): one link with the total (`UPI-EXPECT`, compared
//     with the fake UPI app's logcat by the runner), "Mark as paid" records both payments with method UPI.
//  5. Share a reminder for a name-only member (the in-app sheet; Android's share sheet is not driven).
// With --dart-define=UI_HOLD=<s> every state prints `UI-CAPTURE <name>` and holds for the host screenshots.
//   powershell -Command ". tool\env.ps1; & tool\e2e\capture_d034_b.ps1"
import 'dart:async';

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
import 'package:splitify/core/upi/upi_link.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/friend_code/presentation/friend_code_screen.dart';
import 'package:splitify/features/friends/presentation/friend_page.dart';
import 'package:splitify/features/friends/presentation/friend_routes.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

const _hold = int.fromEnvironment('UI_HOLD');
const _vpaF = 'e2e.f@okaxis';

/// The server as the sync engine sees it, with an "offline" switch (throws like a lost network).
class _SwitchableRemote implements RemoteApi {
  _SwitchableRemote(this._inner);

  final RemoteApi _inner;
  bool offline = false;

  void _check() {
    if (offline) throw const NetworkException('e2e offline');
  }

  @override
  Future<ApplyResponse> applyMutations(List<Map<String, Object?>> batch) {
    _check();
    return _inner.applyMutations(batch);
  }

  @override
  Future<PullPage> pullChanges({
    required Map<String, int> cursors,
    required int userSeq,
    int pageSize = 500,
  }) {
    _check();
    return _inner.pullChanges(cursors: cursors, userSeq: userSeq, pageSize: pageSize);
  }

  @override
  Future<void> refreshSession() => _inner.refreshSession();
}

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitFor(WidgetTester t, Finder f, {int seconds = 30}) => pumpUntil(
  t,
  () => f.evaluate().isNotEmpty,
  timeout: Duration(seconds: seconds),
  reason: '$f',
);

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _pumpFor(t, const Duration(milliseconds: 600));
}

Finder _key(String k) => find.byKey(Key(k));

/// The top-most copy (a page under the current one can stay in the tree after `go`).
Finder _top(String k) => find.byKey(Key(k)).last;

/// Holds the screen for the host screenshot (light, then `-dark` with the emulator in dark mode).
Future<void> _capture(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(milliseconds: 800));
  if (_hold == 0) return;
  for (final n in [name, '$name-dark']) {
    debugPrint('UI-CAPTURE $n');
    await _pumpFor(t, const Duration(seconds: _hold));
  }
}

/// Closes the sheet on top (the scrim's barrier).
Future<void> _closeSheet(WidgetTester t) async {
  final nav = t.state<NavigatorState>(find.byType(Navigator).first);
  nav.pop();
  await _pumpFor(t, const Duration(milliseconds: 800));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D-034 B: friend code, batch settle offline → online, restore, batch UPI, share reminder',
    (t) async {
      final env = devEnv();
      final services = await initRemote(env);
      await services.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
      final uidA = services.auth.currentUser!.id;
      final client = Supabase.instance.client;
      final db = AppDatabase(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final remote = _SwitchableRemote(SupabaseRemoteApi.client(client));
      final balances = SupabaseBalancesRemote.fromClient(client);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          remoteApiProvider.overrideWithValue(remote),
          balancesRemoteProvider.overrideWithValue(balances),
          groupsRemoteProvider.overrideWithValue(services.groups),
          friendsRemoteProvider.overrideWithValue(SupabaseFriendsRemote.fromClient(client)),
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

      // F: a new account each run, with a name and a UPI ID.
      final stamp = DateTime.now().millisecondsSinceEpoch % 10000000;
      final f = (await t.runAsync(() => HarnessUser.signIn(env, 'e2e-b034-$stamp')))!;
      addTearDown(() => t.runAsync(f.dispose));
      await t.runAsync(
        () => f.client.rpc<Object?>(
          'update_profile',
          params: {
            'p_display_name': 'Farah E2E',
            'p_upi_id': _vpaF,
            'p_default_currency': 'INR',
            'p_avatar_path': null,
          },
        ),
      );
      final codeF = (await t.runAsync(() => f.client.rpc<Object?>('my_friend_code')))! as String;

      final router = buildRouter(initialLocation: '/friends');
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
      await sync();
      await _waitFor(t, _key('friends-add'));
      // The host brings the window to the front once (on this emulator a freshly installed test app's surface can
      // stay hidden, so screenshots come out black: HOME + `am start` shows it).
      if (_hold > 0) {
        debugPrint('UI-READY');
        await _pumpFor(t, const Duration(seconds: 6));
      }

      // ---- 1. Friend code: the Add friend sheet, my code, then F's code through the deep link.
      await _tap(t, _key('friends-add'));
      await _waitFor(t, _key('add-friend-my-code'));
      FocusManager.instance.primaryFocus?.unfocus();
      await _capture(t, 'add-friend-sheet');
      await _tap(t, _key('add-friend-my-code'));
      await _waitFor(t, _key('friend-code'), seconds: 20);
      await _capture(t, 'my-code');
      await _closeSheet(t);

      final link = 'splitify://friend?code=$codeF';
      debugPrint('UI-DEEPLINK $link');
      var viaAdb = true;
      try {
        await _waitFor(t, find.byType(FriendCodeScreen), seconds: 25);
      } on TestFailure {
        viaAdb = false;
        router.go(link);
        await _waitFor(t, find.byType(FriendCodeScreen));
      }
      debugPrint('D-034-DEEPLINK ${viaAdb ? 'adb' : 'router'}');
      expect(find.text('${codeF.substring(0, 4)}-${codeF.substring(4)}'), findsOneWidget);
      await _capture(t, 'add-by-code');
      await _tap(t, _key('friend-code-add'));
      await _waitFor(t, _key('friend-settle'), seconds: 40);
      final friendKey = 'u:${f.id}';
      expect(t.widget<FriendPage>(find.byType(FriendPage).last).friendKey, friendKey);
      // One direct group with both accounts linked; F sees it too.
      final directs = (await t.runAsync(
        () => f.client
            .from('group_members')
            .select('group_id, user_id, groups!inner(type)')
            .eq('groups.type', 'direct'),
      ))!;
      final directId = directs.first['group_id']! as String;
      expect({for (final r in directs) r['user_id']}, {uidA, f.id});
      expect(
        {for (final r in directs) r['group_id']},
        {directId},
        reason: 'exactly one direct group',
      );
      debugPrint('D-034-FRIEND-CODE OK');

      // ---- 2. A shared group; F owes A ₹200 there and ₹255 in our friend group; Ravi (name-only) owes A ₹7.
      final groups = container.read(groupsRepositoryProvider);
      final gid = await groups.create(
        name: 'E2E Settle all $stamp',
        ownerName: 'E2E A',
        ownerUserId: uidA,
        type: 'trip',
      );
      final ravi = await container.read(membersRepositoryProvider).addNameOnly(gid, 'Ravi');
      await sync();
      addTearDown(() async {
        await groups.delete(gid, gid);
        remote.offline = false;
        await sync();
      });
      final code =
          (await t.runAsync(
                () => client.from('groups').select('invite_code').eq('id', gid).single(),
              ))!['invite_code']!
              as String;
      expect((await t.runAsync(() => f.rpc('join_group', {'code': code})))!['group_id'], gid);
      await sync();
      Future<String> memberOf(String group, String user) async => (await (db.select(
        db.groupMembers,
      )..where((m) => m.groupId.equals(group) & m.userId.equals(user))).getSingle()).id;
      final aG = await memberOf(gid, uidA);
      final fG = await memberOf(gid, f.id);
      final aD = await memberOf(directId, uidA);
      final fD = await memberOf(directId, f.id);
      Map<String, Object?> expense(
        String group,
        String description,
        int total,
        Map<String, int> payers,
        Map<String, int> shares,
      ) => {
        'mutation_id': newId(),
        'entity': 'expense',
        'op': 'upsert',
        'id': newId(),
        'group_id': group,
        'client_updated_at': DateTime.now().toUtc().toIso8601String(),
        'source': 'app',
        'data': {
          'kind': 'expense',
          'description': description,
          'category': 'other.general',
          'date': '2026-11-27',
          'currency': 'INR',
          'total': total,
          'payers': payers,
          'shares': shares,
          'split_kind': 'exact',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      };
      Future<void> fAdds(List<Map<String, Object?>> batch) async {
        final r = (await t.runAsync(() => f.rpc('apply_mutations', {'batch': batch})))!;
        for (final x in r['results']! as List) {
          expect((x! as Map)['status'], 'applied', reason: '$r');
        }
      }

      await fAdds([
        expense(gid, 'Villa', 40000, {aG: 40000}, {aG: 20000, fG: 20000}),
        expense(directId, 'Concert', 51000, {aD: 51000}, {aD: 25500, fD: 25500}),
        expense(gid, 'Chai', 1400, {aG: 1400}, {aG: 700, ravi: 700}),
      ]);
      await sync();

      // Offline from here: the batch is written on the phone only.
      remote.offline = true;
      router.go(FriendRoutes.page(friendKey));
      await _waitFor(t, _key('friend-status-owed'));
      await _tap(t, _top('friend-settle'));
      await _waitFor(t, _key('settle-all-INR'));
      expect(find.text('owes you ₹455 · 2 groups'), findsOneWidget);
      await _capture(t, 'settle-sheet');
      await _tap(t, _key('settle-all-INR'));
      await _waitFor(t, _key('settle-all-form'));
      expect(find.text('Settles all of ₹455'), findsOneWidget);
      await _capture(t, 'batch-form');
      await _tap(t, _key('settle-all-across'));
      await _waitFor(t, _key('settle-all-breakdown'));
      await _capture(t, 'batch-breakdown');
      await _closeSheet(t);
      await _tap(t, _key('settle-save'));
      await _pumpFor(t, const Duration(seconds: 3));

      final pending = await (db.select(
        db.payments,
      )..where((p) => p.groupId.isIn([gid, directId]))).get();
      expect(pending, hasLength(2));
      expect(pending.every((p) => p.syncState != 'synced'), isTrue, reason: 'not synced yet');
      final queued = [
        for (final o in await db.select(db.outbox).get())
          if (o.entity == 'payment') o.groupId,
      ];
      expect(queued, [directId, gid], reason: 'queued in order, biggest balance first');
      final onServer = (await t.runAsync(
        () => f.client.from('payments').select('id').inFilter('group_id', [gid, directId]),
      ))!;
      expect(onServer, isEmpty, reason: 'offline: nothing reached the server');

      // Online: the outbox sends both, in order; the server nets between A and F are 0 in both groups.
      remote.offline = false;
      await sync();
      for (final (group, a, other) in [(gid, aG, fG), (directId, aD, fD)]) {
        final b = (await t.runAsync(() => balances.groupBalances(group)))!;
        final pairs = b.currencies['INR']?.pairs ?? const [];
        expect(
          pairs.where((p) => {p.from, p.to}.containsAll({a, other})),
          isEmpty,
          reason: 'settled between A and F in $group',
        );
      }
      final added = (await t.runAsync(
        () => f.client.from('activity').select('group_id').eq('type', 'payment_added').inFilter(
          'group_id',
          [gid, directId],
        ),
      ))!;
      expect(
        {for (final r in added) r['group_id']},
        {gid, directId},
        reason: 'Activity shows both',
      );
      debugPrint('D-034-BATCH-OFFLINE-ONLINE OK');

      // The friend page: everything settled → the history collapses.
      router.go(FriendRoutes.page(friendKey));
      await _waitFor(t, _key('friend-show-settled'));
      await _capture(t, 'friend-settled');

      // ---- 3. Restore from the payment page.
      final paid = pending.firstWhere((p) => p.groupId == gid);
      final row = (await (db.select(db.payments)..where((p) => p.id.equals(paid.id))).getSingle());
      await container.read(paymentActionsProvider).delete(row);
      await sync();
      unawaited(router.push(PaymentRoutes.detail(paid.id)));
      await _waitFor(t, _key('payment-restore'));
      expect(find.text('Deleted'), findsOneWidget);
      await _capture(t, 'payment-deleted');
      await _tap(t, _key('payment-restore'));
      await sync();
      final back = (await t.runAsync(
        () => f.client.from('payments').select('deleted_at').eq('id', paid.id).single(),
      ))!;
      expect(back['deleted_at'], isNull);
      final restored = (await t.runAsync(
        () => f.client
            .from('activity')
            .select('id')
            .eq('type', 'payment_restored')
            .eq('target_id', paid.id),
      ))!;
      expect(restored, hasLength(1));
      debugPrint('D-034-RESTORE OK');

      // ---- 4. A owes F ₹150 across both groups: one UPI link for the total, Mark as paid records both.
      await fAdds([
        expense(gid, 'Cab', 20000, {fG: 20000}, {aG: 10000, fG: 10000}),
        expense(directId, 'Snacks', 10000, {fD: 10000}, {aD: 5000, fD: 5000}),
      ]);
      await sync();
      router.go(FriendRoutes.page(friendKey));
      await _waitFor(t, _key('friend-status-owe'));
      await _tap(t, _top('friend-settle'));
      await _waitFor(t, _key('settle-all-INR'));
      await _tap(t, _key('settle-all-INR'));
      await _waitFor(t, _key('settle-upi'));
      expect(find.text('Pay ₹150 via UPI'), findsOneWidget);
      await _capture(t, 'batch-upi');
      final upi = const UpiLinkBuilder().build(
        vpa: _vpaF,
        name: 'Farah E2E',
        amountMinor: 15000,
        currencyCode: 'INR',
        note: 'Splitify: settle up',
      );
      debugPrint('UPI-EXPECT ${upi.uri}');
      await t.tap(_key('settle-upi'));
      // The fake UPI app (when installed) takes the foreground and hands back; then the return sheet.
      await pumpUntil(
        t,
        () => _key('upi-return').evaluate().isNotEmpty || _key('upi-no-app').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 60),
        reason: 'the UPI return sheet',
      );
      expect(
        await (db.select(db.payments)..where((p) => p.method.equals('upi'))).get(),
        isEmpty,
        reason: 'nothing recorded before "Mark as paid" (rule 13)',
      );
      await _tap(t, _key('upi-mark-paid'));
      await _pumpFor(t, const Duration(seconds: 3));
      final upiRows = await (db.select(db.payments)..where((p) => p.method.equals('upi'))).get();
      expect(
        [for (final p in upiRows) (p.groupId, p.amount)]..sort((x, y) => x.$2.compareTo(y.$2)),
        [(gid, 10000), (directId, 5000)]..sort((x, y) => x.$2.compareTo(y.$2)),
      );
      expect(upiRows.every((p) => p.fromMember == aG || p.fromMember == aD), isTrue);
      await sync();
      final serverUpi = (await t.runAsync(
        () => f.client.from('payments').select('amount').eq('method', 'upi').inFilter('group_id', [
          gid,
          directId,
        ]),
      ))!;
      expect(serverUpi, hasLength(2));
      debugPrint('D-034-BATCH-UPI OK');

      // ---- 5. Share a reminder for Ravi (name-only, owes A ₹7): the in-app sheet with the text.
      router.go(FriendRoutes.page('m:$ravi'));
      await _waitFor(t, _key('friend-remind'));
      await _tap(t, _top('friend-remind'));
      await _waitFor(t, _key('remind-share-sheet'));
      expect(
        find.textContaining('Hi Ravi, a reminder about ₹7 for “E2E Settle all $stamp”'),
        findsOneWidget,
      );
      await _capture(t, 'share-reminder');
      await _closeSheet(t);
      debugPrint('D-034-SHARE-REMINDER OK');
    },
  );
}
