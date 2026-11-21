/// Allocation of a total into parts (planning/05-money-engine.md §3).
///
/// Parts are returned in the **fixed order** of the input (member position,
/// then member id); the engine never re-sorts members. Parts always sum to the
/// total.
library;

import 'package:splitify/core/money/money_error.dart';

/// Index of every id in the fixed [order]. Throws [DuplicateMember] when an id repeats.
Map<String, int> fixedOrderIndex(List<String> order) {
  final index = <String, int>{};
  for (var i = 0; i < order.length; i++) {
    if (index.containsKey(order[i])) throw DuplicateMember(order[i]);
    index[order[i]] = i;
  }
  return index;
}

/// Throws [UnknownMember] unless every id in [ids] is in [index].
void checkKnownMembers(Map<String, int> index, Iterable<String> ids) {
  for (final id in ids) {
    if (!index.containsKey(id)) throw UnknownMember(id);
  }
}

/// Equal split of [total] into [n] parts: `base = ⌊total / n⌋`, the first
/// `total mod n` parts get one unit more. ₹100 ÷ 3 → 3334, 3333, 3333.
///
/// Uses floor division (like the oracle's `divmod`), so a negative total also
/// splits into parts that sum to it. Throws [NoParticipants] when `n ≤ 0`.
List<int> allocateEqual(int total, int n) {
  if (n <= 0) throw const NoParticipants();
  final rem = total % n; // Dart's % is non-negative for n > 0.
  final base = (total - rem) ~/ n;
  return [
    for (var i = 0; i < n; i++)
      if (i < rem) base + 1 else base,
  ];
}

/// Largest-remainder (Hamilton) split of [total] by [weights].
///
/// Each part starts at `⌊total × w / Σw⌋` (exact, in [BigInt]); the leftover
/// units go one each to the largest fractional remainders, ties by fixed order
/// (lower index first). Zero weights always get 0. Every part is within one
/// unit of its exact quota. Throws [InvalidWeights] when a weight is negative
/// or all weights are 0 (or the list is empty).
List<int> allocateRatio(int total, List<int> weights) {
  var sum = BigInt.zero;
  for (final w in weights) {
    if (w < 0) throw const InvalidWeights();
    sum += BigInt.from(w);
  }
  if (sum == BigInt.zero) throw const InvalidWeights();

  final t = BigInt.from(total);
  final parts = <int>[];
  // All quotas share the denominator Σw, so numerators of the fractional
  // parts compare exactly like the fractions themselves.
  final remainders = <BigInt>[];
  var allocated = 0;
  for (final w in weights) {
    final quota = t * BigInt.from(w);
    final rem = quota % sum; // non-negative, so (quota − rem) / Σw is the floor
    final part = ((quota - rem) ~/ sum).toInt();
    parts.add(part);
    remainders.add(rem);
    allocated += part;
  }

  final byRemainder = List<int>.generate(weights.length, (i) => i)
    ..sort((a, b) {
      final c = remainders[b].compareTo(remainders[a]);
      return c != 0 ? c : a.compareTo(b);
    });
  final left = total - allocated;
  for (var k = 0; k < left; k++) {
    parts[byRemainder[k]] += 1;
  }
  return parts;
}
