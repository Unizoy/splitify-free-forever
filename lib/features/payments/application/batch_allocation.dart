/// How one payment to (or from) a friend is spread over the groups we share (D-034 B1, "settle everything
/// with one friend"). Pure integer minor units of ONE currency (rules 1, 4): currencies are never mixed, each
/// currency is its own batch.
///
/// The order is fixed and documented (coordinator decision, D-034):
/// 1. The direction is the overall one: whoever owes on balance pays.
/// 2. Balances that go the other way are cleared first, in full (each becomes a payment in its own direction),
///    so the overall amount that changes hands is exactly the amount typed.
/// 3. What is left (the amount plus what step 2 cleared) pays the BIGGEST group balance first, ties broken by
///    group id; each group gets at most what is owed there, so no group balance ever flips.
library;

/// One group's balance between me and the friend in one currency: positive = the friend owes me.
typedef GroupOwed = ({String groupId, int owed});

/// One payment of a batch: [amount] (> 0) in [groupId], from the friend to me when [friendPays], else from me
/// to the friend.
typedef BatchPart = ({String groupId, bool friendPays, int amount});

/// The amount cannot be spread: not positive, more than the overall balance, or nothing is owed overall.
final class BatchAmountError extends ArgumentError {
  BatchAmountError(String message) : super(message);
}

/// What is owed overall in [balances] (positive = the friend owes me).
int batchNet(Iterable<GroupOwed> balances) => balances.fold<int>(0, (a, b) => a + b.owed);

/// Spreads [amount] (1 … |net|) over [balances] in the order above; parts in the order they are written
/// (biggest first, then the cleared opposite balances). Each group appears at most once. Throws
/// [BatchAmountError] when [amount] is out of range or nothing is owed overall.
List<BatchPart> allocateBatch(List<GroupOwed> balances, int amount) {
  final net = batchNet(balances);
  if (net == 0) throw BatchAmountError('nothing is owed overall');
  if (amount <= 0) throw BatchAmountError('amount must be positive');
  if (amount > net.abs()) throw BatchAmountError('amount is more than the overall balance');
  final friendPays = net > 0;
  bool same(GroupOwed g) => friendPays ? g.owed > 0 : g.owed < 0;
  bool opposite(GroupOwed g) => friendPays ? g.owed < 0 : g.owed > 0;
  final cleared = [
    for (final g in balances)
      if (opposite(g)) (groupId: g.groupId, friendPays: !friendPays, amount: g.owed.abs()),
  ];
  var left = amount + cleared.fold<int>(0, (a, p) => a + p.amount);
  final order = [...balances.where(same)]
    ..sort((a, b) {
      final byAmount = b.owed.abs().compareTo(a.owed.abs());
      return byAmount != 0 ? byAmount : a.groupId.compareTo(b.groupId);
    });
  final parts = <BatchPart>[];
  for (final g in order) {
    if (left == 0) break;
    final owed = g.owed.abs();
    final take = left < owed ? left : owed;
    parts.add((groupId: g.groupId, friendPays: friendPays, amount: take));
    left -= take;
  }
  // The same-direction balances add up to |net| + what was cleared, so everything is placed.
  assert(left == 0, 'batch allocation left $left unplaced');
  return [...parts, ...cleared];
}

/// What each group owes after [parts] are paid (positive = the friend owes me), in the order of [balances].
List<GroupOwed> afterBatch(List<GroupOwed> balances, List<BatchPart> parts) => [
  for (final g in balances)
    (
      groupId: g.groupId,
      owed:
          g.owed -
          parts
              .where((p) => p.groupId == g.groupId)
              .fold<int>(0, (a, p) => a + (p.friendPays ? p.amount : -p.amount)),
    ),
];
