// D-034 WP-B (Settle and friends): the friend's Settle up sheet with "Everything with Asha", the batch payment form
// (all, part, more than owed, Pay via UPI) and its breakdown, My friend code (and offline), Add a friend by code
// (empty, from a link), Share a reminder, the friend page with settled history collapsed, the Add friend sheet
// with its code rows, and a deleted payment with Restore — light and dark at text 1.0 and 2.0, plus a small
// phone (320 × 568) at text 1.0; every state passes expectA11y.
import 'package:alchemist/alchemist.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/friend_code/application/friend_code_providers.dart';
import 'package:splitify/features/friend_code/presentation/friend_code_screen.dart';
import 'package:splitify/features/friend_code/presentation/my_code_sheet.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/add_friend_sheet.dart';
import 'package:splitify/features/friends/presentation/friend_page.dart';
import 'package:splitify/features/notifications/application/reminders.dart';
import 'package:splitify/features/notifications/presentation/remind_button.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/application/settle_all_controller.dart';
import 'package:splitify/features/payments/application/upi_providers.dart';
import 'package:splitify/features/payments/presentation/payment_detail_screen.dart';
import 'package:splitify/features/payments/presentation/settle_all_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/l10n/app_localizations_en.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/balances/balance_fixtures.dart';
import '../features/expenses/expense_fixtures.dart' show expenseApp, gid, sampleGroup;
import '../features/friends/friend_fixtures.dart';
import '../features/friends/presentation/friends_harness.dart';
import '../features/payments/settle_all_fixtures.dart';
import '../support/ledger_seed.dart';
import 'golden_support.dart';

const _small = Size(320, 568);

class _FixedCode extends MyFriendCode {
  @override
  Future<String> build() async => 'ABCD2345';
}

class _OfflineCode extends MyFriendCode {
  @override
  Future<String> build() async => throw const FriendCodeFailure(FriendCodeFailureCode.offline);
}

/// A sheet body over its scrim (a routed modal cannot be captured inside alchemist's frame).
class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child});

  final String Function(AppLocalizations l) title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.scrim,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: SingleChildScrollView(
        child: AppSheet(title: title(AppLocalizations.of(context)), child: child),
      ),
    ),
  );
}

List<Friend> _ashaTwoGroups() =>
    friendsOf([goaLedger(), directLedger()], 'u1', profileNames: profileNames);

/// Asha and I are square: a movie and her payment back (settled history collapses).
List<Friend> _settledAsha() => friendsOf(
  [
    ledgerOf(
      seedGroup(id: 'g3', name: 'Me & Asha', type: 'direct'),
      [
        seedMember('c1', groupId: 'g3', name: 'Mohit Bindal', userId: 'u1'),
        seedMember('c2', groupId: 'g3', name: 'Asha', userId: 'u2', position: 1),
      ],
      expenses: [
        seedExpense(
          'e5',
          groupId: 'g3',
          description: 'Movie',
          date: '2026-11-02',
          total: 5000,
          payers: {'c1': 5000},
          shares: {'c1': 2500, 'c2': 2500},
        ),
      ],
      payments: [
        seedPayment('p9', groupId: 'g3', from: 'c2', to: 'c1', amount: 2500, date: '2026-11-04'),
      ],
    ),
  ],
  'u1',
  profileNames: profileNames,
);

List<Override> _batch(SettleAllDraft d, {String? vpa}) => [
  settleAllProvider(settleAllArgs).overrideWith(() => FixedSettleAllController(settleAllArgs, d)),
  upiIdProvider('u2').overrideWith((ref) => Stream.value(vpa)),
];

String _reminderText() => reminderShareText(
  AppLocalizationsEn(),
  name: 'Rahul Mehta',
  owed: const {'INR': 70000},
  groupName: 'Goa trip',
  direct: false,
  myVpa: 'mohit@okaxis',
  myName: 'Mohit Bindal',
);

typedef _Case = (String name, Widget Function() screen, List<Override> Function() overrides);

const _batchScreen = SettleAllScreen(friendKey: 'u:u2', currency: 'INR');

List<_Case> _cases() => [
  (
    'settle_sheet',
    () => _Sheet(
      title: (l) => l.friendSettleTitle('Asha Rao'),
      child: FriendSettlePicker(
        friend: _ashaTwoGroups().firstWhere((f) => f.key == 'u:u2'),
        firstCurrency: 'INR',
        onEverything: (_) {},
        onTransfer: (_, _, _) {},
      ),
    ),
    () => friendOverrides(AsyncData(_ashaTwoGroups())),
  ),
  ('batch_all', () => _batchScreen, () => _batch(sampleSettleAllDraft())),
  ('batch_part', () => _batchScreen, () => _batch(sampleSettleAllDraft(amountText: '300'))),
  ('batch_over', () => _batchScreen, () => _batch(sampleSettleAllDraft(amountText: '500'))),
  (
    'batch_upi',
    () => _batchScreen,
    () => _batch(sampleSettleAllDraft(groups: iOweAshaGroups), vpa: 'asha.rao@okaxis'),
  ),
  (
    'batch_breakdown',
    () => _Sheet(
      title: (l) => l.settle2Across(2),
      child: SettleAllBreakdown(draft: sampleSettleAllDraft(amountText: '300')),
    ),
    () => const [],
  ),
  (
    'my_code',
    () => _Sheet(title: (l) => l.friendCodeMyTitle, child: const MyFriendCodeBody()),
    () => [myFriendCodeProvider.overrideWith(_FixedCode.new)],
  ),
  (
    'my_code_offline',
    () => _Sheet(title: (l) => l.friendCodeMyTitle, child: const MyFriendCodeBody()),
    () => [myFriendCodeProvider.overrideWith(_OfflineCode.new)],
  ),
  ('add_by_code', () => const FriendCodeScreen(), () => const []),
  ('add_by_code_link', () => const FriendCodeScreen(code: 'ABCD2345'), () => const []),
  (
    'share_reminder',
    () => _Sheet(
      title: (l) => l.remindShareTitle,
      child: ShareReminderSheet(text: _reminderText(), onShare: () {}),
    ),
    () => const [],
  ),
  (
    'friend_page_settled',
    () => const FriendPage(friendKey: 'u:u2'),
    () => friendOverrides(AsyncData(_settledAsha())),
  ),
  (
    'add_friend_sheet',
    () => _Sheet(
      title: (l) => l.addFriendTitle,
      child: AddFriendForm(onShowCode: () {}, onScanCode: () {}),
    ),
    () => const [],
  ),
  (
    'payment_deleted',
    () => const PaymentDetailScreen(paymentId: 'p1'),
    () => [
      paymentViewProvider('p1').overrideWithValue(
        AsyncData(
          paymentView(samplePayment().copyWith(deletedAt: const Value('2026-11-21T09:00:00Z'))),
        ),
      ),
      expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
      commentThreadProvider((groupId: gid, targetType: 'payment', targetId: 'p1'))
          .overrideWithValue(const AsyncData([])),
    ],
  ),
];

/// Like [pumpFixedFrames], with the focus taken away (no blinking cursor or keyboard in a golden).
Future<void> _pump(WidgetTester t) async {
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
  await t.pump();
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump(const Duration(milliseconds: 1500));
  await t.pump(const Duration(milliseconds: 100));
  await expectA11y(t);
}

void main() {
  for (final (name, screen, overrides) in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'D-034 B $name ${mode.name} $suffix',
          fileName: 'd034_b_${name}_${mode.name}_$suffix',
          pumpBeforeTest: _pump,
          builder: () => expenseApp(screen(), overrides: overrides(), mode: mode, scale: scale),
        );
      }
    }
  }

  // A small phone: everything still fits or scrolls, the action stays on screen.
  for (final name in [
    'batch_all',
    'batch_upi',
    'my_code',
    'share_reminder',
    'friend_page_settled',
    'add_by_code',
  ]) {
    final (_, screen, overrides) = _cases().firstWhere((c) => c.$1 == name);
    goldenTest(
      'D-034 B $name small phone',
      fileName: 'd034_b_${name}_small_light_text100',
      pumpBeforeTest: _pump,
      builder: () => expenseApp(screen(), overrides: overrides(), size: _small),
    );
  }
}
