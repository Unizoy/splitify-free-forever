// D-034 WP-A smart entry, application layer.
// TC-D034-A1-01 two-person answers: the draft each answer makes, live with the amount, saved offline
// TC-D034-A2-03 Items split: draft checks, saved as exact + split_values.itemized, reopens with the lines
// TC-D034-A3-05 scan apply: ticks, never overwrites typed values without a tick, itemize prefill
// TC-D034-A5-01 (focus fix is a widget test)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/domain/rules/receipt_text_parser.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/itemize_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/application/two_person.dart';
import 'package:splitify/features/receipt_scan/application/scan_apply.dart';

import 'dart:typed_data';

import 'expense_test_env.dart';

const _members = <EditorMember>[
  (id: 'me', name: 'Mohit', isMe: true),
  (id: 'asha', name: 'Asha', isMe: false),
];

ExpenseDraft _two({String amount = '300', List<EditorMember> members = _members}) => ExpenseDraft(
  groupId: 'g',
  groupName: 'Asha',
  groupType: 'direct',
  currency: 'INR',
  members: members,
  split: SplitDraft.initial([for (final m in members) m.id], 2),
  date: DateTime(2026, 11, 21),
  payerId: 'me',
  payers: const {},
  amountText: amount,
  description: 'Movie',
);

Map<String, Object?> _row(ExpenseDraft d) => d.toRow();

Matcher _invalid(String code, [int amount = 0]) => isA<SplitInvalid>()
    .having((s) => s.code, 'code', code)
    .having((s) => s.amount, 'amount', amount);

void main() {
  group('two-person answers', () {
    test('only for exactly me + one other person in a picked group', () {
      expect(_two().twoPeople, isTrue);
      expect(_two().otherPerson?.id, 'asha');
      expect(
        _two(members: [..._members, (id: 'ravi', name: 'Ravi', isMe: false)]).twoPeople,
        isFalse,
      );
      expect(
        _two(members: const [(id: 'a', name: 'A', isMe: false), (id: 'b', name: 'B', isMe: false)])
            .twoPeople,
        isFalse,
      );
      final unpicked = ExpenseDraft(
        groupId: '',
        groupName: '',
        currency: 'INR',
        members: _members,
        split: SplitDraft.initial(const ['me', 'asha'], 2),
        date: DateTime(2026, 11, 21),
        payers: const {},
      );
      expect(unpicked.twoPeople, isFalse);
    });

    test('a new draft reads as "You paid, split equally"', () {
      expect(_two().twoPersonAnswer, TwoPersonAnswer.youPaidEqual);
    });

    test('each answer saves the right payer and shares (₹300)', () {
      final cases = {
        TwoPersonAnswer.youPaidEqual: (
          payers: {'me': 30000},
          shares: {'me': 15000, 'asha': 15000},
          kind: 'equal',
          net: 15000,
        ),
        TwoPersonAnswer.youOwedFull: (
          payers: {'me': 30000},
          shares: {'me': 0, 'asha': 30000},
          kind: 'exact',
          net: 30000,
        ),
        TwoPersonAnswer.theyPaidEqual: (
          payers: {'asha': 30000},
          shares: {'me': 15000, 'asha': 15000},
          kind: 'equal',
          net: -15000,
        ),
        TwoPersonAnswer.theyOwedFull: (
          payers: {'asha': 30000},
          shares: {'me': 30000, 'asha': 0},
          kind: 'exact',
          net: -30000,
        ),
      };
      for (final MapEntry(key: a, value: want) in cases.entries) {
        final d = _two().withAnswer(a);
        final row = _row(d);
        expect(row['kind'], 'expense', reason: '$a is a normal expense, not a loan');
        expect(row['payers'], want.payers, reason: '$a');
        expect(row['shares'], want.shares, reason: '$a');
        expect(row['split_kind'], want.kind, reason: '$a');
        expect(d.twoPersonAnswer, a);
        expect(_two().netFor(a), want.net, reason: '$a');
      }
    });

    test('"owed the full amount" follows the amount as it is typed (and an empty amount)', () {
      var d = _two(amount: '').withAnswer(TwoPersonAnswer.youOwedFull);
      expect(d.netFor(TwoPersonAnswer.youOwedFull), isNull);
      d = d.copyWith(amountText: '4');
      expect(_row(d)['shares'], {'me': 0, 'asha': 400});
      d = d.copyWith(amountText: '450.50');
      expect(_row(d)['shares'], {'me': 0, 'asha': 45050});
      expect(d.canSave, isTrue);
      // A currency change keeps it too.
      d = d.withCurrency('JPY').copyWith(amountText: '1200');
      expect(_row(d)['shares'], {'me': 0, 'asha': 1200});
    });

    test('an odd paisa of an equal split goes to the first person in member order', () {
      final d = _two(amount: '3.01').withAnswer(TwoPersonAnswer.theyPaidEqual);
      expect(_row(d)['shares'], {'me': 151, 'asha': 150});
      expect(d.netFor(TwoPersonAnswer.theyPaidEqual), -151);
    });

    test('any other payer or split change ends the answer', () {
      final d = _two().withAnswer(TwoPersonAnswer.youOwedFull);
      expect(d.withSinglePayer('asha').answer, isNull);
      expect(d.copyWith(split: d.split.switchTo(SplitKind.shares)).answer, isNull);
      expect(d.withMultiplePayers().answer, isNull);
      expect(d.copyWith(description: 'x').answer, TwoPersonAnswer.youOwedFull);
    });

    test('a saved "owed the full amount" (exact or equal on one person) is recognised', () {
      final exact = _two().copyWith(
        split: SplitDraft.initial(const [
          'me',
          'asha',
        ], 2).withValues(SplitKind.exact, {'asha': 30000}),
      );
      expect(exact.twoPersonAnswer, TwoPersonAnswer.youOwedFull);
      final equalOne = _two().copyWith(
        payerId: 'asha',
        split: SplitDraft.initial(const ['me', 'asha'], 2).toggle('asha'),
      );
      expect(equalOne.twoPersonAnswer, TwoPersonAnswer.theyOwedFull);
      final shares = _two().copyWith(split: _two().split.switchTo(SplitKind.shares));
      // A split the four answers cannot show opens the full sheet.
      expect(shares.twoPersonAnswer, isNull);
    });
  });

  group('Items split draft', () {
    SplitDraft items(List<String> people) => SplitDraft.initial(people, 2).switchToItems();

    test('switching to Items starts one empty line for the chosen people', () {
      final s = SplitDraft.initial(const ['a', 'b', 'c'], 2).toggle('c').switchToItems();
      expect(s.isItems, isTrue);
      expect(s.kind, SplitKind.exact);
      expect(s.items!.items.single.members, {'a', 'b'});
      expect(s.check(1000), _invalid('NO_SHARES'));
    });

    test('acceptance: ₹1,000 = 400 (A) + 350 (A, B) + 150 (B) + ₹100 tax → shares add up', () {
      var it = items(const ['a', 'b']).items!;
      final k0 = it.items.first.key;
      it = it.setAmount(k0, '400').toggleMember(k0, 'b');
      it = it.addItem(const ['a', 'b']);
      it = it.setAmount(it.items[1].key, '350');
      it = it.addItem(const ['b']);
      it = it.setAmount(it.items[2].key, '150').setExtra(ItemExtra.tax, '100');
      final s = items(const ['a', 'b']).withItems(it);
      expect(s.valueSum, 100000);
      final check = s.check(100000);
      expect(check, isA<SplitReady>());
      final shares = (check as SplitReady).shares;
      expect(shares, {'a': 63889, 'b': 36111});
      expect(shares.values.reduce((x, y) => x + y), 100000);
      expect(s.check(90000), _invalid('SUM_MISMATCH', -10000));
      expect(s.check(110000), _invalid('SUM_MISMATCH', 10000));
    });

    test('problems: a priced line without people, bad text, too large to save', () {
      var it = items(const ['a']).items!;
      final k = it.items.first.key;
      final nobody = it.setAmount(k, '10').toggleMember(k, 'a');
      expect(items(const ['a']).withItems(nobody).check(1000), _invalid('NO_PARTICIPANTS'));
      final bad = it.setAmount(k, '1.234');
      expect(items(const ['a']).withItems(bad).check(1000), _invalid('INVALID_INPUT'));
      final people = [for (var i = 0; i < 100; i++) 'member-with-a-long-uuid-like-id-$i'];
      var big = SplitDraft.initial(people, 2).switchToItems().items!;
      for (var i = 0; i < maxItems; i++) {
        big = big.addItem(people);
      }
      for (final line in big.items) {
        big = big.setAmount(line.key, '1').setName(line.key, 'x' * 60);
      }
      final s = SplitDraft.initial(people, 2).withItems(big);
      expect(s.check(s.valueSum), _invalid(SplitInvalid.itemsTooLarge));
    });

    test('Items → exact amounts keeps what the lines gave each person', () {
      var it = items(const ['a', 'b']).items!;
      it = it.setAmount(it.items.first.key, '100');
      final exact = items(const ['a', 'b']).withItems(it).switchTo(SplitKind.exact);
      expect(exact.isItems, isFalse);
      expect(exact.values, {'a': 5000, 'b': 5000});
    });

    test('toRow stores exact shares + split_values.itemized (minor units, fixed member order)', () {
      var it = SplitDraft.initial(const ['m1', 'm2'], 2).switchToItems().items!;
      final k = it.items.first.key;
      it = it.setName(k, 'Dosa').setAmount(k, '180').addItem(const ['m2', 'm1']);
      it = it.setAmount(it.items[1].key, '20').setExtra(ItemExtra.service, '10');
      final d = _two(
        members: const [
          (id: 'm1', name: 'Mohit', isMe: true),
          (id: 'm2', name: 'Asha', isMe: false),
        ],
        amount: '210',
      ).copyWith(split: SplitDraft.initial(const ['m1', 'm2'], 2).withItems(it));
      final row = d.toRow();
      expect(row['split_kind'], 'exact');
      expect(row['shares'], {'m1': 10500, 'm2': 10500});
      final values = row['split_values']! as Map<String, Object?>;
      expect(values['m1'], 10500);
      expect(values[itemizedKey], {
        'v': 1,
        'items': [
          {
            'name': 'Dosa',
            'amount': 18000,
            'members': ['m1', 'm2'],
          },
          {
            'amount': 2000,
            'members': ['m1', 'm2'],
          },
        ],
        'extras': {'tax': 0, 'service': 1000, 'tip': 0, 'discount': 0},
      });
      // And reads back.
      final back = ItemizeDraft.fromStored(jsonEncode(values), 2)!;
      expect([for (final i in back.items) i.name], ['Dosa', '']);
      expect([for (final i in back.items) i.amountText], ['180', '20']);
      expect(back.extras, {ItemExtra.service: '10'});
      expect(ItemizeDraft.fromStored('{"m1": 100}', 2), isNull);
      expect(ItemizeDraft.fromStored('not json', 2), isNull);
    });

    test(
      'saved offline through the outbox, then reopens in the Items editor with the lines',
      () async {
        final env = await ExpenseEnv.create(others: const ['Asha']);
        addTearDown(env.dispose);
        final editor = await env.open();
        final a = env.me;
        final b = env.ids['Asha']!;
        editor.edit((d) {
          var it = d.split.switchToItems().items!;
          final k = it.items.first.key;
          it = it.setName(k, 'Paneer').setAmount(k, '400').toggleMember(k, b);
          it = it.addItem([a, b]);
          it = it.setName(it.items[1].key, 'Naan').setAmount(it.items[1].key, '350');
          it = it.addItem([b]);
          it = it.setAmount(it.items[2].key, '150').setExtra(ItemExtra.tax, '100');
          return d.copyWith(
            description: 'Dinner',
            amountText: '1000',
            split: d.split.withItems(it),
          );
        });
        expect(editor.draft.canSave, isTrue);
        final id = (await editor.save())!;
        final row = await (env.db.select(
          env.db.expenses,
        )..where((e) => e.id.equals(id))).getSingle();
        expect(row.splitKind, 'exact');
        expect(row.syncState, SyncState.pending);
        final shares = (jsonDecode(row.shares) as Map).cast<String, int>();
        expect(shares.values.reduce((x, y) => x + y), 100000);
        expect(shares, {a: 63889, b: 36111});
        final out = await env.db.select(env.db.outbox).get();
        final payload = jsonDecode(out.last.payload) as Map<String, Object?>;
        expect((payload['split_values']! as Map)[itemizedKey], isA<Map<String, Object?>>());

        final reopened = await env.open(expenseId: id);
        final s = reopened.draft.split;
        expect(s.isItems, isTrue);
        expect([for (final i in s.items!.items) i.name], ['Paneer', 'Naan', '']);
        expect([for (final i in s.items!.items) i.amountText], ['400', '350', '150']);
        expect(s.items!.items.first.members, {a});
        expect(s.items!.extras[ItemExtra.tax], '100');
        expect(reopened.draft.canSave, isTrue);
      },
    );

    test('a two-person "owed the full amount" saves offline and counts as an expense', () async {
      final env = await ExpenseEnv.create(others: const ['Asha']);
      addTearDown(env.dispose);
      final editor = await env.open();
      editor.edit(
        (d) => d
            .copyWith(description: 'Cab', amountText: '300')
            .withAnswer(TwoPersonAnswer.youOwedFull),
      );
      final id = (await editor.save())!;
      final row = await (env.db.select(env.db.expenses)..where((e) => e.id.equals(id))).getSingle();
      expect(row.kind, 'expense');
      expect(row.syncState, SyncState.pending);
      expect(jsonDecode(row.shares), {env.me: 0, env.ids['Asha']: 30000});
      expect(jsonDecode(row.payers), {env.me: 30000});
      final reopened = await env.open(expenseId: id);
      expect(reopened.draft.twoPersonAnswer, TwoPersonAnswer.youOwedFull);
    });
  });

  group('scan apply', () {
    final photo = PreparedImage(full: Uint8List(1), thumb: Uint8List(1));
    const scan = ReceiptScan(
      total: 99200,
      date: null,
      merchant: 'Hotel Saravana Bhavan',
      tax: 4726,
      service: 4500,
      roundOff: -26,
      items: [
        (name: 'Masala Dosa', amount: 18000),
        (name: 'Ghee Roast', amount: 14000),
        (name: 'Mini Meals', amount: 44000),
        (name: 'Filter Coffee', amount: 14000),
      ],
    );

    test('default ticks never overwrite what was typed', () {
      final empty = _two(amount: '').copyWith(description: '');
      expect(defaultChoice(empty, scan), (amount: true, date: false, description: true));
      final typed = _two(amount: '500');
      expect(defaultChoice(typed, scan), (amount: false, date: false, description: false));
      expect(defaultChoice(_two(amount: '992'), scan).amount, isTrue);
    });

    test('Use these fills the ticked fields and attaches the photo; never saves', () {
      final d = _two(amount: '').copyWith(description: '');
      final next = applyScan(d, scan, (amount: true, date: false, description: true), photo: photo);
      expect(next.amountText, '992');
      expect(next.description, 'Hotel Saravana Bhavan');
      expect(next.receipt.picked, same(photo));
      expect(next.split.isItems, isFalse);
      final kept = applyScan(d, scan, (amount: false, date: false, description: false));
      expect(kept.amountText, '');
      expect(kept.description, '');
    });

    test('Split by items prefills the lines; round off folds into the extras so they add up', () {
      final d = _two(amount: '').copyWith(description: '');
      final next = applyScan(d, scan, (
        amount: true,
        date: false,
        description: true,
      ), itemize: true);
      final s = next.split;
      expect(s.isItems, isTrue);
      expect(s.items!.items.length, 4);
      expect(s.items!.items.first.members, {'me', 'asha'});
      expect(s.items!.extras[ItemExtra.discount], '0.26');
      expect(next.total, 99200);
      expect(next.splitCheck, isA<SplitReady>());
      // Without a total the lines decide the amount.
      final noTotal = applyScan(
        d,
        const ReceiptScan(items: [(name: 'Tea', amount: 4000), (name: 'Samosa', amount: 9000)]),
        (amount: false, date: false, description: false),
        itemize: true,
      );
      expect(noTotal.amountText, '130');
      expect(noTotal.canSave, isFalse, reason: 'no description yet');
    });
  });
}
