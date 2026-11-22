import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/profile_repository.dart';
import 'package:splitify/features/account/presentation/profile_edit_screen.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart' show DotsPulse;
import 'package:splitify/ui/theme/theme.dart';

import '../../../support/fakes.dart';

const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

class _Harness {
  _Harness(this.auth, this.remote, this.router);

  final FakeAuthRepository auth;
  final FakeProfileRemote remote;
  final GoRouter router;
}

Future<_Harness> _pump(
  WidgetTester tester,
  String location, {
  AuthUser? user,
  bool dev = false,
  bool google = false,
  bool gate = false,
  Uint8List? photo,
  int codeLength = 6,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthRepository(user: user);
  final remote = FakeProfileRemote(sampleProfile);
  final db = testDb();
  addTearDown(db.close);
  tester.view.physicalSize = const Size(412 * 3, 915 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = buildRouter(
    initialLocation: location,
    gate: gate
        ? AuthGate(signedIn: user != null, changes: auth.authStateChanges().map((u) => u != null))
        : null,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(auth),
        profileRemoteProvider.overrideWithValue(remote),
        devLoginProvider.overrideWithValue(dev),
        googleConfiguredProvider.overrideWithValue(google),
        emailCodeLengthProvider.overrideWithValue(codeLength),
        e2ePasswordProvider.overrideWithValue('pw'),
        photoPickerProvider.overrideWithValue(() async => photo),
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
  return _Harness(auth, remote, router);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('TC-B1-01 sign-in shows Google and email; dev login only when enabled', (
    tester,
  ) async {
    await _pump(tester, Routes.signIn);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.text('Not set up in this build'), findsOneWidget);
    expect(find.text('Developer sign-in'), findsNothing);

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(find.textContaining("Google sign-in isn't set up in this build"), findsOneWidget);

    await _pump(tester, Routes.signIn, dev: true, google: true);
    expect(find.text('Developer sign-in'), findsOneWidget);
    expect(find.text('Not set up in this build'), findsNothing);
  });

  testWidgets('email code flow: bad email, send, wrong code, right code → profile → groups', (
    tester,
  ) async {
    final h = await _pump(tester, Routes.signIn, gate: true);
    await tester.enterText(find.byType(TextField), 'nope');
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(find.text('Enter an email like name@example.com'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'asha@splitify.test');
    await tester.tap(find.text('Send code'));
    await _settle(tester);
    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    expect(find.textContaining('asha@splitify.test'), findsOneWidget);
    expect(find.text('Resend code in 60\u00A0s'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('code-input')), '000000');
    await _settle(tester);
    expect(find.textContaining('That code is wrong or has expired'), findsOneWidget);
    // S-233: the refused code is cleared so the next try starts with empty boxes.
    expect(find.bySemanticsLabel('6-digit code, 0 of 6 entered'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('code-input')), '1');
    await _settle(tester);
    expect(
      find.textContaining('That code is wrong'),
      findsNothing,
      reason: 'typing clears the error',
    );

    await tester.enterText(find.byKey(const Key('code-input')), '123456');
    await _settle(tester);
    expect(h.auth.currentUser, isNotNull);
    expect(find.text('What should friends call you?'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('profile-upi')).last, 'bad');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Enter a UPI ID like name@bank'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('profile-upi')).last, 'asha@ybl');
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    expect(h.remote.profile?.upiId, 'asha@ybl');
    expect(h.router.state.uri.path, Routes.groups);
  });

  testWidgets('S-232 an 8-digit project shows 8 boxes and verifies only 8 digits', (tester) async {
    final h = await _pump(
      tester,
      '${Routes.signInCode}?email=asha%40splitify.test',
      gate: true,
      codeLength: 8,
    );
    h.auth.goodCode = '12345678';
    expect(find.text('Enter the 8-digit code'), findsOneWidget);
    expect(find.bySemanticsLabel('8-digit code, 0 of 8 entered'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('code-input')), '123456');
    await _settle(tester);
    expect(h.auth.calls.where((c) => c.startsWith('verify')), isEmpty, reason: '6 of 8 digits');
    await tester.enterText(find.byKey(const Key('code-input')), '1234567890');
    await _settle(tester);
    expect(h.auth.calls, contains('verify:12345678'), reason: 'input stops at 8 digits');
    expect(h.auth.currentUser, isNotNull);
  });

  testWidgets('offline verify keeps the typed code', (tester) async {
    final h = await _pump(tester, '${Routes.signInCode}?email=asha%40splitify.test');
    h.auth.fail = const AuthFailure(AuthFailureCode.offline);
    await tester.enterText(find.byKey(const Key('code-input')), '123456');
    await _settle(tester);
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.bySemanticsLabel('6-digit code, 6 of 6 entered'), findsOneWidget);
  });

  testWidgets('Google: the spinner is on the Google button while the sheet is open', (
    tester,
  ) async {
    final h = await _pump(tester, Routes.signIn, google: true);
    final gate = Completer<void>();
    h.auth.googleGate = gate.future;
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    Finder dots(String key) =>
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(DotsPulse));
    expect(dots('sign-in-google'), findsOneWidget);
    expect(dots('sign-in-send'), findsNothing, reason: '"Send code" keeps its label');
    gate.complete();
    await _settle(tester);
    expect(h.auth.calls, contains('google'));
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('dev login deep link signs in e2e-a and opens groups (T4)', (tester) async {
    final h = await _pump(tester, '${Routes.devLogin}?user=e2e-a', dev: true, gate: true);
    await _settle(tester);
    expect(h.auth.calls, contains('password:e2e-a@splitify.test'));
    expect(h.router.state.uri.path, Routes.groups);
  });

  testWidgets('dev login screen lists the test users and shows failures', (tester) async {
    final h = await _pump(tester, Routes.devLogin, dev: true);
    expect(find.text('Test user e2e-b'), findsOneWidget);
    h.auth.fail = const AuthFailure(AuthFailureCode.invalidCredentials);
    await tester.tap(find.text('Test user e2e-b'));
    await _settle(tester);
    expect(find.text('Wrong email or password'), findsOneWidget);
  });

  testWidgets('TC-B2-03 profile edit validates, picks a photo and saves', (tester) async {
    final h = await _pump(
      tester,
      Routes.profile,
      user: const AuthUser(id: 'u1'),
      photo: base64Decode(_png1x1),
    );
    await _settle(tester);
    expect(find.text('Asha Rao'), findsWidgets);
    await tester.enterText(find.byKey(const Key('profile-name')).last, '   ');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter your name (up to 50 characters)'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('profile-name')).last, 'Asha R');
    await tester.tap(find.text('Change photo'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-currency')));
    await _settle(tester);
    // The searchable currency picker (final QA S-253).
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('currency-search')),
        matching: find.byType(TextField),
      ),
      'usd',
    );
    await _settle(tester);
    await tester.tap(find.byKey(const Key('currency-found-USD')));
    await _settle(tester);
    await tester.tap(find.text('Save'));
    await _settle(tester);
    expect(h.remote.profile?.displayName, 'Asha R');
    expect(h.remote.profile?.defaultCurrency, 'USD');
    expect(h.remote.uploads, hasLength(1));
  });

  testWidgets('profile edit offline shows "Needs internet"', (tester) async {
    final h = await _pump(tester, Routes.profile, user: const AuthUser(id: 'u1'));
    await _settle(tester);
    h.remote.fail = const ProfileFailure(ProfileFailureCode.offline);
    await tester.tap(find.text('Save'));
    await _settle(tester);
    expect(find.text('Needs internet. Connect and try again.'), findsOneWidget);
  });

  testWidgets('delete account needs DELETE typed, then signs out to welcome', (tester) async {
    final h = await _pump(tester, Routes.deleteAccount, user: const AuthUser(id: 'u1'), gate: true);
    final button = find.text('Delete my account');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    expect(h.auth.calls, isNot(contains('delete')));

    h.auth.fail = const AuthFailure(AuthFailureCode.unknown);
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(button);
    await _settle(tester);
    expect(find.textContaining('Could not delete your account'), findsOneWidget);
    // Offline: "Needs internet" (rule 9).
    h.auth.fail = const AuthFailure(AuthFailureCode.offline);
    await tester.tap(button);
    await _settle(tester);
    expect(find.text('Needs internet. Connect and try again.'), findsOneWidget);

    await tester.tap(button);
    await _settle(tester);
    expect(h.auth.calls.last, 'delete');
    expect(h.router.state.uri.path, Routes.welcome);
  });

  testWidgets('settings sheet: profile rows, sign out confirm wipes and redirects', (tester) async {
    final h = await _pump(tester, Routes.account, user: const AuthUser(id: 'u1'), gate: true);
    await _settle(tester);
    expect(find.text('Asha Rao'), findsOneWidget);
    await tester.tap(find.byTooltip('Account settings'));
    await _settle(tester);
    expect(find.text('asha.rao@okaxis'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('settings-sign-out')));
    await tester.tap(find.byKey(const Key('settings-sign-out')));
    await _settle(tester);
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sign-out-confirm')));
    await _settle(tester);
    expect(h.auth.calls, contains('signOut'));
    expect(h.router.state.uri.path, Routes.welcome);
  });

  group('authRedirect (T3)', () {
    Uri u(String s) => Uri.parse(s);
    test('signed out: only public pages', () {
      expect(authRedirect(u('/groups'), signedIn: false), Routes.welcome);
      expect(authRedirect(u('/account/profile'), signedIn: false), Routes.welcome);
      expect(authRedirect(u('/welcome'), signedIn: false), isNull);
      expect(authRedirect(u('/sign-in/code?email=a'), signedIn: false), isNull);
      expect(authRedirect(u('/debug/gallery'), signedIn: false), isNull);
    });
    test('signed in: sign-in pages lead on', () {
      expect(authRedirect(u('/welcome'), signedIn: true), Routes.groups);
      expect(authRedirect(u('/sign-in'), signedIn: true), Routes.groups);
      expect(authRedirect(u('/sign-in/code'), signedIn: true), Routes.signInProfile);
      expect(authRedirect(u('/sign-in/profile'), signedIn: true), isNull);
      expect(authRedirect(u('/groups'), signedIn: true), isNull);
    });
    test('dev deep link only in debug', () {
      expect(authRedirect(u('/login?user=e2e-a'), signedIn: false), '/debug/login?user=e2e-a');
      expect(authRedirect(u('/dev/login'), signedIn: false), '/debug/login');
      expect(authRedirect(u('/login'), signedIn: false, debug: false), Routes.welcome);
    });
    test('AuthGate notifies only on changes', () async {
      final changes = StreamController<bool>();
      final gate = AuthGate(signedIn: false, changes: changes.stream);
      var n = 0;
      gate.addListener(() => n++);
      changes
        ..add(false)
        ..add(true);
      await Future<void>.delayed(Duration.zero);
      expect(gate.signedIn, isTrue);
      expect(n, 1);
      gate.dispose();
      await changes.close();
    });
  });
}
