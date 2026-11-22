// Shared harness for the phase 13 widget tests.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart' show syncRepositoryProvider;
import 'package:splitify/features/notifications/application/notifications_providers.dart';

import '../../../support/fakes.dart' show FakeSyncRepository;
import '../../../support/notification_fakes.dart';
import '../../expenses/presentation/presentation_harness.dart';

/// Overrides that put the notification providers on the in-memory fakes. The reminder path also needs a sync
/// repository (it syncs after a send) and preferences. The clock is the harness's (21 Nov 2026, 10:00).
List<Override> notifOverrides({
  FakeNotificationsRepository? repo,
  FakeNotificationsRemote? remote,
  FakePushMessaging? push,
  SharedPreferences? prefs,
}) => [
  if (repo != null) notificationsRepositoryProvider.overrideWithValue(repo),
  if (remote != null) notificationsRemoteProvider.overrideWithValue(remote),
  if (push != null) pushMessagingProvider.overrideWithValue(push),
  if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
  syncRepositoryProvider.overrideWithValue(FakeSyncRepository()),
  notificationsAutoRefreshProvider.overrideWith((ref) {}),
];

/// [home] at '/', with stubs for every place the notification screens can open.
Future<GoRouter> pumpNotif(
  WidgetTester t,
  Widget home, {
  List<Override> overrides = const [],
  double scale = 1,
  double height = 915,
  List<String> stubs = const [
    '/expense/:id',
    '/payment/:id',
    '/groups/:id',
    '/notifications',
    '/account/notifications',
  ],
}) async {
  usePhone(t);
  t.view.physicalSize = Size(412, height);
  if (scale != 1) {
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await t.pumpWidget(const SizedBox());
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      for (final s in stubs) stubRoute(s),
    ],
  );
  await t.pumpWidget(routerApp(router, overrides: overrides));
  await settle(t);
  return router;
}
