import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/recurring_repository.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/repositories/search_repository.dart';
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/data/sync/background_sync.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/network_status.dart';
import 'package:splitify/data/sync/sync_engine.dart';

/// The local database, opened lazily on first use (`splitify.sqlite` in app documents). Tests override with
/// `AppDatabase(NativeDatabase.memory())`. Shared across isolates so a WorkManager run in the same process
/// uses the app's connection (04 §8).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(
    driftDatabase(name: 'splitify', native: const DriftNativeOptions(shareAcrossIsolates: true)),
  );
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Network up/down (connectivity_plus). Bootstrap overrides it; widget tests assume online.
final networkStatusProvider = Provider<NetworkStatus>((ref) => const AssumeOnlineNetworkStatus());

/// WorkManager jobs (04 §8). Bootstrap overrides it once the plugin is initialised.
final backgroundSyncProvider = Provider<BackgroundSync>((ref) => const NoBackgroundSync());

/// Runs when the server still says 401 after one session refresh (04 §7): sign out **without** wiping the
/// phone, so the same person signing in again resumes sync. Bootstrap wires it to the auth repository.
final sessionExpiredProvider = Provider<Future<void> Function()>((ref) => () async {});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final e = SyncEngine(
    db: ref.watch(appDatabaseProvider),
    remote: ref.watch(remoteApiProvider),
    clock: ref.watch(clockProvider),
    onSignedOut: () => ref.read(sessionExpiredProvider)(),
    afterPush: () async {
      await ref.read(uploadQueueProvider).run();
    },
  );
  ref.onDispose(e.dispose);
  return e;
});

final localWriterProvider = Provider<LocalWriter>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return LocalWriter(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    engine.serverClock,
    onWrite: engine.requestSync,
  );
});

final groupsRepositoryProvider = Provider<GroupsRepository>(
  (ref) => GroupsRepository(ref.watch(appDatabaseProvider), ref.watch(localWriterProvider)),
);
final membersRepositoryProvider = Provider<MembersRepository>(
  (ref) => MembersRepository(ref.watch(appDatabaseProvider), ref.watch(localWriterProvider)),
);
final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => ExpensesRepository(ref.watch(appDatabaseProvider), ref.watch(localWriterProvider)),
);
final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(ref.watch(appDatabaseProvider), ref.watch(localWriterProvider)),
);
final commentsRepositoryProvider = Provider<CommentsRepository>(
  (ref) => CommentsRepository(ref.watch(appDatabaseProvider), ref.watch(localWriterProvider)),
);

/// Repeating expenses (#12), written through the outbox.
final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(ref.watch(appDatabaseProvider), ref.watch(localWriterProvider)),
);

/// Offline search (#34).
final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(appDatabaseProvider)),
);

/// Sync state and actions ("Sync & storage", markers, sign-out flush).
final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => SyncRepository(ref.watch(syncEngineProvider)),
);

/// Engine phase, last sync and outbox counts (04 §9).
final syncStatusProvider = StreamProvider<SyncStatus>(
  (ref) => ref.watch(syncRepositoryProvider).watchStatus(),
);

/// Changes the server refused, oldest first.
final syncIssuesProvider = StreamProvider<List<SyncIssue>>(
  (ref) => ref.watch(syncRepositoryProvider).watchIssues(),
);

/// Photos waiting to go up (Sync & storage, S-113/S-114).
final syncUploadsProvider = StreamProvider<List<SyncUpload>>(
  (ref) => ref.watch(syncRepositoryProvider).watchUploads(),
);

/// Groups with a row not on the server yet (Groups home cards).
final unsyncedGroupIdsProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(syncRepositoryProvider).watchUnsyncedGroupIds(),
);

/// True while anything on this phone is not on the server yet: overall balances show the `SyncMarker`.
final anyUnsyncedProvider = StreamProvider<bool>(
  (ref) => ref.watch(syncRepositoryProvider).watchAnyUnsynced(),
);

/// True while a row of the group is not on the server yet: group cards and balances show the `SyncMarker`.
final groupUnsyncedProvider = StreamProvider.family<bool, String>(
  (ref, groupId) => ref.watch(syncRepositoryProvider).watchGroupUnsynced(groupId),
);
