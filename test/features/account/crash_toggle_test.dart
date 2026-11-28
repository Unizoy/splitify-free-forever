// W2-Y (S-436): the "Send crash reports" switch in Account → Settings — off and explained when this build has no
// Firebase, a real switch when it has, and each flip reaches the reporter and is kept on the phone.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/platform/crash_reporting.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/repositories/sync_repository.dart' show SyncStatus;
import 'package:splitify/data/sync/sync_types.dart' show SyncPhase;
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/account/presentation/account_settings_sheet.dart';
import 'package:splitify/ui/components/components.dart';

import '../friends/presentation/friends_harness.dart' show FixedProfile;
import '../expenses/presentation/presentation_harness.dart';

/// Keeps [AccountSettingsList] off the database: a profile, a synced phone and no uploads waiting.
List<Override> accountSettingsOverrides() => [
  profileProvider.overrideWith(FixedProfile.new),
  syncStatusProvider.overrideWith((ref) => Stream.value(const SyncStatus(phase: SyncPhase.idle))),
  syncUploadsProvider.overrideWith((ref) => Stream.value(const [])),
];

Finder _row() => find.byKey(const Key('settings-crash-reports'));

/// A reporter that records what it is told.
class FakeCrashReporter implements CrashReporter {
  FakeCrashReporter({this.available = true});

  @override
  final bool available;
  final choices = <bool>[];

  @override
  Future<void> setEnabled(bool on) async => choices.add(on);

  @override
  Future<void> report(Object error, StackTrace? stack, {required bool fatal}) async {}
}

Future<SharedPreferences> _pump(
  WidgetTester t, {
  CrashReporter? reporter,
  Map<String, Object> saved = const {},
  List<Override> extra = const [],
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  usePhone(t);
  t.view.physicalSize = const Size(412, 2400);
  await t.pumpWidget(
    routerApp(
      GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: SingleChildScrollView(child: AccountSettingsList())),
          ),
        ],
      ),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (reporter != null) crashReporterProvider.overrideWithValue(reporter),
        ...accountSettingsOverrides(),
        ...extra,
      ],
    ),
  );
  await settle(t);
  return prefs;
}

bool _on(WidgetTester t) =>
    t.widget<PillSwitch>(find.descendant(of: _row(), matching: find.byType(PillSwitch))).value;

void main() {
  group('no Firebase in this build (the default reporter)', () {
    // W2-Y S-436
    testWidgets('the row says it is not available and cannot be switched', (t) async {
      await _pump(t);
      expect(_row(), findsOneWidget);
      expect(find.text('Send crash reports'), findsOneWidget);
      expect(find.text('Not available in this build'), findsOneWidget);
      expect(t.widget<ToggleRow>(_row()).onChanged, isNull);
      expect(_on(t), isFalse);
    });

    // W2-Y S-436
    testWidgets('a saved "on" does not show as on while nothing can be sent', (t) async {
      await _pump(t, saved: {crashReportsKey: true});
      expect(_on(t), isFalse);
    });

    // W2-Y S-436
    testWidgets('tapping does nothing: nothing saved', (t) async {
      final prefs = await _pump(t);
      await t.tap(_row());
      await settle(t);
      expect(prefs.containsKey(crashReportsKey), isFalse);
      expect(_on(t), isFalse);
    });
  });

  group('with a reporter', () {
    // W2-Y S-436
    testWidgets('shows the privacy hint and the saved choice', (t) async {
      await _pump(t, reporter: FakeCrashReporter(), saved: {crashReportsKey: true});
      expect(
        find.text('Helps fix crashes. Reports hold no names, amounts or emails.'),
        findsOneWidget,
      );
      expect(find.text('Not available in this build'), findsNothing);
      expect(t.widget<ToggleRow>(_row()).onChanged, isNotNull);
      expect(_on(t), isTrue);
    });

    // W2-Y S-436
    testWidgets('off by default in a debug (test) build', (t) async {
      await _pump(t, reporter: FakeCrashReporter());
      expect(_on(t), isFalse);
    });

    // W2-Y S-436
    testWidgets('switching on and off tells the reporter and keeps the choice', (t) async {
      final reporter = FakeCrashReporter();
      final prefs = await _pump(t, reporter: reporter);
      await t.tap(_row());
      await settle(t);
      expect(_on(t), isTrue);
      expect(reporter.choices, [true]);
      expect(prefs.getBool(crashReportsKey), isTrue);

      await t.tap(_row());
      await settle(t);
      expect(_on(t), isFalse);
      expect(reporter.choices, [true, false]);
      expect(prefs.getBool(crashReportsKey), isFalse);
    });

    // W2-Y S-436
    testWidgets('the row is a labelled switch for a screen reader', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, reporter: FakeCrashReporter(), saved: {crashReportsKey: true});
      final node = t.getSemantics(_row());
      expect(node.label, contains('Send crash reports'));
      expect(node.flagsCollection.isToggled, Tristate.isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);
      handle.dispose();
    });
  });

  group('crash settings (no widgets)', () {
    // W2-Y S-436
    test('release builds default to on, debug builds to off', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(crashReportsOn(prefs, release: true), isTrue);
      expect(crashReportsOn(prefs, release: false), isFalse);
      await prefs.setBool(crashReportsKey, false);
      expect(crashReportsOn(prefs, release: true), isFalse);
    });
  });
}
