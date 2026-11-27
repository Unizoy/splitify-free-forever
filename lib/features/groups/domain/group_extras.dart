import 'package:splitify/features/balances/application/balance_views.dart';

/// One "who owes whom" line on the group page from the viewer's side (D-034 C1): [other] owes me [amount]
/// ([iOwe] false) or I owe [other] [amount] ([iOwe] true), in [currency] (minor units).
typedef BalanceLine = ({String currency, String other, int amount, bool iOwe});

/// My lines in [b] exactly as the Balances tab shows them (simplified transfers when simplify is on, else the
/// pairs; rule 12): per currency, main currency first, in the tab's row order. Empty when I am not an active
/// member or nothing involves me. Currencies are never added together (rule 4).
List<BalanceLine> myBalanceLines(GroupBalances b) {
  final me = b.meId;
  if (me == null) return const [];
  return [
    for (final c in b.currencies)
      for (final t in b.shown(c))
        if (t.amount > 0 && t.to == me && t.from != me)
          (currency: c, other: t.from, amount: t.amount, iOwe: false)
        else if (t.amount > 0 && t.from == me && t.to != me)
          (currency: c, other: t.to, amount: t.amount, iOwe: true),
  ];
}

/// The Groups list filter (D-034 C3), kept on this phone.
enum GroupFilter {
  all,

  /// Any non-zero balance of mine.
  outstanding,

  /// I owe something in at least one currency.
  iOwe,

  /// Someone owes me in at least one currency.
  owedToMe;

  /// Stored name → filter; unknown or missing = [all].
  static GroupFilter parse(String? stored) =>
      values.firstWhere((f) => f.name == stored, orElse: () => all);
}

/// Whether a group with my per-currency nets [mine] passes [filter]. A group where I owe in one currency
/// and am owed in another passes both [GroupFilter.iOwe] and [GroupFilter.owedToMe].
bool groupMatches(GroupFilter filter, Map<String, int> mine) => switch (filter) {
  GroupFilter.all => true,
  GroupFilter.outstanding => mine.values.any((v) => v != 0),
  GroupFilter.iOwe => mine.values.any((v) => v < 0),
  GroupFilter.owedToMe => mine.values.any((v) => v > 0),
};

/// Settle-up reminder setting of a group (D-034 C4; server column `settle_reminder`).
enum SettleReminder {
  off,
  weekly,
  monthly;

  /// Stored value → setting; null (a local group the server has not answered for yet) or unknown = off.
  static SettleReminder parse(String? stored) =>
      values.firstWhere((r) => r.name == stored, orElse: () => off);
}

/// `YYYY-MM-DD` → that calendar day (null for null / bad text).
DateTime? parseDay(String? iso) {
  if (iso == null || iso.length < 10) return null;
  final d = DateTime.tryParse(iso.substring(0, 10));
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// Calendar day → `YYYY-MM-DD`.
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Why a settle-up nudge goes out (server `send_settle_nudges`, 0026).
enum NudgeReason { weekly, monthly, tripEnd }

/// The next day, from [today] on, on which the server would nudge this group (when someone still has a
/// balance), mirroring `private.send_settle_nudges` (0026): weekly on the weekday the group was created
/// ([createdDay], never that first day), monthly on the 1st, and the day after [tripEndsOn] whatever the
/// setting. Null when nothing is due. Days are calendar days in the phone's (India) calendar.
({DateTime day, NudgeReason reason})? nextSettleNudge({
  required SettleReminder reminder,
  required DateTime today,
  DateTime? createdDay,
  DateTime? tripEndsOn,
}) {
  final t = DateTime(today.year, today.month, today.day);
  ({DateTime day, NudgeReason reason})? best;
  void offer(DateTime d, NudgeReason r) {
    if (d.isBefore(t)) return;
    final b = best;
    // The same day: the server writes one nudge, a trip end first (its CASE order).
    if (b == null || d.isBefore(b.day) || (d == b.day && r == NudgeReason.tripEnd)) {
      best = (day: d, reason: r);
    }
  }

  final end = tripEndsOn;
  if (end != null) offer(DateTime(end.year, end.month, end.day + 1), NudgeReason.tripEnd);
  switch (reminder) {
    case SettleReminder.off:
      break;
    case SettleReminder.weekly:
      final created = createdDay == null
          ? null
          : DateTime(createdDay.year, createdDay.month, createdDay.day);
      final weekday = created?.weekday ?? t.weekday;
      var d = DateTime(t.year, t.month, t.day + (weekday - t.weekday + 7) % 7);
      if (created != null && !d.isAfter(created)) d = DateTime(d.year, d.month, d.day + 7);
      offer(d, NudgeReason.weekly);
    case SettleReminder.monthly:
      offer(t.day == 1 ? t : DateTime(t.year, t.month + 1), NudgeReason.monthly);
  }
  return best;
}

/// One record of a group's ledger for [settledHistoryIds]: what it moves per member (minor units of
/// [currency]; + = the member is owed more, − = owes more).
typedef LedgerEntry = ({
  String id,
  String date,
  String? createdAt,
  String currency,
  Map<String, int> deltas,
});

/// Deltas of an expense: paid − owed per member.
Map<String, int> expenseDeltas(Map<String, int> paid, Map<String, int> owed) => {
  for (final id in {...paid.keys, ...owed.keys}) id: (paid[id] ?? 0) - (owed[id] ?? 0),
};

/// Deltas of a payment: the payer gets +amount (their debt shrinks), the receiver −amount. Payments to
/// oneself or of nothing move nothing (as in the balances, 05 §5).
Map<String, int> paymentDeltas(String from, String to, int amount) =>
    from == to || amount <= 0 ? const {} : {from: amount, to: -amount};

/// The records to fold behind "Show settled expenses" (D-034 C2): when every member is square in every
/// currency after the whole ledger, the ids of the records up to and including the one that last made the
/// group settled, in date order (then creation time, then id). Later records moved nothing and stay
/// visible. Empty while any balance is open, or when the group never went from open to settled.
Set<String> settledHistoryIds(List<LedgerEntry> entries) {
  final sorted = [...entries]
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      // Not on the server yet (no creation time) = the newest.
      final ca = a.createdAt;
      final cb = b.createdAt;
      if (ca != cb) {
        if (ca == null) return 1;
        if (cb == null) return -1;
        final byCreated = ca.compareTo(cb);
        if (byCreated != 0) return byCreated;
      }
      return a.id.compareTo(b.id);
    });
  final nets = <String, Map<String, int>>{};
  var open = 0; // non-zero (currency, member) nets
  var lastSettled = -1;
  for (var i = 0; i < sorted.length; i++) {
    final e = sorted[i];
    final wasOpen = open > 0;
    final byMember = nets.putIfAbsent(e.currency, () => <String, int>{});
    e.deltas.forEach((member, delta) {
      if (delta == 0) return;
      final before = byMember[member] ?? 0;
      final after = before + delta;
      byMember[member] = after;
      if (before == 0) open++;
      if (after == 0) open--;
    });
    if (wasOpen && open == 0) lastSettled = i;
  }
  if (open != 0 || lastSettled < 0) return const {};
  return {for (var i = 0; i <= lastSettled; i++) sorted[i].id};
}
