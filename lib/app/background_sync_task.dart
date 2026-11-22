import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/core/logging/logger.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/sync/background_sync.dart';
import 'package:splitify/features/widget/application/home_widget_sync.dart';
import 'package:workmanager/workmanager.dart';

final _log = Logger('sync');

/// Initialises WorkManager with [backgroundSyncDispatcher]; without the plugin (tests) nothing runs in the
/// background and the foreground triggers still sync.
Future<BackgroundSync> initBackgroundSync() async {
  try {
    await Workmanager().initialize(backgroundSyncDispatcher);
    return WorkmanagerBackgroundSync();
  } on Object catch (e) {
    _log.warning('background sync unavailable: $e');
    return const NoBackgroundSync();
  }
}

/// WorkManager entry point (04 §8): one push + photo uploads + pull, never any UI.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, input) => runBackgroundSync());
}

/// One background run. When the signed-in app is alive in this process it runs the sync itself (one Supabase
/// session per process, S-160); otherwise this isolate opens the database and Supabase, syncs, closes.
/// Always true: WorkManager must not retry on its own, the next periodic run picks up what is left.
Future<bool> runBackgroundSync() async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging();
  try {
    if (await askForegroundToSync()) return true;
    final env = Env.load();
    final prefs = await SharedPreferences.getInstance();
    final remote = await initRemote(env, background: true);
    if (remote.auth.currentUser == null) return true;
    final container = ProviderContainer(
      overrides: appOverrides(env: env, prefs: prefs, remote: remote, devLogin: false),
    );
    try {
      await container.read(syncEngineProvider).sync().timeout(const Duration(minutes: 8));
      _log.info('background sync: ${container.read(syncEngineProvider).phase.name}');
      // X3: the home-screen widget shows what this sync brought (phase 18).
      await refreshHomeWidget(container);
    } finally {
      container.dispose();
    }
  } on Object catch (e) {
    _log.warning('background sync failed: $e');
  }
  return true;
}
