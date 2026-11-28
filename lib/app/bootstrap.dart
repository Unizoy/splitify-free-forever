import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/background_sync_task.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/logging/logger.dart';
import 'package:splitify/core/platform/crash_reporting.dart';
import 'package:splitify/core/platform/startup_gate.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/fx_providers.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/remote/push_messaging.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/sync/background_sync.dart';
import 'package:splitify/data/sync/network_status.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';

/// Starts logging and error handlers, validates the build settings, loads
/// local preferences (theme mode) and returns the root widget. Later phases
/// add database, Supabase and Firebase.
Future<Widget> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging();
  installErrorHandlers();
  registerFontLicences();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  try {
    final env = Env.load();
    final prefs = await SharedPreferences.getInstance();
    // The first screen needs the saved session; push, crash reports and WorkManager start after its first
    // frame is on screen (S-456), so the splash ends sooner. Their providers get proxies at once.
    final remote = await initRemote(env);
    final push = DeferredPushMessaging();
    final crash = DeferredCrashReporter();
    final background = DeferredBackgroundSync();
    StartupGate.arm();
    StartupGate.run(
      () => startDeferredServices(prefs, push: push, crash: crash, background: background),
    );
    return ProviderScope(
      overrides: appOverrides(
        env: env,
        prefs: prefs,
        remote: remote,
        push: push,
        crash: crash,
        background: background,
        network: ConnectivityNetworkStatus(),
      ),
      child: const App(),
    );
  } on EnvException catch (e) {
    return ConfigErrorApp(message: e.message);
  }
}

/// Starts what [bootstrap] left for after the first frame (S-456): Firebase + push, then crash reports
/// (W2-Y, S-436: after Firebase; off without google-services.json, S-144 pattern), then WorkManager. A
/// failure leaves that service disabled, as before.
Future<void> startDeferredServices(
  SharedPreferences prefs, {
  required DeferredPushMessaging push,
  required DeferredCrashReporter crash,
  required DeferredBackgroundSync background,
  Future<PushMessaging> Function() initPush = initPush,
  Future<CrashReporter> Function(SharedPreferences) initCrash = initCrashReporting,
  Future<BackgroundSync> Function() initBackground = initBackgroundSync,
}) async {
  Future<T> safe<T>(Future<T> Function() start, T off) async {
    try {
      return await start();
    } on Object {
      return off;
    }
  }

  push.complete(await safe(initPush, const DisabledPushMessaging()));
  crash.complete(await safe(() => initCrash(prefs), const DisabledCrashReporter()));
  background.complete(await safe(initBackground, const NoBackgroundSync()));
}

/// Provider overrides of a running app (bootstrap and the integration tests). [devLogin] defaults to the
/// build setting (debug builds only, TC-B1-08).
List<Override> appOverrides({
  required Env env,
  required SharedPreferences prefs,
  required RemoteServices remote,
  PushMessaging push = const DisabledPushMessaging(),
  CrashReporter crash = const DisabledCrashReporter(),
  BackgroundSync background = const NoBackgroundSync(),
  NetworkStatus network = const AssumeOnlineNetworkStatus(),
  bool? devLogin,
}) => [
  envProvider.overrideWithValue(env),
  sharedPreferencesProvider.overrideWithValue(prefs),
  authRepositoryProvider.overrideWithValue(remote.auth),
  profileRemoteProvider.overrideWithValue(remote.profiles),
  remoteApiProvider.overrideWithValue(remote.api),
  groupsRemoteProvider.overrideWithValue(remote.groups),
  mediaRemoteProvider.overrideWithValue(remote.media),
  historyRemoteProvider.overrideWithValue(remote.history),
  balancesRemoteProvider.overrideWithValue(remote.balances),
  friendsRemoteProvider.overrideWithValue(remote.friends),
  fxRatesRemoteProvider.overrideWithValue(remote.fxRates),
  notificationsRemoteProvider.overrideWithValue(remote.notifications),
  changeNudgesProvider.overrideWithValue(remote.nudges),
  backgroundSyncProvider.overrideWithValue(background),
  networkStatusProvider.overrideWithValue(network),
  // 401 after one refresh (04 §7): sign out but keep the phone's data and outbox.
  sessionExpiredProvider.overrideWith(
    (ref) =>
        () => ref.read(authRepositoryProvider).signOut(),
  ),
  pushMessagingProvider.overrideWithValue(push),
  crashReporterProvider.overrideWithValue(crash),
  googleConfiguredProvider.overrideWithValue(env.hasGoogle),
  emailCodeLengthProvider.overrideWithValue(env.emailOtpLength),
  devLoginProvider.overrideWithValue(devLogin ?? env.devLoginAvailable(releaseMode: kReleaseMode)),
  e2ePasswordProvider.overrideWithValue(kReleaseMode ? '' : env.e2ePassword),
];

bool _licencesAdded = false;

/// Adds the bundled fonts' licences (SIL OFL, MIT) to the in-app licences page.
void registerFontLicences() {
  if (_licencesAdded) return;
  _licencesAdded = true;
  LicenseRegistry.addLicense(() async* {
    for (final (package, file) in const [
      ('Instrument Serif', 'InstrumentSerif-OFL.txt'),
      ('Inter', 'Inter-OFL.txt'),
      ('Phosphor Icons', 'Phosphor-MIT.txt'),
    ]) {
      final text = await rootBundle.loadString('assets/fonts/LICENSES/$file');
      yield LicenseEntryWithLineBreaks([package], text);
    }
  });
}
