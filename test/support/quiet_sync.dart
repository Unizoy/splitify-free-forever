import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/sync/sync_engine.dart';

import 'fakes.dart' show testDb;

/// Sync engine stand-in for screens inside the signed-in shell: `SyncBinding` starts a sync at launch and
/// the real engine would open the on-disk database (no path_provider in tests). Its own in-memory database
/// keeps status, owner and sign-out calls working; sync and push only count.
class QuietSyncEngine extends SyncEngine {
  QuietSyncEngine()
    : super(db: testDb(), remote: const UnconfiguredRemoteApi(), clock: const SystemClock());

  int syncs = 0;

  @override
  Future<void> sync() async => syncs++;

  @override
  Future<void> push() async {}
}

/// No groups for `SyncBinding`'s Realtime topics.
class QuietGroupsRepository implements GroupsRepository {
  @override
  Stream<List<LocalGroup>> watchAll() => Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Keeps `SyncBinding` off the real database and engine.
List<Override> quietSyncOverrides() => [
  syncEngineProvider.overrideWithValue(QuietSyncEngine()),
  groupsRepositoryProvider.overrideWithValue(QuietGroupsRepository()),
];
