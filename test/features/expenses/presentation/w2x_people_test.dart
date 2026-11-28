// W2-X: "With you and" several friends (F11, chips + "+" + remove), "From contacts" (F15) and "Save as group
// default" in the paid/split sheet (P-10), on the one-screen editor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/domain/rules/default_split.dart';
import 'package:splitify/features/expenses/application/default_split_controller.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/friends/application/contact_picker.dart';
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';

import '../expense_fixtures.dart';
import 'presentation_harness.dart';

const _adhoc = 'g-adhoc';
const ExpenseEditorArgs _newAdhoc = (groupId: _adhoc, expenseId: null);
const ExpenseEditorArgs _newDirect = (groupId: 'g-asha', expenseId: null);

const _asha = Friend(
  key: 'u:asha',
  name: 'Asha Rao',
  seed: 'm2',
  links: [],
  balances: {},
  userId: 'asha',
);
const _rahul = Friend(
  key: 'm:rahul',
  name: 'Rahul Mehta',
  seed: 'm3',
  links: [],
  balances: {},
  tint: 2,
);
const _vikram = Friend(key: 'u:vikram', name: 'Vikram Shah', seed: 'm9', links: [], balances: {});

ExpenseDraft _draft({String groupId = _adhoc, String type = 'adhoc', List<EditorMember>? members}) {
  final ms =
      members ??
      const <EditorMember>[
        (id: 'm1', name: 'Mohit Bindal', isMe: true),
        (id: 'm2', name: 'Asha Rao', isMe: false),
        (id: 'm3', name: 'Rahul Mehta', isMe: false),
      ];
  return ExpenseDraft(
    groupId: groupId,
    groupName: 'Mohit, Asha & Rahul',
    groupType: type,
    currency: 'INR',
    members: ms,
    split: SplitDraft.initial([for (final m in ms) m.id], 2),
    date: DateTime(2026, 11, 21),
    payerId: 'm1',
    payers: const {},
    amountText: '900',
    description: 'Dinner',
    canRepeat: true,
  );
}

/// Records where the editor moves.
class _MovingController extends FixedEditorController {
  _MovingController(super.args, super.draft);

  final moved = <String>[];

  @override
  Future<void> pickGroup(String groupId, {bool keepCurrency = false}) async {
    moved.add(groupId);
    state = AsyncData(_draft(groupId: groupId));
  }
}

class _FakeFriends implements FriendActions {
  final calls = <({List<String> keys, List<String> names})>[];

  @override
  Future<String> expenseGroupWith(
    List<Friend> friends, {
    List<String> newNames = const [],
    String Function(int n)? more,
  }) async {
    calls.add((keys: [for (final f in friends) f.key], names: newNames));
    return 'g-${friends.length + newNames.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeContacts implements ContactPicker {
  _FakeContacts(this.name, {this.fail = false});

  final String? name;
  final bool fail;
  int opened = 0;

  @override
  Future<String?> pickName() async {
    opened++;
    if (fail) throw const ContactPickFailed();
    return name;
  }
}

Future<({_MovingController c, _FakeFriends friends})> _open(
  WidgetTester t, {
  ExpenseDraft? draft,
  ExpenseEditorArgs args = _newAdhoc,
  List<Friend> people = const [_asha, _rahul],
  List<Override> overrides = const [],
}) async {
  final friends = _FakeFriends();
  final d = draft ?? _draft();
  final h = await pumpEditor(
    t,
    d,
    args: args,
    make: _MovingController.new,
    overrides: [
      groupFriendsProvider(d.groupId).overrideWithValue(people),
      friendsProvider.overrideWithValue(const AsyncData([_asha, _rahul, _vikram])),
      friendActionsProvider.overrideWithValue(friends),
      ...overrides,
    ],
  );
  return (c: h.controller! as _MovingController, friends: friends);
}

void main() {
  group('F11 several friends', () {
    testWidgets('every person is a chip with a remove button, and "+" adds one more', (t) async {
      await _open(t);
      expect(find.byKey(const Key('expense-with-people')), findsOneWidget);
      expect(find.byKey(const Key('expense-with-person-u:asha')), findsOneWidget);
      expect(find.byKey(const Key('expense-with-person-m:rahul')), findsOneWidget);
      expect(find.byKey(const Key('expense-with-remove-u:asha')), findsOneWidget);
      expect(find.byKey(const Key('expense-with-add')), findsOneWidget);
      expect(find.bySemanticsLabel('Remove Asha Rao'), findsOneWidget);
      expect(find.bySemanticsLabel('Add another person'), findsOneWidget);
    });

    testWidgets(
      '"+" lists only friends not in it yet; picking one moves to the group of all three',
      (t) async {
        final o = await _open(t);
        await tapKey(t, 'expense-with-add');
        expect(find.text('Add a person'), findsOneWidget);
        expect(find.byKey(const Key('with-friend-u:vikram')), findsOneWidget);
        expect(find.byKey(const Key('with-friend-u:asha')), findsNothing);
        expect(find.byKey(const Key('with-friend-m:rahul')), findsNothing);
        // No groups in this list: people are added one by one.
        expect(find.text('RECENT'), findsNothing);
        await tapKey(t, 'with-friend-u:vikram');
        await settle(t);
        expect(o.friends.calls.single.keys, ['u:asha', 'm:rahul', 'u:vikram']);
        expect(o.c.moved, ['g-3']);
        // What was typed stays.
        expect(o.c.state.value!.description, 'Dinner');
      },
    );

    testWidgets('a typed new name joins as a new person (no friend sheet first)', (t) async {
      final o = await _open(t);
      await tapKey(t, 'expense-with-add');
      await t.enterText(find.byKey(const Key('with-search')), 'Neha');
      await settle(t);
      expect(find.text('Add “Neha”'), findsOneWidget);
      await tapKey(t, 'with-add-friend');
      await settle(t);
      expect(o.friends.calls.single.keys, ['u:asha', 'm:rahul']);
      expect(o.friends.calls.single.names, ['Neha']);
    });

    testWidgets('the remove button leaves the others', (t) async {
      final o = await _open(t);
      await tapKey(t, 'expense-with-remove-m:rahul');
      await settle(t);
      expect(o.friends.calls.single.keys, ['u:asha']);
      expect(o.c.moved, ['g-1']);
    });

    testWidgets('a friend expense (one friend) shows the chip and "+", no remove', (t) async {
      final o = await _open(
        t,
        args: _newDirect,
        draft: _draft(
          groupId: 'g-asha',
          type: 'direct',
          members: const [
            (id: 'm1', name: 'Mohit Bindal', isMe: true),
            (id: 'm2', name: 'Asha Rao', isMe: false),
          ],
        ),
        people: const [_asha],
      );
      expect(find.byKey(const Key('expense-with-person-u:asha')), findsOneWidget);
      expect(find.byKey(const Key('expense-with-remove-u:asha')), findsNothing);
      await tapKey(t, 'expense-with-add');
      await tapKey(t, 'with-friend-m:rahul');
      await settle(t);
      expect(o.friends.calls.single.keys, ['u:asha', 'm:rahul']);
    });

    testWidgets('a saved expense keeps its people: no "+" and no remove', (t) async {
      final draft = ExpenseDraft(
        groupId: _adhoc,
        groupName: 'x',
        groupType: 'adhoc',
        expenseId: 'e1',
        currency: 'INR',
        members: _draft().members,
        split: _draft().split,
        date: DateTime(2026, 11, 21),
        payerId: 'm1',
        payers: const {},
        amountText: '900',
        description: 'Dinner',
      );
      await _open(t, draft: draft, args: editArgs);
      expect(find.byKey(const Key('expense-with-person-u:asha')), findsOneWidget);
      expect(find.byKey(const Key('expense-with-add')), findsNothing);
      expect(find.byKey(const Key('expense-with-remove-u:asha')), findsNothing);
    });
  });

  group('F15 from contacts', () {
    testWidgets('a contact who is a friend is that friend', (t) async {
      final contacts = _FakeContacts('  vikram   shah ');
      final o = await _open(t, overrides: [contactPickerProvider.overrideWithValue(contacts)]);
      await tapKey(t, 'expense-with-add');
      expect(find.text('From contacts'), findsOneWidget);
      await tapKey(t, 'with-contacts');
      await settle(t);
      expect(contacts.opened, 1);
      expect(o.friends.calls.single.keys, ['u:asha', 'm:rahul', 'u:vikram']);
      expect(o.friends.calls.single.names, isEmpty);
    });

    testWidgets('another contact joins by name', (t) async {
      final o = await _open(
        t,
        overrides: [contactPickerProvider.overrideWithValue(_FakeContacts('Zoya Khan'))],
      );
      await tapKey(t, 'expense-with-add');
      await tapKey(t, 'with-contacts');
      await settle(t);
      expect(o.friends.calls.single.names, ['Zoya Khan']);
    });

    testWidgets('backing out of the picker changes nothing', (t) async {
      final o = await _open(
        t,
        overrides: [contactPickerProvider.overrideWithValue(_FakeContacts(null))],
      );
      await tapKey(t, 'expense-with-add');
      await tapKey(t, 'with-contacts');
      await settle(t);
      expect(o.friends.calls, isEmpty);
      expect(find.text('Add a person'), findsOneWidget);
    });

    testWidgets('no contacts app: says so, keeps the sheet', (t) async {
      final o = await _open(
        t,
        overrides: [contactPickerProvider.overrideWithValue(_FakeContacts(null, fail: true))],
      );
      await tapKey(t, 'expense-with-add');
      await tapKey(t, 'with-contacts');
      await settle(t);
      expect(find.text("Couldn't open your contacts"), findsOneWidget);
      expect(o.friends.calls, isEmpty);
    });

    test('contact names are folded and capped at 50 characters', () {
      expect(cleanContactName('  Asha \n  Rao  '), 'Asha Rao');
      expect(cleanContactName('x' * 80).length, 50);
    });
  });

  group('P-10 save as group default', () {
    testWidgets('the tick shows for a split that can be a default and saves with the expense', (
      t,
    ) async {
      final saved = <ExpenseDraft>[];
      final h = await pumpEditor(
        t,
        sampleDraft(expenseId: null, split: SplitDraft.initial(ids, 2)),
        args: newArgs,
        overrides: [
          saveDraftAsDefaultProvider.overrideWithValue((d) async {
            saved.add(d);
            return true;
          }),
        ],
      );
      await openPaidSplit(t);
      await tapKey(t, 'payer-m2');
      await reveal(t, find.byKey(const Key('paid-split-save-default')));
      expect(find.text('Save as group default'), findsOneWidget);
      await tapKey(t, 'paid-split-save-default');
      await tapKey(t, 'paid-split-done');
      await tapKey(t, 'expense-save');
      await settle(t, 12);
      expect(h.controller!.saves, 1);
      expect(saved.single.payerId, 'm2');
      expect(defaultFromDraft(saved.single)!.payer, 'm2');
    });

    testWidgets('untouched, nothing is saved as a default', (t) async {
      final saved = <ExpenseDraft>[];
      await pumpEditor(
        t,
        sampleDraft(expenseId: null, split: SplitDraft.initial(ids, 2)),
        args: newArgs,
        overrides: [
          saveDraftAsDefaultProvider.overrideWithValue((d) async {
            saved.add(d);
            return true;
          }),
        ],
      );
      await tapKey(t, 'expense-save');
      await settle(t, 12);
      expect(saved, isEmpty);
    });

    testWidgets('exact amounts can not be a default: no tick', (t) async {
      await pumpEditor(t, sampleDraft(kind: SplitKind.exact, expenseId: null), args: newArgs);
      await openPaidSplit(t);
      expect(find.byKey(const Key('paid-split-save-default')), findsNothing);
    });

    test(
      'defaultFromDraft: equal for everyone, percent and shares; not some people or several payers',
      () {
        final all = sampleDraft(split: SplitDraft.initial(ids, 2));
        expect(defaultFromDraft(all)!.toJson(), {
          'kind': 'equal',
          'values': <String, int>{},
          'payer': 'm1',
        });
        expect(defaultFromDraft(sampleDraft()), isNull, reason: 'equal between three of four');
        final pct = defaultFromDraft(sampleDraft(kind: SplitKind.percent))!;
        expect(pct.kind, SplitKind.percent);
        expect(pct.values, {'m1': 4000, 'm2': 3000, 'm3': 2000, 'm4': 1000});
        expect(pct.resolve(ids), isNotNull);
        final shares = defaultFromDraft(sampleDraft(kind: SplitKind.shares))!;
        expect(shares.values['m4'], 0);
        expect(defaultFromDraft(sampleDraft(kind: SplitKind.adjust)), isNull);
        expect(defaultFromDraft(all.withMultiplePayers()), isNull);
      },
    );

    test('the stored default carries the payer; payerIn drops one who left', () {
      const d = DefaultSplit(SplitKind.equal, {}, 'm2');
      final back = DefaultSplit.decode('{"kind":"equal","values":{},"payer":"m2"}')!;
      expect(back.payer, 'm2');
      expect(back.payerIn(['m1', 'm2']), 'm2');
      expect(back.payerIn(['m1']), isNull);
      expect(d.isPlain, isFalse);
      expect(const DefaultSplit(SplitKind.equal).isPlain, isTrue);
      expect(DefaultSplit.decode('{"kind":"equal","values":{},"payer":""}')!.payer, isNull);
      expect(DefaultSplit.decode('{"kind":"percent","values":{"a":10000}}')!.payer, isNull);
    });
  });
}
