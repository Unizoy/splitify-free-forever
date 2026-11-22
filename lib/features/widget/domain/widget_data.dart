/// What the Android home-screen widget shows (X3, planning/08-feature-specs.md): my overall balance
/// per currency (top 2), its status, "Updated 5 min ago" or "Not synced yet", and the privacy option
/// "Hide amounts" (no numbers are even written then). Values are strings/ints for `home_widget`'s
/// shared preferences; the native layouts (`BalanceWidget*.kt`) only place them.
library;

import 'package:splitify/core/money/money_formatter.dart';

/// Keys the native widget reads (`android/app/src/main/kotlin/com/unizoy/splitify/BalanceWidget.kt`).
abstract final class WidgetKeys {
  static const brand = 'brand';
  static const status = 'status';

  /// `owed`, `owe`, `settled`, `mixed` or `signed_out` (colour of the status line).
  static const tone = 'tone';
  static const line1 = 'line1';
  static const line2 = 'line2';
  static const hidden = 'hidden';

  /// Last sync, epoch milliseconds as text ("0" = never); the widget turns it into "5 min ago".
  static const updatedAt = 'updated_at';

  /// "Updated %s" (`%s` = relative time, filled in natively).
  static const updatedTemplate = 'updated_template';

  /// Set instead of the updated line while my changes are not on the server ("Not synced yet").
  static const pending = 'pending';
}

/// Texts the builder needs (from the ARB file).
typedef WidgetLabels = ({
  String brand,
  String owed,
  String owe,
  String settled,
  String mixed,
  String hidden,
  String updatedTemplate,
  String notSynced,
  String signedOut,
});

/// The widget's values (TC-X3-01). [totals] are my overall nets per currency (rule 3: local rows,
/// [unsynced] when some are not on the server yet); [first] is the currency shown first.
Map<String, Object> buildWidgetData({
  required WidgetLabels labels,
  required bool signedIn,
  required Map<String, int> totals,
  required String first,
  required bool unsynced,
  required DateTime? lastSync,
  required bool hideAmounts,
}) {
  final base = <String, Object>{
    WidgetKeys.brand: labels.brand,
    WidgetKeys.hidden: hideAmounts,
    WidgetKeys.updatedTemplate: labels.updatedTemplate,
    WidgetKeys.updatedAt: '${lastSync?.millisecondsSinceEpoch ?? 0}',
    WidgetKeys.pending: unsynced ? labels.notSynced : '',
  };
  if (!signedIn) {
    return {
      ...base,
      WidgetKeys.status: labels.signedOut,
      WidgetKeys.tone: 'signed_out',
      WidgetKeys.line1: '',
      WidgetKeys.line2: '',
      WidgetKeys.pending: '',
      WidgetKeys.updatedAt: '0',
    };
  }
  // Non-zero currencies, the first currency first, then the biggest amounts (top 2).
  final codes =
      [
        for (final e in totals.entries)
          if (e.value != 0) e.key,
      ]..sort((a, b) {
        if (a == first) return -1;
        if (b == first) return 1;
        final byAmount = totals[b]!.abs().compareTo(totals[a]!.abs());
        return byAmount != 0 ? byAmount : a.compareTo(b);
      });
  final positive = codes.any((c) => totals[c]! > 0);
  final negative = codes.any((c) => totals[c]! < 0);
  final tone = positive && negative
      ? 'mixed'
      : positive
      ? 'owed'
      : negative
      ? 'owe'
      : 'settled';
  final status = switch (tone) {
    'owed' => labels.owed,
    'owe' => labels.owe,
    'mixed' => labels.mixed,
    _ => labels.settled,
  };
  String line(int i) {
    if (hideAmounts) return i == 0 && codes.isNotEmpty ? labels.hidden : '';
    if (i >= codes.length) return i == 0 ? MoneyFormatter.list.format(0, first) : '';
    final net = totals[codes[i]]!;
    // Mixed signs keep their sign (rule 4: never one total over currencies).
    const signed = MoneyFormatter(hideZeroFraction: true, sign: MoneySign.always);
    return tone == 'mixed'
        ? signed.format(net, codes[i])
        : MoneyFormatter.list.format(net.abs(), codes[i]);
  }

  return {
    ...base,
    WidgetKeys.status: status.toUpperCase(),
    WidgetKeys.tone: tone,
    WidgetKeys.line1: line(0),
    WidgetKeys.line2: line(1),
  };
}
