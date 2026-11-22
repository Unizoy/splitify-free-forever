// Phase 15 (04 §7, S-160): a second 401 after one refresh signs out through sessionExpiredProvider.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/sync/sync_types.dart';

import 'sync_fakes.dart';

class _AlwaysExpired extends FakeRemoteApi {
  @override
  Future<ApplyResponse> applyMutations(List<Map<String, Object?>> batch) async =>
      throw const AuthExpiredException();

  @override
  Future<PullPage> pullChanges({
    required Map<String, int> cursors,
    required int userSeq,
    int pageSize = 500,
  }) async => throw const AuthExpiredException();
}

void main() {
  test('401 after the refresh: signed-out phase and the hook runs exactly once', () async {
    final db = memoryDb();
    final remote = _AlwaysExpired();
    var expired = 0;
    final container = ProviderContainer(
      overrides: [
        remoteApiProvider.overrideWithValue(remote),
        appDatabaseProvider.overrideWithValue(db),
        sessionExpiredProvider.overrideWithValue(() async => expired++),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final engine = container.read(syncEngineProvider);
    await engine.sync();
    expect(remote.refreshes, 1);
    expect(expired, 1);
    expect(engine.phase, SyncPhase.signedOut);
    expect(engine.lastError, 'AUTH_EXPIRED');
  });

  test('a 401 that the refresh fixes does not sign out', () async {
    final db = memoryDb();
    final remote = FakeRemoteApi()..pullScript.add((_, _) => const AuthExpiredException());
    var expired = 0;
    final container = ProviderContainer(
      overrides: [
        remoteApiProvider.overrideWithValue(remote),
        appDatabaseProvider.overrideWithValue(db),
        sessionExpiredProvider.overrideWithValue(() async => expired++),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final engine = container.read(syncEngineProvider);
    await engine.sync();
    expect(remote.refreshes, 1);
    expect(expired, 0);
    expect(engine.phase, SyncPhase.idle);
  });
}
