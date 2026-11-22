// Two Android flavours (D-028, S-274/S-275): the payment bubble is only in builds that have it. Host tests
// run with the default flavour (`standard`, pubspec `default-flavor`), so the bubble is off unless a test
// gives the app a capture bridge that supports it.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/build_flavor.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/device/capture_bridge.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/account/presentation/account_settings_sheet.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/capture/application/capture_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../support/capture_fakes.dart';
import '../../support/fakes.dart';

Set<String> _paths(List<RouteBase> routes) => {
  for (final r in routes) ...[
    if (r is GoRoute) r.path,
    ..._paths(r.routes),
    if (r is StatefulShellRoute)
      for (final b in r.branches) ..._paths(b.routes),
  ],
};

Future<void> _pumpSheet(WidgetTester t, CaptureBridge bridge) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  t.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 2400);
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: const AuthUser(id: 'u1')),
        ),
        profileRemoteProvider.overrideWithValue(FakeProfileRemote(sampleProfile)),
        syncRepositoryProvider.overrideWithValue(
          FakeSyncRepository(status: const SyncStatus(phase: SyncPhase.idle)),
        ),
        captureBridgeProvider.overrideWithValue(bridge),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        home: const Scaffold(body: SingleChildScrollView(child: AccountSettingsBody())),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  // Open the Preferences card (only the first card starts open).
  final l = await AppLocalizations.delegate.load(const Locale('en'));
  await t.tap(find.text(l.preferences));
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  test('the bubble is compiled in only for the full flavour (no CAPTURE define in tests)', () {
    expect(BuildFlavor.capture, BuildFlavor.name == 'full');
    expect(MethodChannelCaptureBridge().supported, isFalse, reason: 'not Android / not full');
    expect(const NoCaptureBridge().supported, isFalse);
  });

  test('the router leaves out the bubble routes when the build has no bubble', () {
    final full = _paths(buildRouter().configuration.routes);
    final standard = _paths(buildRouter(capture: false).configuration.routes);
    expect(full, containsAll(['/capture', '/account/payment-bubble']));
    expect(standard, isNot(contains('/capture')));
    expect(standard, isNot(contains('/account/payment-bubble')));
    expect(full.difference(standard), {'/capture', '/account/payment-bubble'});
  });

  testWidgets('Account settings shows the Payment bubble row only when it is supported', (t) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    await _pumpSheet(t, FakeCaptureBridge());
    expect(find.text(l.captureRow), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await _pumpSheet(t, const NoCaptureBridge());
    expect(find.text(l.captureRow), findsNothing);
    expect(find.text(l.notifications), findsOneWidget);
  });
}
