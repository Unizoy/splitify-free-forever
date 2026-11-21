// UI review scenario for phase 07 (gate G5, ui-review skill): shows every groups screen on the emulator with
// fixed sample data (no sign-in, no network) and prints `UI-CAPTURE <name>` while each one is on screen, so
// `.claude/skills/ui-review/scripts/capture_markers.ps1` takes light / dark / 200 % screenshots.
//   powershell -File .claude\skills\ui-review\scripts\capture_markers.ps1 -Phase 07 `
//     -Test integration_test/scenarios/groups_review_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../test/support/fakes.dart';
import '../../test/support/group_fakes.dart';
import '../../test/support/group_harness.dart' show fixedGroupData;

/// Seconds each screen stays up for the host captures (`UI_HOLD`, default 0 = no hold).
const _hold = int.fromEnvironment('UI_HOLD');

/// Hold only these screens (`UI_ONLY=invite-sheet,group-settings`) to re-capture a few shots quickly.
const _only = String.fromEnvironment('UI_ONLY');

final _goa = sampleGroup(id: 'g-goa', name: 'Goa trip');
final _members = [
  sampleMember(id: 'm-asha', userId: 'u1', name: 'Asha Rao', role: 'owner', tint: 0),
  sampleMember(
    id: 'm-ravi',
    userId: 'u2',
    name: 'Ravi Menon',
    position: 1,
    claimedAt: '2026-11-10T10:00:00Z',
    tint: 1,
  ),
  sampleMember(id: 'm-neha', name: 'Neha', position: 2, tint: 3),
  sampleMember(id: 'm-dev', userId: 'u3', name: 'Dev Shah', position: 3, tint: 2),
];

List<Override> _goaData() => fixedGroupData(groups: [_goa], members: {'g-goa': _members});

List<Override> _listData() => fixedGroupData(
  groups: [
    sampleGroup(id: 'g-goa', name: 'Goa trip'),
    sampleGroup(id: 'g-flat', name: 'Flat 4B', type: 'home', syncState: 'pending'),
    sampleGroup(id: 'g-us', name: 'Us two', type: 'couple'),
    sampleGroup(id: 'g-office', name: 'Office lunch', type: 'other'),
    sampleGroup(id: 'g-old', name: 'Old trip', archivedAt: '2026-11-01T10:00:00Z'),
  ],
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> hold(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 800));
    if (_hold == 0 || (_only.isNotEmpty && !_only.split(',').contains(name))) return;
    debugPrint('UI-CAPTURE $name');
    final end = DateTime.now().add(const Duration(seconds: _hold));
    // Real waits, not a pump loop: Dart runs on Android's main thread, and a tight pump loop starves input
    // and configuration events until Android shows "isn't responding".
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await t.pump();
    }
  }

  Future<void> show(
    WidgetTester t,
    String route,
    List<Override> data, {
    FakeGroupsRemote? remote,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = buildRouter(initialLocation: route);
    addTearDown(router.dispose);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(user: const AuthUser(id: 'u1')),
          ),
          profileRemoteProvider.overrideWithValue(FakeProfileRemote(sampleProfile)),
          groupsRemoteProvider.overrideWithValue(remote ?? FakeGroupsRemote()),
          syncNowProvider.overrideWithValue(() async {}),
          ...data,
        ],
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
    await t.pump(const Duration(seconds: 1));
  }

  Future<void> tap(WidgetTester t, String key) async {
    await t.tap(find.byKey(Key(key)));
    await t.pump(const Duration(milliseconds: 900));
  }

  testWidgets('phase 07 screens for the UI review', (t) async {
    await show(t, Routes.groups, _listData());
    await hold(t, 'groups-list');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tap(t, 'groups-archived');
    await hold(t, 'groups-list-archived');

    await show(t, Routes.groups, fixedGroupData(offline: true));
    await hold(t, 'groups-empty-offline');

    await show(t, Routes.newGroup, _goaData());
    await hold(t, 'group-new');
    await show(t, '/groups/g-goa/edit', _goaData());
    await hold(t, 'group-edit');

    await show(t, '/groups/g-goa', _goaData());
    await hold(t, 'group-detail');
    await tap(t, 'group-invite');
    await hold(t, 'invite-sheet');

    await show(
      t,
      '/groups/g-goa',
      fixedGroupData(
        groups: [sampleGroup(id: 'g-goa', name: 'Goa trip', archivedAt: '2026-11-21T10:00:00Z')],
        members: {'g-goa': _members},
        unsynced: {'g-goa'},
      ),
    );
    await hold(t, 'group-detail-archived');

    await show(t, '/groups/g-goa/settings', _goaData());
    await hold(t, 'group-settings');
    await tap(t, 'settings-add-member');
    await hold(t, 'add-member');
    await show(t, '/groups/g-goa/settings', _goaData());
    await tap(t, 'member-m-ravi');
    await hold(t, 'member-actions');

    await show(t, Routes.join, fixedGroupData());
    await hold(t, 'join-enter');
    await show(
      t,
      '/join?code=ABCDEFGH',
      fixedGroupData(),
      remote: FakeGroupsRemote()
        ..previews.add(
          samplePreview(
            memberCount: 6,
            unclaimed: const [
              (id: 'u-1', name: 'Ravi', tint: 1),
              (id: 'u-2', name: 'Neha Gupta', tint: 3),
              (id: 'u-3', name: 'Dev', tint: null),
            ],
          ),
        ),
    );
    await hold(t, 'join-claim');
    await show(
      t,
      '/join?code=ABCDEFGH',
      fixedGroupData(),
      remote: FakeGroupsRemote()..previews.add(samplePreview(archived: true)),
    );
    await hold(t, 'join-archived');

    await show(
      t,
      Routes.deletedGroups,
      fixedGroupData(
        deleted: [
          sampleGroup(id: 'g-del1', name: 'Goa trip', deletedAt: '2026-11-15T10:00:00Z'),
          sampleGroup(
            id: 'g-del2',
            name: 'Old flat',
            type: 'home',
            deletedAt: '2026-10-01T10:00:00Z',
          ),
        ],
      ),
    );
    await hold(t, 'deleted-groups');
  });
}
