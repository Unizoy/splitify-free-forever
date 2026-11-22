import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/groups/application/groups_providers.dart' as groups;

import '../../../data/sync/sync_fakes.dart';

/// A group "Goa trip" (INR) owned by Mohit (user `u1`) plus [others], on an in-memory database.
class ExpenseEnv {
  ExpenseEnv._(this.db, this.remote, this.clock, this.container);

  final AppDatabase db;
  final FakeRemoteApi remote;
  final FakeClock clock;
  final ProviderContainer container;

  late String groupId;

  /// Member ids by display name.
  final ids = <String, String>{};

  String get me => ids['Mohit']!;

  static Future<ExpenseEnv> create({
    List<String> others = const ['Asha', 'Ravi'],
    String? userId = 'u1',
    List<Override> overrides = const [],
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = memoryDb();
    final remote = FakeRemoteApi();
    final clock = FakeClock(DateTime(2026, 11, 21, 10));
    final container = ProviderContainer(
      // Riverpod 3 retries failed builds; tests want the first error.
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        remoteApiProvider.overrideWithValue(remote),
        clockProvider.overrideWithValue(clock),
        currentUserIdProvider.overrideWithValue(userId),
        ...overrides,
        groups.currentUserIdProvider.overrideWithValue(userId),
      ],
    );
    final env = ExpenseEnv._(db, remote, clock, container);
    env.groupId = await container
        .read(groupsRepositoryProvider)
        .create(name: 'Goa trip', ownerName: 'Mohit', ownerUserId: 'u1', mainCurrency: 'INR');
    for (final name in others) {
      await env.addMember(name);
    }
    await env.reloadIds();
    return env;
  }

  Future<void> addMember(String name) async {
    await container.read(membersRepositoryProvider).addNameOnly(groupId, name);
    await reloadIds();
  }

  Future<void> reloadIds() async {
    ids
      ..clear()
      ..addEntries([
        for (final m in await db.select(db.groupMembers).get()) MapEntry(m.displayName, m.id),
      ]);
  }

  /// Loads the editor and keeps it alive (Riverpod 3 pauses unlistened providers).
  Future<Editor> open({String? expenseId, String? groupId}) async {
    final args = (
      groupId: expenseId == null ? (groupId ?? this.groupId) : groupId,
      expenseId: expenseId,
    );
    final p = expenseEditorProvider(args);
    container.invalidate(p);
    container.listen(p, (_, _) {});
    await container.read(p.future);
    return Editor(container, args);
  }

  void dispose() {
    container.dispose();
    unawaited(db.close());
  }
}

/// Handle on one open editor.
class Editor {
  Editor(this._c, this.args);

  final ProviderContainer _c;
  final ExpenseEditorArgs args;

  ExpenseEditorController get controller => _c.read(expenseEditorProvider(args).notifier);

  ExpenseDraft get draft => _c.read(expenseEditorProvider(args)).requireValue;

  void edit(ExpenseDraft Function(ExpenseDraft d) change) => controller.edit(change);

  Future<String?> save() => controller.save();
}
