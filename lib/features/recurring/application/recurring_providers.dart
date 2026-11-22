import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/rules/recurrence.dart';
import 'package:splitify/l10n/app_localizations.dart';

/// Which expense a repeat rule is looked up for (the copy's `recurring_id`, if any).
typedef RecurringLookup = ({String expenseId, String? recurringId});

/// The template behind an expense: the one it was started from or the one that made it (#12).
final expenseRecurringProvider = StreamProvider.autoDispose
    .family<LocalRecurring?, RecurringLookup>(
      (ref, key) => ref
          .watch(recurringRepositoryProvider)
          .watchForExpense(key.expenseId, recurringId: key.recurringId),
    );

/// One template (the editor's "Edit future copies").
final recurringTemplateProvider = StreamProvider.autoDispose.family<LocalRecurring?, String>(
  (ref, id) => ref.watch(recurringRepositoryProvider).watchOne(id),
);

/// Stop / repeat again, through the outbox.
final recurringActionsProvider = Provider<RecurringActions>(RecurringActions.new);

class RecurringActions {
  RecurringActions(this._ref);

  final Ref _ref;

  Future<void> stop(LocalRecurring t) => _ref.read(recurringRepositoryProvider).stop(t);

  Future<void> resume(LocalRecurring t) => _ref.read(recurringRepositoryProvider).resume(t);
}

/// What a template shows: its rule, the next copy, whether it still repeats and is synced.
extension RecurringView on LocalRecurring {
  RecurrenceInterval get repeatInterval => RecurrenceInterval.parse(interval);

  /// Next copy date (server value, or the phone's guess while pending); null when none is left.
  DateTime? get nextCopy => nextDate == null ? null : parseIsoDate(nextDate!.substring(0, 10));

  DateTime? get endDate => endsOn == null ? null : parseIsoDate(endsOn!.substring(0, 10));

  bool get unsynced => syncState != SyncState.synced;

  /// Still adds copies.
  bool get repeating => active && deletedAt == null && nextDate != null;

  /// The copies' description.
  String get title {
    final f = jsonDecode(template);
    return f is Map && f['description'] is String ? f['description'] as String : '';
  }
}

/// "Every week", "Every 2 weeks", "Every month", "Every year".
String intervalLabel(AppLocalizations l, RecurrenceInterval i) => switch (i) {
  RecurrenceInterval.weekly => l.repeatWeekly,
  RecurrenceInterval.fortnightly => l.repeatFortnightly,
  RecurrenceInterval.monthly => l.repeatMonthly,
  RecurrenceInterval.yearly => l.repeatYearly,
};

/// A local calendar day as the date-only UTC value the recurrence rules use.
DateTime ruleDate(DateTime local) => DateTime.utc(local.year, local.month, local.day);

/// A rule date as a local calendar day (for display and the editor).
DateTime localDate(DateTime rule) => DateTime(rule.year, rule.month, rule.day);

/// The first copy of [rule] saved on [today]: on or after today, never on the anchor (03 §6, S-171).
DateTime? firstCopyFrom(Recurrence rule, DateTime today) {
  final t = ruleDate(today);
  return rule.nextAfter(DateTime.utc(t.year, t.month, t.day - 1));
}
