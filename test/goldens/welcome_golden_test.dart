import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/onboarding/presentation/welcome_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import 'golden_support.dart';

/// The welcome on a phone of [size] (system bars as padding) at text [scale].
class _Phone extends StatelessWidget {
  const _Phone({required this.size, required this.scale});

  final Size size;
  final double scale;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: size,
    child: ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          textScaler: TextScaler.linear(scale),
        ),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          debugShowCheckedModeBanner: false,
          home: const WelcomeScreen(),
        ),
      ),
    ),
  );
}

void main() {
  // D-029: the redesigned welcome adapts to short phones (glass card alone, page scrolls) and to a
  // mid text size (1.3: back covers left out). The 412 × 915 light/dark × 1.0/2.0 set is in
  // screens_golden_test.dart.
  for (final (name, size, scale) in [
    ('small_text100', const Size(360, 640), 1.0),
    ('tall_text130', const Size(412, 915), 1.3),
  ]) {
    goldenTest(
      'D-029 welcome $name',
      fileName: 'welcome_$name',
      pumpBeforeTest: pumpFixedFrames,
      builder: () => _Phone(size: size, scale: scale),
    );
  }
}
