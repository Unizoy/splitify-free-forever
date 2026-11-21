import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart' show clockProvider;
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' hide clockProvider;
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/invite_sheet.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../data/sync/sync_fakes.dart' show FakeClock;
import '../support/fakes.dart' hide FakeClock;
import '../support/group_fakes.dart';
import '../support/group_harness.dart' show fixedGroupData;
import 'golden_support.dart';

const _frame = Size(goldenWidth, 915);

/// A whole app (router, themes) in a phone-sized frame, signed in as `u1`, with fixed group data and no
/// database or server.
class _PhoneApp extends StatelessWidget {
  const _PhoneApp({
    required this.location,
    required this.mode,
    required this.scale,
    required this.prefs,
    required this.data,
    this.remote,
    this.inviteFor,
  });

  final String location;
  final ThemeMode mode;
  final double scale;
  final SharedPreferences prefs;
  final List<Override> data;
  final FakeGroupsRemote? remote;

  /// Shows the invite sheet for this group over a scrim instead of a routed screen.
  final String? inviteFor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: _frame,
      child: ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(user: const AuthUser(id: 'u1')),
          ),
          profileRemoteProvider.overrideWithValue(FakeProfileRemote(sampleProfile)),
          groupsRemoteProvider.overrideWithValue(remote ?? FakeGroupsRemote()),
          syncNowProvider.overrideWithValue(() async {}),
          clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 22, 10))),
          ...data,
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: _frame,
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            textScaler: TextScaler.linear(scale),
          ),
          child: _app(),
        ),
      ),
    );
  }

  Widget _app() {
    final invite = inviteFor;
    return invite != null
        ? MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                backgroundColor: context.colors.scrim,
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: _frame.height - 24),
                    child: AppSheet(
                      title: AppLocalizations.of(context).invitePeople,
                      child: InviteSheetBody(groupId: invite),
                    ),
                  ),
                ),
              ),
            ),
            localizationsDelegates: _delegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            debugShowCheckedModeBanner: false,
          )
        : MaterialApp.router(
            routerConfig: buildRouter(initialLocation: location),
            localizationsDelegates: _delegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            debugShowCheckedModeBanner: false,
          );
  }
}

const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Fixed rows shared by the screens.
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

List<Override> _groupData() => fixedGroupData(groups: [_goa], members: {'g-goa': _members});

/// One screen to capture: its route, the data behind it and what to do before the picture.
typedef _Shot = ({
  String name,
  String route,
  List<Override> Function() data,
  FakeGroupsRemote Function()? remote,
  bool invite,
});

_Shot _shot(
  String name,
  String route,
  List<Override> Function() data, {
  FakeGroupsRemote Function()? remote,
  bool invite = false,
}) => (name: name, route: route, data: data, remote: remote, invite: invite);

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final shots = <_Shot>[
    _shot(
      'groups_list',
      Routes.groups,
      () => fixedGroupData(
        groups: [
          sampleGroup(id: 'g-goa', name: 'Goa trip', createdAt: '2026-11-20T10:00:00Z'),
          sampleGroup(
            id: 'g-flat',
            name: 'Flat 4B',
            type: 'home',
            syncState: 'pending',
            createdAt: '2026-11-19T10:00:00Z',
          ),
          sampleGroup(
            id: 'g-us',
            name: 'Us two',
            type: 'couple',
            createdAt: '2026-11-18T10:00:00Z',
          ),
          sampleGroup(
            id: 'g-old',
            name: 'Old trip',
            archivedAt: '2026-11-01T10:00:00Z',
            createdAt: '2026-10-01T10:00:00Z',
          ),
        ],
      ),
    ),
    _shot('group_detail', '/groups/g-goa', _groupData),
    // The new-group form draws its cover from a fresh random id, so the picture would change on every run;
    // the edit form is the same screen with a fixed id.
    _shot('group_form', '/groups/g-goa/edit', _groupData),
    _shot('group_settings', '/groups/g-goa/settings', _groupData),
    // The sheet itself (a routed modal cannot be captured inside alchemist's own app frame).
    _shot('invite_sheet', '/groups/g-goa', _groupData, invite: true),
    _shot('join_enter', Routes.join, () => fixedGroupData()),
    _shot(
      'join_claim',
      '/join?code=ABCDEFGH',
      () => fixedGroupData(),
      remote: () => FakeGroupsRemote()
        ..previews.add(
          samplePreview(
            memberCount: 6,
            unclaimed: const [
              (id: 'u-1', name: 'Ravi', tint: 1),
              (id: 'u-2', name: 'Neha', tint: 3),
              (id: 'u-3', name: 'Dev', tint: null),
            ],
          ),
        ),
    ),
    _shot(
      'deleted_groups',
      Routes.deletedGroups,
      () => fixedGroupData(
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
    ),
  ];

  // One golden per mode: the router uses a shared navigator key, so two apps cannot be on screen at once.
  for (final shot in shots) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        // TC-B3-03: every screen in light and dark at text scale 1.0 and 2.0.
        goldenTest(
          'TC-B3-03 screen ${shot.name} ${mode.name} $suffix',
          fileName: 'screen_${shot.name}_${mode.name}_$suffix',
          pumpBeforeTest: pumpFixedFrames,
          builder: () => _PhoneApp(
            location: shot.route,
            mode: mode,
            scale: scale,
            prefs: prefs,
            data: shot.data(),
            remote: shot.remote?.call(),
            inviteFor: shot.invite ? 'g-goa' : null,
          ),
        );
      }
    }
  }
}
