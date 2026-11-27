// Shared data for the D-034 batch settle widget tests and goldens: Asha owes me ₹200 in Goa and ₹255 in our
// friend group (₹455 overall), no database.
import 'package:splitify/features/payments/application/settle_all_controller.dart';

import '../balances/balance_fixtures.dart';
import '../expenses/expense_fixtures.dart' show fixedToday;

const SettleAllArgs settleAllArgs = (friendKey: 'u:u2', currency: 'INR');

const List<SettleAllGroup> ashaGroups = [
  (groupId: 'g1', name: 'Goa trip', type: 'trip', meId: 'm1', friendMemberId: 'm2', owed: 20000),
  (
    groupId: 'g3',
    name: 'Mohit & Asha',
    type: 'direct',
    meId: 'c1',
    friendMemberId: 'c2',
    owed: 25500,
  ),
];

/// The same two groups the other way: I owe Asha ₹455.
const List<SettleAllGroup> iOweAshaGroups = [
  (groupId: 'g1', name: 'Goa trip', type: 'trip', meId: 'm1', friendMemberId: 'm2', owed: -20000),
  (
    groupId: 'g3',
    name: 'Mohit & Asha',
    type: 'direct',
    meId: 'c1',
    friendMemberId: 'c2',
    owed: -25500,
  ),
];

SettleAllDraft sampleSettleAllDraft({
  String amountText = '455',
  List<SettleAllGroup> groups = ashaGroups,
  String method = 'cash',
  String note = '',
  bool othersOpen = false,
}) => SettleAllDraft(
  friendKey: 'u:u2',
  friendName: 'Asha Rao',
  friendUserId: 'u2',
  me: goaMembers()[0],
  friend: goaMembers()[1],
  currency: 'INR',
  groups: groups,
  othersOpen: othersOpen,
  date: fixedToday,
  amountText: amountText,
  method: method,
  note: note,
);

/// A batch form whose build returns [initial]; save records the parts instead of writing.
class FixedSettleAllController extends SettleAllController {
  FixedSettleAllController(super.args, this.initial);

  final SettleAllDraft initial;
  final saved = <SettleAllDraft>[];

  @override
  Future<SettleAllDraft> build() async => initial;

  @override
  Future<List<String>?> save() async {
    final d = state.value;
    if (d == null || !d.canSave) return null;
    saved.add(d);
    return [for (final p in d.parts) 'pay-${p.groupId}'];
  }
}
