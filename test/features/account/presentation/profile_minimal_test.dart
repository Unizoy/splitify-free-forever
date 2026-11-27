// D-033 (minimal flows like Splitwise): the profile edit screen (tap the avatar, UPI scan inside the field,
// inline UPI check) and the first-run profile confirm (name + Continue, UPI behind a chip).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/domain/entities/profile.dart';
import 'package:splitify/features/account/presentation/profile_edit_screen.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/auth/application/pending_join.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../../support/fakes.dart';
import '../../../support/group_fakes.dart';

const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

/// A profile with no UPI ID yet.
final _noUpi = sampleProfile.copyWith(clearUpi: true);

class _Rig {
  _Rig(this.remote, this.router);

  final FakeProfileRemote remote;
  final GoRouter router;

  String get path => router.state.uri.path;
}

Future<_Rig> _pump(
  WidgetTester tester,
  String location, {
  Profile? profile,
  Uint8List? photo,
  PendingJoin? pending,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthRepository(user: const AuthUser(id: 'u1'));
  final remote = FakeProfileRemote(profile ?? sampleProfile);
  final db = testDb();
  addTearDown(db.close);
  tester.view.physicalSize = const Size(412 * 3, 915 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(auth),
        profileRemoteProvider.overrideWithValue(remote),
        groupsRemoteProvider.overrideWithValue(
          FakeGroupsRemote()..previews.add(const GroupFailure(GroupFailureCode.offline)),
        ),
        photoPickerProvider.overrideWithValue(() async => photo),
        if (pending != null) pendingJoinProvider.overrideWithValue(pending),
        ...emptyGroupsOverrides(),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await _settle(tester);
  return _Rig(remote, router);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Finder _key(String k) => find.byKey(Key(k));

/// The text field inside an [UnderlineField] keyed [k].
Finder _field(String k) => find.descendant(of: _key(k), matching: find.byType(TextField));

Future<void> _type(WidgetTester t, String k, String text) async {
  await t.tap(_field(k));
  await t.pump();
  await t.enterText(_field(k), text);
  await t.pump();
}

Future<void> _save(WidgetTester t) async {
  await t.tap(_key('profile-save'));
  await _settle(t);
}

void main() {
  group('D-033 profile edit', () {
    // D-033
    testWidgets('D-033 tapping the avatar picks a photo and Save uploads it', (t) async {
      final rig = await _pump(t, Routes.profile, photo: base64Decode(_png1x1));
      expect(_key('profile-photo'), findsOneWidget);
      expect(find.bySemanticsLabel('Change your photo'), findsOneWidget);
      await t.tap(_key('profile-photo'));
      await _settle(t);
      await _save(t);
      expect(rig.remote.uploads, hasLength(1));
      expect(rig.remote.profile?.avatarPath, isNotNull);
    });

    // D-033
    testWidgets('D-033 Save without picking a photo uploads nothing', (t) async {
      final rig = await _pump(t, Routes.profile);
      await t.tap(_key('profile-photo'));
      await _settle(t);
      await _save(t);
      expect(rig.remote.uploads, isEmpty);
    });

    // D-033
    testWidgets('D-033 the UPI field has the scan button inside it', (t) async {
      await _pump(t, Routes.profile);
      expect(_key('profile-upi'), findsOneWidget);
      expect(_key('profile-scan-upi'), findsOneWidget);
      expect(
        find.descendant(of: _key('profile-upi'), matching: _key('profile-scan-upi')),
        findsOneWidget,
      );
      expect(find.byTooltip('Scan my UPI QR'), findsOneWidget);
    });

    // D-033
    testWidgets(
      'D-033 a bad UPI ID is flagged when focus leaves the field, keeps the text, and Save writes nothing',
      (t) async {
        final rig = await _pump(t, Routes.profile);
        expect(find.text('Enter a UPI ID like name@bank'), findsNothing);
        await _type(t, 'profile-upi', 'abc');
        // Still typing: no error yet.
        expect(find.text('Enter a UPI ID like name@bank'), findsNothing);
        // Move focus away by tapping the name field.
        await t.tap(_field('profile-name'));
        await _settle(t);
        expect(find.text('Enter a UPI ID like name@bank'), findsOneWidget);
        expect(find.text('abc'), findsOneWidget);

        await _save(t);
        expect(rig.remote.profile, sampleProfile);
        expect(find.text('Enter a UPI ID like name@bank'), findsOneWidget);
        expect(find.text('abc'), findsOneWidget);
        expect(rig.path, Routes.profile);

        // Fix it: the error clears and Save stores it.
        await _type(t, 'profile-upi', 'asha@okaxis');
        expect(find.text('Enter a UPI ID like name@bank'), findsNothing);
        await _save(t);
        expect(rig.remote.profile?.upiId, 'asha@okaxis');
      },
    );

    // D-033
    testWidgets('D-033 clearing the UPI field saves no UPI ID', (t) async {
      final rig = await _pump(t, Routes.profile);
      await _type(t, 'profile-upi', '');
      await _save(t);
      expect(rig.remote.profile?.upiId, isNull);
      expect(rig.remote.profile?.displayName, 'Asha Rao');
    });

    // D-033
    testWidgets('D-033 an empty name shows the name error and saves nothing', (t) async {
      final rig = await _pump(t, Routes.profile);
      await _type(t, 'profile-name', '   ');
      await _save(t);
      expect(find.text('Enter your name (up to 50 characters)'), findsOneWidget);
      expect(rig.remote.profile, sampleProfile);
    });
  });

  group('D-033 profile confirm (first sign-in)', () {
    // D-033
    testWidgets(
      'D-033 shows only the name and an "Add a UPI ID" chip; the chip opens the focused field',
      (t) async {
        await _pump(t, Routes.signInProfile, profile: _noUpi);
        expect(_key('profile-name'), findsOneWidget);
        expect(_key('profile-add-upi'), findsOneWidget);
        expect(find.text('Add a UPI ID (optional)'), findsOneWidget);
        expect(_key('profile-upi'), findsNothing);
        expect(_key('profile-currency'), findsNothing);
        expect(_key('profile-continue'), findsOneWidget);

        await t.tap(_key('profile-add-upi'));
        await _settle(t);
        expect(_key('profile-upi'), findsOneWidget);
        expect(_key('profile-add-upi'), findsNothing);
        expect(t.widget<TextField>(_field('profile-upi')).focusNode?.hasFocus ?? false, isTrue);
      },
    );

    // D-033
    testWidgets('D-033 a profile that already has a UPI ID shows the field at once', (t) async {
      await _pump(t, Routes.signInProfile);
      expect(_key('profile-upi'), findsOneWidget);
      expect(_key('profile-add-upi'), findsNothing);
      expect(find.text('asha.rao@okaxis'), findsOneWidget);
    });

    // D-033
    testWidgets('D-033 Continue saves the name and opens Groups', (t) async {
      final rig = await _pump(t, Routes.signInProfile, profile: _noUpi);
      await _type(t, 'profile-name', 'Asha R');
      await t.tap(_key('profile-continue'));
      await _settle(t);
      expect(rig.remote.profile?.displayName, 'Asha R');
      expect(rig.remote.profile?.upiId, isNull);
      expect(rig.path, Routes.groups);
    });

    // D-033
    testWidgets('D-033 Continue with a pending invite opens that join instead of Groups', (
      t,
    ) async {
      final pending = PendingJoin()..remember('ABCD2345');
      final rig = await _pump(t, Routes.signInProfile, profile: _noUpi, pending: pending);
      await t.tap(_key('profile-continue'));
      await _settle(t);
      expect(rig.path, '/join');
      expect(rig.router.state.uri.queryParameters['code'], 'ABCD2345');
      expect(pending.waiting, isFalse);
    });

    // D-033
    testWidgets('D-033 an empty name stops Continue with the inline error', (t) async {
      final rig = await _pump(t, Routes.signInProfile, profile: _noUpi);
      await _type(t, 'profile-name', '');
      await t.tap(_key('profile-continue'));
      await _settle(t);
      expect(find.text('Enter your name (up to 50 characters)'), findsOneWidget);
      expect(rig.path, Routes.signInProfile);
    });
  });
}
