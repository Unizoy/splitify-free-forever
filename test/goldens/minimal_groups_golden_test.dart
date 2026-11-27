// D-033 goldens: the minimal group / people / joining / profile / import states, light and dark at text 1.0
// and 2.0, plus a small phone (320 × 568) at text 1.0. The routed screens run in the real router.
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart' show clockProvider, syncRepositoryProvider;
import 'package:splitify/data/local/app_database.dart' show LocalImportBatch;
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' hide clockProvider;
import 'package:splitify/features/friends/presentation/add_friend_sheet.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/invite_sheet.dart';
import 'package:splitify/features/import_splitwise/application/import_controller.dart';
import 'package:splitify/features/import_splitwise/application/import_providers.dart';
import 'package:splitify/features/import_splitwise/domain/import_csv.dart';
import 'package:splitify/features/import_splitwise/domain/import_mapping.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_reconstruction.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../data/sync/sync_fakes.dart' show FakeClock;
import '../support/fakes.dart' hide FakeClock;
import '../support/group_fakes.dart';
import '../support/group_harness.dart' show fixedGroupData;
import 'golden_support.dart';

const _phone = Size(goldenWidth, 915);
const _small = Size(320, 568);

/// Account-entry import state (no group yet): a new group named after the file, people matched to "you".
class _FixedImport extends ImportController {
  _FixedImport(this._state) : super(null);

  final ImportState _state;

  @override
  ImportState build() => _state;
}

ImportState _accountImport() {
  final parsed = parseImportCsv(
    File('test/fixtures/splitwise/group_inr_usd.csv').readAsStringSync(),
  );
  const members = <MappingMember>[(id: newGroupMeId, name: 'Asha Rao', isMe: true)];
  final mapping = suggestMapping(parsed.file.members, members);
  final result = reconstructSplitwise(parsed.file, acceptTotalsMismatch: true);
  return ImportState(
    step: ImportStep.people,
    fileName: 'goa-trip_2026-11-21_export.csv',
    parsed: parsed,
    newGroupName: 'Goa trip',
    members: members,
    mapping: mapping,
    preview: (file: parsed.file, dropped: 0, result: result),
  );
}

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
];

List<Override> _groupData() => fixedGroupData(
  groups: [
    _goa,
    sampleGroup(id: 'g-flat', name: 'Flat 4B', type: 'home'),
  ],
  members: {'g-goa': _members},
);

const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// A phone-sized app signed in as `u1`: the routed screen at [location], or [sheet] over a scrim.
class _App extends StatelessWidget {
  const _App({
    required this.size,
    required this.mode,
    required this.scale,
    required this.prefs,
    required this.data,
    this.location,
    this.sheet,
  });

  final Size size;
  final ThemeMode mode;
  final double scale;
  final SharedPreferences prefs;
  final List<Override> data;
  final String? location;
  final (String Function(AppLocalizations l), Widget)? sheet;

  @override
  Widget build(BuildContext context) {
    final sheet = this.sheet;
    return SizedBox.fromSize(
      size: size,
      child: ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(user: const AuthUser(id: 'u1')),
          ),
          profileRemoteProvider.overrideWithValue(FakeProfileRemote(sampleProfile)),
          groupsRemoteProvider.overrideWithValue(
            FakeGroupsRemote()
              ..previews.add(
                samplePreview(
                  memberCount: 4,
                  unclaimed: const [
                    (id: 'u-1', name: 'Ravi', tint: 1),
                    (id: 'u-2', name: 'Neha', tint: 3),
                  ],
                ),
              ),
          ),
          syncNowProvider.overrideWithValue(() async {}),
          syncRepositoryProvider.overrideWithValue(FakeSyncRepository()),
          clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 22, 10))),
          importControllerProvider(null).overrideWith(() => _FixedImport(_accountImport())),
          importBatchesProvider.overrideWith((ref, id) => Stream.value(const <LocalImportBatch>[])),
          ...data,
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            textScaler: TextScaler.linear(scale),
          ),
          child: sheet == null
              ? MaterialApp.router(
                  routerConfig: buildRouter(initialLocation: location!),
                  localizationsDelegates: _delegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: AppTheme.light(),
                  darkTheme: AppTheme.dark(),
                  themeMode: mode,
                  debugShowCheckedModeBanner: false,
                )
              : MaterialApp(
                  home: Builder(
                    builder: (context) => Scaffold(
                      backgroundColor: context.colors.scrim,
                      body: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: size.height - 24),
                          child: AppSheet(
                            title: sheet.$1(AppLocalizations.of(context)),
                            child: sheet.$2,
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
                ),
        ),
      ),
    );
  }
}

typedef _Shot = ({
  String name,
  String? route,
  (String Function(AppLocalizations l), Widget)? sheet,
  Future<void> Function(WidgetTester t)? act,
});

_Shot _route(String name, String route, {Future<void> Function(WidgetTester t)? act}) =>
    (name: name, route: route, sheet: null, act: act);

_Shot _sheetShot(String name, String Function(AppLocalizations l) title, Widget body) =>
    (name: name, route: null, sheet: (title, body), act: null);

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final shots = <_Shot>[
    // The one-screen form with a person typed and added, and a second name that is too long.
    _route(
      'group_form_people',
      '/groups/g-goa/edit',
      act: (t) async {
        // Large text / small phone: the field sits below the fold of the lazy list.
        await t.scrollUntilVisible(
          find.byKey(const Key('group-add-person')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await t.enterText(_field('group-add-person'), 'Kiran');
        await t.testTextInput.receiveAction(TextInputAction.done);
        await t.pump();
        await t.enterText(_field('group-add-person'), 'x' * 51);
        await t.testTextInput.receiveAction(TextInputAction.done);
        await t.pump();
        FocusManager.instance.primaryFocus?.unfocus();
      },
    ),
    _route('group_form_edit', '/groups/g-goa/edit'),
    _route('group_settings', '/groups/g-goa/settings'),
    _sheetShot('invite_sheet', (l) => l.invitePeople, const InviteSheetBody(groupId: 'g-goa')),
    _route(
      'join_enter',
      Routes.join,
      act: (t) async => FocusManager.instance.primaryFocus?.unfocus(),
    ),
    _route('join_claim', '/join?code=ABCDEFGH'),
    _sheetShot('add_friend', (l) => l.addFriendTitle, const AddFriendForm()),
    _route(
      'profile_upi_error',
      Routes.profile,
      act: (t) async {
        await t.enterText(_field('profile-upi'), 'asha.okaxis');
        await t.pump();
        FocusManager.instance.primaryFocus?.unfocus();
      },
    ),
    _route('profile_confirm', Routes.signInProfile),
    _route('import_setup_account', '/account/import'),
  ];

  Future<void> Function(WidgetTester) pump(_Shot shot) => (t) async {
    await pumpFixedFrames(t);
    final act = shot.act;
    if (act != null) {
      await act(t);
      await pumpFixedFrames(t);
    }
  };

  for (final shot in shots) {
    Widget app(Size size, ThemeMode mode, double scale) => _App(
      size: size,
      mode: mode,
      scale: scale,
      prefs: prefs,
      data: _groupData(),
      location: shot.route,
      sheet: shot.sheet,
    );
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'D-033 ${shot.name} ${mode.name} $suffix',
          fileName: 'minimal_${shot.name}_${mode.name}_$suffix',
          pumpBeforeTest: pump(shot),
          builder: () => app(_phone, mode, scale),
        );
      }
      goldenTest(
        'D-033 ${shot.name} ${mode.name} small phone',
        fileName: 'minimal_${shot.name}_${mode.name}_small',
        pumpBeforeTest: pump(shot),
        builder: () => app(_small, mode, 1),
      );
    }
  }
}
