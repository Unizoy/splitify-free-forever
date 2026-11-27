// D-033: the + opens the editor at once; "With you and" picks the group or friend on the editor (recent
// groups with covers + friends, search, a new name-only friend), keeps what was typed, and a group page
// opens the editor with its group already picked.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';

import '../expense_fixtures.dart';
import 'presentation_harness.dart';

const ExpenseEditorArgs _plus = (groupId: null, expenseId: null);

ExpenseDraft _unpicked() => ExpenseDraft(
  groupId: '',
  groupName: '',
  currency: 'INR',
  members: const [],
  split: SplitDraft.initial(const [], 2),
  date: DateTime(2026, 11, 21),
  payers: const {},
  categoryOrigin: CategoryOrigin.initial,
  canRepeat: true,
);

/// Records the picks; moving to a group gives the sample Goa trip draft with what was typed.
class _PickingController extends FixedEditorController {
  _PickingController(super.args, super.draft);

  final picked = <String>[];
  bool? keptCurrency;

  @override
  Future<void> pickGroup(String groupId, {bool keepCurrency = false}) async {
    picked.add(groupId);
    keptCurrency = keepCurrency;
    final old = state.value!;
    final fresh = sampleDraft(expenseId: null, amount: '', description: '', canRepeat: true);
    state = AsyncData(fresh.carriedFrom(old, keepCurrency: keepCurrency));
  }
}

class _FakeFriends implements FriendActions {
  final names = <String>[];

  @override
  Future<({String groupId, String key})> addNameOnlyFriend(String name) async {
    names.add(name);
    return (groupId: 'g-new', key: 'm:new');
  }

  @override
  Future<String> expenseGroupFor(Friend friend) async => 'g-${friend.key}';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_PickingController> _open(
  WidgetTester t, {
  ExpenseDraft? draft,
  ExpenseEditorArgs args = _plus,
  List<Override> overrides = const [],
}) async {
  usePhone(t);
  late _PickingController c;
  await t.pumpWidget(
    expenseApp(
      PushHost(ExpenseEditorScreen(groupId: args.groupId)),
      targets: sampleTargets(),
      overrides: [
        expenseEditorProvider(args)
            .overrideWith(() => c = _PickingController(args, draft ?? _unpicked())),
        friendsProvider.overrideWithValue(
          const AsyncData([
            Friend(key: 'u:vikram', name: 'Vikram Shah', seed: 'm9', links: [], balances: {}),
          ]),
        ),
        ...overrides,
      ],
    ),
  );
  await t.tap(find.byKey(const Key('open')));
  await settle(t);
  return c;
}

void main() {
  group('opened from the + (nobody picked)', () {
    testWidgets('shows the dashed chooser and the recent groups and friends as one-tap picks', (
      t,
    ) async {
      await _open(t);
      expect(find.byKey(const Key('expense-with-choose')), findsOneWidget);
      expect(find.text('Choose group or friend'), findsOneWidget);
      expect(find.byKey(const Key('with-quick-$gid')), findsOneWidget);
      expect(find.byKey(const Key('with-quick-g-asha')), findsOneWidget);
      expect(find.text('Asha Rao'), findsOneWidget);
      // Four suggestions at most.
      expect(find.byKey(const Key('with-quick-g-office')), findsOneWidget);
      expect(find.text('Choose a group or friend first'), findsOneWidget);
    });

    testWidgets('a suggestion picks the group and keeps the typed description and amount', (
      t,
    ) async {
      final c = await _open(t);
      await t.enterText(fieldIn('expense-description'), 'Chai');
      await t.enterText(fieldIn('expense-amount'), '240');
      await settle(t);
      await tapKey(t, 'with-quick-$gid');
      expect(c.picked, [gid]);
      expect(c.keptCurrency, isFalse);
      expect(find.byKey(const Key('expense-with-choose')), findsNothing);
      expect(find.byKey(const Key('expense-with-chip')), findsOneWidget);
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.text('Chai'), findsOneWidget);
      expect(find.text('240'), findsOneWidget);
      expect(c.state.value!.description, 'Chai');
      expect(c.state.value!.amountText, '240');
      expect(find.textContaining('split equally'), findsOneWidget);
    });

    testWidgets('Save without a group says so and opens the picker', (t) async {
      final c = await _open(t);
      await t.enterText(fieldIn('expense-description'), 'Chai');
      await t.enterText(fieldIn('expense-amount'), '240');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(t);
      await tapKey(t, 'expense-save');
      await settle(t);
      expect(find.text('Choose who this is with'), findsOneWidget);
      expect(find.byKey(const Key('with-picker')), findsOneWidget);
      expect(c.saves, 0);
      await tapKey(t, 'with-target-g-flat');
      expect(c.picked, ['g-flat']);
      expect(find.byKey(const Key('with-picker')), findsNothing);
      expect(find.text('Choose who this is with'), findsNothing);
    });

    testWidgets('the Paid by pill opens the picker while nobody is picked', (t) async {
      await _open(t);
      await tapKey(t, 'split-summary');
      expect(find.byKey(const Key('with-picker')), findsOneWidget);
      expect(find.byKey(const Key('split-kind')), findsNothing);
    });
  });

  group('the picker', () {
    testWidgets('recent groups (covers) and friends; search narrows both', (t) async {
      await _open(t);
      await tapKey(t, 'expense-with-choose');
      expect(find.text('RECENT'), findsOneWidget);
      for (final id in [gid, 'g-asha', 'g-flat', 'g-office']) {
        expect(find.byKey(Key('with-target-$id')), findsOneWidget);
      }
      expect(find.text('MORE FRIENDS'), findsOneWidget);
      expect(find.byKey(const Key('with-friend-u:vikram')), findsOneWidget);

      await t.enterText(find.byKey(const Key('with-search')), 'fla');
      await settle(t);
      expect(find.byKey(const Key('with-target-g-flat')), findsOneWidget);
      expect(find.byKey(const Key('with-target-$gid')), findsNothing);
      expect(find.byKey(const Key('with-friend-u:vikram')), findsNothing);
      // A name that matches nobody can be added as a friend.
      expect(find.byKey(const Key('with-add-friend')), findsOneWidget);

      await t.enterText(find.byKey(const Key('with-search')), 'vik');
      await settle(t);
      expect(find.byKey(const Key('with-friend-u:vikram')), findsOneWidget);
      expect(find.byKey(const Key('with-target-g-flat')), findsNothing);
    });

    testWidgets('a friend without our group yet goes to the group made for us', (t) async {
      final c = await _open(
        t,
        overrides: [friendActionsProvider.overrideWithValue(_FakeFriends())],
      );
      await tapKey(t, 'expense-with-choose');
      await tapKey(t, 'with-friend-u:vikram');
      expect(c.picked, ['g-u:vikram']);
    });

    testWidgets('a new name becomes a name-only friend and is picked', (t) async {
      final friends = _FakeFriends();
      final c = await _open(t, overrides: [friendActionsProvider.overrideWithValue(friends)]);
      await tapKey(t, 'expense-with-choose');
      await t.enterText(find.byKey(const Key('with-search')), 'Neha');
      await settle(t);
      expect(find.text('Add “Neha” as a friend'), findsOneWidget);
      await tapKey(t, 'with-add-friend');
      expect(friends.names, ['Neha']);
      expect(c.picked, ['g-new']);
    });

    testWidgets('a chosen currency stays when the group changes', (t) async {
      final c = await _open(
        t,
        draft: sampleDraft(expenseId: null, amount: '', description: '', canRepeat: true),
        args: newArgs,
      );
      await tapKey(t, 'expense-currency');
      // The picker first asks the group's currency (no database here: it gives up after 2 s).
      await t.pump(const Duration(seconds: 3));
      await settle(t);
      await t.enterText(
        find.descendant(
          of: find.byKey(const Key('currency-search')),
          matching: find.byType(TextField),
        ),
        'USD',
      );
      await settle(t);
      await tapKey(t, 'currency-found-USD');
      expect(c.state.value!.currency, 'USD');
      await tapKey(t, 'expense-with-chip');
      await tapKey(t, 'with-target-g-flat');
      expect(c.keptCurrency, isTrue);
      expect(c.state.value!.currency, 'USD');
    });
  });

  group('opened from a group', () {
    testWidgets('the group is picked; the chip opens the picker with it checked', (t) async {
      final c = await _open(
        t,
        draft: sampleDraft(expenseId: null, amount: '', description: '', canRepeat: true),
        args: newArgs,
      );
      expect(find.byKey(const Key('expense-with-choose')), findsNothing);
      expect(find.byKey(const Key('with-suggestions')), findsNothing);
      expect(find.text('Goa trip'), findsOneWidget);
      await tapKey(t, 'expense-with-chip');
      final row = find.byKey(const Key('with-target-$gid'));
      expect(
        t.getSemantics(row),
        matchesSemantics(
          label: 'Goa trip',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      // Picking the same group changes nothing.
      await tapKey(t, 'with-target-$gid');
      expect(c.picked, isEmpty);
    });

    testWidgets('a saved expense keeps its group: the chip is read-only', (t) async {
      usePhone(t);
      await pumpEditor(t, sampleDraft());
      expect(find.byKey(const Key('expense-with')), findsOneWidget);
      expect(find.byKey(const Key('expense-with-chip')), findsNothing);
      await t.tap(find.text('Goa trip'));
      await settle(t);
      expect(find.byKey(const Key('with-picker')), findsNothing);
    });
  });
}
