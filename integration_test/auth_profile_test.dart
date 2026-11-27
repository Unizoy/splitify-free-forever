// Phase 05 T9 on the dev project: TC-B1-03 (dev sign-in → home), TC-B2-04 (profile edit persists after a
// restart), TC-B1-04 (sign-out wipes the phone), plus one live call of the deployed `delete-account` function.
// Run: flutter test integration_test/auth_profile_test.dart -d emulator-5554 \
//        --dart-define-from-file=secrets/env.dev.json
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Env env;
  setUpAll(() => env = devEnv());

  /// The app as bootstrap builds it, with the debug developer sign-in on.
  Future<Widget> app() async {
    final prefs = await SharedPreferences.getInstance();
    final remote = await initRemote(env);
    return ProviderScope(
      overrides: appOverrides(env: env, prefs: prefs, remote: remote, devLogin: true),
      child: const App(),
    );
  }

  ProviderContainer scope(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(App)));
  String path(WidgetTester t) => scope(t).read(routerProvider).state.uri.path;

  testWidgets('dev sign-in → edit profile → restart → still signed in → sign out', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await tester.pumpWidget(await app());
    await tester.pump(const Duration(seconds: 1));
    expect(path(tester), Routes.welcome);

    // TC-B1-03: the debug deep link signs e2e-a in (account created on first use) and opens Groups.
    scope(tester).read(routerProvider).go('/debug/login?user=e2e-a');
    await pumpUntil(tester, () => path(tester) == Routes.groups, reason: 'dev sign-in');
    final uid = Supabase.instance.client.auth.currentUser!.id;
    expect(Supabase.instance.client.auth.currentUser!.email, e2eEmail('e2e-a'));

    // TC-B2-04: edit name + UPI ID online.
    final name = 'E2E A ${DateTime.now().millisecondsSinceEpoch % 100000}';
    unawaited(scope(tester).read(routerProvider).push<void>(Routes.profile));
    await pumpUntil(
      tester,
      () =>
          find.byKey(const Key('profile-name')).evaluate().isNotEmpty &&
          scope(tester).read(profileProvider).value != null,
      reason: 'profile loaded',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('profile-name')),
        matching: find.byType(EditableText),
      ),
      name,
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('profile-upi')),
        matching: find.byType(EditableText),
      ),
      'e2e.a@okaxis',
    );
    await tester.ensureVisible(find.byKey(const Key('profile-save')));
    await tester.tap(find.byKey(const Key('profile-save')));
    await pumpUntil(
      tester,
      () => scope(tester).read(profileProvider).value?.displayName == name,
      reason: 'profile saved',
    );
    final server = await Supabase.instance.client
        .from('profiles')
        .select('display_name, upi_id')
        .eq('id', uid)
        .single();
    expect(server['display_name'], name);
    expect(server['upi_id'], 'e2e.a@okaxis');

    // Restart: tear the app down, drop the Supabase client, start again from the saved session.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // Let the old app's database close and its in-flight reads finish before the new app opens the same file
    // (phase 19: startup reads of the second app hit the closing connection).
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await tester.pump();
    await Supabase.instance.dispose();
    await tester.pumpWidget(await app());
    await pumpUntil(tester, () => path(tester) == Routes.groups, reason: 'still signed in');
    expect(Supabase.instance.client.auth.currentUser?.id, uid);
    scope(tester).read(routerProvider).go(Routes.account);
    await pumpUntil(tester, () => find.text(name).evaluate().isNotEmpty, reason: 'account name');

    // TC-B1-04: sign out from the settings list (the Account tab itself since D-033) → welcome, session and
    // local data gone.
    await tester.ensureVisible(find.byKey(const Key('settings-sign-out')));
    await tester.tap(find.byKey(const Key('settings-sign-out')));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('sign-out-confirm')));
    await pumpUntil(tester, () => path(tester) == Routes.welcome, reason: 'signed out');
    expect(Supabase.instance.client.auth.currentUser, isNull);
    // The router leaves on the sign-out event; the wipe (database, then secure storage, then prefs) finishes
    // right after.
    await pumpUntil(
      tester,
      () => prefs.getKeys().every((k) => k == 'theme_mode'),
      reason: 'local wipe',
    );
    final db = scope(tester).read(appDatabaseProvider);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(await db.select(db.groups).get(), isEmpty);
  });

  testWidgets('delete-account (deployed Edge Function) removes a throwaway user', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: appOverrides(env: env, prefs: prefs, remote: await initRemote(env)),
    );
    addTearDown(c.dispose);
    final auth = Supabase.instance.client.auth;
    final email = 'e2e-del-${DateTime.now().millisecondsSinceEpoch}@splitify.test';

    await c
        .read(authRepositoryProvider)
        .signInWithPassword(email: email, password: env.e2ePassword);
    expect(auth.currentUser?.email, email);

    await c.read(accountActionsProvider).deleteAccount();
    expect(auth.currentUser, isNull);
    // The auth user is gone: the same password no longer signs in.
    await expectLater(
      auth.signInWithPassword(email: email, password: env.e2ePassword),
      throwsA(isA<AuthException>()),
    );
  });
}
