// R3-B motion capture (S-451/S-452): drives the key animations at real speed on the emulator while
// `adb shell screenrecord` films them (`tool/e2e/capture_r3b.ps1`, built as a profile APK with the `.qa` id and
// started with `am start`, like perf_r3_test.dart — the flutter tool never touches the device). Seeded like a
// pull, signed in without a server; prints `R3CAP <step>` lines so the video can be cut by step.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/sync/pull_applier.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';

class _SignedIn implements AuthRepository {
  const _SignedIn(this.id);

  final String id;

  @override
  AuthUser? get currentUser => AuthUser(id: id);

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(currentUser);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _me = '00000000-0000-4000-8000-0000000000aa';

({PullPage page, String open, String settled}) _seed() {
  var seq = 0;
  final groups = <Map<String, Object?>>[];
  final members = <Map<String, Object?>>[];
  final expenses = <Map<String, Object?>>[];
  final payments = <Map<String, Object?>>[];
  String group(String name, String type, {String created = '2026-11-01T10:00:00Z'}) {
    final id = newId();
    groups.add({
      'id': id,
      'name': name,
      'type': type,
      'main_currency': 'INR',
      'cover_kind': 'generated',
      'simplify_debts': false,
      'created_at': created,
      'created_by': _me,
      'seq': ++seq,
    });
    return id;
  }

  List<String> people(String gid, List<String> names) => [
    for (final (i, n) in names.indexed)
      () {
        final id = newId();
        members.add({
          'id': id,
          'group_id': gid,
          'user_id': i == 0 ? _me : null,
          'display_name': n,
          'position': i,
          'role': i == 0 ? 'owner' : 'member',
          'status': 'active',
          'created_at': '2026-11-01T10:0$i:00Z',
          'created_by': _me,
          'seq': ++seq,
        });
        return id;
      }(),
  ];

  void expense(
    String gid,
    String what,
    String cat,
    int total,
    String payer,
    List<String> among,
    int day,
  ) {
    final share = total ~/ among.length;
    final left = total - share * among.length;
    expenses.add({
      'id': newId(),
      'group_id': gid,
      'kind': 'expense',
      'description': what,
      'category': cat,
      'date': '2026-11-${day.toString().padLeft(2, '0')}',
      'currency': 'INR',
      'total': total,
      'payers': {payer: total},
      'shares': {for (var j = 0; j < among.length; j++) among[j]: share + (j < left ? 1 : 0)},
      'split_kind': 'equal',
      'source': 'app',
      'created_at': '2026-11-${day.toString().padLeft(2, '0')}T12:00:00Z',
      'created_by': _me,
      'seq': ++seq,
    });
  }

  // The newest group: its card comes first on the Groups home.
  final goa = group('Goa trip', 'trip', created: '2026-11-25T10:00:00Z');
  final g = people(goa, ['Sam', 'Asha', 'Rohan', 'Priya']);
  const what = [
    ('Dinner at Thalassa', 'food.dining_out'),
    ('Cab to airport', 'travel.cab_auto'),
    ('Groceries', 'groceries.groceries'),
    ('Scooter rental', 'travel.cab_auto'),
    ('Beach shack', 'food.dining_out'),
  ];
  for (var i = 0; i < 24; i++) {
    final w = what[i % what.length];
    expense(goa, w.$1, w.$2, 120000 + i * 3700, g[i % 4], g, 1 + i);
  }
  final flat = group('Flat 4B', 'home');
  final f = people(flat, ['Sam', 'Meera']);
  expense(flat, 'Electricity bill', 'utilities.electricity', 240000, f[0], f, 3);
  expense(flat, 'Wifi bill', 'utilities.internet_phone', 120000, f[1], f, 5);
  // Meera paid back what she owed: the flat is settled, its history folds (D-034 C2).
  payments.add({
    'id': newId(),
    'group_id': flat,
    'from_member': f[1],
    'to_member': f[0],
    'amount': 60000,
    'currency': 'INR',
    'date': '2026-11-06',
    'method': 'upi',
    'created_at': '2026-11-06T12:00:00Z',
    'created_by': _me,
    'seq': ++seq,
  });
  for (final (name, type) in [
    ('Office lunch', 'other'),
    ('Date nights', 'couple'),
    ('Coorg weekend', 'trip'),
  ]) {
    final id = group(name, type);
    final p = people(id, ['Sam', 'Kabir', 'Isha']);
    expense(id, 'Lunch', 'food.dining_out', 90000, p[1], p, 10);
  }
  return (
    page: PullPage(
      serverTime: DateTime.now().toUtc(),
      userSeq: 0,
      nextCursors: {for (final gr in groups) gr['id']! as String: seq + 1},
      rows: {
        'profiles': [
          {'id': _me, 'display_name': 'Sam', 'upi_id': 'sam@okaxis', 'default_currency': 'INR'},
        ],
        'groups': groups,
        'group_members': members,
        'expenses': expenses,
        'payments': payments,
      },
    ),
    open: goa,
    settled: flat,
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('R3-B motion capture', (t) async {
    final env = Env.load();
    final data = _seed();
    final db = AppDatabase(NativeDatabase.memory());
    await t.runAsync(() => PullApplier(db).apply(data.page));
    final prefs = (await t.runAsync(SharedPreferences.getInstance))!;
    final container = ProviderContainer(
      overrides: [
        ...appOverrides(
          env: env,
          prefs: prefs,
          remote: const RemoteServices(auth: _SignedIn(_me), profiles: null),
        ),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    /// Real time on screen (the recording needs the frames; live pumps follow the clock).
    Future<void> hold(int ms) async {
      final end = DateTime.now().add(Duration(milliseconds: ms));
      while (DateTime.now().isBefore(end)) {
        await t.pump(const Duration(milliseconds: 16));
      }
    }

    void step(String name) => debugPrint('R3CAP $name');

    Future<void> tapKey(String key) async {
      final f = find.byKey(Key(key));
      if (f.evaluate().isEmpty) {
        // Lazy lists build only what is near the screen.
        await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
      }
      await t.ensureVisible(f.first);
      await t.pump();
      await t.tap(f.first);
    }

    step('start');
    await t.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
    await hold(2500);

    step('group-card-hero');
    await tapKey('group-card-${data.open}');
    await hold(1500);

    step('who-owes-whom');
    await tapKey('group-lines-toggle');
    await hold(900);
    await tapKey('group-lines-toggle');
    await hold(900);

    step('editor-save-insert');
    unawaited(router.push(ExpenseRoutes.add(data.open)));
    await hold(900);
    FocusManager.instance.primaryFocus?.unfocus();
    await hold(200);
    binding.testTextInput.register();
    await t.enterText(find.byKey(const Key('expense-description')), 'Sunset cruise');
    await hold(300);
    await t.enterText(find.byKey(const Key('expense-amount-input')), '3200');
    await hold(500);
    FocusManager.instance.primaryFocus?.unfocus();
    await hold(300);
    await tapKey('expense-save');
    await hold(2200);

    step('settled-history');
    router.go(Routes.group(data.settled));
    await hold(1500);
    await tapKey('expenses-settled');
    await hold(1500);
    await tapKey('expenses-settled');
    await hold(1000);

    step('home-filter');
    router.go(Routes.groups);
    await hold(1500);

    step('done');
    debugPrint('R3CAP-DONE');
    await hold(500);
  });
}
