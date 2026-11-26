// The welcome screen on its own, in the app's real router and themes (system light/dark and text size), for
// screenshots on a device that is signed in (the real app would redirect to Groups). It opens no database, no
// session and no server, so the installed app's data stays as it is. Build it as a release x64 APK:
//   flutter build apk --release --target-platform android-x64 -t integration_test/support/welcome_preview_main.dart \
//     --dart-define-from-file=secrets/env.dev.json
// Never shipped: the store build uses lib/main.dart.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: buildRouter(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}
