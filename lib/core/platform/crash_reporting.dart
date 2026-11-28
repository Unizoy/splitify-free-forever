import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';

final _log = Logger('crash');

/// Crash reports (W2-Y, S-436; docs/PRIVACY.md "Crash reports"). Firebase Crashlytics, free. A report holds
/// only the error's TYPE and the stack trace (file / line / method of the app's own code) plus what
/// Crashlytics adds itself (phone model, Android version, app version, a random install id). Never the
/// error's message, the widget details Flutter attaches, names, amounts, emails, notes or ids: messages can
/// quote what the person typed, so they stay on the phone.
abstract interface class CrashReporter {
  /// Firebase is set up in this build (google-services.json, not a `.qa` side-by-side build).
  bool get available;

  /// Turns sending on or off; Crashlytics keeps the choice for the next start too.
  Future<void> setEnabled(bool on);

  /// Sends one uncaught error (only its type and stack).
  Future<void> report(Object error, StackTrace? stack, {required bool fatal});
}

/// No Firebase (contributors' builds, `.qa` builds, tests): nothing is collected or sent.
class DisabledCrashReporter implements CrashReporter {
  const DisabledCrashReporter();

  @override
  bool get available => false;

  @override
  Future<void> setEnabled(bool on) async {}

  @override
  Future<void> report(Object error, StackTrace? stack, {required bool fatal}) async {}
}

/// What a report says about an error: its type, nothing else (see [CrashReporter]).
final class ScrubbedError implements Exception {
  const ScrubbedError(this.type);

  /// `FormatException`, `StateError`, `_TypeError`, …
  final String type;

  /// The type of [error] (a [FlutterErrorDetails] reports the type of its exception).
  factory ScrubbedError.of(Object error) => ScrubbedError(
    (error is FlutterErrorDetails ? error.exception : error).runtimeType.toString(),
  );

  @override
  String toString() => type;
}

typedef CrashSink = Future<void> Function(ScrubbedError error, StackTrace? stack, bool fatal);

/// [CrashReporter] over Firebase Crashlytics (device glue: proven on a release build with Firebase).
class CrashlyticsReporter implements CrashReporter {
  CrashlyticsReporter(this._crashlytics, {CrashSink? sink})
    : _sink =
          sink ??
          ((error, stack, fatal) =>
              _crashlytics.recordError(error, stack, fatal: fatal, printDetails: false));

  final FirebaseCrashlytics _crashlytics;
  final CrashSink _sink;

  @override
  bool get available => true;

  @override
  Future<void> setEnabled(bool on) => _crashlytics.setCrashlyticsCollectionEnabled(on);

  @override
  Future<void> report(Object error, StackTrace? stack, {required bool fatal}) =>
      _sink(ScrubbedError.of(error), stack, fatal);
}

/// The preference key of the toggle in Account → Settings.
const crashReportsKey = 'w2y.crashReports';

/// Crash reports are on by default in store (release) builds, off in debug builds (S-436).
bool crashReportsDefault({bool release = kReleaseMode}) => release;

/// Whether the person lets this phone send crash reports.
bool crashReportsOn(SharedPreferences prefs, {bool release = kReleaseMode}) =>
    prefs.getBool(crashReportsKey) ?? crashReportsDefault(release: release);

/// Starts crash reporting when Firebase is set up (call after Firebase.initializeApp, i.e. after `initPush`):
/// applies the saved choice and sends uncaught Flutter and platform errors, on top of the handlers already
/// installed (they keep logging). Without Firebase it returns [DisabledCrashReporter] (S-144 pattern).
Future<CrashReporter> initCrashReporting(SharedPreferences prefs) async {
  if (Firebase.apps.isEmpty) return const DisabledCrashReporter();
  final CrashReporter reporter;
  try {
    reporter = CrashlyticsReporter(FirebaseCrashlytics.instance);
    await reporter.setEnabled(crashReportsOn(prefs));
  } on Object catch (e) {
    _log.info('crash reports off: ${e.runtimeType}');
    return const DisabledCrashReporter();
  }
  chainCrashHandlers(reporter);
  return reporter;
}

/// Sends uncaught errors to [reporter] after the existing [FlutterError.onError] /
/// [PlatformDispatcher.onError] handlers ran.
void chainCrashHandlers(CrashReporter reporter, {PlatformDispatcher? dispatcher}) {
  final d = dispatcher ?? PlatformDispatcher.instance;
  final flutter = FlutterError.onError;
  FlutterError.onError = (details) {
    flutter?.call(details);
    unawaited(reporter.report(details, details.stack, fatal: !details.silent));
  };
  final platform = d.onError;
  d.onError = (error, stack) {
    final handled = platform?.call(error, stack) ?? false;
    unawaited(reporter.report(error, stack, fatal: true));
    return handled;
  };
}

/// The crash reporter of this run (bootstrap overrides it; tests get the disabled one).
final crashReporterProvider = Provider<CrashReporter>((ref) => const DisabledCrashReporter());

/// The "Send crash reports" switch (Account → Settings), kept on this phone.
class CrashReportsSetting extends Notifier<bool> {
  @override
  bool build() {
    try {
      return crashReportsOn(ref.watch(sharedPreferencesProvider));
    } on Object {
      return crashReportsDefault();
    }
  }

  Future<void> set({required bool on}) async {
    state = on;
    try {
      await ref.read(sharedPreferencesProvider).setBool(crashReportsKey, on);
    } on Object catch (e) {
      _log.fine('crash choice not saved: ${e.runtimeType}');
    }
    await ref.read(crashReporterProvider).setEnabled(on);
  }
}

final crashReportsSettingProvider = NotifierProvider<CrashReportsSetting, bool>(
  CrashReportsSetting.new,
);

/// Crash reports that start after the first frame (R3-B, S-456): until [complete] the switch is hidden
/// ([available] false), and a choice or a report made meanwhile waits for the real reporter.
class DeferredCrashReporter implements CrashReporter {
  DeferredCrashReporter();

  final _impl = Completer<CrashReporter>();
  CrashReporter? _ready;

  /// Sets the real reporter (once).
  void complete(CrashReporter reporter) {
    if (_impl.isCompleted) return;
    _ready = reporter;
    _impl.complete(reporter);
  }

  @override
  bool get available => _ready?.available ?? false;

  @override
  Future<void> setEnabled(bool on) async => (await _impl.future).setEnabled(on);

  @override
  Future<void> report(Object error, StackTrace? stack, {required bool fatal}) async =>
      (await _impl.future).report(error, stack, fatal: fatal);
}
