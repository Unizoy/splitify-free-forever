import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:logging/logging.dart';
import 'package:workmanager/workmanager.dart';

final _log = Logger('sync');

/// WorkManager jobs that sync while the app is closed (04 §8): every 15 minutes, and once as soon as a network
/// is there when the app goes to the background with changes waiting.
abstract interface class BackgroundSync {
  /// Periodic job (keeps an existing one).
  Future<void> start();

  /// One-off job that runs when a network is available (replaces a waiting one).
  Future<void> syncWhenOnline();

  /// Sign-out: no more background runs.
  Future<void> stop();
}

/// Widget tests and builds without the plugin.
class NoBackgroundSync implements BackgroundSync {
  const NoBackgroundSync();

  @override
  Future<void> start() async {}

  @override
  Future<void> syncWhenOnline() async {}

  @override
  Future<void> stop() async {}
}

/// [BackgroundSync] over the `workmanager` plugin. [Workmanager.initialize] must have run (bootstrap).
class WorkmanagerBackgroundSync implements BackgroundSync {
  WorkmanagerBackgroundSync([Workmanager? workmanager]) : _wm = workmanager ?? Workmanager();

  final Workmanager _wm;

  static const periodicName = 'splitify-sync-periodic';
  static const onceName = 'splitify-sync-once';
  static const taskName = 'sync';

  static final _network = Constraints(networkType: NetworkType.connected);

  @override
  Future<void> start() => _safe(
    () => _wm.registerPeriodicTask(
      periodicName,
      taskName,
      frequency: const Duration(minutes: 15),
      constraints: _network,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    ),
  );

  @override
  Future<void> syncWhenOnline() => _safe(
    () => _wm.registerOneOffTask(
      onceName,
      taskName,
      constraints: _network,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    ),
  );

  @override
  Future<void> stop() => _safe(_wm.cancelAll);

  Future<void> _safe(Future<void> Function() body) async {
    try {
      await body();
    } on Object catch (e) {
      // Background sync is a bonus: the foreground triggers still work without it.
      _log.warning('background sync not scheduled: $e');
    }
  }
}

/// Port name the signed-in app registers so a WorkManager run in the same process asks it to sync instead of
/// starting a second Supabase session (two sessions would race on refresh-token rotation, S-160).
const foregroundSyncPortName = 'splitify.sync.foreground';

/// Main isolate side of [askForegroundToSync]: answers `started` at once and `done` after [sync].
class ForegroundSyncPort {
  ForegroundSyncPort(this.sync) {
    IsolateNameServer.removePortNameMapping(foregroundSyncPortName);
    IsolateNameServer.registerPortWithName(_port.sendPort, foregroundSyncPortName);
    _port.listen((message) {
      if (message is! SendPort) return;
      message.send('started');
      unawaited(
        sync()
            .catchError((Object e) => _log.warning('foreground sync for worker: $e'))
            .whenComplete(() => message.send('done')),
      );
    });
  }

  final Future<void> Function() sync;
  final _port = ReceivePort();

  void close() {
    final mapped = IsolateNameServer.lookupPortByName(foregroundSyncPortName);
    if (mapped == _port.sendPort) {
      IsolateNameServer.removePortNameMapping(foregroundSyncPortName);
    }
    _port.close();
  }
}

/// Worker side: true when the signed-in app in this process ran the sync; false when there is none (or it
/// did not answer within [answer]), so the worker syncs on its own.
Future<bool> askForegroundToSync({
  Duration answer = const Duration(seconds: 3),
  Duration finish = const Duration(minutes: 5),
}) async {
  final main = IsolateNameServer.lookupPortByName(foregroundSyncPortName);
  if (main == null) return false;
  final reply = ReceivePort();
  final replies = StreamIterator<Object?>(reply);
  try {
    main.send(reply.sendPort);
    if (!await replies.moveNext().timeout(answer, onTimeout: () => false)) {
      IsolateNameServer.removePortNameMapping(foregroundSyncPortName);
      return false;
    }
    await replies.moveNext().timeout(finish, onTimeout: () => false);
    return true;
  } finally {
    await replies.cancel();
    reply.close();
  }
}
