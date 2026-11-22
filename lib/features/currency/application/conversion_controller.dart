import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/fx.dart';
import 'package:splitify/core/money/money.dart' show checkAmount;
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/fx_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/rules/recurrence.dart' show parseIsoDate;
import 'package:splitify/features/balances/application/balances_providers.dart'
    show ledgerRepositoryProvider;
import 'package:splitify/features/currency/application/conversion_actions.dart';
import 'package:splitify/features/currency/domain/conversion.dart';
import 'package:splitify/features/currency/domain/converted_balances.dart';
import 'package:splitify/features/currency/domain/fx_service.dart';

/// Which record the conversion sheet converts.
typedef ConversionArgs = ({String recordId, bool payment});

/// The record is not on this phone, or it is already in the group's main currency.
class ConversionNotPossible implements Exception {
  const ConversionNotPossible();
}

/// Why the typed rate can't be used.
enum RateProblem { invalid, tooLarge }

/// The conversion sheet (#32, T5): the record, the automatic rate (or why there is none), what is typed.
final class ConversionDraft {
  const ConversionDraft({
    required this.groupId,
    required this.record,
    required this.to,
    required this.order,
    required this.lookup,
    required this.rateText,
    this.saved,
    this.manual = false,
  });

  final String groupId;
  final FxRecord record;

  /// Target (the group's main currency).
  final String to;

  /// Members in fixed order (re-allocation of parts).
  final List<String> order;

  /// The cached Frankfurter rate for the record date, or why there is none.
  final FxLookup lookup;

  /// The rate field ("1 [from] = rateText [to]").
  final String rateText;

  /// The conversion saved on the record now (to [to] or another currency).
  final SavedFx? saved;

  /// The rate was typed (source `manual`), not taken from [lookup].
  final bool manual;

  String get from => record.currency;

  /// Date-only UTC of the record.
  DateTime get date => parseIsoDate(record.date);

  FxRate? get autoRate => switch (lookup) {
    FxRateFound(:final rate) => rate,
    FxNeedsManualRate() => null,
  };

  /// The rate the sheet would save, or null while the typed text is not a rate.
  FxRate? get rate {
    final auto = autoRate;
    if (!manual && auto != null) return auto;
    try {
      return FxService(const _NoRates()).manualRate(from, to, date, rateText);
    } on MoneyError {
      return null;
    }
  }

  /// Converted total (expense) or amount (payment) at [rate].
  int? get converted {
    final r = rate;
    if (r == null) return null;
    try {
      final c = convert(record.amount, from, to, r.rate);
      checkAmount(c);
      return c;
    } on MoneyError {
      return null;
    }
  }

  RateProblem? get problem {
    if (rate == null) return RateProblem.invalid;
    if (converted == null) return RateProblem.tooLarge;
    return null;
  }

  bool get canSave => problem == null;

  /// The saved conversion is to [to] (so "Remove conversion" applies).
  bool get hasSaved => saved != null && saved!.currency == to;

  ConversionDraft copyWith({FxLookup? lookup, String? rateText, bool? manual}) => ConversionDraft(
    groupId: groupId,
    record: record,
    to: to,
    order: order,
    lookup: lookup ?? this.lookup,
    rateText: rateText ?? this.rateText,
    saved: saved,
    manual: manual ?? this.manual,
  );
}

/// Rate text as it starts in the field: the canonical decimal (`89.643714233`), no trailing zeros.
String rateFieldText(String rate) {
  try {
    return parseRate(rate).toString();
  } on MoneyError {
    return rate;
  }
}

Duration? _noRetry(int retryCount, Object error) => null;

final conversionProvider = AsyncNotifierProvider.autoDispose
    .family<ConversionController, ConversionDraft, ConversionArgs>(
      ConversionController.new,
      retry: _noRetry,
    );

/// Loads the record and the cached rate for its date, lets the person keep or type the rate, saves.
class ConversionController extends AsyncNotifier<ConversionDraft> {
  ConversionController(this.args);

  final ConversionArgs args;

  @override
  Future<ConversionDraft> build() async {
    final ledgers = ref.read(ledgerRepositoryProvider);
    final LocalExpense? expense;
    final LocalPayment? payment;
    if (args.payment) {
      expense = null;
      payment = await ledgers.watchPayment(args.recordId).first;
    } else {
      payment = null;
      expense = await ref.read(expensesRepositoryProvider).watchOne(args.recordId).first;
    }
    final groupId = expense?.groupId ?? payment?.groupId;
    if (groupId == null || (expense?.deletedAt ?? payment?.deletedAt) != null) {
      throw const ConversionNotPossible();
    }
    final ledger = await ledgers.loadGroup(groupId);
    if (ledger == null) throw const ConversionNotPossible();
    final record = expense != null ? fxRecordOfExpense(expense) : fxRecordOfPayment(payment!);
    final to = ledger.group.mainCurrency.trim();
    if (record.currency == to) throw const ConversionNotPossible();
    final saved = expense != null ? savedFxOfExpense(expense) : savedFxOfPayment(payment!);
    final lookup = await ref.read(fxServiceProvider).rate(record.currency, to, record.dateUtc);
    final savedHere = saved != null && saved.currency == to ? saved : null;
    final auto = lookup is FxRateFound ? lookup.rate : null;
    final manual = savedHere != null
        ? savedHere.source == FxSource.manual || auto == null || auto.rate != savedHere.rate
        : auto == null;
    final draft = ConversionDraft(
      groupId: groupId,
      record: record,
      to: to,
      order: [for (final m in ledger.members) m.id],
      lookup: lookup,
      rateText: rateFieldText(savedHere?.rate ?? auto?.rate ?? ''),
      saved: saved,
      manual: manual,
    );
    if (auto == null && lookup is FxNeedsManualRate && lookup.reason == FxMissingReason.noRates) {
      unawaited(_fetchMissing(draft));
    }
    return draft;
  }

  /// Online, the server may have the days the cache lacks: fetch them and offer the rate.
  Future<void> _fetchMissing(ConversionDraft d) async {
    final rates = ref.read(fxRatesRepositoryProvider);
    await rates.ensureFor({d.from, d.to}, d.date);
    final lookup = await ref.read(fxServiceProvider).rate(d.from, d.to, d.date);
    if (!ref.mounted || lookup is! FxRateFound) return;
    final now = state.value;
    if (now == null) return;
    final untouched = now.rateText.trim().isEmpty && now.saved == null;
    state = AsyncData(
      untouched
          ? now.copyWith(lookup: lookup, rateText: rateFieldText(lookup.rate.rate), manual: false)
          : now.copyWith(lookup: lookup),
    );
  }

  void _set(ConversionDraft Function(ConversionDraft d) f) {
    final d = state.value;
    if (d != null) state = AsyncData(f(d));
  }

  /// The person typed a rate: it becomes a manual rate unless it is exactly the automatic one.
  void setRateText(String text) => _set((d) {
    final auto = d.autoRate;
    final same = auto != null && rateFieldText(text.trim()) == rateFieldText(auto.rate);
    return d.copyWith(rateText: text, manual: !same);
  });

  /// Back to the Frankfurter rate.
  void useAuto() => _set((d) {
    final auto = d.autoRate;
    return auto == null ? d : d.copyWith(rateText: rateFieldText(auto.rate), manual: false);
  });

  /// Saves the conversion (offline-first); false when the draft can't be saved.
  Future<bool> save() async {
    final d = state.value;
    final r = d?.rate;
    if (d == null || r == null || !d.canSave) return false;
    await ref.read(conversionActionsProvider).save(d.groupId, d.record, r, d.order);
    return true;
  }

  /// Removes the saved conversion.
  Future<void> remove() async {
    final d = state.value;
    if (d == null || d.saved == null) return;
    await ref.read(conversionActionsProvider).remove(d.groupId, d.record);
  }
}

extension on FxRecord {
  DateTime get dateUtc => parseIsoDate(date);
}

/// [FxService.manualRate] reads no cache.
final class _NoRates implements RatesSource {
  const _NoRates();

  @override
  Future<List<EurRate>> ratesOnOrBefore(Set<String> currencies, DateTime date) async => const [];
}
