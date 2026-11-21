import 'dart:async';

/// Starts a sync on: connectivity regained, a Realtime "changed" nudge, app resume (04 §1).
class SyncTriggers {
  SyncTriggers({required this.sync, required Stream<bool> online, required Stream<void> nudges}) {
    _subs
      ..add(
        online.listen((on) {
          if (on && _wasOnline == false) unawaited(sync());
          _wasOnline = on;
        }),
      )
      ..add(nudges.listen((_) => unawaited(sync())));
  }

  final Future<void> Function() sync;
  final _subs = <StreamSubscription<Object?>>[];
  bool? _wasOnline;

  /// App came back to the foreground.
  void onResume() => unawaited(sync());

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
  }
}

/// Realtime nudges for the user's groups (`group:<id>`, `user:<uid>`); implemented in `lib/data/remote`.
abstract class ChangeNudges {
  Stream<void> get nudges;

  /// Subscribes to exactly these group topics (plus the user topic).
  Future<void> watchGroups(Set<String> groupIds);

  Future<void> dispose();
}
