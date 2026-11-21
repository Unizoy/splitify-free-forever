// Phase 07 device tests on the DEV project with the e2e users (TC-1-06, TC-3-04, TC-3-05, TC-4-04 and the
// phase E2E scenario). The phone is user A; user B is the multi-user harness (its own Supabase client).
//   flutter test integration_test/groups_test.dart -d emulator-5554 --dart-define-from-file=secrets/env.dev.json
// "Offline" = the sync engine's server switched off (every call fails like a dropped network), as in phase 08.
import 'dart:convert';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/rules/invite_code.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/join_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

/// The real server, switched off while "offline".
class SwitchableRemote implements RemoteApi {
  SwitchableRemote(this.inner, {this.online = false});

  final RemoteApi inner;
  bool online;

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

RemoteServices? _services;

/// Starts Supabase once (with the PIN_HOST_IP workaround, S-214) and signs the phone in as e2e-a.
Future<(Env, RemoteServices, String)> _signInA() async {
  final env = devEnv();
  final services = _services ??= await initRemote(env);
  if (services.auth.currentUser == null) {
    await services.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
  }
  return (env, services, services.auth.currentUser!.id);
}

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [f] finds something (real network calls take a moment), or fails after [max].
Future<void> _waitFor(
  WidgetTester t,
  Finder f, {
  Duration max = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(max);
  while (f.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting for $f');
    await t.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _pumpFor(t, const Duration(milliseconds: 600));
}

Future<void> _type(WidgetTester t, Key field, String text) async {
  final input = find.descendant(of: find.byKey(field), matching: find.byType(TextField));
  await t.ensureVisible(input);
  await t.enterText(input, text);
  await t.pump();
}

class _Phone {
  _Phone(this.container, this.router, this.db, this.server);

  final ProviderContainer container;
  final GoRouter router;
  final AppDatabase db;
  final SwitchableRemote server;

  Future<void> sync() => container.read(syncEngineProvider).sync();
}

Future<_Phone> _open(
  WidgetTester t,
  RemoteServices services,
  String location, {
  bool online = true,
  List<Override> extra = const [],
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final server = SwitchableRemote(services.api, online: online);
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      remoteApiProvider.overrideWithValue(server),
      groupsRemoteProvider.overrideWithValue(services.groups),
      authRepositoryProvider.overrideWithValue(services.auth),
      profileRemoteProvider.overrideWithValue(services.profiles),
      ...extra,
    ],
  );
  addTearDown(container.dispose);
  final router = buildRouter(initialLocation: location);
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
      ),
    ),
  );
  await _pumpFor(t, const Duration(seconds: 2));
  return _Phone(container, router, db, server);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'E2E: A creates e2e-Goa offline, syncs, shares the code; B claims Rahul; A sees Rahul linked, '
    'balances unchanged (TC-1-06, TC-3-05, TC-4-04)',
    (t) async {
      final (env, services, uid) = await _signInA();
      final client = Supabase.instance.client;
      final p = await _open(t, services, Routes.groups, online: false);
      final name = 'e2e-Goa ${DateTime.now().millisecondsSinceEpoch}';

      // Offline: create the trip group through the form.
      await _waitFor(t, find.byKey(const Key('groups-empty-new')));
      await _tap(t, find.byKey(const Key('groups-empty-new')));
      await _type(t, const Key('group-name'), name);
      await _tap(t, find.byKey(const Key('group-type-trip')));
      await _tap(t, find.byKey(const Key('group-save')));
      await _waitFor(t, find.byKey(const Key('group-settings')));
      final gid = p.router.state.pathParameters['id']!;
      var group = await (p.db.select(p.db.groups)..where((g) => g.id.equals(gid))).getSingle();
      expect(group.name, name);
      expect(group.type, 'trip');
      expect(group.syncState, SyncState.pending);
      expect(find.text('Not synced yet'), findsWidgets);

      // Still offline: add the name-only member "Rahul" in settings.
      await _tap(t, find.byKey(const Key('group-settings')));
      await _tap(t, find.byKey(const Key('settings-add-member')));
      await _type(t, const Key('member-name'), 'Rahul');
      await _tap(t, find.byKey(const Key('member-save')));
      await _waitFor(t, find.text('Rahul'));
      final members = await p.container.read(membersRepositoryProvider).watchForGroup(gid).first;
      final me = members.firstWhere((m) => m.userId == uid);
      final rahul = members.firstWhere((m) => m.displayName == 'Rahul');
      expect(rahul.userId, isNull);

      // A balance for Rahul: he paid A ₹500 (offline, through the outbox).
      await p.container.read(paymentsRepositoryProvider).save(gid, {
        'from_member': rahul.id,
        'to_member': me.id,
        'amount': 50000,
        'currency': 'INR',
        'date': '2026-11-22',
        'method': 'cash',
      });

      // Back online: everything reaches the server; the pull brings the invite code.
      p.server.online = true;
      await p.sync();
      await _pumpFor(t, const Duration(seconds: 1));
      group = await (p.db.select(p.db.groups)..where((g) => g.id.equals(gid))).getSingle();
      expect(group.syncState, SyncState.synced);
      expect(group.inviteCode, isNotNull);
      final serverGroup = await client.from('groups').select('name, type').eq('id', gid).single();
      expect(serverGroup['name'], name);
      expect(serverGroup['type'], 'trip');
      final serverMembers = await client
          .from('group_members')
          .select('id, user_id, role')
          .eq('group_id', gid);
      expect(serverMembers.where((m) => m['user_id'] == uid && m['role'] == 'owner'), hasLength(1));
      expect(serverMembers.where((m) => m['id'] == rahul.id && m['user_id'] == null), hasLength(1));
      final before = jsonEncode(
        await client.rpc<Object?>('group_balances', params: {'group_id': gid}),
      );
      expect(before, contains(rahul.id));

      // Share: the invite sheet shows the code.
      await _tap(t, find.byTooltip('Back'));
      await _tap(t, find.byKey(const Key('group-invite')));
      await _waitFor(t, find.byKey(const Key('invite-code')));
      final shown = t.widget<Text>(find.byKey(const Key('invite-code'))).data!;
      final code = InviteCode.parse(shown)!;
      expect(code, group.inviteCode);

      // Harness B previews and claims Rahul.
      final harness = await HarnessUser.signIn(env, 'e2e-b');
      final b = harness.client;
      final buid = harness.id;
      final preview = (await b.rpc<Object?>('preview_join', params: {'code': code}))! as Map;
      expect((preview['unclaimed']! as List).map((m) => (m as Map)['id']), contains(rahul.id));
      final joined =
          (await b.rpc<Object?>('join_group', params: {'code': code, 'claim_member_id': rahul.id}))!
              as Map;
      expect(joined['status'], 'claimed');

      // A's phone: Rahul is now linked; the balance did not move (TC-4-04).
      await p.sync();
      await _pumpFor(t, const Duration(seconds: 1));
      final linked = await (p.db.select(
        p.db.groupMembers,
      )..where((m) => m.id.equals(rahul.id))).getSingle();
      expect(linked.userId, buid);
      expect(linked.claimedAt, isNotNull);
      Navigator.of(t.element(find.byKey(const Key('invite-code')))).pop();
      await _pumpFor(t, const Duration(seconds: 1));
      await _tap(t, find.byKey(const Key('group-settings')));
      await _waitFor(t, find.text('Claimed this spot'));
      final after = jsonEncode(
        await client.rpc<Object?>('group_balances', params: {'group_id': gid}),
      );
      expect(after, before);
      final activity = await client
          .from('activity')
          .select('type')
          .eq('group_id', gid)
          .eq('type', 'member_claimed');
      expect(activity, hasLength(1));

      // Clean up: the creator deletes the group (soft, restorable).
      await p.container.read(groupActionsProvider).delete(gid);
      await p.sync();
      final deleted = await client.from('groups').select('deleted_at').eq('id', gid).maybeSingle();
      expect(deleted == null || deleted['deleted_at'] != null, isTrue);
      await harness.dispose();
    },
  );

  testWidgets(
    'TC-3-04 scanning B\'s invite QR previews and joins; the deep link opens the join screen',
    (t) async {
      final (env, services, uid) = await _signInA();
      final harness = await HarnessUser.signIn(env, 'e2e-b');
      final b = harness.client;
      final gid = newId();
      final name = 'e2e-Manali ${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().toUtc().toIso8601String();
      Map<String, Object?> mutation(String entity, String id, Map<String, Object?> data) => {
        'mutation_id': newId(),
        'entity': entity,
        'op': 'upsert',
        'id': id,
        'group_id': gid,
        'client_updated_at': now,
        'data': data,
      };
      await b.rpc<Object?>(
        'apply_mutations',
        params: {
          'batch': [
            mutation('group', gid, {
              'name': name,
              'type': 'trip',
              'main_currency': 'INR',
              'owner_member': {'id': newId(), 'display_name': 'E2E B'},
            }),
            mutation('member', newId(), {'display_name': 'Kiran', 'position': 1}),
          ],
        },
      );
      final code =
          (await b.from('groups').select('invite_code').eq('id', gid).single())['invite_code']
              as String;

      // The QR scanner is injected: it "reads" B's invite link.
      final p = await _open(
        t,
        services,
        Routes.join,
        extra: [qrScannerProvider.overrideWithValue((_) async => InviteCode.link(code))],
      );
      await _tap(t, find.byKey(const Key('join-scan')));
      await _waitFor(t, find.byKey(const Key('join-preview')));
      expect(find.text(name), findsOneWidget);
      expect(find.text("I'm Kiran"), findsOneWidget);
      await _tap(t, find.byKey(const Key('join-new')));
      await _tap(t, find.byKey(const Key('join-submit')));
      await _waitFor(t, find.byKey(const Key('group-settings')));
      expect(p.router.state.uri.path, '/groups/$gid');
      final mine = await (p.db.select(
        p.db.groupMembers,
      )..where((m) => m.groupId.equals(gid) & m.userId.equals(uid))).get();
      expect(mine, hasLength(1));

      // `splitify://join?code=…` → the join screen, which now says A is already in.
      expect(authRedirect(Uri.parse(InviteCode.link(code)), signedIn: true), '/join?code=$code');
      p.router.go('/join?code=$code');
      await _waitFor(t, find.text('Open group'));

      // Clean up: A leaves (no balance), B deletes the group.
      await p.container.read(groupActionsProvider).leave(gid);
      await b.rpc<Object?>(
        'apply_mutations',
        params: {
          'batch': [
            {...mutation('group', gid, const {}), 'op': 'delete'},
          ],
        },
      );
      await harness.dispose();
    },
  );
}
