import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/data/repositories/repositories.dart' as repos;
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/domain/balance_check.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';

final _log = Logger('balances');

/// Local reads for balances, totals and payments.
final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => LedgerRepository(ref.watch(appDatabaseProvider)),
);

/// One group's ledger from the phone's database (null when the group is not here).
final groupLedgerProvider = StreamProvider.autoDispose.family<GroupLedger?, String>(
  (ref, groupId) => ref.watch(ledgerRepositoryProvider).watchGroup(groupId),
);

/// Every live group's ledger.
final allLedgersProvider = StreamProvider.autoDispose<List<GroupLedger>>(
  (ref) => ref.watch(ledgerRepositoryProvider).watchAll(),
);

/// End of the last successful sync; the server checks run again after every sync.
final lastSyncProvider = Provider<DateTime?>(
  (ref) => ref.watch(syncStatusProvider.select((s) => s.value?.lastSync)),
);

/// The server's balances of a group compared with the phone's (T3, TC-15-04).
class GroupCheck {
  const GroupCheck({
    required this.server,
    required this.localChecksum,
    required this.serverChecksum,
  });

  final ServerGroupBalances server;
  final int localChecksum;
  final int serverChecksum;

  bool get matches => localChecksum == serverChecksum;
}

/// `my_overview` compared with the phone's overall balances.
class OverviewCheck {
  const OverviewCheck({required this.server, required this.differences});

  final ServerOverview server;

  /// Groups whose balance differs.
  final List<String> differences;

  bool get matches => differences.isEmpty;
}

/// After a sync, compares the phone's balances with the server's (05 §5 "Server vs phone"). Skips
/// while anything is unsynced (the numbers would differ on purpose) or offline; a difference is a bug:
/// it is logged (sync diagnostics, "Export debug log") and the server's numbers are shown.
class BalanceChecker {
  BalanceChecker(this._ref);

  final Ref _ref;

  LedgerRepository get _ledgers => _ref.read(ledgerRepositoryProvider);
  BalancesRemote get _remote => _ref.read(balancesRemoteProvider);

  Future<GroupCheck?> checkGroup(String groupId) async {
    final db = _ref.read(appDatabaseProvider);
    if (await repos.watchGroupUnsynced(db, groupId).first) return null;
    final ledger = await _ledgers.loadGroup(groupId);
    if (ledger == null) return null;
    final ServerGroupBalances server;
    try {
      server = await _remote.groupBalances(groupId);
    } on Exception catch (e) {
      _log.fine('group $groupId: server balances not checked (${e.runtimeType})');
      return null;
    }
    final local = groupBalancesOf(ledger, _ref.read(currentUserIdProvider));
    final check = GroupCheck(
      server: server,
      localChecksum: balancesChecksum(local.byCurrency),
      serverChecksum: balancesChecksum(server.currencies),
    );
    if (check.matches) {
      _log.fine('group $groupId: balances match (${checksumText(check.localChecksum)})');
    } else {
      _log.warning(
        'group $groupId: balances differ, local ${checksumText(check.localChecksum)} '
        '!= server ${checksumText(check.serverChecksum)}; showing the server balances',
      );
    }
    return check;
  }

  Future<OverviewCheck?> checkOverview() async {
    if (await _ref.read(syncRepositoryProvider).watchAnyUnsynced().first) return null;
    final ServerOverview server;
    try {
      server = await _remote.myOverview();
    } on Exception catch (e) {
      _log.fine('overview not checked (${e.runtimeType})');
      return null;
    }
    final uid = _ref.read(currentUserIdProvider);
    final local = myBalancesOf([for (final l in await _ledgers.loadAll()) groupBalancesOf(l, uid)]);
    final check = OverviewCheck(
      server: server,
      differences: overviewDifferences(local.byGroup, {
        for (final g in server.groups) g.groupId: g.balances,
      }),
    );
    if (!check.matches) {
      _log.warning(
        'overview: groups ${check.differences.join(',')} differ from the server; showing the '
        'server balances',
      );
    }
    return check;
  }
}

final balanceCheckerProvider = Provider<BalanceChecker>(BalanceChecker.new);

/// The group check after the latest sync (null before the first sync, offline or while unsynced).
final groupCheckProvider = FutureProvider.autoDispose.family<GroupCheck?, String>((ref, id) {
  if (ref.watch(lastSyncProvider) == null) return Future.value();
  return ref.read(balanceCheckerProvider).checkGroup(id);
});

/// The overview check after the latest sync.
final overviewCheckProvider = FutureProvider.autoDispose<OverviewCheck?>((ref) {
  if (ref.watch(lastSyncProvider) == null) return Future.value();
  return ref.read(balanceCheckerProvider).checkOverview();
});

AsyncValue<T>? _notReady<T>(AsyncValue<Object?> v) {
  if (v.hasError && !v.hasValue) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
  if (!v.hasValue) return AsyncLoading<T>();
  return null;
}

/// Balances of one group (Balances tab, status pill, settle up): local and instant, marked unsynced
/// while rows are pending; the server's numbers when the after-sync check found a difference.
final groupBalancesProvider = Provider.autoDispose.family<AsyncValue<GroupBalances?>, String>((
  ref,
  groupId,
) {
  final ledger = ref.watch(groupLedgerProvider(groupId));
  final wait = _notReady<GroupBalances?>(ledger);
  if (wait != null) return wait;
  final l = ledger.value;
  if (l == null) return const AsyncData(null);
  final local = groupBalancesOf(l, ref.watch(currentUserIdProvider));
  if (ref.watch(groupUnsyncedProvider(groupId)).value ?? false) {
    return AsyncData(local.copyWith(unsynced: true));
  }
  final check = ref.watch(groupCheckProvider(groupId)).value;
  if (check != null && !check.matches) return AsyncData(local.withServer(check.server));
  return AsyncData(local);
});

/// Local balances of every live group (Groups home cards, settle-up picker, wallet breakdown).
final allGroupBalancesProvider = Provider.autoDispose<AsyncValue<List<GroupBalances>>>((ref) {
  final ledgers = ref.watch(allLedgersProvider);
  final wait = _notReady<List<GroupBalances>>(ledgers);
  if (wait != null) return wait;
  final uid = ref.watch(currentUserIdProvider);
  return AsyncData([for (final l in ledgers.requireValue) groupBalancesOf(l, uid)]);
});

/// My overall balances (T6): local, with the "not synced yet" mark while anything is pending; the
/// server's `my_overview` when the after-sync check found a difference.
final myBalancesProvider = Provider.autoDispose<AsyncValue<MyBalances>>((ref) {
  final all = ref.watch(allGroupBalancesProvider);
  final wait = _notReady<MyBalances>(all);
  if (wait != null) return wait;
  final local = myBalancesOf(all.requireValue);
  if (ref.watch(anyUnsyncedProvider).value ?? false) {
    return AsyncData(local.copyWith(unsynced: true));
  }
  final check = ref.watch(overviewCheckProvider).value;
  if (check != null && !check.matches) return AsyncData(MyBalances.fromServer(check.server));
  return AsyncData(local);
});
