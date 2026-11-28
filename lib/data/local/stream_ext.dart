import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;

/// Stream helpers for the phone's database reads (R3-B, S-455).
///
/// Drift re-runs a watched query after every write to a table it reads, even when the write was for another
/// group, and emits the new rows although they equal the last ones. During a sync (one pull page per
/// transaction, many pages) that rebuilt every open screen and recomputed every balance once per page.
extension DistinctRows<T> on Stream<List<T>> {
  /// Drops a list equal to the last one (drift rows compare by value).
  Stream<List<T>> distinctRows() => distinct(listEquals);
}

/// Coalescing [Stream.asyncMap] for "something changed → load again" streams.
extension LatestLoad<S> on Stream<S> {
  /// Runs [load] for each event, but events that arrive while a load runs collapse into ONE more run with
  /// the newest event (only the newest state matters). Errors of [load] go to the stream like asyncMap's.
  /// Single-subscription; pausing and cancelling pass through.
  Stream<T> asyncMapLatest<T>(Future<T> Function(S event) load) {
    late final StreamController<T> out;
    StreamSubscription<S>? sub;
    var running = false;
    var sourceDone = false;
    var hasPending = false;
    S? pending;

    Future<void> run(S event) async {
      running = true;
      try {
        final value = await load(event);
        if (!out.isClosed) out.add(value);
      } on Object catch (e, s) {
        if (!out.isClosed) out.addError(e, s);
      }
      running = false;
      if (hasPending) {
        hasPending = false;
        final next = pending as S;
        pending = null;
        unawaited(run(next));
      } else if (sourceDone && !out.isClosed) {
        unawaited(out.close());
      }
    }

    out = StreamController<T>(
      onListen: () {
        sub = listen(
          (event) {
            if (running) {
              pending = event;
              hasPending = true;
            } else {
              unawaited(run(event));
            }
          },
          onError: out.addError,
          onDone: () {
            sourceDone = true;
            if (!running && !out.isClosed) unawaited(out.close());
          },
        );
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }
}
