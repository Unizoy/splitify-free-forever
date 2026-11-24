import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/auth/application/pending_join.dart';
import 'package:splitify/features/auth/presentation/sign_in_screen.dart';
import 'package:splitify/features/groups/presentation/join_screen.dart';
import 'package:splitify/features/onboarding/presentation/welcome_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../support/fakes.dart';
import '../../support/group_fakes.dart';

class _Harness {
  _Harness(this.router, this.auth, this.pending, this.groups);

  final GoRouter router;
  final FakeAuthRepository auth;
  final PendingJoin pending;
  final FakeGroupsRemote groups;
}

/// The app's router at [location], signed out behind the real auth gate (or with no gate at all).
Future<_Harness> _pump(
  WidgetTester tester, {
  String location = Routes.welcome,
  bool gate = true,
  Size size = const Size(412, 915),
  double scale = 1,
  bool reduced = false,
  bool google = false,
  ThemeMode mode = ThemeMode.light,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthRepository();
  final pending = PendingJoin();
  final groups = FakeGroupsRemote()..previews.add(samplePreview());
  final db = testDb();
  addTearDown(db.close);
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final router = buildRouter(
    initialLocation: location,
    gate: gate
        ? AuthGate(signedIn: false, changes: auth.authStateChanges().map((u) => u != null))
        : null,
    pendingJoin: pending,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(auth),
        profileRemoteProvider.overrideWithValue(FakeProfileRemote(sampleProfile)),
        googleConfiguredProvider.overrideWithValue(google),
        groupsRemoteProvider.overrideWithValue(groups),
        pendingJoinProvider.overrideWithValue(pending),
        ...emptyGroupsOverrides(),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale), disableAnimations: reduced),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return _Harness(router, auth, pending, groups);
}

/// Pumps past a route transition (the welcome floats forever, so never settle).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

final _getStarted = find.byKey(const Key('welcome-get-started'));
const _tall = Size(480, 1200);
final _invite = find.byKey(const Key('welcome-invite'));

void main() {
  group('D-029 welcome', () {
    testWidgets('shows the preview, headline, features and both actions; no dashed circle', (
      tester,
    ) async {
      // The test font's glyphs are wide, so the page needs a taller phone than real text does.
      await _pump(tester, size: _tall);
      expect(find.byType(DashedCircleButton), findsNothing);
      expect(find.byType(GlassCard), findsOneWidget);
      expect(find.byType(GroupCoverCard), findsNWidgets(2));
      expect(find.text('GOA TRIP'), findsOneWidget);
      expect(find.text('FLAT 4B'), findsOneWidget);
      expect(find.text('₹2,450'), findsOneWidget);
      expect(find.text('SPLITIFY'), findsOneWidget);
      expect(find.text('Free forever\u00A0· no ads'), findsOneWidget);
      expect(find.textContaining('settle it.'), findsOneWidget);
      expect(
        find.text('Split bills with friends, settle up with UPI.\nWorks offline, free forever.'),
        findsOneWidget,
      );
      for (final chip in ['UPI settle-up', 'Works offline', 'No ads ever']) {
        expect(find.text(chip), findsOneWidget);
      }
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('OPEN SOURCE\u00A0· MADE IN\u00A0INDIA'), findsOneWidget);
      // The preview is sample data: screen readers skip it.
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Goa Trip')), findsNothing);
      expect(find.bySemanticsLabel('Have an invite? Join a group'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('looks the same in dark mode (the light hero)', (tester) async {
      await _pump(tester, mode: ThemeMode.dark);
      final scaffold = tester.widget<Scaffold>(
        find.descendant(of: find.byType(WelcomeScreen), matching: find.byType(Scaffold)),
      );
      expect(scaffold.backgroundColor, AppColors.light.heroTop);
      final context = tester.element(find.byType(GlassCard));
      expect(Theme.of(context).brightness, Brightness.light);
    });

    testWidgets('Get started pushes sign-in with the shared-axis move; back returns', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.tap(_getStarted);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      // Mid-transition: sign-in slides over the welcome, which stays below.
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
        find.ancestor(of: find.byType(SignInScreen), matching: find.byType(SharedAxisTransition)),
        findsOneWidget,
      );
      await _settle(tester);
      expect(h.router.state.uri.path, Routes.signIn);
      expect(find.text('How would you like to sign in?'), findsOneWidget);
      expect(
        find.text(
          'Use Google or a one-time code sent by email. The same email always opens the same account.',
        ),
        findsOneWidget,
      );
      expect(h.pending.waiting, isFalse);

      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);
      expect(h.router.state.uri.path, Routes.welcome);
      expect(_getStarted, findsOneWidget);
    });

    testWidgets('S-283 invite while signed out: sign in first, then the join screen opens', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.tap(_invite);
      await _settle(tester);
      expect(h.router.state.uri.path, Routes.signIn);
      expect(h.pending.waiting, isTrue);
      expect(
        find.text('Sign in with Google or an email code, then we open your invite.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'asha@splitify.test');
      await tester.tap(find.text('Send code'));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('code-input')), '123456');
      await _settle(tester);
      expect(h.auth.currentUser, isNotNull);
      expect(find.text('What should friends call you?'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await _settle(tester);
      expect(h.router.state.uri.path, Routes.join);
      expect(find.byType(JoinScreen), findsOneWidget);
      expect(h.pending.waiting, isFalse);
    });

    testWidgets('S-283 an invite link opened signed out keeps its code through Google sign-in', (
      tester,
    ) async {
      final h = await _pump(tester, location: '/join?code=ABCDEFGH', google: true);
      await _settle(tester);
      expect(h.router.state.uri.path, Routes.signIn);
      await tester.tap(find.text('Continue with Google'));
      await _settle(tester);
      // The profile step comes first, then the invite opens.
      expect(h.router.state.uri.path, Routes.signInProfile);
      expect(h.pending.waiting, isTrue);
      await tester.tap(find.text('Continue'));
      await _settle(tester);
      expect(h.router.state.uri.toString(), '/join?code=ABCDEFGH');
      expect(h.groups.calls, contains('preview:ABCDEFGH'));
    });

    testWidgets('without the auth gate the invite link opens the join screen directly', (
      tester,
    ) async {
      final h = await _pump(tester, gate: false);
      await tester.tap(_invite);
      await _settle(tester);
      expect(h.router.state.uri.path, Routes.join);
      expect(find.byType(JoinScreen), findsOneWidget);
    });

    testWidgets('Get started forgets a codeless invite but keeps an invite code', (tester) async {
      final h = await _pump(tester);
      h.pending.remember(null);
      await tester.tap(_getStarted);
      await _settle(tester);
      expect(h.pending.waiting, isFalse);

      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);
      h.pending.remember('ABCDEFGH');
      await tester.tap(_getStarted);
      await _settle(tester);
      expect(h.pending.take(), '/join?code=ABCDEFGH');
    });

    testWidgets('reduced motion: everything is in place at once and nothing keeps animating', (
      tester,
    ) async {
      await _pump(tester, reduced: true);
      expect(tester.binding.transientCallbackCount, 0);
      final opacities = tester
          .widgetList<Opacity>(
            find.descendant(of: find.byType(WelcomeScreen), matching: find.byType(Opacity)),
          )
          .map((o) => o.opacity);
      expect(opacities, everyElement(1.0));
      // Settles (it would time out with the idle float running).
      await tester.pumpAndSettle();
    });

    testWidgets('the entrance ends within 350 ms, then the cards float', (tester) async {
      await _pump(tester);
      // _pump already let 400 ms pass: the entrance is over.
      final opacities = tester
          .widgetList<Opacity>(
            find.descendant(of: find.byType(WelcomeScreen), matching: find.byType(Opacity)),
          )
          .map((o) => o.opacity);
      expect(opacities, everyElement(1.0));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, greaterThan(0), reason: 'idle float');
    });

    for (final (size, scale) in [
      (const Size(320, 568), 1.0),
      (const Size(360, 640), 1.0),
      (const Size(360, 640), 2.0),
      (const Size(412, 915), 1.3),
      (const Size(412, 915), 2.0),
      (const Size(480, 1066), 1.0),
      (const Size(915, 412), 1.0),
    ]) {
      testWidgets('lays out without overflow at ${size.width}x${size.height}, text $scale', (
        tester,
      ) async {
        await _pump(tester, size: size, scale: scale);
        expect(tester.takeException(), isNull);
        // Reachable: the page scrolls when it is taller than the screen.
        await tester.scrollUntilVisible(_invite, 200, scrollable: find.byType(Scrollable).first);
        expect(tester.getBottomLeft(_invite).dy, lessThanOrEqualTo(size.height));
        // Short or large-text screens keep only the glass card; the page scrolls instead.
        if (size.height < 700 || scale >= 2) expect(find.byType(GroupCoverCard), findsNothing);
      });
    }

    testWidgets('a tall phone fans the covers and keeps the actions at the bottom', (tester) async {
      await _pump(tester, size: _tall);
      expect(find.byType(GroupCoverCard), findsNWidgets(2));
      final bottom = tester.getBottomLeft(find.text('OPEN SOURCE\u00A0· MADE IN\u00A0INDIA')).dy;
      expect(bottom, greaterThan(_tall.height - 60));
      final left = tester.getCenter(find.byType(GroupCoverCard).first);
      final glass = tester.getCenter(find.byType(GlassCard));
      expect(left.dy, lessThan(glass.dy), reason: 'covers peek out above the glass card');
    });
  });

  group('S-283 auth redirect with a pending join', () {
    Uri u(String s) => Uri.parse(s);

    test('signed out, /join goes to sign-in and is kept', () {
      final p = PendingJoin();
      expect(authRedirect(u('/join'), signedIn: false, pendingJoin: p), Routes.signIn);
      expect(p.take(), '/join');
    });

    test('signed out, the invite link keeps its code (query or path)', () {
      final p = PendingJoin();
      expect(
        authRedirect(u('splitify://join?code=ABCDEFGH'), signedIn: false, pendingJoin: p),
        '/join?code=ABCDEFGH',
      );
      expect(
        authRedirect(u('/join?code=ABCDEFGH'), signedIn: false, pendingJoin: p),
        Routes.signIn,
      );
      expect(p.take(), '/join?code=ABCDEFGH');
      expect(authRedirect(u('/join/QWERTYUI'), signedIn: false, pendingJoin: p), Routes.signIn);
      expect(p.take(), '/join?code=QWERTYUI');
    });

    test('signed in on sign-in or welcome: a kept join goes through the profile step', () {
      final p = PendingJoin()..remember('ABCDEFGH');
      expect(authRedirect(u('/sign-in'), signedIn: true, pendingJoin: p), Routes.signInProfile);
      expect(authRedirect(u('/welcome'), signedIn: true, pendingJoin: p), Routes.signInProfile);
      expect(p.take(), '/join?code=ABCDEFGH', reason: 'the profile step takes it');
      expect(authRedirect(u('/sign-in'), signedIn: true, pendingJoin: p), Routes.groups);
    });

    test('the code step still goes to the profile step (it opens the join)', () {
      final p = PendingJoin()..remember(null);
      expect(
        authRedirect(u('/sign-in/code'), signedIn: true, pendingJoin: p),
        Routes.signInProfile,
      );
      expect(p.waiting, isTrue);
    });

    test('other signed-out pages still go to welcome', () {
      final p = PendingJoin();
      expect(authRedirect(u('/groups'), signedIn: false, pendingJoin: p), Routes.welcome);
      expect(p.waiting, isFalse);
    });
  });
}
