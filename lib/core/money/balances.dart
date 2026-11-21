/// Group balances (planning/05-money-engine.md §5): nets, who owes whom
/// (pairwise, simplify off), simplify debts, and the total with a friend.
///
/// All functions work on ONE currency and take members in the fixed order
/// (position, then id). Records in another currency are rejected with
/// [CurrencyMismatch]; [balancesByCurrency] splits mixed records into one
/// block per currency (rule 4: never mix currencies).
library;

import 'package:splitify/core/money/allocation.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_error.dart';

/// One expense as balances see it: what each member paid and what each owes.
final class ExpenseFlow {
  const ExpenseFlow({required this.currency, required this.paid, required this.shares});

  final String currency;

  /// Minor units paid per member id (payers needn't be participants).
  final Map<String, int> paid;

  /// Minor units owed per member id.
  final Map<String, int> shares;
}

/// A recorded payment: [from] paid [to] [amount] minor units of [currency].
final class Payment {
  const Payment({
    required this.currency,
    required this.from,
    required this.to,
    required this.amount,
  });

  final String currency;
  final String from;
  final String to;
  final int amount;
}

/// "[from] owes [to] [amount]" (or, from simplify, "[from] should pay [to]").
final class Transfer {
  const Transfer(this.from, this.to, this.amount);

  final String from;
  final String to;

  /// Minor units, always > 0.
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is Transfer && other.from == from && other.to == to && other.amount == amount;

  @override
  int get hashCode => Object.hash(from, to, amount);

  @override
  String toString() => 'Transfer($from → $to: $amount)';
}

/// Net per member (every member of [order] listed, 0 included). Positive = is
/// owed. `net(m) = Σ paid − Σ share + Σ payments sent − Σ payments received`.
/// The nets always sum to 0 when every expense's paid and shares sum equally.
Map<String, int> nets(List<String> order, List<ExpenseFlow> expenses, List<Payment> payments) =>
    _nets(order, expenses, payments);

Map<String, int> _nets(List<String> order, List<ExpenseFlow> expenses, List<Payment> payments) {
  final index = fixedOrderIndex(order);
  _checkOneCurrency(expenses, payments);
  final n = <String, int>{for (final m in order) m: 0};
  for (final e in expenses) {
    checkKnownMembers(index, e.paid.keys);
    checkKnownMembers(index, e.shares.keys);
    e.paid.forEach((m, v) => n[m] = n[m]! + v);
    e.shares.forEach((m, v) => n[m] = n[m]! - v);
  }
  for (final p in payments) {
    _checkPayment(index, p);
    n[p.from] = n[p.from]! + p.amount;
    n[p.to] = n[p.to]! - p.amount;
  }
  return Map.unmodifiable(n);
}

/// Who owes whom for ONE expense: per-expense nets `paid − share`, debtors
/// matched to creditors in fixed order (north-west corner). Exact, no
/// rounding; with a single payer every participant owes the payer their share.
List<Transfer> expensePairs(List<String> order, Map<String, int> paid, Map<String, int> shares) {
  final index = fixedOrderIndex(order);
  checkKnownMembers(index, paid.keys);
  checkKnownMembers(index, shares.keys);
  final debtors = <String>[];
  final debts = <int>[];
  final creditors = <String>[];
  final credits = <int>[];
  for (final m in order) {
    if (!paid.containsKey(m) && !shares.containsKey(m)) continue;
    final v = (paid[m] ?? 0) - (shares[m] ?? 0);
    if (v < 0) {
      debtors.add(m);
      debts.add(-v);
    } else if (v > 0) {
      creditors.add(m);
      credits.add(v);
    }
  }
  final out = <Transfer>[];
  var i = 0;
  var j = 0;
  while (i < debtors.length && j < creditors.length) {
    final x = debts[i] < credits[j] ? debts[i] : credits[j];
    out.add(Transfer(debtors[i], creditors[j], x));
    debts[i] -= x;
    credits[j] -= x;
    if (debts[i] == 0) i++;
    if (credits[j] == 0) j++;
  }
  return out;
}

/// The "original debts" (simplify OFF): [expensePairs] of every expense summed
/// per pair, payments reduce what `from` owes `to`, and the net of each pair is
/// shown. Sorted by the fixed order of the pair (lower member first, then the
/// other). A cycle can leave non-zero pairs while every net is 0.
List<Transfer> pairwise(List<String> order, List<ExpenseFlow> expenses, List<Payment> payments) {
  final index = fixedOrderIndex(order);
  _checkOneCurrency(expenses, payments);
  final n = order.length;
  // Key i * n + j (i < j): positive = order[i] owes order[j].
  final acc = <int, int>{};
  void add(String a, String b, int x) {
    final ia = index[a]!;
    final ib = index[b]!;
    if (ia < ib) {
      acc[ia * n + ib] = (acc[ia * n + ib] ?? 0) + x;
    } else {
      acc[ib * n + ia] = (acc[ib * n + ia] ?? 0) - x;
    }
  }

  for (final e in expenses) {
    for (final t in expensePairs(order, e.paid, e.shares)) {
      add(t.from, t.to, t.amount);
    }
  }
  for (final p in payments) {
    _checkPayment(index, p);
    add(p.from, p.to, -p.amount);
  }
  final out = <Transfer>[];
  for (final key in acc.keys.toList()..sort()) {
    final a = order[key ~/ n];
    final b = order[key % n];
    final v = acc[key]!;
    if (v > 0) {
      out.add(Transfer(a, b, v));
    } else if (v < 0) {
      out.add(Transfer(b, a, -v));
    }
  }
  return out;
}

/// Simplify debts (rule 12) from [net] (missing members = 0): (1) settle exact
/// opposites in fixed order, (2) repeatedly move `min(largest credit, largest
/// debt)` from the largest debtor to the largest creditor, ties by fixed order.
/// Never changes anyone's net; at most n − 1 transfers; deterministic.
/// Throws `NETS_DO_NOT_SUM_TO_ZERO` or `UNKNOWN_MEMBER`.
List<Transfer> simplify(List<String> order, Map<String, int> net) {
  final index = fixedOrderIndex(order);
  checkKnownMembers(index, net.keys);
  if (net.values.fold(0, (a, b) => a + b) != 0) throw const NetsDoNotSumToZero();
  final bal = [for (final m in order) net[m] ?? 0];
  final out = <Transfer>[];
  for (var d = 0; d < bal.length; d++) {
    if (bal[d] >= 0) continue;
    for (var c = 0; c < bal.length; c++) {
      if (bal[c] > 0 && bal[c] == -bal[d]) {
        out.add(Transfer(order[d], order[c], bal[c]));
        bal[d] = 0;
        bal[c] = 0;
        break;
      }
    }
  }
  while (bal.any((v) => v != 0)) {
    var c = -1;
    var d = -1;
    for (var i = 0; i < bal.length; i++) {
      if (bal[i] > 0 && (c < 0 || bal[i] > bal[c])) c = i;
      if (bal[i] < 0 && (d < 0 || bal[i] < bal[d])) d = i;
    }
    final x = bal[c] < -bal[d] ? bal[c] : -bal[d];
    out.add(Transfer(order[d], order[c], x));
    bal[c] -= x;
    bal[d] += x;
  }
  return out;
}

/// Balances of one group in one currency.
final class Balances {
  const Balances({required this.nets, required this.pairs, required this.simplified});

  /// Computes [nets], [pairs] ([pairwise]) and [simplified] ([simplify]) for
  /// records that all share one currency.
  factory Balances.compute(List<String> order, List<ExpenseFlow> expenses, List<Payment> payments) {
    final n = _nets(order, expenses, payments);
    return Balances(
      nets: n,
      pairs: pairwise(order, expenses, payments),
      simplified: simplify(order, n),
    );
  }

  /// Net per member, positive = is owed.
  final Map<String, int> nets;

  /// Original debts (simplify off).
  final List<Transfer> pairs;

  /// Simplified transfers (simplify on).
  final List<Transfer> simplified;

  /// What the group screen shows: [simplified] when simplify is on, else [pairs].
  List<Transfer> shown({required bool simplify}) => simplify ? simplified : pairs;
}

/// One [Balances] block per currency used by [expenses] or [payments], keyed
/// by currency code in alphabetical order. Amounts of different currencies
/// are never added together.
Map<String, Balances> balancesByCurrency(
  List<String> order,
  List<ExpenseFlow> expenses,
  List<Payment> payments,
) {
  final codes = {...expenses.map((e) => e.currency), ...payments.map((p) => p.currency)}.toList()
    ..sort();
  return Map.unmodifiable({
    for (final code in codes)
      code: Balances.compute(
        order,
        [...expenses.where((e) => e.currency == code)],
        [...payments.where((p) => p.currency == code)],
      ),
  });
}

/// One group (or the direct friend group) shared by me and a friend, as the
/// group screen shows it. Members are not accounts, so [me] and [friend] are
/// the member ids of the two people in THIS group.
final class FriendGroup {
  const FriendGroup({
    required this.me,
    required this.friend,
    required this.balances,
    this.simplify = false,
  });

  final String me;
  final String friend;

  /// The group's balances per currency (from [balancesByCurrency]).
  final Map<String, Balances> balances;

  /// Whether this group has simplify debts on.
  final bool simplify;
}

/// Total with a friend (#16), per currency: Σ over [groups] (shared groups +
/// the direct group) of what each group screen shows between the two people —
/// simplified transfers when that group has simplify on, else pairs. Positive =
/// the friend owes me. Currencies that net to 0 are left out (settled up);
/// keys are in alphabetical order.
Map<String, int> friendTotals(List<FriendGroup> groups) {
  final totals = <String, int>{};
  for (final g in groups) {
    g.balances.forEach((code, b) {
      for (final t in b.shown(simplify: g.simplify)) {
        if (t.from == g.friend && t.to == g.me) {
          totals[code] = (totals[code] ?? 0) + t.amount;
        } else if (t.from == g.me && t.to == g.friend) {
          totals[code] = (totals[code] ?? 0) - t.amount;
        }
      }
    });
  }
  final codes = totals.keys.where((c) => totals[c] != 0).toList()..sort();
  return Map.unmodifiable({for (final c in codes) c: totals[c]});
}

void _checkOneCurrency(List<ExpenseFlow> expenses, List<Payment> payments) {
  final codes = [...expenses.map((e) => e.currency), ...payments.map((p) => p.currency)];
  for (final c in codes) {
    if (c != codes.first) throw CurrencyMismatch(codes.first, c);
  }
}

void _checkPayment(Map<String, int> index, Payment p) {
  checkKnownMembers(index, [p.from, p.to]);
  if (p.from == p.to) throw InvalidPayment(p.from);
  checkAmount(p.amount);
}
