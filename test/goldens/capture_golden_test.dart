import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/device/capture_bridge.dart';
import 'package:splitify/domain/entities/payment_capture.dart';
import 'package:splitify/features/capture/application/capture_providers.dart';
import 'package:splitify/features/capture/presentation/capture_routes.dart';
import 'package:splitify/features/capture/presentation/capture_settings_screen.dart';
import 'package:splitify/features/capture/presentation/payments_to_add.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/capture/capture_harness.dart' show sampleApps, sampleCapture;
import '../features/expenses/expense_fixtures.dart' show expenseApp;
import '../support/capture_fakes.dart';
import 'golden_support.dart';

/// A scenario: the widget, what feeds it and the frame height at text scale 1.0 / 2.0.
typedef _Case = ({
  String name,
  Widget Function() screen,
  List<Override> Function() overrides,
  double height,
  double tallHeight,
});

class _FixedSettings extends CaptureSettingsController {
  _FixedSettings(this.value);

  final CaptureSettings value;

  @override
  Future<CaptureSettings> build() async => value;
}

/// Local wall-clock times, so the goldens read the same in every time zone.
final _captures = [
  sampleCapture(id: captureId1, amount: 125050, at: DateTime(2026, 11, 19, 10, 42)),
  sampleCapture(
    id: captureId2,
    amount: 49900,
    payee: 'Cafe Mocha',
    appName: 'PhonePe',
    ref: null,
    source: CaptureSource.sms,
    at: DateTime(2026, 11, 18, 21, 5),
  ),
];

class _SheetHost extends StatelessWidget {
  const _SheetHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black54,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AppSheet(title: AppLocalizations.of(context).paymentsToAddTitle, child: child),
    ),
  );
}

/// The Groups hero's colours behind the pill.
class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(AppSpacing.screen),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.heroTop, c.heroBottom],
          ),
        ),
        child: Align(alignment: AlignmentDirectional.topStart, child: child),
      ),
    );
  }
}

const _places = <CaptureChip>[
  (id: 'g-trip', name: 'Goa trip', friend: false),
  (id: 'g-flat', name: 'Flat 4B', friend: false),
  (id: 'g-asha', name: 'Asha', friend: true),
];

List<Override> _settings() => [
  captureBridgeProvider.overrideWithValue(FakeCaptureBridge()),
  captureSettingsProvider.overrideWith(() => _FixedSettings(const CaptureSettings(enabled: true))),
  // Overlay is missing, so the "Allow restricted settings" guide shows.
  capturePermissionsProvider.overrideWith(
    (ref) async => const CapturePermissions(
      supported: true,
      sdk: 35,
      notifications: true,
      postNotifications: true,
    ),
  ),
  captureAppsProvider.overrideWith((ref) async => sampleApps),
];

List<Override> _pending() => [pendingCapturesProvider.overrideWithValue(AsyncData(_captures))];

List<Override> _capture() => [
  captureLinkProvider(captureId1).overrideWithValue(AsyncData(_captures.first)),
  capturePlacesProvider.overrideWithValue(const AsyncData(_places)),
];

List<_Case> _cases() => [
  (
    name: 'settings',
    screen: () => const CaptureSettingsScreen(),
    overrides: _settings,
    height: 2000,
    tallHeight: 5600,
  ),
  (
    name: 'sheet',
    screen: () => const _SheetHost(child: PaymentsToAddList()),
    overrides: _pending,
    height: 915,
    tallHeight: 1500,
  ),
  (
    name: 'add_screen',
    screen: () => const CaptureScreen(captureId: captureId1),
    overrides: _capture,
    height: 915,
    tallHeight: 1700,
  ),
  (
    name: 'hero_pill',
    screen: () => const _HeroBackdrop(child: PaymentsToAddPill()),
    overrides: _pending,
    height: 200,
    tallHeight: 260,
  ),
];

void main() {
  // TC-X4-08 / TC-X4-07 / TC-X4-06 visuals: settings (restricted-settings guide showing), the payments-to-add
  // sheet, the capture screen and the Groups hero pill, light and dark at text scale 1.0 and 2.0.
  for (final c in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'phase 18b capture ${c.name} ${mode.name} $suffix',
          fileName: 'capture_${c.name}_${mode.name}_$suffix',
          pumpBeforeTest: pumpFixedFrames,
          builder: () => expenseApp(
            c.screen(),
            overrides: c.overrides(),
            mode: mode,
            scale: scale,
            size: Size(goldenWidth, scale > 1 ? c.tallHeight : c.height),
          ),
        );
      }
    }
  }
}
