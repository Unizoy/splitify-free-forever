import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/logging/logger.dart';
import 'package:splitify/data/fx_providers.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';

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
    final remote = await initRemote(env);
    return ProviderScope(
      overrides: appOverrides(env: env, prefs: prefs, remote: remote),
      child: const App(),
    );
  } on EnvException catch (e) {
    return ConfigErrorApp(message: e.message);
  }
}

/// Provider overrides of a running app (bootstrap and the integration tests). [devLogin] defaults to the
/// build setting (debug builds only, TC-B1-08).
List<Override> appOverrides({
  required Env env,
  required SharedPreferences prefs,
  required RemoteServices remote,
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
  fxRatesRemoteProvider.overrideWithValue(remote.fxRates),
  googleConfiguredProvider.overrideWithValue(env.hasGoogle),
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
