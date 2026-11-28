import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

/// Startup timings for profile measurements (R3-B, S-450): only with `--dart-define=SPLITIFY_STARTUP_LOG=true`
/// (`tool/e2e/perf_r3.ps1`), never in store builds. One logcat line when the first frame is on screen:
/// `R3START main_to_run_app=… main_to_first_frame=… process_to_first_frame=…` (milliseconds).
abstract final class StartupTrace {
  static const on = bool.fromEnvironment('SPLITIFY_STARTUP_LOG');

  static final _sinceMain = Stopwatch();
  static int? _runApp;

  /// First line of `main`.
  static void start() {
    if (on) _sinceMain.start();
  }

  /// Just before `runApp`.
  static void runApp() {
    if (!on) return;
    _runApp = _sinceMain.elapsedMilliseconds;
    unawaited(
      WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) {
        debugPrint(
          'R3START main_to_run_app=$_runApp main_to_first_frame=${_sinceMain.elapsedMilliseconds} '
          'process_to_first_frame=${processAgeMs() ?? -1}',
        );
      }, onError: (Object _) {}),
    );
  }

  /// How long this process has run (Android/Linux `/proc`, 10 ms ticks); null elsewhere.
  @visibleForTesting
  static int? processAgeMs({String stat = '/proc/self/stat', String uptime = '/proc/uptime'}) {
    try {
      final s = File(stat).readAsStringSync();
      // Fields after the command name "(…)": state is field 3, starttime is field 22.
      final fields = s.substring(s.lastIndexOf(')') + 2).split(' ');
      final startTicks = int.parse(fields[19]);
      final up = double.parse(File(uptime).readAsStringSync().split(' ').first);
      return (up * 1000).round() - startTicks * 10;
    } on Object {
      return null;
    }
  }
}
