// Sample balances for the Remind button (widget tests + goldens): three people owe me in the Goa trip.
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/features/balances/application/balance_views.dart';

import '../../support/group_fakes.dart' show sampleMember;
import '../expenses/expense_fixtures.dart' show gid;

/// Asha (m2, has the app) owes me 1,200, Priya (m4, has the app, already reminded) owes me 450 and Rahul
/// (m3, name only) owes me 300. I am Mohit (m1).
GroupBalances remindBalances() => GroupBalances(
  groupId: gid,
  groupName: 'Goa trip',
  mainCurrency: 'INR',
  members: [
    sampleMember(id: 'm1', groupId: gid, userId: 'u1', name: 'Mohit Bindal', tint: 0),
    sampleMember(id: 'm2', groupId: gid, userId: 'u2', name: 'Asha Rao', position: 1, tint: 1),
    sampleMember(id: 'm3', groupId: gid, name: 'Rahul Mehta', position: 2, tint: 2),
    sampleMember(id: 'm4', groupId: gid, userId: 'u4', name: 'Priya Nair', position: 3, tint: 3),
  ],
  byCurrency: const {
    'INR': Balances(
      nets: {'m1': 195000, 'm2': -120000, 'm3': -30000, 'm4': -45000},
      pairs: [
        Transfer('m2', 'm1', 120000),
        Transfer('m4', 'm1', 45000),
        Transfer('m3', 'm1', 30000),
      ],
      simplified: [
        Transfer('m2', 'm1', 120000),
        Transfer('m4', 'm1', 45000),
        Transfer('m3', 'm1', 30000),
      ],
    ),
  },
  simplify: false,
  meId: 'm1',
  hasRecords: true,
);
