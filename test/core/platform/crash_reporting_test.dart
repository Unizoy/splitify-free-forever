// W2-Y (S-436): crash reports carry no personal data (only the error's type and the stack), follow the
// person's switch (on by default in release builds, off in debug), keep the earlier error handlers, and are off
// without Firebase.
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/platform/crash_reporting.dart';

class _Reporter implements CrashReporter {
  final reports = <(String, bool)>[];
  final enabled = <bool>[];

  @override
  bool get available => true;

  @override
  Future<void> setEnabled(bool on) async => enabled.add(on);

  @override
  Future<void> report(Object error, StackTrace? stack, {required bool fatal}) async =>
      reports.add((ScrubbedError.of(error).toString(), fatal));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a report says only what kind of error it was', () {
    const secret = 'Mohit owes Asha ₹1,200 for “Goa villa”, mohit@example.com';
    final e = ScrubbedError.of(const FormatException(secret));
    expect(e.type, 'FormatException');
    expect('$e', 'FormatException');
    expect('$e'.contains('Mohit'), isFalse);
    final details = FlutterErrorDetails(
      exception: StateError(secret),
      informationCollector: () => [DiagnosticsNode.message(secret)],
    );
    expect('${ScrubbedError.of(details)}', 'StateError');
  });

  test('on by default in release builds, off in debug builds; the saved choice wins', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(crashReportsOn(prefs, release: true), isTrue);
    expect(crashReportsOn(prefs, release: false), isFalse);
    await prefs.setBool(crashReportsKey, false);
    expect(crashReportsOn(prefs, release: true), isFalse);
    await prefs.setBool(crashReportsKey, true);
    expect(crashReportsOn(prefs, release: false), isTrue);
  });

  test('uncaught errors go to the reporter after the existing handlers', () {
    final dispatcher = PlatformDispatcher.instance;
    final oldFlutter = FlutterError.onError;
    final oldPlatform = dispatcher.onError;
    addTearDown(() {
      FlutterError.onError = oldFlutter;
      dispatcher.onError = oldPlatform;
    });
    final seen = <String>[];
    FlutterError.onError = (d) => seen.add('flutter ${d.exception.runtimeType}');
    dispatcher.onError = (e, s) {
      seen.add('platform ${e.runtimeType}');
      return true;
    };
    final reporter = _Reporter();
    chainCrashHandlers(reporter, dispatcher: dispatcher);

    FlutterError.onError!(FlutterErrorDetails(exception: ArgumentError('Asha')));
    FlutterError.onError!(FlutterErrorDetails(exception: RangeError('x'), silent: true));
    expect(dispatcher.onError!(const FormatException('₹500'), StackTrace.current), isTrue);

    expect(seen, ['flutter ArgumentError', 'flutter RangeError', 'platform FormatException']);
    expect(reporter.reports, [
      ('ArgumentError', true),
      ('RangeError', false),
      ('FormatException', true),
    ]);
  });

  test('without Firebase there is nothing to report to', () async {
    SharedPreferences.setMockInitialValues({});
    final reporter = await initCrashReporting(await SharedPreferences.getInstance());
    expect(reporter, isA<DisabledCrashReporter>());
    expect(reporter.available, isFalse);
    await reporter.setEnabled(true);
    await reporter.report(StateError('x'), null, fatal: true);
  });

  test('the Account switch saves the choice and tells the reporter', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final reporter = _Reporter();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        crashReporterProvider.overrideWithValue(reporter),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(crashReportsSettingProvider), kReleaseMode);
    await container.read(crashReportsSettingProvider.notifier).set(on: false);
    expect(container.read(crashReportsSettingProvider), isFalse);
    expect(prefs.getBool(crashReportsKey), isFalse);
    await container.read(crashReportsSettingProvider.notifier).set(on: true);
    expect(reporter.enabled, [false, true]);
    expect(prefs.getBool(crashReportsKey), isTrue);
  });

  test('without preferences the switch falls back to the build default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(crashReportsSettingProvider), kReleaseMode);
    expect(container.read(crashReporterProvider), isA<DisabledCrashReporter>());
  });
}
