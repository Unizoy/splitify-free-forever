import 'package:splitify/domain/rules/recurrence.dart';
import 'package:splitify/features/recurring/application/recurring_providers.dart' show ruleDate;

/// The editor's "Repeat" choice (#12): [interval] null = Never; [endsOn] = last day a copy may fall on
/// (local calendar day, inclusive), null = no end date.
final class RepeatDraft {
  const RepeatDraft({this.interval, this.endsOn});

  static const never = RepeatDraft();

  final RecurrenceInterval? interval;
  final DateTime? endsOn;

  bool get repeats => interval != null;

  /// Another interval; Never also clears the end date.
  RepeatDraft withInterval(RecurrenceInterval? i) =>
      RepeatDraft(interval: i, endsOn: i == null ? null : endsOn);

  RepeatDraft withEnd(DateTime? day) => RepeatDraft(interval: interval, endsOn: day);

  /// The end date is before [start] (the expense date): not saveable.
  bool endsBefore(DateTime start) {
    final end = endsOn;
    return repeats && end != null && ruleDate(end).isBefore(ruleDate(start));
  }

  /// The rule anchored on [start]; null for Never or an end date before [start].
  Recurrence? ruleFrom(DateTime start) {
    final i = interval;
    if (i == null || endsBefore(start)) return null;
    final end = endsOn;
    return Recurrence(
      interval: i,
      anchor: ruleDate(start),
      endsOn: end == null ? null : ruleDate(end),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RepeatDraft && other.interval == interval && other.endsOn == endsOn;

  @override
  int get hashCode => Object.hash(interval, endsOn);
}
