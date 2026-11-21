// Next-date rules for recurring bills (planning/08-feature-specs.md #12, planning/03-backend.md §6,
// phase 16 T1). Contract: test/fixtures/recurring_vectors.json, shared with the SQL generator
// (phase 16 T2), which must give the same dates.
//
// Rules:
// - Dates are calendar dates only: `DateTime.utc(y, m, d)` at midnight, no time of day, no time zone.
//   The caller picks "today" (the server uses the Asia/Kolkata date).
// - Occurrence 0 is the anchor (the date of the original expense); copies are occurrences 1, 2, …
// - Every occurrence is computed from the anchor, never from the previous copy, so a 31st clamped to
//   Feb 28/29 returns to the 31st in March, and Feb 29 returns in the next leap year.
// - Monthly/yearly: day = min(anchor day, last day of the target month).
// - `endsOn` is inclusive: a copy dated on it is still created. It may equal the anchor (no copies),
//   but never be before it.

/// How often a template repeats; [key] is the `recurring_templates.interval` value.
enum RecurrenceInterval {
  weekly('weekly'),
  fortnightly('fortnightly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurrenceInterval(this.key);

  /// Stored value (`weekly`, `fortnightly`, `monthly`, `yearly`).
  final String key;

  /// The interval stored as [key]; throws [UnknownInterval] for any other text.
  static RecurrenceInterval parse(String key) {
    for (final interval in values) {
      if (interval.key == key) return interval;
    }
    throw UnknownInterval(key);
  }
}

/// Errors of the recurrence rules, each with a stable [code] (also used by the SQL generator).
sealed class RecurrenceError implements Exception {
  const RecurrenceError();

  /// Stable error code, e.g. `UNKNOWN_INTERVAL`.
  String get code;

  /// Extra values, keyed like the vectors.
  Map<String, Object> get data => const {};

  @override
  String toString() => data.isEmpty ? 'RecurrenceError($code)' : 'RecurrenceError($code, $data)';
}

/// A stored interval is not one of [RecurrenceInterval.values].
final class UnknownInterval extends RecurrenceError {
  const UnknownInterval(this.interval);

  final String interval;

  @override
  String get code => 'UNKNOWN_INTERVAL';

  @override
  Map<String, Object> get data => {'interval': interval};
}

/// The end date is before the anchor.
final class EndsBeforeAnchor extends RecurrenceError {
  const EndsBeforeAnchor();

  @override
  String get code => 'ENDS_BEFORE_ANCHOR';
}

/// A value is not a date-only UTC `DateTime` or not a valid `YYYY-MM-DD` text.
final class NotADate extends RecurrenceError {
  const NotADate(this.value);

  final String value;

  @override
  String get code => 'NOT_A_DATE';

  @override
  Map<String, Object> get data => {'value': value};
}

final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Parses `YYYY-MM-DD` into a date-only UTC `DateTime`; throws [NotADate] for anything else
/// (including impossible dates such as `2026-02-30`).
DateTime parseIsoDate(String text) {
  final match = _isoDate.firstMatch(text);
  if (match == null) throw NotADate(text);
  final date = DateTime.utc(int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
  if (formatIsoDate(date) != text) throw NotADate(text);
  return date;
}

/// `YYYY-MM-DD` text of the calendar date of [date] (the form stored in SQL `date` columns).
String formatIsoDate(DateTime date) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
}

/// Returns [date] when it is a UTC midnight; throws [NotADate] otherwise.
DateTime checkDateOnly(DateTime date) {
  final midnight = DateTime.utc(date.year, date.month, date.day);
  if (!date.isUtc || date != midnight) throw NotADate(date.toIso8601String());
  return date;
}

/// Number of days in [month] (1–12) of [year].
int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// What one generator run produces: the copy dates to create, oldest first, and the template's new
/// `next_date` (`null` = no copies left, the template ends).
typedef RecurrenceRun = ({List<DateTime> dates, DateTime? next});

/// A repeat rule: [interval] counted from [anchor], optionally ending on [endsOn] (inclusive).
final class Recurrence {
  /// Throws [NotADate] for dates with a time part, [EndsBeforeAnchor] when `endsOn < anchor`.
  Recurrence({required this.interval, required DateTime anchor, DateTime? endsOn})
    : anchor = checkDateOnly(anchor),
      endsOn = endsOn == null ? null : checkDateOnly(endsOn) {
    final end = this.endsOn;
    if (end != null && end.isBefore(this.anchor)) throw const EndsBeforeAnchor();
  }

  /// From stored values: interval key and `YYYY-MM-DD` texts (`endsOn` may be `null`).
  factory Recurrence.parse({required String interval, required String anchor, String? endsOn}) =>
      Recurrence(
        interval: RecurrenceInterval.parse(interval),
        anchor: parseIsoDate(anchor),
        endsOn: endsOn == null ? null : parseIsoDate(endsOn),
      );

  final RecurrenceInterval interval;
  final DateTime anchor;
  final DateTime? endsOn;

  /// Date of occurrence [index] (0 = the anchor), ignoring [endsOn].
  DateTime occurrence(int index) {
    RangeError.checkNotNegative(index, 'index');
    final a = anchor;
    switch (interval) {
      case RecurrenceInterval.weekly:
        return DateTime.utc(a.year, a.month, a.day + 7 * index);
      case RecurrenceInterval.fortnightly:
        return DateTime.utc(a.year, a.month, a.day + 14 * index);
      case RecurrenceInterval.monthly:
        final months = a.month - 1 + index;
        final year = a.year + months ~/ 12;
        final month = months % 12 + 1;
        return _clamped(year, month, a.day);
      case RecurrenceInterval.yearly:
        return _clamped(a.year + index, a.month, a.day);
    }
  }

  /// The `next_date` of a new template: the first copy after the anchor, `null` if [endsOn] comes first.
  DateTime? get firstCopy => nextAfter(anchor);

  /// The first copy dated strictly after [date] and not after [endsOn]; `null` when none is left.
  /// Copies never fall on or before the anchor, so any [date] before it gives the first copy.
  DateTime? nextAfter(DateTime date) =>
      _withinEnd(occurrence(_firstIndexOnOrAfter(_addDays(checkDateOnly(date), 1))));

  /// One generator run on [today] for a template whose stored `next_date` is [nextDate]: every copy
  /// from [nextDate] up to and including [today] (catch-up after missed days), and the new
  /// `next_date`. A [nextDate] that is not on the series (template edited) snaps to the next copy.
  /// Running again with the returned `next` on the same [today] creates nothing (idempotent).
  RecurrenceRun run({required DateTime nextDate, required DateTime today}) {
    checkDateOnly(today);
    final dates = <DateTime>[];
    var index = _firstIndexOnOrAfter(checkDateOnly(nextDate));
    while (true) {
      final date = _withinEnd(occurrence(index));
      if (date == null) return (dates: dates, next: null);
      if (date.isAfter(today)) return (dates: dates, next: date);
      dates.add(date);
      index++;
    }
  }

  /// Smallest copy index (≥ 1) whose date is on or after [date].
  int _firstIndexOnOrAfter(DateTime date) {
    final a = anchor;
    final int guess;
    switch (interval) {
      case RecurrenceInterval.weekly:
      case RecurrenceInterval.fortnightly:
        final step = interval == RecurrenceInterval.weekly ? 7 : 14;
        final days = date.difference(a).inDays;
        return days <= step ? 1 : (days + step - 1) ~/ step;
      case RecurrenceInterval.monthly:
        guess = (date.year - a.year) * 12 + date.month - a.month;
      case RecurrenceInterval.yearly:
        guess = date.year - a.year;
    }
    final index = guess < 1 ? 1 : guess;
    return occurrence(index).isBefore(date) ? index + 1 : index;
  }

  DateTime? _withinEnd(DateTime date) {
    final end = endsOn;
    return end != null && date.isAfter(end) ? null : date;
  }

  static DateTime _clamped(int year, int month, int day) {
    final last = daysInMonth(year, month);
    return DateTime.utc(year, month, day < last ? day : last);
  }

  static DateTime _addDays(DateTime date, int days) =>
      DateTime.utc(date.year, date.month, date.day + days);
}
