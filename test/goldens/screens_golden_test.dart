import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import 'golden_support.dart';

const _frame = Size(goldenWidth, 915);

/// A whole app (router, themes) in a phone-sized frame with system-bar padding.
class _PhoneApp extends StatelessWidget {
  const _PhoneApp({
    required this.location,
    required this.mode,
    required this.scale,
    required this.prefs,
  });

  final String location;
  final ThemeMode mode;
  final double scale;
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: _frame,
      child: ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MediaQuery(
          data: MediaQueryData(
            size: _frame,
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            textScaler: TextScaler.linear(scale),
          ),
          child: MaterialApp.router(
            routerConfig: buildRouter(initialLocation: location),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
  }
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const screens = <(String, String)>[
    ('welcome', Routes.welcome),
    ('groups', Routes.groups),
    ('friends', Routes.friends),
    ('activity', Routes.activity),
    ('account', Routes.account),
    ('appearance', Routes.appearance),
  ];

  // One golden per mode: the router uses a shared navigator key, so two apps cannot
  // be on screen at once.
  for (final (name, route) in screens) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        // TC-B3-03: every screen in light and dark at text scale 1.0 and 2.0.
        goldenTest(
          'TC-B3-03 screen $name ${mode.name} $suffix',
          fileName: 'screen_${name}_${mode.name}_$suffix',
          pumpBeforeTest: pumpFixedFrames,
          builder: () => _PhoneApp(location: route, mode: mode, scale: scale, prefs: prefs),
        );
      }
    }
  }
}
