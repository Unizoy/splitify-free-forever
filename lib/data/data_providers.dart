import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/sync_engine.dart';

/// The local database, opened lazily on first use (`splitify.sqlite` in app documents). Tests override with
/// `AppDatabase(NativeDatabase.memory())`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'splitify'));
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final e = SyncEngine(
    db: ref.watch(appDatabaseProvider),
    remote: ref.watch(remoteApiProvider),
    clock: ref.watch(clockProvider),
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
