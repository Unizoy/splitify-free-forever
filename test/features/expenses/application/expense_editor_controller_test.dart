import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';

import 'expense_test_env.dart';

Map<String, Object?> _json(String s) => jsonDecode(s) as Map<String, Object?>;

/// Waits for the first data value of an AsyncValue provider (kept alive while waiting).
Future<T> _data<T>(
  ProviderContainer c,
  ProviderListenable<AsyncValue<T>> p, {
  bool Function(T value)? until,
}) {
  final done = Completer<T>();
  late final ProviderSubscription<AsyncValue<T>> sub;
  sub = c.listen(p, (_, next) {
    if (next.hasValue &&
        !next.isLoading &&
        !done.isCompleted &&
        (until == null || until(next.requireValue)))
      done.complete(next.requireValue);
    if (next.hasError && !done.isCompleted) done.completeError(next.error!);
  }, fireImmediately: true);
  return done.future.whenComplete(sub.close);
}

ExpenseDraft Function(ExpenseDraft) _fill(String amount, String description) =>
    (d) => d.copyWith(amountText: amount, description: description);

void main() {
  late ExpenseEnv env;

  String _now() => env.clock.time.toUtc().toIso8601String();

  Future<LocalExpense> expense(String id) =>
      (env.db.select(env.db.expenses)..where((e) => e.id.equals(id))).getSingle();

  setUp(() async => env = await ExpenseEnv.create());
  tearDown(() => env.dispose());

  group('new expense draft', () {
    test('starts equal between all active members, me as payer, today, INR', () async {
      final e = await env.open();
      final d = e.draft;
      expect(d.isEdit, isFalse);
      expect(d.groupName, 'Goa trip');
      expect(d.currency, 'INR');
      expect([for (final m in d.members) m.name], ['Mohit', 'Asha', 'Ravi']);
      expect([for (final m in d.members) m.isMe], [true, false, false]);
      expect(d.payerId, env.me);
      expect(d.date, DateTime(2026, 11, 21));
      expect(d.split.kind, SplitKind.equal);
      expect(d.split.participants, [env.me, env.ids['Asha'], env.ids['Ravi']]);
      expect(d.category, 'other.general');
      expect(d.canSave, isFalse);
    });

    test('removed members are not offered', () async {
      await env.db.customStatement(
        "UPDATE group_members SET deleted_at = '2026-11-20T00:00:00Z' WHERE display_name = 'Ravi'",
      );
      final e = await env.open();
      expect([for (final m in e.draft.members) m.name], ['Mohit', 'Asha']);
    });

    test('without an account the first member pays', () async {
      env.dispose();
      env = await ExpenseEnv.create(userId: null);
      final e = await env.open();
      expect(e.draft.payerId, env.me);
      expect(e.draft.members.any((m) => m.isMe), isFalse);
    });

    test('suggests the last category of the group, normalised', () async {
      final e = await env.open();
      e.edit((d) => _fill('50', 'Chai')(d).copyWith(category: 'food.snacks'));
      await e.save();
      expect((await env.open()).draft.category, 'food.snacks');

      env.clock.time = DateTime(2026, 11, 21, 11);
      final f = await env.open();
      f.edit((d) => _fill('60', 'Odd')(d).copyWith(category: 'weird.thing'));
      await f.save();
      expect((await env.open()).draft.category, 'other.general');
    });

    test('TC-35-01 a percent default split prefills the draft', () async {
      final a = env.ids['Asha']!;
      final r = env.ids['Ravi']!;
      await env.container.read(groupsRepositoryProvider).update(env.groupId, {
        'default_split': {
          'kind': 'percent',
          'values': {env.me: 5000, a: 3000, r: 2000},
        },
      });
      final e = await env.open();
      expect(e.draft.split.kind, SplitKind.percent);
      expect(e.draft.split.values, {env.me: 5000, a: 3000, r: 2000});
      e.edit(_fill('100', 'Dinner'));
      expect((e.draft.splitCheck as SplitReady).shares, {env.me: 5000, a: 3000, r: 2000});
    });

    test('TC-35-01 a shares default prefills too', () async {
      await env.container.read(groupsRepositoryProvider).update(env.groupId, {
        'default_split': {
          'kind': 'shares',
          'values': {for (final id in env.ids.values) id: 1000},
        },
      });
      expect((await env.open()).draft.split.kind, SplitKind.shares);
    });

    test('TC-35-01 falls back to equal when the members changed', () async {
      await env.container.read(groupsRepositoryProvider).update(env.groupId, {
        'default_split': {
          'kind': 'percent',
          'values': {env.me: 5000, env.ids['Asha']!: 3000, env.ids['Ravi']!: 2000},
        },
      });
      await env.addMember('Zoya');
      final e = await env.open();
      expect(e.draft.split.kind, SplitKind.equal);
      expect(e.draft.split.participants, hasLength(4));
    });

    test('a default split that is not understood is ignored', () async {
      await env.db.customStatement("UPDATE \"groups\" SET default_split = 'not json'");
      expect((await env.open()).draft.split.kind, SplitKind.equal);
    });
  });

  group('edit and save', () {
    test('edit changes the state', () async {
      final e = await env.open();
      e.edit(_fill('450+120', 'Lunch'));
      expect(e.draft.amountText, '450+120');
      expect(e.draft.total, 57000);
      expect(e.draft.description, 'Lunch');
    });

    test('edit and save before the draft loaded do nothing', () async {
      final p = expenseEditorProvider((groupId: env.groupId, expenseId: null));
      env.container.listen(p, (_, _) {});
      final n = env.container.read(p.notifier);
      n.edit((d) => d.copyWith(description: 'x'));
      expect(env.container.read(p).hasValue, isFalse);
      expect(await n.save(), isNull);
    });

    test('TC-13-01 save returns null when the draft is invalid', () async {
      final e = await env.open();
      expect(await e.save(), isNull);
      e.edit(_fill('100', '   '));
      expect(e.draft.descriptionProblem, DescriptionProblem.missing);
      expect(await e.save(), isNull);
      e.edit(_fill('0', 'Dinner'));
      expect(await e.save(), isNull);
      e.edit(_fill('100', 'x' * (maxDescription + 1)));
      expect(e.draft.descriptionProblem, DescriptionProblem.tooLong);
      expect(await e.save(), isNull);
      e.edit((d) => d.copyWith(description: 'Dinner', notes: 'n' * (maxNotes + 1)));
      expect(await e.save(), isNull);
      expect(await env.db.select(env.db.expenses).get(), isEmpty);
      final out = await env.db.select(env.db.outbox).get();
      expect(out.where((o) => o.entity == SyncEntity.expense.wire), isEmpty);
    });

    test('TC-13-01 save writes the expense row and an outbox mutation', () async {
      final e = await env.open();
      final a = env.ids['Asha']!;
      final r = env.ids['Ravi']!;
      e.edit(
        (d) => d.copyWith(
          amountText: '100',
          description: '  Dinner  ',
          notes: '   ',
          category: 'food.snacks',
          date: DateTime(2026, 11, 20),
          payerId: a,
        ),
      );
      final id = await e.save();
      expect(id, isNotNull);

      final row = await expense(id!);
      expect(row.groupId, env.groupId);
      expect(row.total, 10000);
      expect(row.currency, 'INR');
      expect(row.description, 'Dinner');
      expect(row.notes, isNull);
      expect(row.category, 'food.snacks');
      expect(row.date, '2026-11-20');
      expect(row.splitKind, 'equal');
      expect(row.splitValues, isNull);
      expect(_json(row.payers), {a: 10000});
      expect(_json(row.shares), {env.me: 3334, a: 3333, r: 3333});
      expect(row.createdAt, _now());

      final all = await env.db.select(env.db.outbox).get();
      final out = all.where((o) => o.entity == SyncEntity.expense.wire).toList();
      expect(out, hasLength(1));
      expect(out.single.op, SyncOp.upsert.name);
      expect(out.single.recordId, id);
      expect(out.single.groupId, env.groupId);
      final payload = _json(out.single.payload);
      expect(payload['total'], 10000);
      expect(payload['description'], 'Dinner');
      expect(payload['notes'], isNull);
    });

    test('notes are trimmed and kept when present', () async {
      final e = await env.open();
      e.edit((d) => _fill('10', 'Tea')(d).copyWith(notes: '  with sugar '));
      final row = await expense((await e.save())!);
      expect(row.notes, 'with sugar');
    });

    test('editing a saved expense keeps its id and created_at', () async {
      final e = await env.open();
      e.edit(_fill('100', 'Dinner'));
      final id = (await e.save())!;

      final created = _now();
      env.clock.time = DateTime(2026, 11, 22, 9);
      final again = await env.open(expenseId: id);
      expect(again.draft.isEdit, isTrue);
      expect(again.draft.expenseId, id);
      again.edit(_fill('200', 'Dinner 2'));
      expect(await again.save(), id);

      final rows = await env.db.select(env.db.expenses).get();
      expect(rows, hasLength(1));
      expect(rows.single.total, 20000);
      expect(rows.single.description, 'Dinner 2');
      expect(rows.single.createdAt, created);
      final out = await env.db.select(env.db.outbox).get();
      expect(out.where((o) => o.entity == SyncEntity.expense.wire), hasLength(2));
    });
  });

  group('reopening a saved expense (TC-5..9-03)', () {
    Future<void> reopens(
      void Function(Editor e) setup, {
      required SplitKind kind,
      required int participants,
    }) async {
      final e = await env.open();
      e.edit(_fill('100', 'Dinner'));
      setup(e);
      expect(e.draft.canSave, isTrue, reason: 'setup must give a valid draft');
      final before = e.draft;
      final id = (await e.save())!;

      final r = await env.open(expenseId: id);
      final d = r.draft;
      expect(d.split.kind, kind);
      expect(d.split.participants, before.split.participants);
      expect(d.split.participants, hasLength(participants));
      expect(d.split.values, before.split.values);
      expect(d.total, 10000);
      expect(d.amountText, '100');
      expect(d.payerId, env.me);
      expect((d.splitCheck as SplitReady).shares, (before.splitCheck as SplitReady).shares);
      // Saving again without changes stores the same thing.
      final saved = await expense(id);
      expect(await r.save(), id);
      final resaved = await expense(id);
      expect(resaved.shares, saved.shares);
      expect(resaved.splitValues, saved.splitValues);
      expect(resaved.splitKind, saved.splitKind);
    }

    test('TC-5-03 equal with one person unticked', () async {
      await reopens(
        (e) => e.edit((d) => d.copyWith(split: d.split.toggle(env.ids['Ravi']!))),
        kind: SplitKind.equal,
        participants: 2,
      );
    });

    test('TC-6-03 exact', () async {
      await reopens(
        (e) => e.edit(
          (d) => d.copyWith(
            split: d.split
                .switchTo(SplitKind.exact, total: 10000)
                .setText(env.me, '50')
                .setText(env.ids['Asha']!, '30')
                .setText(env.ids['Ravi']!, '20'),
          ),
        ),
        kind: SplitKind.exact,
        participants: 3,
      );
    });

    test('TC-7-03 percent', () async {
      await reopens(
        (e) => e.edit(
          (d) => d.copyWith(
            split: d.split
                .switchTo(SplitKind.percent)
                .setText(env.me, '50')
                .setText(env.ids['Asha']!, '30')
                .setText(env.ids['Ravi']!, '20'),
          ),
        ),
        kind: SplitKind.percent,
        participants: 3,
      );
    });

    test('TC-8-03 shares', () async {
      await reopens(
        (e) => e.edit(
          (d) => d.copyWith(
            split: d.split.switchTo(SplitKind.shares).setShareUnits(env.ids['Asha']!, 2000),
          ),
        ),
        kind: SplitKind.shares,
        participants: 3,
      );
      final row = (await env.db.select(env.db.expenses).get()).single;
      expect(_json(row.splitValues!)[env.ids['Asha']!], 2000);
    });

    test('TC-9-03 adjust with one person unticked', () async {
      await reopens(
        (e) => e.edit(
          (d) => d.copyWith(
            split: d.split
                .toggle(env.ids['Ravi']!)
                .switchTo(SplitKind.adjust)
                .setText(env.ids['Asha']!, '10'),
          ),
        ),
        kind: SplitKind.adjust,
        participants: 2,
      );
    });

    test('a removed member of an old expense stays in the draft', () async {
      final e = await env.open();
      e.edit(_fill('90', 'Dinner'));
      final id = (await e.save())!;
      await env.db.customStatement(
        "UPDATE group_members SET deleted_at = '2026-11-22T00:00:00Z' WHERE display_name = 'Ravi'",
      );
      final d = (await env.open(expenseId: id)).draft;
      expect([for (final m in d.members) m.name], ['Mohit', 'Asha', 'Ravi']);
      expect(d.split.participants, hasLength(3));
    });

    test('several payers are kept as saved (payerId null)', () async {
      final a = env.ids['Asha']!;
      await env.container.read(expensesRepositoryProvider).save(env.groupId, {
        'kind': 'expense',
        'description': 'Split bill',
        'category': 'food.dining_out',
        'date': '2026-11-20',
        'currency': 'INR',
        'total': 10000,
        'payers': {env.me: 6000, a: 4000},
        'shares': {env.me: 5000, a: 5000},
        'split_kind': 'equal',
        'split_values': null,
      }, id: 'e-multi');
      final r = await env.open(expenseId: 'e-multi');
      expect(r.draft.payerId, isNull);
      expect(r.draft.payers, {env.me: 6000, a: 4000});
      expect(r.draft.payersOk, isTrue);
      expect(r.draft.category, 'food.dining_out');
      expect(r.draft.canSave, isTrue);
    });
  });

  group('ExpenseNotFound', () {
    Future<void> notFound(ExpenseEditorArgs args) async {
      final p = expenseEditorProvider(args);
      env.container.listen(p, (_, _) {}, onError: (_, _) {});
      await expectLater(env.container.read(p.future), throwsA(isA<ExpenseNotFound>()));
    }

    test('unknown expense id', () => notFound((groupId: env.groupId, expenseId: 'nope')));

    test('unknown group', () => notFound((groupId: 'nope', expenseId: null)));

    test('args with neither id', () => notFound((groupId: null, expenseId: null)));

    test('deleted expense', () async {
      final e = await env.open();
      e.edit(_fill('100', 'Dinner'));
      final id = (await e.save())!;
      await env.container.read(expenseActionsProvider).delete(await expense(id));
      await notFound((groupId: null, expenseId: id));
    });
  });

  group('views and actions', () {
    Future<String> saveDinner({String? payer, bool dropMe = false}) async {
      final e = await env.open();
      e.edit(
        (d) => d.copyWith(
          amountText: '100',
          description: 'Dinner',
          payerId: payer,
          split: dropMe ? d.split.toggle(env.me) : d.split,
        ),
      );
      return (await e.save())!;
    }

    test('groupExpenseViewsProvider builds views for the viewer', () async {
      final id = await saveDinner();
      final views = await _data(env.container, groupExpenseViewsProvider(env.groupId));
      expect(views, hasLength(1));
      final v = views.single;
      expect(v.expense.id, id);
      expect(v.meId, env.me);
      expect(v.paid, {env.me: 10000});
      expect(v.owed[env.me], 3334);
      expect(v.singlePayer, env.me);
      expect(v.myNet, 10000 - 3334);
      expect(v.involved, isTrue);
      expect(v.nameOf(env.me), 'Mohit');
      expect(v.nameOf('unknown'), '');
      expect(v.userNames, {'u1': 'Mohit'});
    });

    test('a member who neither paid nor owes is not involved', () async {
      await saveDinner(payer: env.ids['Asha'], dropMe: true);
      final v = (await _data(env.container, groupExpenseViewsProvider(env.groupId))).single;
      expect(v.involved, isFalse);
      expect(v.myNet, 0);
      expect(v.singlePayer, env.ids['Asha']);
    });

    test('unsynced follows the row sync state', () async {
      final id = await saveDinner();
      Future<void> setState(String state) => env.db.customUpdate(
        'UPDATE expenses SET sync_state = ?',
        variables: [Variable<String>(state)],
        updates: {env.db.expenses},
      );
      await setState('pending');
      final p = expenseViewProvider(id);
      expect(
        (await _data<ExpenseView?>(env.container, p, until: (v) => v != null))!.unsynced,
        isTrue,
      );
      await setState('synced');
      final synced = await _data<ExpenseView?>(
        env.container,
        p,
        until: (v) => v?.unsynced == false,
      );
      expect(synced!.unsynced, isFalse);
    });

    test('without a matching member the viewer is not involved', () async {
      await saveDinner();
      final e = await env.db.select(env.db.expenses).get();
      final m = await env.db.select(env.db.groupMembers).get();
      final v = expenseViews(e, m, null).single;
      expect(v.meId, isNull);
      expect(v.myNet, 0);
      expect(v.involved, isFalse);
      expect(expenseViews(e, m, 'someone-else').single.meId, isNull);
      // A removed member is not "me".
      final removed = [
        for (final x in m) x.userId == 'u1' ? x.copyWith(deletedAt: const Value('x')) : x,
      ];
      expect(expenseViews(e, removed, 'u1').single.meId, isNull);
    });

    test('expenseViewProvider is null for an unknown expense', () async {
      expect(await _data<ExpenseView?>(env.container, expenseViewProvider('nope')), isNull);
    });

    test('delete sets deleted_at and logs a mutation, restore clears it', () async {
      final id = await saveDinner();
      final actions = env.container.read(expenseActionsProvider);

      await actions.delete(await expense(id));
      var row = await expense(id);
      expect(row.deletedAt, _now());
      expect(await _data<ExpenseView?>(env.container, expenseViewProvider(id)), isNull);
      var out = await env.db.select(env.db.outbox).get();
      expect(out.last.op, SyncOp.delete.name);

      await actions.restore(row);
      row = await expense(id);
      expect(row.deletedAt, isNull);
      out = await env.db.select(env.db.outbox).get();
      expect(out.last.op, SyncOp.restore.name);
      expect(
        await _data<ExpenseView?>(env.container, expenseViewProvider(id), until: (v) => v != null),
        isNotNull,
      );
    });

    test('a deleted expense leaves the group list', () async {
      final id = await saveDinner();
      await env.container.read(expenseActionsProvider).delete(await expense(id));
      expect(await _data(env.container, groupExpenseViewsProvider(env.groupId)), isEmpty);
    });

    test('expenseGroupProvider streams the group', () async {
      final p = expenseGroupProvider(env.groupId);
      env.container.listen(p, (_, _) {});
      final g = await env.container.read(p.future);
      expect(g!.name, 'Goa trip');
    });
  });
}
