import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/sync/sync_engine.dart';

/// Sync engine stand-in for screens inside the signed-in shell: `SyncBinding` starts a sync at launch and
/// the real engine would open the on-disk database (no path_provider in tests). Counts syncs.
class QuietSyncEngine implements SyncEngine {
  int syncs = 0;

  @override
  Future<void> sync() async => syncs++;

  @override
  Stream<int> get superseded => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
