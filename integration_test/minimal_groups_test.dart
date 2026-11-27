// D-033 end to end on the emulator against the DEV project (phone = e2e-a, second person = e2e-b through
// the multi-user harness): create a group on the one-screen form with name-only people, "Invite with a link
// or QR" saves it and shows the code once synced, B joins through the code claiming Asha, A sees Asha linked;
// A joins B's group by pasting the shared message; add a friend in one sheet; profile edit with inline UPI
// validation (restored afterwards); import a Splitwise fixture on the one setup screen → preview → done →
// the rows reach the server. Test groups are soft-deleted at the end.
//   flutter test integration_test/minimal_groups_test.dart -d emulator-5554 \
//     --dart-define-from-file=secrets/env.dev.json --dart-define=PIN_HOST_IP=<ip resolved on the PC>
// With --dart-define=UI_HOLD=6 it prints `UI-CAPTURE <name>` (+ `<name>-dark`) and holds each state for
// tool/e2e/capture_minimal_groups.ps1. Build side by side with the store build: SPLITIFY_APP_ID_SUFFIX=.qa.
import 'dart:convert';
import 'dart:typed_data';

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
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/domain/rules/invite_code.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/import_splitwise/application/import_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

/// Seconds each reviewed state stays up for the host captures (`UI_HOLD`, 0 = no hold).
const _hold = int.fromEnvironment('UI_HOLD');

/// A small Splitwise export: three expenses and one payment between Mohit, Asha and Rahul.
const _csv =
    'Date,Description,Category,Cost,Currency,Mohit,Asha,Rahul\n'
    '2026-11-01,Dinner,Dining out,900.00,INR,600.00,-300.00,-300.00\n'
    '2026-11-02,Taxi,Taxi,300.00,INR,-100.00,200.00,-100.00\n'
    '2026-11-03,Hotel,Hotel,3000.00,INR,-1000.00,-1000.00,2000.00\n'
    '2026-11-04,Rahul paid Mohit,Payment,500.00,INR,-500.00,0.00,500.00\n'
    '\n'
    '2026-11-04,Total balance,,,INR,-1000.00,-1100.00,2100.00\n';

class _Picker implements ImportFilePicker {
  @override
  Future<PickedFile?> pick() async =>
      (name: 'goa-trip_2026-11-27_export.csv', bytes: Uint8List.fromList(utf8.encode(_csv)));
}

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Lazy lists build only what is near the screen: scroll the page to [f] first.
Future<void> _reveal(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  }
  await t.ensureVisible(f);
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await _reveal(t, f);
  await t.pump();
  await t.tap(f);
  await _pumpFor(t, const Duration(milliseconds: 600));
}

Future<void> _waitFor(WidgetTester t, Finder f, {String reason = ''}) =>
    pumpUntil(t, () => f.evaluate().isNotEmpty, reason: reason.isEmpty ? '$f' : reason);

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

Future<void> _type(WidgetTester t, String key, String text) async {
  await _reveal(t, find.byKey(Key(key)));
  await t.enterText(_field(key), text);
  await _pumpFor(t, const Duration(milliseconds: 300));
}

/// Holds the screen (light, then dark) for the host captures.
Future<void> _shot(WidgetTester t, String name, {bool unfocus = true}) async {
  await _pumpFor(t, const Duration(milliseconds: 800));
  if (unfocus) FocusManager.instance.primaryFocus?.unfocus();
  await _pumpFor(t, const Duration(milliseconds: 400));
  if (_hold == 0) return;
  for (final n in [name, '$name-dark']) {
    debugPrint('UI-CAPTURE $n');
    final end = DateTime.now().add(const Duration(seconds: _hold));
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await t.pump();
    }
  }
}

Future<void> _closeSheet(WidgetTester t) async {
  await t.tapAt(const Offset(20, 80));
  await _pumpFor(t, const Duration(milliseconds: 800));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D-033: group form → invite → B joins; paste-join; add friend; profile; import', (
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
        importFilePickerProvider.overrideWithValue(_Picker()),
      ],
    );
    addTearDown(container.dispose);
    final engine = container.read(syncEngineProvider);
    Future<void> sync() => t.runAsync(() async {
      await engine.sync();
      await engine.sync();
    });
    final b = await HarnessUser.signIn(env, 'e2e-b');
    final cleanups = <Future<void> Function()>[];
    addTearDown(() async {
      for (final c in cleanups.reversed) {
        try {
          await c();
        } on Object catch (e) {
          debugPrint('cleanup failed: $e');
        }
      }
      await b.dispose();
    });

    final router = buildRouter(initialLocation: Routes.newGroup);
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
    await _waitFor(t, find.byKey(const Key('group-name')), reason: 'group form');
    await _shot(t, 'group-new');

    // 1. One screen: name, type, two name-only people (the second still in the field when saving).
    final name = 'Goa trip (E2E ${DateTime.now().millisecondsSinceEpoch % 100000})';
    await _type(t, 'group-name', name);
    await _tap(t, find.byKey(const Key('group-type-home')));
    await _type(t, 'group-add-person', 'Asha');
    await _tap(t, find.byKey(const Key('group-add-person-button')));
    await _type(t, 'group-add-person', 'Rahul');
    await _shot(t, 'group-new-filled');

    // 2. "Invite with a link or QR" saves the group and shows its invite sheet; the code comes once synced.
    await _tap(t, find.byKey(const Key('group-invite')));
    await _waitFor(t, find.byKey(const Key('invite-no-code')), reason: 'invite sheet before sync');
    final gid = (await (db.select(db.groups)).get()).singleWhere((g) => g.name == name).id;
    cleanups.add(() async {
      await container.read(groupsRepositoryProvider).delete(gid, gid);
      await engine.sync();
    });
    final local = await (db.select(db.groupMembers)).get();
    expect(
      local.where((m) => m.groupId == gid).map((m) => m.displayName).toSet(),
      containsAll(<String>{'Asha', 'Rahul'}),
    );
    await sync();
    await _waitFor(t, find.byKey(const Key('invite-code')), reason: 'code after sync');
    await _shot(t, 'invite-sheet');
    final code = InviteCode.normalize(t.widget<Text>(find.byKey(const Key('invite-code'))).data!);
    expect(find.text(InviteCode.link(code)), findsOneWidget);
    final serverGroup = await t.runAsync(
      () => client.from('groups').select('type, name').eq('id', gid).single(),
    );
    expect(serverGroup!['type'], 'home');
    await _closeSheet(t);

    // 3. B joins through the code and claims Asha; A sees Asha linked after a sync.
    final ashaId = local.singleWhere((m) => m.groupId == gid && m.displayName == 'Asha').id;
    final preview =
        (await t.runAsync(() => b.client.rpc<Object?>('preview_join', params: {'code': code})))!
            as Map;
    expect((preview['unclaimed']! as List).map((m) => (m as Map)['id']), contains(ashaId));
    await t.runAsync(
      () => b.client.rpc<Object?>('join_group', params: {'code': code, 'claim_member_id': ashaId}),
    );
    await sync();
    final asha = await (db.select(db.groupMembers)..where((m) => m.id.equals(ashaId))).getSingle();
    expect(asha.userId, b.id);
    router.go('/groups/$gid/settings');
    await _waitFor(t, find.byKey(const Key('settings-edit-group')));
    await _shot(t, 'group-settings');
    router.go('/groups/$gid/edit');
    await _waitFor(t, find.byKey(const Key('group-name')));
    await _shot(t, 'group-edit');

    // 4. A joins B's group by pasting the shared message on the join screen.
    final bid = newId();
    final now = DateTime.now().toUtc().toIso8601String();
    Map<String, Object?> mutation(String entity, String id, Map<String, Object?> data) => {
      'mutation_id': newId(),
      'entity': entity,
      'op': 'upsert',
      'id': id,
      'group_id': bid,
      'client_updated_at': now,
      'data': data,
    };
    await t.runAsync(
      () => b.client.rpc<Object?>(
        'apply_mutations',
        params: {
          'batch': [
            mutation('group', bid, {
              'name': 'Manali weekend (E2E)',
              'type': 'trip',
              'main_currency': 'INR',
              'owner_member': {'id': newId(), 'display_name': 'Kiran'},
            }),
            mutation('member', newId(), {'display_name': 'Neha', 'position': 1}),
          ],
        },
      ),
    );
    cleanups.add(() async {
      await container.read(groupActionsProvider).leave(bid);
      await b.client.rpc<Object?>(
        'apply_mutations',
        params: {
          'batch': [
            {...mutation('group', bid, const {}), 'op': 'delete'},
          ],
        },
      );
    });
    final bCode =
        (await t.runAsync(
              () => b.client.from('groups').select('invite_code').eq('id', bid).single(),
            ))!['invite_code']
            as String;
    router.go(Routes.join);
    await _waitFor(t, find.byKey(const Key('join-code')));
    await _shot(t, 'join');
    await t.enterText(
      _field('join-code'),
      'Join my group “Manali weekend” on Splitify Free Forever: code ${InviteCode.display(bCode)}',
    );
    await _waitFor(t, find.byKey(const Key('join-preview')), reason: 'pasted code looked up');
    await _tap(t, find.byKey(const Key('join-new')));
    await _shot(t, 'join-preview');
    await _tap(t, find.byKey(const Key('join-submit')));
    await pumpUntil(t, () => router.state.uri.path == '/groups/$bid', reason: 'joined group');
    final mine = await (db.select(db.groupMembers)..where((m) => m.groupId.equals(bid))).get();
    expect(mine.where((m) => m.userId == uid), hasLength(1));

    // 5. Add a friend in one sheet; their page opens (compact header, Settle up, Add expense).
    router.go(Routes.friends);
    await _waitFor(t, find.byKey(const Key('friends-add')));
    await _tap(t, find.byKey(const Key('friends-add')));
    await _waitFor(t, find.byKey(const Key('add-friend-name')));
    await _type(t, 'add-friend-name', 'Kabir');
    await _shot(t, 'add-friend');
    await _tap(t, find.byKey(const Key('add-friend-save')));
    await _waitFor(t, find.byKey(const Key('friend-settle')), reason: 'friend page');
    final direct = (await (db.select(db.groups)).get()).singleWhere(
      (g) => g.type == 'direct' && g.deletedAt == null && g.name.contains('Kabir'),
    );
    cleanups.add(() async {
      await container.read(groupsRepositoryProvider).delete(direct.id, direct.id);
      await engine.sync();
    });
    await _shot(t, 'friend-page');

    // 6. Profile: inline UPI check on leaving the field, save, then put the old profile back.
    final before = container.read(profileProvider).value!;
    cleanups.add(() => container.read(profileProvider.notifier).save(before));
    router.go(Routes.profile);
    await _waitFor(t, find.byKey(const Key('profile-upi')));
    await _shot(t, 'profile-edit');
    await _type(t, 'profile-upi', 'not a upi');
    FocusManager.instance.primaryFocus?.unfocus();
    await _pumpFor(t, const Duration(milliseconds: 500));
    expect(find.text('Enter a UPI ID like name@bank'), findsOneWidget);
    await _shot(t, 'profile-upi-error');
    await _type(t, 'profile-upi', 'e2e.a@okaxis');
    await _tap(t, find.byKey(const Key('profile-save')));
    await pumpUntil(
      t,
      () => container.read(profileProvider).value?.upiId == 'e2e.a@okaxis',
      reason: 'profile saved',
    );
    final saved = await t.runAsync(
      () => client.from('profiles').select('upi_id').eq('id', uid).single(),
    );
    expect(saved!['upi_id'], 'e2e.a@okaxis');
    router.go(Routes.signInProfile);
    await _waitFor(t, find.byKey(const Key('profile-continue')));
    await _shot(t, 'profile-confirm');

    // 7. Import the fixture into the test group: file → setup (people) → preview → done → server.
    router.go('/groups/$gid/import');
    await _waitFor(t, find.byKey(const Key('import-pick')));
    await _shot(t, 'import-file');
    await _tap(t, find.byKey(const Key('import-pick')));
    await _waitFor(t, find.byKey(const Key('import-setup')));
    await _shot(t, 'import-setup');
    await _tap(t, find.byKey(const Key('import-continue')));
    await _waitFor(t, find.byKey(const Key('import-run')));
    await _shot(t, 'import-preview');
    await _tap(t, find.byKey(const Key('import-run')));
    await _waitFor(t, find.byKey(const Key('import-done')), reason: 'import done');
    await _shot(t, 'import-done');
    await sync();
    final rows = await t.runAsync(
      () => client.from('expenses').select('id').eq('group_id', gid).isFilter('deleted_at', null),
    );
    final payments = await t.runAsync(
      () => client.from('payments').select('id').eq('group_id', gid).isFilter('deleted_at', null),
    );
    expect(rows, hasLength(3));
    expect(payments, hasLength(1));
    debugPrint('D-033-MINIMAL-GROUPS OK code=$code');
  });
}
