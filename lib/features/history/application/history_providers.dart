import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/expense_reads.dart';
import 'package:splitify/data/repositories/history_repository.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show currentUserIdProvider;
import 'package:splitify/features/history/domain/version_diff.dart';

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(appDatabaseProvider), ref.watch(historyRemoteProvider)),
);

/// Which record's history (route `/expense/:id/history` or `/payment/:id/history`).
typedef HistoryTarget = ({HistoryRecordKind kind, String id});

/// The record as stored on this phone (deleted ones too).
typedef HistoryRecordRow = ({
  String groupId,
  int seq,
  bool pending,
  LocalExpense? expense,
  LocalPayment? payment,
});

/// The expense or payment whose history is shown; data(null) when it is not on this phone.
final historyRecordProvider = StreamProvider.autoDispose.family<HistoryRecordRow?, HistoryTarget>((
  ref,
  t,
) {
  bool pending(String state) => state != SyncState.synced;
  return switch (t.kind) {
    HistoryRecordKind.expense =>
      ref
          .watch(expensesRepositoryProvider)
          .watchOne(t.id)
          .map(
            (e) => e == null
                ? null
                : (
                    groupId: e.groupId,
                    seq: e.seq,
                    pending: pending(e.syncState),
                    expense: e,
                    payment: null,
                  ),
          ),
    HistoryRecordKind.payment =>
      ref
          .watch(paymentsRepositoryProvider)
          .watchPayment(t.id)
          .map(
            (p) => p == null
                ? null
                : (
                    groupId: p.groupId,
                    seq: p.seq,
                    pending: pending(p.syncState),
                    expense: null,
                    payment: p,
                  ),
          ),
  };
});

/// Fetches versions newer than the cache when the screen opens and again whenever the record's `seq` moves
/// (a pull brought a new edit). Errors (offline) are shown, never retried automatically.
final historyFetchProvider = FutureProvider.autoDispose.family<int, HistoryTarget>((ref, t) async {
  final seq = ref.watch(historyRecordProvider(t).select((r) => r.value?.seq));
  if (seq == null) return 0; // not loaded yet, or not on this phone
  return ref.watch(historyRepositoryProvider).refresh(t.id);
}, retry: (_, _) => null);

final _versionsProvider = StreamProvider.autoDispose.family<List<LocalVersion>, String>(
  (ref, id) => ref.watch(historyRepositoryProvider).watch(id),
);

final _membersProvider = StreamProvider.autoDispose.family<List<LocalMember>, String>(
  (ref, groupId) => ref.watch(expensesRepositoryProvider).watchAllMembers(groupId),
);

/// What the history screen shows.
final class HistoryView {
  const HistoryView({
    required this.target,
    required this.record,
    required this.entries,
    required this.memberNames,
    required this.userNames,
    this.meUserId,
    this.meMemberId,
  });

  final HistoryTarget target;
  final HistoryRecordRow record;

  /// Timeline, newest first.
  final List<HistoryEntry> entries;

  /// Display names by member id (removed members too).
  final Map<String, String> memberNames;

  /// Display names by account id (who made each change).
  final Map<String, String> userNames;

  final String? meUserId;
  final String? meMemberId;
}

/// Cached row → diff-builder input.
VersionRecord versionRecordOf(LocalVersion v) => VersionRecord(
  seq: v.seq,
  op: v.op,
  snapshot: (jsonDecode(v.snapshot) as Map).cast<String, Object?>(),
  changedAt: DateTime.parse(v.changedAt).toUtc(),
  changedBy: v.changedBy,
);

/// The history screen's data; data(null) when the record is not on this phone.
final historyViewProvider = Provider.autoDispose.family<AsyncValue<HistoryView?>, HistoryTarget>((
  ref,
  t,
) {
  final record = ref.watch(historyRecordProvider(t));
  if (!record.hasValue) {
    return record.hasError ? AsyncError(record.error!, record.stackTrace!) : const AsyncLoading();
  }
  final r = record.value;
  if (r == null) return const AsyncData(null);
  final versions = ref.watch(_versionsProvider(t.id));
  final members = ref.watch(_membersProvider(r.groupId));
  for (final v in [versions, members]) {
    if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
  }
  if (!versions.hasValue || !members.hasValue) return const AsyncLoading();
  final uid = ref.watch(currentUserIdProvider);
  final m = members.requireValue;
  return AsyncData(
    HistoryView(
      target: t,
      record: r,
      entries: buildHistory(t.kind, [
        for (final v in versions.requireValue) versionRecordOf(v),
      ]).reversed.toList(),
      memberNames: {for (final x in m) x.id: x.displayName},
      userNames: {
        for (final x in m)
          if (x.userId != null) x.userId!: x.displayName,
      },
      meUserId: uid,
      meMemberId: m
          .where((x) => uid != null && x.userId == uid && x.deletedAt == null)
          .map((x) => x.id)
          .firstOrNull,
    ),
  );
});
