import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show currentUserIdProvider;

import '../../../data/sync/sync_fakes.dart' show FakeClock, FakeRemoteApi;
import '../../../support/fakes.dart' show testDb;
import '../../../support/history_data_fakes.dart';

/// In-memory database + container for the history / deleted-items / comments providers. Group `g1` has
/// members `m1` = Mohit (user `u1`), `m2` = Asha (user `u2`) and `m3` = Ravi (name only).
class HistoryEnv {
  HistoryEnv._(this.db, this.history, this.remote, this.clock, this.container);

  final AppDatabase db;
  final FakeHistoryRemote history;
  final FakeRemoteApi remote;
  final FakeClock clock;
  final ProviderContainer container;

  static Future<HistoryEnv> create({String? userId = 'u1', bool members = true}) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = testDb();
    final history = FakeHistoryRemote();
    final remote = FakeRemoteApi();
    final clock = FakeClock(DateTime.utc(2026, 11, 22, 9));
    final container = ProviderContainer(
      // Riverpod 3 retries failed builds; tests want the first error.
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        historyRemoteProvider.overrideWithValue(history),
        remoteApiProvider.overrideWithValue(remote),
        clockProvider.overrideWithValue(clock),
        currentUserIdProvider.overrideWithValue(userId),
      ],
    );
    final env = HistoryEnv._(db, history, remote, clock, container);
    if (members) {
      await putRow(db, 'group_members', memberRow('m1', userId: 'u1', name: 'Mohit'));
      await putRow(db, 'group_members', memberRow('m2', userId: 'u2', name: 'Asha', position: 1));
      await putRow(db, 'group_members', memberRow('m3', name: 'Ravi', position: 2));
    }
    return env;
  }

  /// Keeps an autoDispose provider alive (Riverpod 3 pauses unlistened ones) and returns its subscription.
  ProviderSubscription<T> keep<T>(ProviderListenable<T> p) => container.listen<T>(p, (_, _) {});

  void dispose() {
    container.dispose();
    unawaited(db.close());
  }
}
