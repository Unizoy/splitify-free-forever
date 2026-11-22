// Phase 13 T6 (TC-19-01 live, TC-19-04 in-app part, TC-23-01/02 on the device): A (e2e-a) uses the app, B (e2e-b)
// uses the API. B joins A's group and adds an expense with A → the server writes A's notification, pg_net calls
// the deployed `send-push`, which marks it `skipped` (no FCM secret, D-020 dummy mode) → A's bell shows the
// badge, the list shows the row, tapping it opens the expense and marks it read (server too). B reminds A
// (reminders kind); A adds an expense, then reminds B from the Balances tab → B's notification, the button
// turns into "Reminded". The `dumpsys notification` check needs Firebase → SKIPPED until the owner adds it.
//   flutter test integration_test/notifications_test.dart -d emulator-5554 \
//     --dart-define-from-file=secrets/env.dev.json [--dart-define=PIN_HOST_IP=<ip resolved on the PC>]
// With `--dart-define=UI_HOLD=<s>` it holds each screen and prints `UI-CAPTURE <name>` for
// `.claude/skills/ui-review/scripts/capture_markers.ps1` (device UI review, G5).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/features/notifications/presentation/push_pre_prompt.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart' show FolderTabs, showAppSheet;
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

/// Seconds each screen stays up for the host captures (`UI_HOLD`, 0 = no captures).
const _hold = int.fromEnvironment('UI_HOLD');

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Holds the screen for the host captures (real-time waits, never a tight pump loop).
Future<void> _capture(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(seconds: 1));
  if (_hold == 0) return;
  debugPrint('UI-CAPTURE $name');
  final end = DateTime.now().add(const Duration(seconds: _hold));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await t.pump();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TC-19-04 B adds an expense → A\'s bell → tap opens it; reminders both ways', (
    t,
  ) async {
    final env = devEnv();
    final services = await initRemote(env);
    await services.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
    final uidA = services.auth.currentUser!.id;
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
        notificationsRemoteProvider.overrideWithValue(
          SupabaseNotificationsRemote.fromClient(client),
        ),
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
    final b = (await t.runAsync(() => HarnessUser.signIn(env, 'e2e-b')))!;
    addTearDown(() => t.runAsync(b.dispose));

    // A's group (offline-first write, then sync); B joins with the invite code.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final groupName = 'E2E bell $stamp';
    final gid = await container
        .read(groupsRepositoryProvider)
        .create(name: groupName, ownerName: 'E2E A', ownerUserId: uidA, type: 'trip');
    await sync();
    final code =
        (await t.runAsync(
              () => client.from('groups').select('invite_code').eq('id', gid).single(),
            ))!['invite_code']!
            as String;
    expect((await t.runAsync(() => b.rpc('join_group', {'code': code})))!['group_id'], gid);
    await sync();
    final rows = await (db.select(db.groupMembers)..where((m) => m.groupId.equals(gid))).get();
    final ma = rows.firstWhere((m) => m.userId == uidA).id;
    final mb = rows.firstWhere((m) => m.userId == b.id).id;

    // B adds "Bell dinner" ₹1,000 paid by B, split with A (A owes B ₹500).
    final eid = newId();
    final r = (await t.runAsync(
      () => b.rpc('apply_mutations', {
        'batch': [
          {
            'mutation_id': newId(),
            'entity': 'expense',
            'op': 'upsert',
            'id': eid,
            'group_id': gid,
            'client_updated_at': DateTime.now().toUtc().toIso8601String(),
            'source': 'app',
            'data': {
              'kind': 'expense',
              'description': 'Bell dinner',
              'category': 'food.dining_out',
              'date': DateTime.now().toIso8601String().substring(0, 10),
              'currency': 'INR',
              'total': 100000,
              'payers': {mb: 100000},
              'shares': {ma: 50000, mb: 50000},
              'split_kind': 'equal',
            },
          },
        ],
      }),
    ))!;
    expect(((r['results']! as List).single! as Map)['status'], 'applied', reason: '$r');

    // TC-19-01 live: A's row exists (actor B gets none), and send-push answers 'skipped' (dummy mode).
    final activityId =
        (await t.runAsync(
              () => client
                  .from('activity')
                  .select('id')
                  .eq('target_id', eid)
                  .eq('type', 'expense_added')
                  .single(),
            ))!['id']!
            as String;
    Map<String, dynamic>? serverRow;
    final until = DateTime.now().add(const Duration(seconds: 45));
    while (DateTime.now().isBefore(until)) {
      serverRow = await t.runAsync<Map<String, dynamic>?>(
        () async => client
            .from('notifications')
            .select('id, kind, body, push_status, read_at, data')
            .eq('activity_id', activityId)
            .maybeSingle(),
      );
      if (serverRow != null && serverRow['push_status'] != 'pending') break;
      await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    }
    expect(serverRow, isNotNull, reason: 'A has a notification for B\'s expense');
    expect(serverRow!['kind'], 'expenses');
    expect(serverRow['body'] as String, contains('added “Bell dinner” · ₹1,000'));
    expect(
      serverRow['push_status'],
      'skipped',
      reason: 'send-push without FCM secret marks skipped',
    );
    final nid = serverRow['id']! as String;
    final bRows = await t.runAsync(
      () => b.client.from('notifications').select('id').eq('activity_id', activityId),
    );
    expect(bRows, isEmpty, reason: 'the actor is never notified');

    // The app: Activity tab with the bell badge.
    final router = buildRouter(initialLocation: '/activity');
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
    await pumpUntil(
      t,
      () => find.byKey(const Key('hero-badge')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 40),
      reason: 'bell badge',
    );
    await _capture(t, 'activity_bell');

    // Bell → list → tap the row → the expense opens, the row is read (phone and server).
    await t.tap(find.byKey(const Key('activity-bell')));
    await pumpUntil(
      t,
      () => find.byKey(ValueKey('notification-$nid')).evaluate().isNotEmpty,
      reason: 'notification row',
    );
    expect(find.textContaining('added “Bell dinner”'), findsWidgets);
    await _capture(t, 'notifications_list');
    await t.tap(find.byKey(ValueKey('notification-$nid')));
    await pumpUntil(
      t,
      () => find.text('Bell dinner', skipOffstage: false).evaluate().isNotEmpty,
      reason: 'expense detail',
    );
    expect(find.byType(ExpenseDetailScreen), findsOneWidget);
    final local = await (db.select(db.notifications)..where((n) => n.id.equals(nid))).getSingle();
    expect(local.readAt, isNotNull);
    String? readAt;
    final readUntil = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(readUntil)) {
      readAt =
          (await t.runAsync(
                () => client.from('notifications').select('read_at').eq('id', nid).single(),
              ))!['read_at']
              as String?;
      if (readAt != null) break;
      await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    }
    expect(readAt, isNotNull, reason: 'the read mark reached the server');

    // TC-23-01 live: B reminds A (A owes B ₹500) → A's reminders notification with the 08 #23 copy.
    final sent = (await t.runAsync(
      () => b.rpc('send_reminder', {'group_id': gid, 'to_member_id': ma}),
    ))!;
    expect(sent['amounts'], {'INR': 50000});
    final reminderBody =
        (await t.runAsync(
              () => client
                  .from('notifications')
                  .select('body, kind')
                  .eq('group_id', gid)
                  .eq('kind', 'reminders')
                  .single(),
            ))!['body']!
            as String;
    expect(reminderBody, contains('reminded you about ₹500 in “$groupName”'));

    // A adds ₹3,000 paid by A, split with B → B owes A ₹1,000; A reminds B from the Balances tab.
    await container.read(expensesRepositoryProvider).save(gid, {
      'kind': 'expense',
      'description': 'Bell hotel',
      'notes': null,
      'category': 'travel.hotel',
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'currency': 'INR',
      'total': 300000,
      'payers': {ma: 300000},
      'shares': {ma: 150000, mb: 150000},
      'split_kind': 'equal',
      'split_values': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await sync();
    router.go('/groups/$gid?tab=balances');
    final remind = find.byKey(Key('remind-$mb'), skipOffstage: false);
    await pumpUntil(t, () => remind.evaluate().isNotEmpty, reason: 'Remind button');
    expect(
      find.descendant(of: find.byType(FolderTabs), matching: find.text('Balances')),
      findsWidgets,
    );
    await t.ensureVisible(remind);
    await _pumpFor(t, const Duration(milliseconds: 300));
    await _capture(t, 'balances_remind');
    await t.tap(remind);
    await pumpUntil(
      t,
      () => find.textContaining('Reminder sent to').evaluate().isNotEmpty,
      reason: 'reminder snackbar',
    );
    final forB = await t.runAsync(
      () =>
          b.client.from('notifications').select('body').eq('group_id', gid).eq('kind', 'reminders'),
    );
    expect(forB, hasLength(1));
    expect(forB!.single['body'] as String, contains('reminded you about ₹1,000'));
    await _pumpFor(t, const Duration(seconds: 1));
    await _capture(t, 'balances_reminded');

    // Settings page (bell only on this build) and the pre-prompt sheet, for the device review.
    if (_hold > 0) {
      router.go('/account/notifications');
      await _capture(t, 'notification_settings');
      final ctx = t.element(find.byType(Scaffold).first);
      final l = AppLocalizations.of(ctx);
      // ignore: discarded_futures
      showAppSheet<bool>(
        ctx,
        title: l.notifPrePromptTitle,
        builder: (_) => const PushPrePromptBody(),
      );
      await _capture(t, 'push_preprompt');
    }

    // Tidy up the dev project: mark A's notifications read, soft-delete the test group (restorable).
    await t.runAsync(() => client.rpc<Object?>('mark_notifications_read'));
    await container.read(groupsRepositoryProvider).delete(gid, gid);
    await sync();
  });
}
