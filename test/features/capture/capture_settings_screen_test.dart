// TC-X4-08: Account -> Payment bubble settings: master switch, sources, live access state, restricted-settings
// guide, per-app switches and the sample bubble.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/entities/payment_capture.dart';
import 'package:splitify/features/capture/presentation/capture_settings_screen.dart';

import '../../support/capture_fakes.dart';
import '../expenses/presentation/presentation_harness.dart';
import 'capture_harness.dart';

const _allOff = CapturePermissions(supported: true, sdk: 35);
const _alertsAndPost = CapturePermissions(
  supported: true,
  sdk: 35,
  notifications: true,
  postNotifications: true,
);
const _everything = CapturePermissions(
  supported: true,
  sdk: 35,
  notifications: true,
  overlay: true,
  accessibility: true,
  postNotifications: true,
);

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(_key(key));
  await settle(t);
}

void main() {
  Future<FakeCaptureBridge> pump(
    WidgetTester t, {
    CaptureSettings settings = const CaptureSettings(),
    CapturePermissions perms = _allOff,
    bool sampleShown = false,
    double scale = 1,
  }) async {
    final bridge = FakeCaptureBridge(
      settingsState: settings,
      permissionState: perms,
      appList: sampleApps,
      sampleShown: sampleShown,
    );
    await pumpCapture(t, const CaptureSettingsScreen(), bridge: bridge);
    return bridge;
  }

  group('master switch', () {
    // TC-X4-08
    testWidgets('off by default: only the privacy note and the master row', (t) async {
      await pump(t);
      expect(_key('capture-privacy'), findsOneWidget);
      expect(_key('capture-master'), findsOneWidget);
      expect(switchOn(t, 'capture-master'), isFalse);
      expect(rowEnabled(t, 'capture-master'), isTrue);
      for (final k in [
        'capture-source-alerts',
        'capture-source-bubble',
        'capture-source-smart',
        'capture-during-payment',
        'capture-access-notifications',
        'capture-restricted-guide',
        'capture-sample',
        'capture-app-com.phonepe.app',
      ]) {
        expect(_key(k), findsNothing, reason: k);
      }
      expect(_key('capture-unsupported'), findsNothing);
    });

    // TC-X4-08
    testWidgets('turning it on saves enabled and shows sources, access rows and apps', (t) async {
      final bridge = await pump(t);
      await _tap(t, 'capture-master');
      expect(bridge.saved.last.enabled, isTrue);
      expect(switchOn(t, 'capture-master'), isTrue);
      expect(_key('capture-source-alerts'), findsOneWidget);
      expect(_key('capture-source-bubble'), findsOneWidget);
      expect(_key('capture-source-smart'), findsOneWidget);
      expect(_key('capture-during-payment'), findsOneWidget);
      // Alerts + bubble are the default sources, plus the notification permission.
      expect(_key('capture-access-notifications'), findsOneWidget);
      expect(_key('capture-access-overlay'), findsOneWidget);
      expect(_key('capture-access-postNotifications'), findsOneWidget);
      expect(_key('capture-access-accessibility'), findsNothing);
      expect(_key('capture-app-com.google.android.apps.nbu.paisa.user'), findsOneWidget);
      expect(_key('capture-app-com.phonepe.app'), findsOneWidget);
      expect(_key('capture-app-com.hdfc.sms'), findsOneWidget);
      expect(_key('capture-sample'), findsOneWidget);
    });

    // TC-X4-08
    testWidgets('turning it off again saves enabled false', (t) async {
      final bridge = await pump(
        t,
        settings: const CaptureSettings(enabled: true),
        perms: _everything,
      );
      await _tap(t, 'capture-master');
      expect(bridge.saved.last.enabled, isFalse);
      expect(_key('capture-sample'), findsNothing);
    });

    // TC-X4-08
    testWidgets('unsupported phone: master switch disabled and a note explains', (t) async {
      final bridge = await pump(t, perms: const CapturePermissions());
      expect(_key('capture-unsupported'), findsOneWidget);
      expect(find.text('The payment bubble works on Android 8 and newer.'), findsOneWidget);
      expect(rowEnabled(t, 'capture-master'), isFalse);
      await t.tap(_key('capture-master'), warnIfMissed: false);
      await settle(t);
      expect(bridge.saved, isEmpty);
    });
  });

  group('access rows', () {
    const on = CaptureSettings(enabled: true);

    // TC-X4-08
    testWidgets(
      "granted shows an 'Allowed' pill, missing shows a Grant button that opens the screen",
      (t) async {
        final bridge = await pump(t, settings: on, perms: _alertsAndPost);
        expect(_key('capture-allowed-notifications'), findsOneWidget);
        expect(_key('capture-grant-notifications'), findsNothing);
        expect(
          find.descendant(
            of: _key('capture-allowed-notifications'),
            matching: find.text('Allowed'),
          ),
          findsOneWidget,
        );
        expect(_key('capture-allowed-postNotifications'), findsOneWidget);
        expect(_key('capture-allowed-overlay'), findsNothing);
        expect(
          find.descendant(of: _key('capture-grant-overlay'), matching: find.text('Grant')),
          findsOneWidget,
        );

        await _tap(t, 'capture-grant-overlay');
        expect(bridge.opened, ['overlay']);
      },
    );

    // TC-X4-08
    testWidgets('every access has its own Grant button', (t) async {
      final bridge = await pump(
        t,
        settings: const CaptureSettings(enabled: true, smart: true),
        perms: _allOff,
      );
      for (final a in CaptureAccess.values) {
        await _tap(t, 'capture-grant-${a.name}');
      }
      expect(bridge.opened, [for (final a in CaptureAccess.values) a.name]);
    });

    // TC-X4-08
    testWidgets('the restricted-settings guide shows while an access is missing', (t) async {
      final bridge = await pump(t, settings: on, perms: _alertsAndPost);
      expect(_key('capture-restricted-guide'), findsOneWidget);
      await _tap(t, 'capture-app-info');
      expect(bridge.opened, ['appInfo']);
    });

    // TC-X4-08
    testWidgets('no guide once the needed accesses are granted', (t) async {
      await pump(
        t,
        settings: on,
        perms: const CapturePermissions(
          supported: true,
          sdk: 35,
          notifications: true,
          overlay: true,
        ),
      );
      expect(_key('capture-restricted-guide'), findsNothing);
    });

    // TC-X4-08
    testWidgets('only the post-notifications access missing does not raise the guide', (t) async {
      await pump(
        t,
        settings: on,
        perms: const CapturePermissions(
          supported: true,
          sdk: 35,
          notifications: true,
          overlay: true,
        ),
      );
      expect(_key('capture-grant-postNotifications'), findsOneWidget);
      expect(_key('capture-restricted-guide'), findsNothing);
    });
  });

  group('sources', () {
    // TC-X4-08
    testWidgets("'During payment' is disabled until smart capture is on", (t) async {
      final bridge = await pump(
        t,
        settings: const CaptureSettings(enabled: true),
        perms: _everything,
      );
      expect(rowEnabled(t, 'capture-during-payment'), isFalse);
      expect(switchOn(t, 'capture-during-payment'), isFalse);

      await _tap(t, 'capture-source-smart');
      expect(bridge.saved.last.smart, isTrue);
      expect(rowEnabled(t, 'capture-during-payment'), isTrue);

      await _tap(t, 'capture-during-payment');
      expect(bridge.saved.last.duringPayment, isTrue);
      expect(switchOn(t, 'capture-during-payment'), isTrue);
    });

    // TC-X4-08
    testWidgets('turning smart capture off also clears during payment', (t) async {
      final bridge = await pump(
        t,
        settings: const CaptureSettings(enabled: true, smart: true, duringPayment: true),
        perms: _everything,
      );
      expect(switchOn(t, 'capture-during-payment'), isTrue);
      await _tap(t, 'capture-source-smart');
      expect(bridge.saved.last.smart, isFalse);
      expect(bridge.saved.last.duringPayment, isFalse);
      expect(rowEnabled(t, 'capture-during-payment'), isFalse);
    });

    // TC-X4-08
    testWidgets('smart capture adds the accessibility access row', (t) async {
      await pump(
        t,
        settings: const CaptureSettings(enabled: true, smart: true),
        perms: _everything,
      );
      expect(_key('capture-access-accessibility'), findsOneWidget);
      expect(_key('capture-allowed-accessibility'), findsOneWidget);
    });
  });

  group('apps and sample', () {
    // TC-X4-08
    testWidgets('per-app switch saves {package: false}', (t) async {
      final bridge = await pump(
        t,
        settings: const CaptureSettings(enabled: true),
        perms: _everything,
      );
      expect(switchOn(t, 'capture-app-com.phonepe.app'), isTrue);
      await _tap(t, 'capture-app-com.phonepe.app');
      expect(bridge.saved.last.apps, {'com.phonepe.app': false});
      expect(switchOn(t, 'capture-app-com.phonepe.app'), isFalse);
    });

    // TC-X4-08
    testWidgets('an app that is off by default can be switched on', (t) async {
      final bridge = await pump(
        t,
        settings: const CaptureSettings(enabled: true),
        perms: _everything,
      );
      expect(switchOn(t, 'capture-app-com.hdfc.sms'), isFalse);
      await _tap(t, 'capture-app-com.hdfc.sms');
      expect(bridge.saved.last.apps, {'com.hdfc.sms': true});
    });

    // TC-X4-08
    testWidgets('sample button calls showSample and says it is off when nothing can show', (
      t,
    ) async {
      final bridge = await pump(t, settings: const CaptureSettings(enabled: true), perms: _allOff);
      await _tap(t, 'capture-sample');
      expect(bridge.samples, [(payee: 'Rahul', app: 'Splitify Free Forever')]);
      expect(find.text('Turn on the payment bubble and its access first.'), findsOneWidget);
    });

    // TC-X4-08
    testWidgets('sample says so when the bubble is on screen', (t) async {
      await pump(
        t,
        settings: const CaptureSettings(enabled: true),
        perms: _everything,
        sampleShown: true,
      );
      await _tap(t, 'capture-sample');
      expect(find.text('The sample bubble is over the app now.'), findsOneWidget);
    });

    // TC-X4-08
    testWidgets('sample falls back to a notification when only that is allowed', (t) async {
      await pump(t, settings: const CaptureSettings(enabled: true), perms: _alertsAndPost);
      await _tap(t, 'capture-sample');
      expect(
        find.text('Sent as a notification. Allow display over other apps to see the bubble.'),
        findsOneWidget,
      );
    });
  });
}
