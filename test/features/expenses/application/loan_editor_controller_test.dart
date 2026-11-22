// TC-11-01, TC-11-02 (logic): the "Record a loan" draft and controller.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/loan_draft.dart';
import 'package:splitify/features/expenses/application/loan_editor_controller.dart';

import 'expense_test_env.dart';

Map<String, Object?> _json(String s) => jsonDecode(s) as Map<String, Object?>;

LoanDraft _draft({
  LoanDirection direction = LoanDirection.lent,
  String? person = 'b',
  String amount = '100',
  String note = '',
  String self = 'a',
}) => LoanDraft(
  groupId: 'g',
  groupName: 'Goa',
  currency: 'INR',
  members: const [
    (id: 'a', name: 'A', isMe: true),
    (id: 'b', name: 'B', isMe: false),
    (id: 'c', name: 'C', isMe: false),
  ],
  selfId: self,
  date: DateTime(2026, 11, 21),
  direction: direction,
  personId: person,
  amountText: amount,
  note: note,
);

void main() {
  group('LoanDraft', () {
    // TC-11-01
    test('toRow: lender pays the total, borrower owes the total, note or default', () {
      final row = _draft(note: '  Auto fare ').toRow(defaultDescription: 'Loan');
      expect(row, {
        'kind': 'iou',
        'description': 'Auto fare',
        'notes': null,
        'category': 'other.general',
        'date': '2026-11-21',
        'currency': 'INR',
        'total': 10000,
        'payers': {'a': 10000},
        'shares': {'b': 10000},
        'split_kind': 'equal',
        'split_values': null,
      });
      expect(_draft(note: '   ').toRow(defaultDescription: 'Loan')['description'], 'Loan');
    });

    // TC-11-01
    test('"I borrowed" swaps lender and borrower', () {
      final d = _draft(direction: LoanDirection.borrowed);
      expect((d.lenderId, d.borrowerId), ('b', 'a'));
      final row = d.toRow(defaultDescription: 'Loan');
      expect(row['payers'], {'b': 10000});
      expect(row['shares'], {'a': 10000});
      final lent = _draft();
      expect((lent.lenderId, lent.borrowerId), ('a', 'b'));
    });

    // TC-11-02
    test('canSave rules', () {
      expect(_draft().canSave, isTrue);
      expect(_draft(person: null).canSave, isFalse);
      expect(_draft(person: 'a').canSave, isFalse);
      expect(_draft(person: 'zzz').canSave, isFalse);
      expect(_draft(amount: '').canSave, isFalse);
      expect(_draft(amount: '0').canSave, isFalse);
      expect(_draft(note: 'x' * 120).canSave, isTrue);
      final long = _draft(note: 'x' * 121);
      expect(long.noteTooLong, isTrue);
      expect(long.canSave, isFalse);
      expect(() => long.toRow(defaultDescription: 'Loan'), throwsStateError);
    });

    // TC-11-01
    test('others exclude self; member lookup; copyWith', () {
      final d = _draft();
      expect([for (final m in d.others) m.id], ['b', 'c']);
      expect(d.member('c')!.name, 'C');
      expect(d.member(null), isNull);
      final e = d.copyWith(
        direction: LoanDirection.borrowed,
        personId: 'c',
        amountText: '5',
        note: 'n',
        date: DateTime(2026, 1, 2),
      );
      expect(
        (e.direction, e.personId, e.amountText, e.note),
        (LoanDirection.borrowed, 'c', '5', 'n'),
      );
      expect(e.date, DateTime(2026, 1, 2));
      expect(d.isEdit, isFalse);
    });
  });

  group('LoanEditorController', () {
    late ExpenseEnv env;

    Future<LoanDraft> open(LoanEditorArgs args, {ExpenseEnv? on}) async {
      final c = (on ?? env).container;
      final p = loanEditorProvider(args);
      c.listen(p, (_, _) {});
      return c.read(p.future);
    }

    LoanEditorArgs fresh({String? withMember}) =>
        (groupId: env.groupId, expenseId: null, withMember: withMember);

    Future<LocalExpense> expense(String id) =>
        (env.db.select(env.db.expenses)..where((e) => e.id.equals(id))).getSingle();

    Future<String> saveIou(String lender, String borrower, {int total = 5000, String? id}) async {
      return env.container.read(expensesRepositoryProvider).save(env.groupId, {
        'kind': 'iou',
        'description': 'Cab',
        'category': 'other.general',
        'date': '2026-11-20',
        'currency': 'INR',
        'total': total,
        'payers': {lender: total},
        'shares': {borrower: total},
        'split_kind': 'equal',
        'split_values': null,
      }, id: id ?? 'iou-1');
    }

    setUp(() async => env = await ExpenseEnv.create());
    tearDown(() => env.dispose());

    // TC-11-01
    test('a new loan starts with me as lender, group currency, today, nobody picked', () async {
      final d = await open(fresh());
      expect(d.isEdit, isFalse);
      expect(d.groupName, 'Goa trip');
      expect(d.currency, 'INR');
      expect(d.selfId, env.me);
      expect(d.selfIsMe, isTrue);
      expect(d.direction, LoanDirection.lent);
      expect(d.personId, isNull);
      expect(d.date, DateTime(2026, 11, 21));
      expect(d.canSave, isFalse);
      expect([for (final m in d.others) m.name], ['Asha', 'Ravi']);
    });

    // TC-11-01
    test('withMember is honoured; an unknown or own id is ignored', () async {
      final asha = env.ids['Asha']!;
      expect((await open(fresh(withMember: asha))).personId, asha);
      env.container.invalidate(loanEditorProvider(fresh(withMember: 'nope')));
      expect((await open(fresh(withMember: 'nope'))).personId, isNull);
      expect((await open(fresh(withMember: env.me))).personId, isNull);
    });

    // TC-11-01
    test('a single other member is picked automatically', () async {
      env.dispose();
      env = await ExpenseEnv.create(others: const ['Asha']);
      final d = await open(fresh());
      expect(d.personId, env.ids['Asha']);
    });

    // TC-11-02
    test('the viewer without a member in the group cannot record a loan', () async {
      env.dispose();
      env = await ExpenseEnv.create(userId: 'nobody');
      final p = loanEditorProvider(fresh());
      env.container.listen(p, (_, _) {}, onError: (_, _) {});
      await expectLater(env.container.read(p.future), throwsA(isA<LoanNotPossible>()));
    });

    // TC-11-02
    test('missing group or expense is ExpenseNotFound', () async {
      Future<void> notFound(LoanEditorArgs args) async {
        final p = loanEditorProvider(args);
        env.container.listen(p, (_, _) {}, onError: (_, _) {});
        await expectLater(env.container.read(p.future), throwsA(isA<ExpenseNotFound>()));
      }

      await notFound((groupId: null, expenseId: null, withMember: null));
      await notFound((groupId: 'nope', expenseId: null, withMember: null));
      await notFound((groupId: env.groupId, expenseId: 'nope', withMember: null));
    });

    // TC-11-02
    test('a deleted loan and a normal expense are ExpenseNotFound', () async {
      final asha = env.ids['Asha']!;
      final id = await saveIou(env.me, asha);
      await env.container.read(expensesRepositoryProvider).save(env.groupId, {
        'kind': 'expense',
        'description': 'Dinner',
        'category': 'other.general',
        'date': '2026-11-20',
        'currency': 'INR',
        'total': 100,
        'payers': {env.me: 100},
        'shares': {env.me: 100},
        'split_kind': 'equal',
        'split_values': null,
      }, id: 'plain');
      Future<void> notFound(String expenseId) async {
        final p = loanEditorProvider((groupId: null, expenseId: expenseId, withMember: null));
        env.container.listen(p, (_, _) {}, onError: (_, _) {});
        await expectLater(env.container.read(p.future), throwsA(isA<ExpenseNotFound>()));
      }

      await notFound('plain');
      await env.container.read(expensesRepositoryProvider).delete(id, env.groupId);
      await notFound(id);
    });

    // TC-11-02
    test('a saved loan where I lent reopens as "lent"', () async {
      final asha = env.ids['Asha']!;
      final id = await saveIou(env.me, asha, total: 12550);
      final d = await open((groupId: null, expenseId: id, withMember: null));
      expect(d.isEdit, isTrue);
      expect(d.direction, LoanDirection.lent);
      expect((d.selfId, d.personId, d.selfIsMe), (env.me, asha, true));
      expect(d.amountText, '125.5');
      expect(d.note, 'Cab');
      expect(d.date, DateTime(2026, 11, 20));
    });

    // TC-11-02
    test('a saved loan where I borrowed reopens as "borrowed"', () async {
      final asha = env.ids['Asha']!;
      final id = await saveIou(asha, env.me);
      final d = await open((groupId: null, expenseId: id, withMember: null));
      expect(d.direction, LoanDirection.borrowed);
      expect((d.selfId, d.personId, d.selfIsMe), (env.me, asha, true));
    });

    // TC-11-02
    test('a loan between two other people shows the lender as self (not me)', () async {
      final asha = env.ids['Asha']!;
      final ravi = env.ids['Ravi']!;
      final id = await saveIou(asha, ravi);
      final d = await open((groupId: null, expenseId: id, withMember: null));
      expect(d.selfIsMe, isFalse);
      expect(d.selfId, asha);
      expect(d.personId, ravi);
      expect(d.direction, LoanDirection.lent);
    });

    // TC-11-02
    test('a removed member of a saved loan stays in the people list', () async {
      final asha = env.ids['Asha']!;
      final id = await saveIou(env.me, asha);
      await env.db.customStatement(
        "UPDATE group_members SET deleted_at = '2026-11-20T00:00:00Z' WHERE display_name = 'Asha'",
      );
      final d = await open((groupId: null, expenseId: id, withMember: null));
      expect(d.member(asha), isNotNull);
      final fresh2 = await open((groupId: env.groupId, expenseId: null, withMember: null));
      expect(fresh2.member(asha), isNull);
    });

    // TC-11-01
    test('save writes an iou row and an outbox mutation; created_at only for new loans', () async {
      final asha = env.ids['Asha']!;
      final args = fresh(withMember: asha);
      await open(args);
      final c = env.container.read(loanEditorProvider(args).notifier);
      expect(await c.save(defaultDescription: 'Loan'), isNull);

      c.edit((d) => d.copyWith(amountText: '75'));
      final id = (await c.save(defaultDescription: 'Loan'))!;
      final row = await expense(id);
      expect(row.kind, 'iou');
      expect(row.description, 'Loan');
      expect(row.total, 7500);
      expect(_json(row.payers), {env.me: 7500});
      expect(_json(row.shares), {asha: 7500});
      expect(row.createdAt, env.clock.time.toUtc().toIso8601String());
      final out = await env.db.select(env.db.outbox).get();
      expect(out.where((o) => o.recordId == id), hasLength(1));

      // Editing keeps the id and the original created_at.
      final created = row.createdAt;
      env.clock.time = DateTime(2026, 11, 22, 9);
      final eargs = (groupId: null, expenseId: id, withMember: null);
      await open(eargs);
      final ec = env.container.read(loanEditorProvider(eargs).notifier);
      ec.edit((d) => d.copyWith(amountText: '80', direction: LoanDirection.borrowed));
      expect(await ec.save(defaultDescription: 'Loan'), id);
      final again = await expense(id);
      expect(again.total, 8000);
      expect(again.createdAt, created);
      expect(_json(again.payers), {asha: 8000});
      expect(_json(again.shares), {env.me: 8000});
    });

    // TC-11-02
    test('edit before the form loaded does nothing', () async {
      final p = loanEditorProvider(fresh());
      env.container.listen(p, (_, _) {}, onError: (_, _) {});
      final c = env.container.read(p.notifier);
      c.edit((d) => d.copyWith(amountText: '1'));
      expect(await c.save(defaultDescription: 'Loan'), isNull);
    });
  });
}
