import 'dart:async';

import 'package:flutter/widgets.dart';

/// Work that waits until the first frame is on screen (R3-B, S-456): push, crash reports and background sync
/// start, the bell refresh, the exchange-rate refresh and the home-screen widget update. The native splash
/// only waits for what the first screen needs (preferences, Supabase's saved session, the database).
///
/// [arm] is called once by `bootstrap`; without it (tests, the WorkManager isolate) [afterFirstFrame] is
/// already open, so nothing changes there.
abstract final class StartupGate {
  static Completer<void>? _gate;

  /// Extra quiet time after the first frame, so the first screen's data loads before the deferred work.
  static const settle = Duration(milliseconds: 600);

  /// Opens anyway after this long (the first frame never came: the app started in the background).
  static const fallback = Duration(seconds: 4);

  /// Whether this run waits for its first frame.
  static bool get armed => _gate != null && !_gate!.isCompleted;

  /// Completes once the first frame is on screen (plus [settle]); at once when not armed.
  static Future<void> get afterFirstFrame => _gate?.future ?? Future<void>.value();

  /// Called by `bootstrap` before `runApp`.
  static void arm({WidgetsBinding? binding}) {
    if (_gate != null) return;
    final gate = _gate = Completer<void>();
    void open() {
      if (!gate.isCompleted) gate.complete();
    }

    final timer = Timer(fallback, open);
    unawaited(
      (binding ?? WidgetsBinding.instance).waitUntilFirstFrameRasterized.then((_) {
        timer.cancel();
        Timer(settle, open);
      }),
    );
  }

  /// Runs [work] once the gate opens (errors are the caller's: [work] should catch its own).
  static void run(Future<void> Function() work) => unawaited(afterFirstFrame.then((_) => work()));

  @visibleForTesting
  static void debugReset() => _gate = null;
}
