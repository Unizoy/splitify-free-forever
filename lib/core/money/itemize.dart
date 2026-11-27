/// Itemized split (D-034 P-2, planning/research/11 A2): receipt lines, each shared by some people, plus
/// tax, service charge, tip and discount spread in proportion to what each person's lines come to.
///
/// Integer minor units only. Each line is shared with [allocateEqual] between its people in the fixed
/// member order (₹100 between three → 33.34 + 33.33 + 33.33); the extras go out with [allocateRatio] by
/// the people's line subtotals, leftover units by fixed order on ties (rule 2). The parts always add up
/// to [itemizedTotal].
library;

import 'package:splitify/core/money/allocation.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_error.dart';

/// One receipt line: its price in minor units and who shares it (member ids).
typedef ItemLine = ({int amount, List<String> members});

/// Amounts added to (tax, service charge, tip) or taken off (discount) the lines, all ≥ 0 minor units.
typedef ItemExtras = ({int tax, int service, int tip, int discount});

/// No extras.
const ItemExtras noExtras = (tax: 0, service: 0, tip: 0, discount: 0);

/// Lines plus extras: what the receipt comes to. Throws [AmountTooLarge] for values outside
/// ±[maxAmount] and [NegativeShare] for a negative line or extra.
int itemizedTotal(List<ItemLine> items, [ItemExtras extras = noExtras]) {
  _checkValues(items, extras);
  return _sum([for (final i in items) i.amount]) + _net(extras);
}

/// Each person's share of an itemized bill, for every id in [order] (the fixed member order; people
/// without lines get 0). Sums to [itemizedTotal].
///
/// Throws a [MoneyError]: `NO_PARTICIPANTS` (empty [order], or a line with nobody on it),
/// `DUPLICATE_MEMBER`, `UNKNOWN_MEMBER` (a line names someone not in [order]), `NO_SHARES` (no line with
/// an amount), `NEGATIVE_SHARE` (a negative value, or a discount bigger than the lines plus the other
/// extras), `AMOUNT_TOO_LARGE`, `AMOUNT_NOT_POSITIVE` (the bill comes to 0).
Map<String, int> itemize(List<String> order, List<ItemLine> items, [ItemExtras extras = noExtras]) {
  if (order.isEmpty) throw const NoParticipants();
  final index = fixedOrderIndex(order);
  _checkValues(items, extras);
  final subtotal = List<int>.filled(order.length, 0);
  for (final item in items) {
    if (item.members.isEmpty) throw const NoParticipants();
    checkKnownMembers(index, item.members);
    // The line's people in fixed member order, whatever order they were ticked in.
    final people = [...item.members]..sort((a, b) => index[a]!.compareTo(index[b]!));
    fixedOrderIndex(people);
    final parts = allocateEqual(item.amount, people.length);
    for (var i = 0; i < people.length; i++) {
      subtotal[index[people[i]]!] += parts[i];
    }
  }
  final lines = _sum(subtotal);
  if (lines == 0) throw const NoShares();
  final total = lines + _net(extras);
  if (total < 0) throw const NegativeShare();
  checkAmount(total);
  final extra = allocateRatio(_net(extras), subtotal);
  final shares = [for (var i = 0; i < order.length; i++) subtotal[i] + extra[i]];
  // Proportional extras keep everyone ≥ 0 while the total is ≥ 0; checked anyway (never a negative part).
  if (shares.any((s) => s < 0)) throw const NegativeShare();
  return Map.unmodifiable({for (var i = 0; i < order.length; i++) order[i]: shares[i]});
}

int _net(ItemExtras e) => e.tax + e.service + e.tip - e.discount;

void _checkValues(List<ItemLine> items, ItemExtras e) {
  final values = [for (final i in items) i.amount, e.tax, e.service, e.tip, e.discount];
  if (values.any((v) => v > maxAmount)) throw const AmountTooLarge();
  if (values.any((v) => v < 0)) throw const NegativeShare();
}

int _sum(Iterable<int> values) => values.fold(0, (a, b) => a + b);
