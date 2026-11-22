// #12 recurring bills: the Repeat section of the expense editor, saving a template next to a new
// expense, and "Edit future copies" (template mode).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/rules/recurrence.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/editor/receipt_field.dart';
import 'package:splitify/features/recurring/application/repeat_draft.dart';

import '../expenses/application/expense_test_env.dart';
import '../expenses/expense_fixtures.dart';
import '../expenses/presentation/presentation_harness.dart';

Map<String, Object?> _json(Object? s) => (s is String ? jsonDecode(s) : s) as Map<String, Object?>;

const _monthly = RepeatDraft(interval: RecurrenceInterval.monthly);

/// A new or saved or template draft with the fixture people (no database).
ExpenseDraft _draft({
  bool canRepeat = false,
  String? templateId,
  String? expenseId,
  RepeatDraft repeat = RepeatDraft.never,
  String description = 'Rent',
}) => ExpenseDraft(
  groupId: gid,
  groupName: 'Goa trip',
  expenseId: expenseId,
  currency: 'INR',
  members: people,
  split: SplitDraft.initial(ids, 2),
  date: fixedToday,
  payerId: me,
  payers: const {},
  amountText: '1200',
  description: description,
  category: 'rent.rent',
  repeat: repeat,
  canRepeat: canRepeat,
  templateId: templateId,
);

/// Template-mode editor (`ExpenseEditorScreen(templateId:)`) on a fixed draft, opened from a host.
Future<FixedEditorController> _pumpTemplate(WidgetTester tester, ExpenseDraft draft) async {
  usePhone(tester);
  late FixedEditorController controller;
  await tester.pumpWidget(
    expenseApp(
      const PushHost(ExpenseEditorScreen(templateId: 't1', initialStep: EditorStep.details)),
      overrides: [
        templateEditorProvider('t1').overrideWith(
          () => controller = FixedEditorController((groupId: null, expenseId: null), draft),
        ),
      ],
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await settle(tester);
  return controller;
}

void main() {
  group('Repeat section (widget)', () {
    testWidgets('a new expense offers Repeat; choosing Every month sets the draft', (tester) async {
      final h = await pumpEditor(
        tester,
        _draft(canRepeat: true, expenseId: null),
        step: EditorStep.details,
        args: newArgs,
      );
      await reveal(tester, find.byKey(const Key('repeat-monthly')));
      expect(find.text('REPEAT'), findsOneWidget);
      await tapKey(tester, 'repeat-monthly');
      expect(h.draft.repeat, _monthly);
      expect(find.byKey(const Key('repeat-hint')), findsOneWidget);
      expect(find.byKey(const Key('repeat-never')), findsOneWidget);
      await tapKey(tester, 'repeat-never');
      expect(h.draft.repeat.repeats, isFalse);
    });

    testWidgets('a copy or an expense that already repeats has no Repeat section', (tester) async {
      await pumpEditor(tester, _draft(), step: EditorStep.details);
      expect(find.byKey(const Key('repeat-monthly')), findsNothing);
      expect(find.byKey(const Key('repeat-never')), findsNothing);
    });

    testWidgets('an end date before the expense date blocks Save until it is cleared', (
      tester,
    ) async {
      final h = await pumpEditor(
        tester,
        _draft(
          canRepeat: true,
          expenseId: null,
          repeat: RepeatDraft(interval: RecurrenceInterval.monthly, endsOn: DateTime(2026, 11, 10)),
        ),
        step: EditorStep.details,
        args: newArgs,
      );
      await reveal(tester, find.byKey(const Key('repeat-hint')));
      expect(find.text("The end date can't be before 21\u00A0Nov\u00A02026"), findsOneWidget);
      expect(buttonEnabled(tester, 'expense-save'), isFalse);
      expect(h.draft.canSave, isFalse);
      await tapKey(tester, 'repeat-no-end');
      expect(buttonEnabled(tester, 'expense-save'), isTrue);
      expect(h.draft.canSave, isTrue);
    });
  });

  group('Edit future copies (template mode, widget)', () {
    testWidgets('shows the start date read-only, no Never, no receipt, the header pill', (
      tester,
    ) async {
      await _pumpTemplate(tester, _draft(templateId: 't1', repeat: _monthly));
      expect(find.text('Future copies\u00A0· Goa trip'), findsOneWidget);
      await reveal(tester, find.byKey(const Key('template-start')));
      expect(find.byKey(const Key('template-start')), findsOneWidget);
      expect(find.text('21\u00A0Nov\u00A02026'), findsWidgets);
      expect(find.byKey(const Key('date-today')), findsNothing);
      await reveal(tester, find.byKey(const Key('repeat-monthly')));
      expect(find.byKey(const Key('repeat-never')), findsNothing);
      expect(find.byKey(const Key('repeat-monthly')), findsOneWidget);
      expect(find.byType(ReceiptField), findsNothing);
    });

    testWidgets('Save edits the template and says so', (tester) async {
      final c = await _pumpTemplate(tester, _draft(templateId: 't1', repeat: _monthly));
      await tapKey(tester, 'repeat-yearly');
      expect(c.state.value!.repeat.interval, RecurrenceInterval.yearly);
      await tester.tap(find.byKey(const Key('expense-save')));
      await settle(tester, 20);
      expect(c.saves, 1);
      expect(find.text('Future copies updated'), findsOneWidget);
    });

    testWidgets('an end date before the start blocks Save', (tester) async {
      final c = await _pumpTemplate(
        tester,
        _draft(
          templateId: 't1',
          repeat: RepeatDraft(interval: RecurrenceInterval.weekly, endsOn: DateTime(2026, 11, 1)),
        ),
      );
      expect(buttonEnabled(tester, 'expense-save'), isFalse);
      expect(c.state.value!.canSave, isFalse);
      await tapKey(tester, 'repeat-no-end');
      expect(buttonEnabled(tester, 'expense-save'), isTrue);
    });

    testWidgets('an unknown template shows "Not on this phone"', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        expenseApp(
          const PushHost(ExpenseEditorScreen(templateId: 'gone')),
          overrides: [templateEditorProvider('gone').overrideWith(() => _Missing())],
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await settle(tester);
      expect(find.text('Not on this phone'), findsOneWidget);
    });
  });

  group('saving (controller, local database)', () {
    late ExpenseEnv env;

    setUp(() async => env = await ExpenseEnv.create());
    tearDown(() => env.dispose());

    Future<List<OutboxItem>> outbox(SyncEntity entity) async => [
      for (final o in await env.db.select(env.db.outbox).get())
        if (o.entity == entity.wire) o,
    ];

    Future<Editor> fill({
      RepeatDraft repeat = RepeatDraft.never,
      DateTime? date,
      String description = 'Rent',
    }) async {
      final e = await env.open();
      e.edit(
        (d) => d
            .copyWith(
              amountText: '1200',
              description: description,
              category: 'rent.rent',
              date: date ?? DateTime(2026, 11, 20),
            )
            .withRepeat(repeat),
      );
      return e;
    }

    test('a new expense offers Repeat', () async {
      final e = await env.open();
      expect(e.draft.canRepeat, isTrue);
      expect(e.draft.repeat.repeats, isFalse);
    });

    test('new expense + Every month saves the expense and a template with its fields', () async {
      final e = await fill(repeat: _monthly);
      final id = await e.save();
      expect(id, isNotNull);

      final exp = await outbox(SyncEntity.expense);
      expect(exp, hasLength(1));
      expect(exp.single.recordId, id);

      final rec = await outbox(SyncEntity.recurring);
      expect(rec, hasLength(1));
      expect(rec.single.op, SyncOp.upsert.name);
      expect(rec.single.groupId, env.groupId);
      expect(rec.single.recordId, isNot(id));
      final p = _json(rec.single.payload);
      expect(p['expense_id'], id);
      expect(p['interval'], 'monthly');
      expect(p['anchor_date'], '2026-11-20');
      expect(p['ends_on'], isNull);
      expect(p['active'], true);
      final t = _json(p['template']);
      expect(t['description'], 'Rent');
      expect(t['total'], 120000);
      expect(t['category'], 'rent.rent');
      expect(t['currency'], 'INR');
      expect(t.containsKey('date'), isFalse);
      expect(_json(t['payers']), {env.me: 120000});

      final row = await (env.db.select(env.db.recurringTemplates)).getSingle();
      expect(row.interval, 'monthly');
      expect(row.anchorDate, '2026-11-20');
      expect(row.syncState, SyncState.pending);
      expect(row.nextDate!.substring(0, 10), '2026-12-20');
    });

    test('an end date is saved on the template as ends_on', () async {
      final e = await fill(
        repeat: RepeatDraft(interval: RecurrenceInterval.weekly, endsOn: DateTime(2027, 1, 31)),
      );
      await e.save();
      final p = _json((await outbox(SyncEntity.recurring)).single.payload);
      expect(p['interval'], 'weekly');
      expect(p['ends_on'], '2027-01-31');
    });

    test('Never saves no template', () async {
      final e = await fill();
      expect(await e.save(), isNotNull);
      expect(await outbox(SyncEntity.recurring), isEmpty);
      expect(await env.db.select(env.db.recurringTemplates).get(), isEmpty);
    });

    test('an end date before the expense date does not save', () async {
      final e = await fill(
        repeat: RepeatDraft(interval: RecurrenceInterval.monthly, endsOn: DateTime(2026, 11, 1)),
      );
      expect(e.draft.repeatProblem, isTrue);
      expect(e.draft.canSave, isFalse);
      expect(await e.save(), isNull);
      expect(await outbox(SyncEntity.expense), isEmpty);
      expect(await outbox(SyncEntity.recurring), isEmpty);
    });

    test(
      'a saved expense without a template can start repeating; one with a template cannot',
      () async {
        final e = await fill();
        final id = (await e.save())!;
        final again = await env.open(expenseId: id);
        expect(again.draft.canRepeat, isTrue);

        again.edit((d) => d.withRepeat(_monthly));
        expect(await again.save(), id);
        expect(await outbox(SyncEntity.recurring), hasLength(1));

        final third = await env.open(expenseId: id);
        expect(third.draft.canRepeat, isFalse);
      },
    );

    test('a copy made by a template (source recurring) has no Repeat section', () async {
      final e = await fill();
      final id = (await e.save())!;
      await env.db.customStatement("UPDATE expenses SET source = 'recurring' WHERE id = '$id'");
      final copy = await env.open(expenseId: id);
      expect(copy.draft.canRepeat, isFalse);
    });

    test('template mode loads the template, shows its first date and saves edits', () async {
      final e = await fill(
        repeat: RepeatDraft(interval: RecurrenceInterval.monthly, endsOn: DateTime(2027, 5, 20)),
      );
      await e.save();
      final tpl = await env.db.select(env.db.recurringTemplates).getSingle();

      final p = templateEditorProvider(tpl.id);
      env.container.listen(p, (_, _) {});
      final d = await env.container.read(p.future);
      expect(d.isTemplate, isTrue);
      expect(d.templateId, tpl.id);
      expect(d.date, DateTime(2026, 11, 20));
      expect(d.description, 'Rent');
      expect(d.amountText, '1200');
      expect(d.category, 'rent.rent');
      expect(d.groupName, 'Goa trip');
      expect(d.split.kind, SplitKind.equal);
      expect(d.repeat.interval, RecurrenceInterval.monthly);
      expect(d.repeat.endsOn, DateTime(2027, 5, 20));
      expect(d.canSave, isTrue);

      final c = env.container.read(p.notifier);
      c.edit(
        (x) => x
            .copyWith(description: 'Rent (new flat)', amountText: '1500')
            .withRepeat(const RepeatDraft(interval: RecurrenceInterval.yearly)),
      );
      expect(await c.save(), tpl.id);

      final after = await env.db.select(env.db.recurringTemplates).getSingle();
      expect(after.interval, 'yearly');
      expect(after.endsOn, isNull);
      final t = _json(after.template);
      expect(t['description'], 'Rent (new flat)');
      expect(t['total'], 150000);
      expect(after.anchorDate, '2026-11-20');
      // The expense it was started from stays as it was.
      final exp = await (env.db.select(env.db.expenses)).getSingle();
      expect(exp.description, 'Rent');
      expect(exp.total, 120000);
      final rec = await outbox(SyncEntity.recurring);
      expect(rec, hasLength(2));
      expect(_json(rec.last.payload)['interval'], 'yearly');
    });

    test('template mode with an end date before the first date does not save', () async {
      final e = await fill(repeat: _monthly);
      await e.save();
      final tpl = await env.db.select(env.db.recurringTemplates).getSingle();
      final p = templateEditorProvider(tpl.id);
      env.container.listen(p, (_, _) {});
      await env.container.read(p.future);
      final c = env.container.read(p.notifier);
      c.edit(
        (x) => x.withRepeat(
          RepeatDraft(interval: RecurrenceInterval.monthly, endsOn: DateTime(2026, 1, 1)),
        ),
      );
      expect(await c.save(), isNull);
      expect(await outbox(SyncEntity.recurring), hasLength(1));
    });

    test('an unknown template fails with ExpenseNotFound', () async {
      final p = templateEditorProvider('nope');
      env.container.listen(p, (_, _) {});
      await expectLater(env.container.read(p.future), throwsA(isA<ExpenseNotFound>()));
    });
  });
}

class _Missing extends FixedEditorController {
  _Missing() : super((groupId: null, expenseId: null), _draft());

  @override
  Future<ExpenseDraft> build() async => throw const ExpenseNotFound();
}
