// Shared sample data for the phase 09 widget and golden tests (balances, payments, activity).
// The Goa trip from the expense fixtures: Asha owes me 1,200, I owe Rahul 300, Priya is settled.
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/balances/application/account_stats.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/totals_providers.dart';
import 'package:splitify/features/balances/domain/group_totals.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/application/settle_controller.dart';

import '../../support/group_fakes.dart' show sampleMember;
import '../expenses/expense_fixtures.dart';

export '../expenses/expense_fixtures.dart'
    show
        baseOverrides,
        expenseApp,
        fixedToday,
        gid,
        memberNames,
        people,
        sampleView,
        sampleViews,
        sampleExpense,
        sampleGroup;

/// Flat 4B, the second group of the home and account samples.
const flatGid = 'g-flat';

/// The four Goa members as stored rows (me = m1 / user u1).
List<LocalMember> goaMembers() => [
  sampleMember(id: 'm1', groupId: gid, userId: 'u1', name: 'Mohit Bindal', tint: 0),
  sampleMember(id: 'm2', groupId: gid, userId: 'u2', name: 'Asha Rao', position: 1, tint: 1),
  sampleMember(id: 'm3', groupId: gid, name: 'Rahul Mehta', position: 2, tint: 2),
  sampleMember(id: 'm4', groupId: gid, name: 'Priya Nair', position: 3, tint: 3),
];

/// Flat 4B: me (f1) and Dev Shah (f2).
List<LocalMember> flatMembers() => [
  sampleMember(id: 'f1', groupId: flatGid, userId: 'u1', name: 'Mohit Bindal', tint: 0),
  sampleMember(id: 'f2', groupId: flatGid, userId: 'u3', name: 'Dev Shah', position: 1, tint: 4),
];

/// Goa INR: Asha owes me 1,200 (m2 → m1), I owe Rahul 300 (m1 → m3), Priya settled. My net +900.
const goaInr = Balances(
  nets: {'m1': 90000, 'm2': -120000, 'm3': 30000, 'm4': 0},
  pairs: [Transfer('m2', 'm1', 120000), Transfer('m1', 'm3', 30000)],
  simplified: [Transfer('m2', 'm1', 90000), Transfer('m2', 'm3', 30000)],
);

/// Goa USD: I owe Rahul $20 (m1 → m3).
const goaUsd = Balances(
  nets: {'m1': -2000, 'm2': 0, 'm3': 2000, 'm4': 0},
  pairs: [Transfer('m1', 'm3', 2000)],
  simplified: [Transfer('m1', 'm3', 2000)],
);

/// Goa INR where I only owe Rahul 300.
const goaInrOwe = Balances(
  nets: {'m1': -30000, 'm2': 0, 'm3': 30000, 'm4': 0},
  pairs: [Transfer('m1', 'm3', 30000)],
  simplified: [Transfer('m1', 'm3', 30000)],
);

/// Goa INR with everything paid back.
const goaInrSettled = Balances(
  nets: {'m1': 0, 'm2': 0, 'm3': 0, 'm4': 0},
  pairs: [],
  simplified: [],
);

GroupBalances _goa(
  Map<String, Balances> byCurrency, {
  bool simplify = false,
  bool hasRecords = true,
  bool unsynced = false,
  String? meId = 'm1',
}) => GroupBalances(
  groupId: gid,
  groupName: 'Goa trip',
  mainCurrency: 'INR',
  members: goaMembers(),
  byCurrency: byCurrency,
  simplify: simplify,
  meId: meId,
  hasRecords: hasRecords,
  unsynced: unsynced,
);

/// I am owed ₹900 (Asha owes me, I owe Rahul).
GroupBalances goaOwed({bool simplify = false, bool unsynced = false}) =>
    _goa({'INR': goaInr}, simplify: simplify, unsynced: unsynced);

/// I only owe: ₹300 to Rahul.
GroupBalances goaOwe() => _goa({'INR': goaInrOwe});

/// Owed ₹900 in rupees and owing $20: a mixed banner, two currency sections.
GroupBalances goaMixed({bool simplify = false}) =>
    _goa({'INR': goaInr, 'USD': goaUsd}, simplify: simplify);

/// Owing in both currencies.
GroupBalances goaOweTwoCurrencies() => _goa({'INR': goaInrOwe, 'USD': goaUsd});

/// Records exist and everyone paid back.
GroupBalances goaSettled() => _goa({'INR': goaInrSettled});

/// No expenses or payments yet.
GroupBalances goaEmpty() => _goa(const {}, hasRecords: false);

/// Flat 4B: Dev owes me ₹500.
GroupBalances flatOwed() => GroupBalances(
  groupId: flatGid,
  groupName: 'Flat 4B',
  mainCurrency: 'INR',
  members: flatMembers(),
  byCurrency: const {
    'INR': Balances(
      nets: {'f1': 50000, 'f2': -50000},
      pairs: [Transfer('f2', 'f1', 50000)],
      simplified: [Transfer('f2', 'f1', 50000)],
    ),
  },
  meId: 'f1',
  hasRecords: true,
);

/// Overall: owed in Goa (₹900) and Flat (₹500) = ₹1,400; Asha and Dev owe me, I owe Rahul.
const myOwed = MyBalances(
  totals: {'INR': 140000},
  byGroup: {
    gid: {'INR': 90000},
    flatGid: {'INR': 50000},
  },
  people: [
    PersonBalance(key: 'u:u2', name: 'Asha Rao', seed: 'm2', balances: {'INR': 120000}),
    PersonBalance(key: 'm:m3', name: 'Rahul Mehta', seed: 'm3', balances: {'INR': -30000}),
    PersonBalance(key: 'u:u3', name: 'Dev Shah', seed: 'f2', balances: {'INR': 50000}),
  ],
);

/// Overall: I only owe Rahul ₹300.
const myOwe = MyBalances(
  totals: {'INR': -30000},
  byGroup: {
    gid: {'INR': -30000},
  },
  people: [
    PersonBalance(key: 'm:m3', name: 'Rahul Mehta', seed: 'm3', balances: {'INR': -30000}),
  ],
);

/// Overall: owed ₹900 and owing $20 (signs differ: never one total).
const myMixed = MyBalances(
  totals: {'INR': 90000, 'USD': -2000},
  byGroup: {
    gid: {'INR': 90000, 'USD': -2000},
  },
  people: [
    PersonBalance(key: 'u:u2', name: 'Asha Rao', seed: 'm2', balances: {'INR': 120000}),
    PersonBalance(
      key: 'm:m3',
      name: 'Rahul Mehta',
      seed: 'm3',
      balances: {'INR': -30000, 'USD': -2000},
    ),
  ],
);

/// Overall: owed, with rows not on the server yet.
const myOwedUnsynced = MyBalances(
  totals: {'INR': 140000},
  byGroup: {
    gid: {'INR': 90000},
    flatGid: {'INR': 50000},
  },
  people: [
    PersonBalance(key: 'u:u2', name: 'Asha Rao', seed: 'm2', balances: {'INR': 120000}),
  ],
  unsynced: true,
);

/// Account stats of the samples above.
const sampleStats = AccountStats(
  currency: 'INR',
  spentThisMonth: 1234550,
  groups: 2,
  people: 3,
  expenses: 18,
);

CurrencyTotals _inr(
  int spent,
  int count,
  Map<String, int> paid,
  Map<String, int> shares, [
  String currency = 'INR',
]) => CurrencyTotals(currency: currency, spent: spent, count: count, paid: paid, shares: shares);

/// Totals: ₹4,825 all time over 7 expenses, ₹900 this month over 2.
GroupTotalsView sampleTotals({bool withUsd = false, bool meMissing = false}) => GroupTotalsView(
  mainCurrency: 'INR',
  members: goaMembers(),
  meId: meMissing ? null : 'm1',
  month: {
    'INR': _inr(
      90000,
      2,
      {'m1': 60000, 'm2': 30000},
      {'m1': 22500, 'm2': 22500, 'm3': 22500, 'm4': 22500},
    ),
  },
  allTime: {
    'INR': _inr(
      482500,
      7,
      {'m1': 300000, 'm2': 150000, 'm3': 32500},
      {'m1': 120625, 'm2': 120625, 'm3': 120625, 'm4': 120625},
    ),
    if (withUsd) 'USD': _inr(12000, 1, {'m2': 12000}, {'m1': 6000, 'm2': 6000}, 'USD'),
  },
);

/// Nothing spent yet.
GroupTotalsView emptyTotals() =>
    GroupTotalsView(mainCurrency: 'INR', members: goaMembers(), meId: 'm1', month: {}, allTime: {});

/// A stored payment row.
LocalPayment samplePayment({
  String id = 'p1',
  String from = 'm2',
  String to = 'm1',
  int amount = 50000,
  String currency = 'INR',
  String date = '2026-11-20',
  String method = 'upi',
  String? note = 'Thanks for the cab',
  String syncState = SyncState.synced,
}) => LocalPayment(
  id: id,
  groupId: gid,
  fromMember: from,
  toMember: to,
  amount: amount,
  currency: currency,
  date: date,
  method: method,
  note: note,
  createdAt: '2026-11-20T14:05:00Z',
  createdBy: 'u1',
  seq: 1,
  syncState: syncState,
);

PaymentView paymentView([LocalPayment? p, String? meId = 'm1']) =>
    PaymentView(payment: p ?? samplePayment(), names: memberNames, meId: meId);

/// Payments list: Asha paid me (21 Nov... 20 Nov), I paid Rahul (unsynced, 26 Oct), Rahul paid Priya.
List<PaymentView> samplePayments() => [
  paymentView(),
  paymentView(
    samplePayment(
      id: 'p2',
      from: 'm1',
      to: 'm3',
      amount: 30000,
      date: '2026-10-26',
      method: 'cash',
      note: null,
      syncState: SyncState.pending,
    ),
  ),
  paymentView(
    samplePayment(
      id: 'p3',
      from: 'm3',
      to: 'm4',
      amount: 7550,
      date: '2026-10-20',
      method: 'bank',
      note: null,
    ),
  ),
];

/// The Settle up args and form: I pay Rahul the ₹300 I owe.
const SettleArgs settleArgs = (
  groupId: gid,
  from: 'm1',
  to: 'm3',
  currency: 'INR',
  paymentId: null,
);

SettleDraft sampleSettleDraft({
  String from = 'm1',
  String to = 'm3',
  String amountText = '300',
  String method = 'cash',
  String note = '',
  String? paymentId,
  GroupBalances? balances,
}) => SettleDraft(
  groupId: gid,
  groupName: 'Goa trip',
  members: goaMembers(),
  balances: balances ?? goaOwed(),
  meId: 'm1',
  from: from,
  to: to,
  currency: 'INR',
  date: fixedToday,
  amountText: amountText,
  amountEdited: paymentId != null,
  method: method,
  note: note,
  paymentId: paymentId,
);

/// Settle up whose build returns [initial] (no database); save only counts.
class FixedSettleController extends SettleController {
  FixedSettleController(super.args, this.initial);

  final SettleDraft initial;
  int saves = 0;

  @override
  Future<SettleDraft> build() async => initial;

  @override
  Future<String?> save() async {
    final d = state.value;
    if (d == null || !d.canSave) return null;
    saves++;
    return d.paymentId ?? 'new-payment';
  }
}

const _me = (name: 'Mohit Bindal', seed: 'm1', isMe: true);
const _asha = (name: 'Asha Rao', seed: 'm2', isMe: false);
const _rahul = (name: 'Rahul Mehta', seed: 'm3', isMe: false);
const _priya = (name: 'Priya Nair', seed: 'm4', isMe: false);

/// Feed rows relative to the fixed clock (21 Nov 2026, 10:00): three today (one unsynced), two
/// yesterday, one older. Newest first.
List<ActivityItem> sampleActivity() => [
  ActivityItem(
    id: 'a3',
    type: 'expense_added',
    groupId: gid,
    groupName: 'Goa trip',
    at: DateTime(2026, 11, 21, 9, 55),
    actor: _me,
    description: 'Cab to airport',
    amount: 120000,
    currency: 'INR',
    targetType: 'expense',
    targetId: 'e2',
    pending: true,
  ),
  ActivityItem(
    id: 'a1',
    type: 'expense_added',
    groupId: gid,
    groupName: 'Goa trip',
    at: DateTime(2026, 11, 21, 9, 30),
    actor: _asha,
    description: 'Dinner at Thalassa',
    amount: 240000,
    currency: 'INR',
    targetType: 'expense',
    targetId: 'e1',
  ),
  ActivityItem(
    id: 'a2',
    type: 'payment_added',
    groupId: gid,
    groupName: 'Goa trip',
    at: DateTime(2026, 11, 21, 8, 15),
    actor: _me,
    from: _asha,
    to: _me,
    amount: 50000,
    currency: 'INR',
    targetType: 'payment',
    targetId: 'p1',
  ),
  ActivityItem(
    id: 'a4',
    type: 'comment_added',
    groupId: gid,
    groupName: 'Goa trip',
    at: DateTime(2026, 11, 20, 18, 45),
    actor: _rahul,
    description: 'Dinner at Thalassa',
    targetType: 'expense',
    targetId: 'e1',
  ),
  ActivityItem(
    id: 'a5',
    type: 'member_joined',
    groupId: gid,
    groupName: 'Goa trip',
    at: DateTime(2026, 11, 20, 12),
    actor: _priya,
    targetType: 'group',
    targetId: gid,
  ),
  ActivityItem(
    id: 'a6',
    type: 'group_created',
    groupId: gid,
    groupName: 'Goa trip',
    at: DateTime(2026, 11, 14, 11),
    actor: _me,
    description: 'Goa trip',
    targetType: 'group',
    targetId: gid,
  ),
];

/// One item per remaining activity type, for the sentence table.
ActivityItem activityOf(
  String type, {
  ActivityPerson actor = _me,
  ActivityPerson? member,
  ActivityPerson? from,
  ActivityPerson? to,
  String? description,
}) => ActivityItem(
  id: 'x-$type',
  type: type,
  groupId: gid,
  groupName: 'Goa trip',
  at: DateTime(2026, 11, 21, 9),
  actor: actor,
  member: member,
  from: from,
  to: to,
  description: description,
);

/// Pieces tests use to build their own activity rows.
const activityMe = _me;
const activityAsha = _asha;
const activityRahul = _rahul;
const activityPriya = _priya;
