import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/sync/mutation_queue.dart';
import 'package:splitify/data/sync/pull_applier.dart';
import 'package:splitify/data/sync/server_clock.dart';
import 'package:splitify/data/sync/sync_types.dart';

final _log = Logger('sync');

typedef TimerFactory = Timer Function(Duration delay, void Function() callback);

/// Push outbox → pull pages (04 §3–4). Single flight: a sync requested while one runs makes it run once
/// more. Network/server errors back off 2 s → 5 min with jitter; a 401 refreshes once, then signs out
/// without touching the local database.
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.remote,
    required this.clock,
    this.onSignedOut,
    Random? random,
    TimerFactory? timer,
    this.batchSize = 50,
    this.pageSize = 500,
    this.debounce = const Duration(seconds: 1),
  }) : _random = random ?? Random(),
       _timer = timer ?? Timer.new;

  final AppDatabase db;
  final RemoteApi remote;
  final Clock clock;
  final Future<void> Function()? onSignedOut;
  final int batchSize;
  final int pageSize;
  final Duration debounce;
  final Random _random;
  final TimerFactory _timer;

  static const lastSyncKey = 'last_sync';
  static const maxPages = 1000;

  late final SyncDao dao = SyncDao(db);
  late final MutationQueue queue = MutationQueue(db);
  late final PullApplier applier = PullApplier(db);
  late final ServerClock serverClock = ServerClock(clock, dao);

  final _phase = StreamController<SyncPhase>.broadcast();
  final _superseded = StreamController<int>.broadcast();
  SyncPhase _current = SyncPhase.idle;
  Future<void>? _running;
  bool _again = false;
  bool _disposed = false;
  Timer? _retry;
  Timer? _debounced;

  /// Consecutive failed runs (drives the backoff).
  int failures = 0;

  /// Last error code shown on "Sync & storage".
  String? lastError;

  SyncPhase get phase => _current;
  Stream<SyncPhase> get phases => _phase.stream;

  /// Count of local edits that lost to a newer server edit (one-time snackbar).
  Stream<int> get superseded => _superseded.stream;

  /// Runs push then pull; joins a running sync (and queues one more run).
  Future<void> sync() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  /// After a local write: sync once writes have been quiet for [debounce].
  void requestSync() {
    _debounced?.cancel();
    _debounced = _timer(debounce, () => unawaited(sync()));
  }

  /// Delay before retry number [n] (1-based): 2 s doubling up to 5 min, with 50–100 % jitter.
  Duration backoff(int n) {
    final ms = min(2000 * pow(2, min(n - 1, 20)).toInt(), 300000);
    return Duration(milliseconds: ms ~/ 2 + _random.nextInt(ms ~/ 2 + 1));
  }

  Future<void> _loop() async {
    do {
      _again = false;
      await _once();
    } while (_again && _current == SyncPhase.idle && !_disposed);
  }

  Future<void> _once() async {
    _retry?.cancel();
    _set(SyncPhase.syncing);
    try {
      try {
        await _pushThenPull();
      } on AuthExpiredException {
        await remote.refreshSession();
        await _pushThenPull();
      }
      failures = 0;
      lastError = null;
      await dao.setMeta(lastSyncKey, clock.now().toUtc().toIso8601String());
      _set(SyncPhase.idle);
    } on AuthExpiredException {
      lastError = 'AUTH_EXPIRED';
      _set(SyncPhase.signedOut);
      await onSignedOut?.call();
    } on NetworkException catch (e) {
      _fail(SyncPhase.offline, e.message);
    } on RemoteException catch (e) {
      _fail(SyncPhase.error, e.code);
    } on Exception catch (e) {
      _log.warning('sync failed: $e');
      _fail(SyncPhase.error, 'LOCAL_ERROR');
    }
  }

  void _fail(SyncPhase p, String code) {
    failures++;
    lastError = code;
    _set(p);
    if (_disposed) return;
    _retry = _timer(backoff(failures), () => unawaited(sync()));
  }

  Future<void> _pushThenPull() async {
    await push();
    await pull();
  }

  /// Sends queued mutations in order, 50 at a time.
  Future<void> push() async {
    await queue.resetInFlight();
    while (true) {
      final batch = await queue.nextBatch(batchSize);
      if (batch.isEmpty) return;
      await queue.markInFlight(batch);
      final ApplyResponse resp;
      try {
        resp = await remote.applyMutations([for (final i in batch) queue.toWire(i)]);
      } on Exception catch (e) {
        await queue.requeue(batch, '$e');
        rethrow;
      }
      await serverClock.measure(resp.serverTime);
      final byId = {for (final r in resp.results) r.mutationId: r};
      var lost = 0;
      await db.transaction(() async {
        for (final item in batch) {
          final r = byId[item.mutationId];
          switch (r?.status) {
            case null:
              await queue.requeue([item], 'NO_RESULT');
            case MutationStatus.applied || MutationStatus.duplicate:
              await queue.complete(item);
            case MutationStatus.superseded:
              lost++;
              await queue.complete(item);
            case MutationStatus.rejected:
              await queue.fail(item, r!.code ?? 'REJECTED');
          }
        }
      });
      if (lost > 0) _superseded.add(lost);
      if (batch.length < batchSize || byId.isEmpty) return;
    }
  }

  /// Pulls pages until `has_more` is false; each page is stored with its cursors in one transaction.
  Future<void> pull() async {
    for (var i = 0; i < maxPages; i++) {
      final page = await remote.pullChanges(
        cursors: await dao.groupCursors(),
        userSeq: await dao.userCursor(),
        pageSize: pageSize,
      );
      await serverClock.measure(page.serverTime);
      await applier.apply(page);
      if (!page.hasMore) return;
    }
  }

  void _set(SyncPhase p) {
    _current = p;
    if (!_phase.isClosed) _phase.add(p);
  }

  Future<void> dispose() async {
    _disposed = true;
    _retry?.cancel();
    _debounced?.cancel();
    await _phase.close();
    await _superseded.close();
  }
}
