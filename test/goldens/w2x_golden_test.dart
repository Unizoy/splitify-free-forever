// W2-X goldens: "With you and" several friends (chips, remove, +), the add-person sheet with "From contacts", the
// paid/split sheet with "Save as group default", the default split sheet with a default payer, and "Show in INR"
// on a friend's page and the Home overall card — light and dark at text 1.0 and 2.0, plus a small phone
// (320 x 568) at text 1.0. Every state runs the a11y guidelines (expectA11y in pumpFixedFrames).
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/core/money/split.dart';
import 'package:splitify/data/data_providers.dart' show appDatabaseProvider, syncRepositoryProvider;
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' show profileProvider;
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/currency/application/in_currency_providers.dart';
import 'package:splitify/features/currency/domain/in_currency.dart';
import 'package:splitify/features/expenses/application/default_split_controller.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/default_split_sheet.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/editor/paid_split_sheet.dart';
import 'package:splitify/features/expenses/presentation/editor/with_picker.dart';
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/friend_page.dart';
import 'package:splitify/features/groups/application/groups_providers.dart' show syncNowProvider;
import 'package:splitify/features/groups/presentation/groups_home_screen.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart'
    show unreadNotificationsProvider;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/expenses/expense_fixtures.dart';
import '../features/friends/friend_fixtures.dart' as ff;
import '../features/friends/presentation/friends_harness.dart';
import '../support/fakes.dart' show FakeSyncRepository, testDb;
import '../support/group_fakes.dart' as gf;
import '../support/group_harness.dart' show fixedGroupData;
import 'golden_support.dart';

const _small = Size(320, 568);
const _adhoc = 'g-adhoc';

const _asha = Friend(
  key: 'u:asha',
  name: 'Asha Rao',
  seed: 'm2',
  links: [],
  balances: {},
  userId: 'asha',
  tint: 1,
);
const _rahul = Friend(
  key: 'm:rahul',
  name: 'Rahul Mehta',
  seed: 'm3',
  links: [],
  balances: {},
  tint: 2,
);
const _neha = Friend(
  key: 'm:neha',
  name: 'Neha Kapoor',
  seed: 'm5',
  links: [],
  balances: {},
  tint: 3,
);
const _vikram = Friend(
  key: 'u:vikram',
  name: 'Vikram Shah',
  seed: 'm9',
  links: [],
  balances: {},
  tint: 4,
);

ExpenseDraft _adhocDraft() {
  const ms = <EditorMember>[
    (id: 'm1', name: 'Mohit Bindal', isMe: true),
    (id: 'm2', name: 'Asha Rao', isMe: false),
    (id: 'm3', name: 'Rahul Mehta', isMe: false),
  ];
  return ExpenseDraft(
    groupId: _adhoc,
    groupName: 'Mohit, Asha & Rahul',
    groupType: 'adhoc',
    currency: 'INR',
    members: ms,
    split: SplitDraft.initial([for (final m in ms) m.id], 2),
    date: fixedToday,
    payerId: 'm1',
    payers: const {},
    amountText: '900',
    description: 'Dinner at Bastian',
    category: 'food.dining_out',
    canRepeat: true,
  );
}

class _SheetHost extends StatelessWidget {
  const _SheetHost({required this.title, required this.child});

  final String Function(AppLocalizations l) title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.scrim,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AppSheet(title: title(AppLocalizations.of(context)), child: child),
    ),
  );
}

class _ShowInOn extends ShowInHomeCurrency {
  @override
  bool build() => true;
}

const ExpenseEditorArgs _newAdhoc = (groupId: _adhoc, expenseId: null);

typedef _Case = (
  String name,
  Widget Function() screen,
  List<Override> Function() overrides,
  double height,
);

List<_Case> _cases() => [
  (
    'editor_people',
    () => const ExpenseEditorScreen(groupId: _adhoc),
    () => [
      expenseEditorProvider(_newAdhoc)
          .overrideWith(() => FixedEditorController(_newAdhoc, _adhocDraft())),
      groupFriendsProvider(_adhoc).overrideWithValue(const [_asha, _rahul]),
      friendsProvider.overrideWithValue(const AsyncData([_asha, _rahul, _neha, _vikram])),
    ],
    915,
  ),
  (
    'add_person',
    () => _SheetHost(
      title: (l) => l.w2xAddPersonTitle,
      child: WithPicker(
        addPerson: true,
        exclude: const {'u:asha', 'm:rahul'},
        onPicked: (_) {},
        onPerson: (_) {},
      ),
    ),
    () => [
      friendsProvider.overrideWithValue(const AsyncData([_asha, _rahul, _neha, _vikram])),
    ],
    915,
  ),
  (
    'paid_split_default',
    () => _SheetHost(
      title: (l) => l.expPaidSplitTitle,
      child: PaidSplitPanel(
        draft: sampleDraft(
          expenseId: null,
          split: SplitDraft.initial(ids, 2),
        ).withSinglePayer('m2'),
        onPayer: (_) {},
        onMultiple: () {},
        onPayerText: (_, _) {},
        onSplit: (_) {},
        onDone: () {},
        saveAsDefault: true,
        onSaveAsDefault: (_) {},
      ),
    ),
    () => const [],
    1100,
  ),
  (
    'default_split_payer',
    () => _SheetHost(
      title: (l) => l.expDefaultSplitTitle,
      child: DefaultSplitSheet(groupId: gid, onSaved: () {}),
    ),
    () => [
      defaultSplitProvider(gid).overrideWith(
        () => FixedDefaultSplitController(
          gid,
          DefaultSplitState(
            groupName: 'Goa trip',
            members: people,
            split: SplitDraft.initial(
              ids,
              2,
            ).withValues(SplitKind.shares, {'m1': 2000, 'm2': 1000, 'm3': 1000, 'm4': 1000}),
            payer: 'm2',
          ),
        ),
      ),
    ],
    1100,
  ),
  (
    'friend_in_inr',
    () => const FriendPage(friendKey: 'u:u2'),
    () => [
      ...friendOverrides(AsyncData(friendsOf([ff.twoCurrencyLedger(), ff.directLedger()], 'u1'))),
      showInHomeCurrencyProvider.overrideWith(_ShowInOn.new),
    ],
    915,
  ),
  (
    'home_in_inr',
    // Nested: these replace some of the editor harness's own overrides.
    () => ProviderScope(
      overrides: [
        ...fixedGroupData(
          groups: <LocalGroup>[gf.sampleGroup(id: 'g-w2x', name: 'Goa trip')],
          my: const MyBalances(
            totals: {'INR': 135000, 'USD': 2500},
            byGroup: {
              'g-w2x': {'INR': 135000, 'USD': 2500},
            },
            people: [],
          ),
        ),
        appDatabaseProvider.overrideWithValue(testDb()),
        unreadNotificationsProvider.overrideWith((ref) => Stream.value(2)),
        syncNowProvider.overrideWithValue(() async {}),
        syncRepositoryProvider.overrideWithValue(FakeSyncRepository()),
        profileProvider.overrideWith(FixedProfile.new),
        showInHomeCurrencyProvider.overrideWith(_ShowInOn.new),
        myTotalInProvider('INR').overrideWithValue(
          const InCurrency(
            currency: 'INR',
            amount: 155875,
            notConverted: {'EUR': 1200},
            counted: true,
          ),
        ),
      ],
      child: const GroupsHomeScreen(),
    ),
    () => const [],
    915,
  ),
];

void main() {
  for (final (name, screen, overrides, height) in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'w2x $name ${mode.name} $suffix',
          fileName: 'w2x_${name}_${mode.name}_$suffix',
          pumpBeforeTest: pumpFixedFrames,
          builder: () => expenseApp(
            screen(),
            overrides: overrides(),
            mode: mode,
            scale: scale,
            size: Size(goldenWidth, height),
          ),
        );
      }
    }
    goldenTest(
      'w2x $name small phone',
      fileName: 'w2x_${name}_small_light_text100',
      pumpBeforeTest: pumpFixedFrames,
      builder: () => expenseApp(screen(), overrides: overrides(), size: _small),
    );
  }
}
