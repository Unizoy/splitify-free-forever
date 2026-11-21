import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/expenses/application/default_split_controller.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';

import 'expense_test_env.dart';

void main() {
  late ExpenseEnv env;

  setUp(() async => env = await ExpenseEnv.create());
  tearDown(() => env.dispose());

  Future<DefaultSplitController> open([String? groupId]) async {
    final p = defaultSplitProvider(groupId ?? env.groupId);
    env.container.listen(p, (_, _) {});
    await env.container.read(p.future);
    return env.container.read(p.notifier);
  }

  DefaultSplitState state() => env.container.read(defaultSplitProvider(env.groupId)).requireValue;

  Future<LocalGroup> group() => (env.db.select(env.db.groups)).getSingle();

  test('builds from the group: members in position order, isMe, equal by default', () async {
    await open();
    final s = state();
    expect(s.groupName, 'Goa trip');
    expect([for (final m in s.members) m.name], ['Mohit', 'Asha', 'Ravi']);
    expect([for (final m in s.members) m.isMe], [true, false, false]);
    expect(s.split.kind, SplitKind.equal);
    expect(s.canSave, isTrue);
  });

  test('without an account nobody is me', () async {
    env.dispose();
    env = await ExpenseEnv.create(userId: null);
    await open();
    expect(state().members.any((m) => m.isMe), isFalse);
  });

  test('TC-35-01 the saved preset is applied', () async {
    final a = env.ids['Asha']!;
    final r = env.ids['Ravi']!;
    await env.container.read(groupsRepositoryProvider).update(env.groupId, {
      'default_split': {
        'kind': 'percent',
        'values': {env.me: 5000, a: 3000, r: 2000},
      },
    });
    await open();
    expect(state().split.kind, SplitKind.percent);
    expect(state().split.values, {env.me: 5000, a: 3000, r: 2000});
  });

  test('TC-35-01 a preset that no longer fits the members is ignored', () async {
    await env.container.read(groupsRepositoryProvider).update(env.groupId, {
      'default_split': {
        'kind': 'shares',
        'values': {env.me: 1000},
      },
    });
    await open();
    expect(state().split.kind, SplitKind.equal);
  });

  test('select switches kind with sensible values', () async {
    final c = await open();
    c.select(SplitKind.percent);
    expect(state().split.kind, SplitKind.percent);
    expect(state().split.values!.values.fold(0, (a, b) => a + b), 10000);
    expect(state().canSave, isTrue);
    c.select(SplitKind.shares);
    expect(state().split.values!.values, everyElement(1000));
    expect(state().split.values, hasLength(3));
    c.select(SplitKind.equal);
    expect(state().split.kind, SplitKind.equal);
  });

  test('edit changes the split; canSave is false when percent is not 100 %', () async {
    final c = await open();
    c.select(SplitKind.percent);
    c.edit((s) => s.setText(env.me, '10'));
    expect(state().canSave, isFalse);
    expect(state().check, isA<SplitInvalid>());
    expect(await c.save(), isFalse);
    expect(await group().then((g) => g.defaultSplit), isNull);

    c.edit(
      (s) =>
          s.setText(env.me, '50').setText(env.ids['Asha']!, '30').setText(env.ids['Ravi']!, '20'),
    );
    expect(state().canSave, isTrue);
  });

  test('save writes default_split {kind, values} through the groups repository', () async {
    final a = env.ids['Asha']!;
    final r = env.ids['Ravi']!;
    final c = await open();
    c.select(SplitKind.percent);
    c.edit((s) => s.setText(env.me, '50').setText(a, '30').setText(r, '20'));
    expect(await c.save(), isTrue);

    final g = await group();
    expect(jsonDecode(g.defaultSplit!), {
      'kind': 'percent',
      'values': {env.me: 5000, a: 3000, r: 2000},
    });
    final out = await env.db.select(env.db.outbox).get();
    expect(out.last.entity, 'group');
    expect((jsonDecode(out.last.payload) as Map)['default_split'], {
      'kind': 'percent',
      'values': {env.me: 5000, a: 3000, r: 2000},
    });
  });

  test('shares save, then selecting equal and saving clears the default', () async {
    final c = await open();
    c.select(SplitKind.shares);
    c.edit((s) => s.setShareUnits(env.ids['Asha']!, 2000));
    expect(await c.save(), isTrue);
    expect(jsonDecode((await group()).defaultSplit!)['kind'], 'shares');

    c.select(SplitKind.equal);
    expect(await c.save(), isTrue);
    expect((await group()).defaultSplit, isNull);
  });

  test('shares with nobody cannot be saved', () async {
    final c = await open();
    c.select(SplitKind.shares);
    c.edit(
      (s) => s
          .setShareUnits(env.me, 0)
          .setShareUnits(env.ids['Asha']!, 0)
          .setShareUnits(env.ids['Ravi']!, 0),
    );
    expect(state().canSave, isFalse);
    expect(await c.save(), isFalse);
  });

  test('edit and save before loading do nothing', () async {
    final p = defaultSplitProvider(env.groupId);
    env.container.listen(p, (_, _) {});
    final c = env.container.read(p.notifier);
    c.select(SplitKind.percent);
    c.edit((s) => s);
    expect(env.container.read(p).hasValue, isFalse);
    expect(await c.save(), isFalse);
  });

  test('ExpenseNotFound when the group is missing', () async {
    final p = defaultSplitProvider('nope');
    env.container.listen(p, (_, _) {}, onError: (_, _) {});
    await expectLater(env.container.read(p.future), throwsA(isA<ExpenseNotFound>()));
  });
}
