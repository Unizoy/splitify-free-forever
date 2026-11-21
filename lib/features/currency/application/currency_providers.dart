import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/fx_providers.dart';
import 'package:splitify/data/repositories/currency_reads.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/currency/application/conversion_actions.dart';
import 'package:splitify/features/currency/domain/converted_balances.dart';
import 'package:splitify/features/groups/application/groups_providers.dart' show currentUserIdProvider;

/// Keeps the exchange-rate cache fresh: refreshes after every successful sync (the repository skips pulls
/// younger than 6 h), so conversions work offline later (05 §6). Watched by the signed-in shell.
final fxAutoRefreshProvider = Provider<void>((ref) {
  ref.listen<DateTime?>(lastSyncProvider, (_, next) {
    if (next != null) unawaited(ref.read(fxRatesRepositoryProvider).refresh());
  }, fireImmediately: true);
});

final currencyReadsProvider = Provider<CurrencyReads>(
  (ref) => CurrencyReads(ref.watch(appDatabaseProvider)),
);

/// Recently used currencies on this phone, newest first (currency picker "Recent").
final recentCurrenciesProvider = StreamProvider.autoDispose<List<String>>(
  (ref) => ref.watch(currencyReadsProvider).watchRecent(),
);

/// One group's balances in its main currency (#32 "Show balances in INR") next to its normal balances
/// (names, me, simplify setting).
class ConvertedGroupView {
  const ConvertedGroupView({required this.group, required this.converted, required this.records});

  /// The group's normal (per-currency) balances: members, me, main currency, simplify.
  final GroupBalances group;
  final ConvertedBalances converted;

  /// Every live record by id (the missing list opens the conversion sheet on one).
  final Map<String, FxRecord> records;

  String get currency => converted.currency;

  /// The group has a record in a currency other than its main one (the converted view is worth offering).
  bool get hasForeign => records.values.any((r) => r.currency != currency);
}

/// The converted view of [groupId] (null while the group is not on this phone).
final convertedGroupProvider = Provider.autoDispose.family<AsyncValue<ConvertedGroupView?>, String>((
  ref,
  groupId,
) {
  final ledger = ref.watch(groupLedgerProvider(groupId));
  if (!ledger.hasValue) {
    if (ledger.hasError) return AsyncError(ledger.error!, ledger.stackTrace ?? StackTrace.current);
    return const AsyncLoading();
  }
  final l = ledger.value;
  if (l == null) return const AsyncData(null);
  final group = groupBalancesOf(l, ref.watch(currentUserIdProvider));
  final records = fxRecordsOf(l);
  return AsyncData(
    ConvertedGroupView(
      group: group,
      converted: convertedBalances(group.mainCurrency, [for (final m in l.members) m.id], records),
      records: {for (final r in records) r.id: r},
    ),
  );
});
