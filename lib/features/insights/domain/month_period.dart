/// Month navigation for Totals and Insights (D-034 WP-D, F13): `YYYY-MM` keys, stepping by months and
/// the range the ‹ › buttons may reach. Pure Dart.
library;

/// The month [delta] months after [key] (`2026-01` − 1 = `2025-12`).
String addMonths(String key, int delta) {
  final index = int.parse(key.substring(0, 4)) * 12 + int.parse(key.substring(5, 7)) - 1 + delta;
  final year = index ~/ 12;
  final month = index % 12 + 1;
  return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
}

/// The months ‹ › can show: from the oldest month with spending to the newest one, always including
/// [current] (today's month, even with nothing spent yet).
final class MonthRange {
  const MonthRange(this.first, this.last);

  /// Range of [months] (keys in any order) plus [current].
  factory MonthRange.of(Iterable<String> months, String current) {
    var first = current;
    var last = current;
    for (final m in months) {
      if (m.compareTo(first) < 0) first = m;
      if (m.compareTo(last) > 0) last = m;
    }
    return MonthRange(first, last);
  }

  final String first;
  final String last;

  bool canGoBack(String month) => month.compareTo(first) > 0;

  bool canGoForward(String month) => month.compareTo(last) < 0;

  /// [month] moved into the range.
  String clamp(String month) => month.compareTo(first) < 0
      ? first
      : month.compareTo(last) > 0
      ? last
      : month;
}
