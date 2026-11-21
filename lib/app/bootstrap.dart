import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/logging/logger.dart';
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
      overrides: [
        envProvider.overrideWithValue(env),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(remote.auth),
        profileRemoteProvider.overrideWithValue(remote.profiles),
        googleConfiguredProvider.overrideWithValue(env.hasGoogle),
        devLoginProvider.overrideWithValue(env.devLoginAvailable(releaseMode: kReleaseMode)),
        e2ePasswordProvider.overrideWithValue(kReleaseMode ? '' : env.e2ePassword),
      ],
      child: const App(),
    );
  } on EnvException catch (e) {
    return ConfigErrorApp(message: e.message);
  }
}

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
