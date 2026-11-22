// Phase 15 (04 §1, §8; S-046/S-160): SyncBinding wires the automatic sync triggers around the signed-in shell.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/sync/background_sync.dart';
import 'package:splitify/data/sync/network_status.dart';
import 'package:splitify/data/sync/sync_engine.dart';
import 'package:splitify/data/sync/sync_triggers.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/sync/presentation/sync_binding.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/l10n/app_localizations_en.dart';

import '../../../support/fakes.dart';
import '../../../support/group_fakes.dart';

class _FakeNetwork implements NetworkStatus {
  final changes = StreamController<bool>.broadcast();

  @override
  Stream<bool> watch() => changes.stream;

  @override
  Future<bool> isOnline() async => true;
}

class _FakeNudges implements ChangeNudges {
  final controller = StreamController<void>.broadcast();
  final watched = <Set<String>>[];

  @override
  Stream<void> get nudges => controller.stream;

  @override
  Future<void> watchGroups(Set<String> groupIds) async => watched.add(groupIds);

  @override
  Future<void> dispose() async {}
}

class _FakeBackground implements BackgroundSync {
  final calls = <String>[];

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> syncWhenOnline() async => calls.add('once');

  @override
  Future<void> stop() async => calls.add('stop');
}

/// Counts syncs; only the parts SyncBinding uses.
class _FakeEngine implements SyncEngine {
  int syncs = 0;
  final lost = StreamController<int>.broadcast();

  @override
  Future<void> sync() async => syncs++;

  @override
  Stream<int> get superseded => lost.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGroups implements GroupsRepository {
  final controller = StreamController<List<LocalGroup>>.broadcast();

  @override
  Stream<List<LocalGroup>> watchAll() => controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rig {
  final network = _FakeNetwork();
  final nudges = _FakeNudges();
  final background = _FakeBackground();
  final engine = _FakeEngine();
  final repo = FakeSyncRepository();
  final groups = _FakeGroups();
}

Future<_Rig> _pump(WidgetTester tester, {AuthUser? user = const AuthUser(id: 'u1')}) async {
  final rig = _Rig();
  addTearDown(() async {
    await rig.network.changes.close();
    await rig.nudges.controller.close();
    await rig.engine.lost.close();
    await rig.groups.controller.close();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(user: user)),
        networkStatusProvider.overrideWithValue(rig.network),
        changeNudgesProvider.overrideWithValue(rig.nudges),
        backgroundSyncProvider.overrideWithValue(rig.background),
        syncEngineProvider.overrideWithValue(rig.engine),
        syncRepositoryProvider.overrideWithValue(rig.repo),
        groupsRepositoryProvider.overrideWithValue(rig.groups),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SyncBinding(child: Text('shell'))),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return rig;
}

void _lifecycle(WidgetTester tester, List<AppLifecycleState> states) {
  for (final s in states) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

const _toBackground = [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];
const _toForeground = [
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

void main() {
  // TC-OFF-BIND-START: owner check, background jobs, then one sync.
  testWidgets('start: adopts the owner, schedules background sync, syncs once', (tester) async {
    final rig = await _pump(tester);
    expect(find.text('shell'), findsOneWidget);
    expect(rig.repo.calls, ['owner:u1']);
    expect(rig.background.calls, ['start']);
    expect(rig.engine.syncs, 1);
  });

  testWidgets('start without a user skips the owner check but still syncs', (tester) async {
    final rig = await _pump(tester, user: null);
    expect(rig.repo.calls, isEmpty);
    expect(rig.engine.syncs, 1);
  });

  // TC-OFF-BIND-NET: only offline -> online starts a sync.
  testWidgets('network: false to true syncs, true to true does not', (tester) async {
    final rig = await _pump(tester);
    rig.network.changes.add(true); // first value: already online at start
    await tester.pump();
    expect(rig.engine.syncs, 1);
    rig.network.changes.add(true);
    await tester.pump();
    expect(rig.engine.syncs, 1);
    rig.network.changes.add(false);
    await tester.pump();
    expect(rig.engine.syncs, 1);
    rig.network.changes.add(true);
    await tester.pump();
    expect(rig.engine.syncs, 2);
  });

  // TC-OFF-BIND-NUDGE: a Realtime nudge syncs.
  testWidgets('a nudge syncs', (tester) async {
    final rig = await _pump(tester);
    rig.nudges.controller.add(null);
    await tester.pump();
    expect(rig.engine.syncs, 2);
  });

  // TC-OFF-BIND-RESUME: back to the foreground syncs.
  testWidgets('app resumed syncs', (tester) async {
    final rig = await _pump(tester);
    _lifecycle(tester, _toBackground);
    await tester.pump();
    expect(rig.engine.syncs, 1);
    _lifecycle(tester, _toForeground);
    await tester.pump();
    expect(rig.engine.syncs, 2);
  });

  // TC-OFF-BIND-PAUSE: a one-off WorkManager job only when something is waiting.
  testWidgets('paused with changes waiting asks for a one-off background sync', (tester) async {
    final rig = await _pump(tester);
    rig.repo.unsynced = true;
    _lifecycle(tester, _toBackground);
    await tester.pump();
    await tester.pump();
    expect(rig.background.calls, ['start', 'once']);
  });

  testWidgets('paused with nothing waiting schedules nothing', (tester) async {
    final rig = await _pump(tester);
    _lifecycle(tester, _toBackground);
    await tester.pump();
    await tester.pump();
    expect(rig.background.calls, ['start']);
  });

  // TC-OFF-BIND-TOPICS: Realtime topics follow the user's groups.
  testWidgets('watchGroups gets the ids of the live groups and follows changes', (tester) async {
    final rig = await _pump(tester);
    rig.groups.controller.add([sampleGroup(id: 'g1'), sampleGroup(id: 'g2')]);
    await tester.pump();
    await tester.pump();
    expect(rig.nudges.watched.last, {'g1', 'g2'});
    rig.groups.controller.add([sampleGroup(id: 'g2')]);
    await tester.pump();
    await tester.pump();
    expect(rig.nudges.watched.last, {'g2'});
  });

  // TC-OFF-BIND-LOST: one-time "newer edit was kept" snackbar (04 §3, T4).
  testWidgets('superseded edits show the snackbar with the count', (tester) async {
    final rig = await _pump(tester);
    rig.engine.lost.add(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('sync-superseded')), findsOneWidget);
    expect(find.text(AppLocalizationsEn().syncSuperseded(1)), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.text('shell'))).clearSnackBars();
    await tester.pump();
    rig.engine.lost.add(3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppLocalizationsEn().syncSuperseded(3)), findsOneWidget);
  });

  testWidgets('disposing stops listening: no sync after the shell is gone', (tester) async {
    final rig = await _pump(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    rig.nudges.controller.add(null);
    await tester.pump();
    expect(rig.engine.syncs, 1, reason: 'nudge');
    rig.network.changes
      ..add(false)
      ..add(true);
    await tester.pump();
    expect(rig.engine.syncs, 1, reason: 'network');
  });
}
