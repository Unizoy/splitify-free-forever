import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/fx_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/domain/rules/recurrence.dart' show parseIsoDate;
import 'package:splitify/features/balances/application/balances_providers.dart'
    show ledgerRepositoryProvider;
import 'package:splitify/features/currency/domain/conversion.dart';
import 'package:splitify/features/currency/domain/converted_balances.dart';
import 'package:splitify/features/currency/domain/fx_service.dart';

final _log = Logger('fx');

/// What "Convert all" did.
typedef ConvertAllResult = ({int converted, int needRate});

/// [FxRecord] of a live expense row.
FxRecord fxRecordOfExpense(LocalExpense e) => FxRecord.expense(
  id: e.id,
  date: e.date.length > 10 ? e.date.substring(0, 10) : e.date,
  currency: e.currency.trim(),
  amount: e.total,
  description: e.description,
  paid: _minor(e.payers),
  shares: _minor(e.shares),
  fxCurrency: e.fxCurrency?.trim(),
  fxAmount: e.fxTotal,
  fxPaid: e.fxPayers == null ? null : _minor(e.fxPayers),
  fxShares: e.fxShares == null ? null : _minor(e.fxShares),
);

/// [FxRecord] of a live payment row.
FxRecord fxRecordOfPayment(LocalPayment p) => FxRecord.payment(
  id: p.id,
  date: p.date.length > 10 ? p.date.substring(0, 10) : p.date,
  currency: p.currency.trim(),
  amount: p.amount,
  from: p.fromMember,
  to: p.toMember,
  fxCurrency: p.fxCurrency?.trim(),
  fxAmount: p.fxAmount,
);

/// Every live record of [ledger] as [FxRecord]s.
List<FxRecord> fxRecordsOf(GroupLedger ledger) => [
  for (final e in ledger.expenses) fxRecordOfExpense(e),
  for (final p in ledger.payments) fxRecordOfPayment(p),
];

/// The saved conversion of an expense row (null when none).
SavedFx? savedFxOfExpense(LocalExpense e) => SavedFx.tryRead(
  rate: e.fxRate,
  rateDate: e.fxRateDate,
  source: e.fxSource,
  currency: e.fxCurrency,
  total: e.fxTotal,
);

/// The saved conversion of a payment row (null when none).
SavedFx? savedFxOfPayment(LocalPayment p) => SavedFx.tryRead(
  rate: p.fxRate,
  rateDate: p.fxRateDate,
  source: p.fxSource,
  currency: p.fxCurrency,
  total: p.fxAmount,
);

/// Saves and removes conversions (through the repositories → outbox, offline-first) and runs
/// "Convert all at their dates' rates" (#32).
class ConversionActions {
  ConversionActions(this._ref);

  final Ref _ref;

  /// Saves [rate] on [record] (an expense or payment in `rate.from`). Throws the money engine's errors.
  Future<void> save(String groupId, FxRecord record, FxRate rate, List<String> order) async {
    if (record.isPayment) {
      await _ref
          .read(paymentsRepositoryProvider)
          .save(groupId, paymentFxColumns(amount: record.amount, rate: rate), id: record.id);
    } else {
      await _ref
          .read(expensesRepositoryProvider)
          .save(
            groupId,
            expenseFxColumns(
              total: record.amount,
              paid: record.paid!,
              shares: record.shares!,
              order: order,
              rate: rate,
            ),
            id: record.id,
          );
    }
  }

  /// Removes the saved conversion of [record].
  Future<void> remove(String groupId, FxRecord record) => record.isPayment
      ? _ref.read(paymentsRepositoryProvider).save(groupId, clearedPaymentFx, id: record.id)
      : _ref.read(expensesRepositoryProvider).save(groupId, clearedExpenseFx, id: record.id);

  /// Converts every record of [groupId] that has no saved conversion to the main currency at the rate of
  /// its own date (cached rates; missing days are fetched when online). Records without a rate are left for
  /// the person to type one.
  Future<ConvertAllResult> convertAll(String groupId) async {
    final ledger = await _ref.read(ledgerRepositoryProvider).loadGroup(groupId);
    if (ledger == null) return (converted: 0, needRate: 0);
    final main = ledger.group.mainCurrency.trim();
    final order = [for (final m in ledger.members) m.id];
    final missing = convertedBalances(main, order, fxRecordsOf(ledger)).missing;
    if (missing.isEmpty) return (converted: 0, needRate: 0);
    final rates = _ref.read(fxRatesRepositoryProvider);
    final fx = _ref.read(fxServiceProvider);
    await rates.refresh();
    var converted = 0;
    var needRate = 0;
    for (final r in missing) {
      try {
        final date = parseIsoDate(r.date);
        await rates.ensureFor({r.currency, main}, date);
        final lookup = await fx.rate(r.currency, main, date);
        if (lookup is FxRateFound) {
          await save(groupId, r, lookup.rate, order);
          converted++;
        } else {
          needRate++;
        }
      } on Exception catch (e) {
        _log.warning('record ${r.id} not converted: ${e.runtimeType}');
        needRate++;
      }
    }
    return (converted: converted, needRate: needRate);
  }
}

final conversionActionsProvider = Provider<ConversionActions>(ConversionActions.new);

Map<String, int> _minor(String? json) {
  if (json == null) return const {};
  final m = jsonDecode(json) as Map<String, Object?>;
  return {for (final e in m.entries) e.key: (e.value! as num).toInt()};
}
