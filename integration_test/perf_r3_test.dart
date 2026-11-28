// R3-B profile-mode numbers (S-450) on the shared emulator WITHOUT the flutter tool on the device: the flutter
// tool uninstalls the app it ran when `flutter drive`/`flutter test` ends (S-415), so this file is built as a
// profile APK with the side-by-side `.qa` id, installed with `adb install -r`, started with `am start`, and
// it prints one `R3PERF {json}` line to logcat (`tool/e2e/perf_r3.ps1`). Frame numbers come from the engine's
// own FrameTiming reports (no VM service, no host driver).
//
// Data: 50 groups and ~5,000 expenses (group 0 has 2,000), 300 activity rows, seeded like one pull from the
// server and signed in without a server (the run never syncs). Screens: Groups home (open + scroll), the
// 2,000-expense group (open + scroll), a sync "storm" while that group is open (10 pulls into other groups),
// the expense editor, Insights over every group, search over every row, and RSS after opening and closing
// those screens 20 times.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show ProcessInfo;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/groups/presentation/group_detail_screen.dart';
import 'package:splitify/features/groups/presentation/groups_home_screen.dart';
import 'package:splitify/features/insights/presentation/insights_routes.dart';
import 'package:splitify/features/insights/presentation/insights_screen.dart';
import 'package:splitify/features/search/presentation/search_screen.dart';

/// Signed in as [id] without a server.
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
const _groupCount = 50;
const _bigExpenses = 2000;
const _expensesPerGroup = 62;
const _feedPerGroup = 6;

const _what = [
  ('Dinner at Toit', 'food.dining_out'),
  ('Cab to airport', 'travel.cab_auto'),
  ('Groceries', 'groceries.groceries'),
  ('Electricity bill', 'utilities.electricity'),
  ('Movie tickets', 'entertainment.movies'),
  ('Hotel booking', 'travel.hotel'),
  ('Breakfast', 'food.snacks'),
  ('Petrol', 'travel.fuel'),
  ('Biryani takeaway', 'food.takeaway'),
  ('Train tickets', 'travel.train_bus'),
  ('Rent', 'rent.rent'),
  ('Birthday gift', 'shopping.gifts'),
];

const _types = ['trip', 'home', 'couple', 'other'];
const _names = ['Asha', 'Rohan', 'Priya', 'Kabir', 'Meera', 'Arjun', 'Isha', 'Dev', 'Tara', 'Neel'];

String _iso(DateTime d) => d.toIso8601String();
String _day(DateTime d) => d.toIso8601String().substring(0, 10);

/// One expense row as `pull_changes` sends it; leftover units go one each in member order (rule 2).
Map<String, Object?> _expense(String gid, List<String> ids, int i, int k, DateTime at, int seq) {
  final total = 15000 + (i * 7919 + k * 104729) % 450000;
  final people = i % 5 == 4 ? ids.sublist(0, 3) : ids;
  final share = total ~/ people.length;
  final left = total - share * people.length;
  final what = _what[(i + k * 3) % _what.length];
  return {
    'id': newId(),
    'group_id': gid,
    'kind': 'expense',
    'description': what.$1,
    'notes': i % 7 == 0 ? 'Split from the group chat' : null,
    'category': what.$2,
    'date': _day(at),
    'currency': 'INR',
    'total': total,
    'payers': {ids[(i + k) % ids.length]: total},
    'shares': {for (var j = 0; j < people.length; j++) people[j]: share + (j < left ? 1 : 0)},
    'split_kind': 'equal',
    'split_values': null,
    'source': 'app',
    'created_at': _iso(at),
    'created_by': _me,
    'seq': seq,
  };
}

({PullPage page, List<String> groups, Map<String, List<String>> members, int seq}) _seed() {
  var seq = 0;
  final end = DateTime.utc(2026, 11, 20, 20);
  final groups = <Map<String, Object?>>[];
  final members = <Map<String, Object?>>[];
  final expenses = <Map<String, Object?>>[];
  final activity = <Map<String, Object?>>[];
  final groupIds = <String>[];
  final memberIds = <String, List<String>>{};
  for (var k = 0; k < _groupCount; k++) {
    final gid = newId();
    groupIds.add(gid);
    final n = k == 0 ? _bigExpenses : _expensesPerGroup;
    final step = k == 0 ? const Duration(hours: 6) : const Duration(hours: 60);
    DateTime at(int i) => end.subtract(step * (n - 1 - i) + Duration(hours: k * 3));
    final created = at(0).subtract(const Duration(days: 1));
    groups.add({
      'id': gid,
      'name': k == 0 ? 'Goa trip 2026' : 'Group ${k + 1}',
      'type': _types[k % _types.length],
      'main_currency': 'INR',
      'cover_kind': 'generated',
      'simplify_debts': false,
      'archived_at': null,
      'created_at': _iso(created),
      'created_by': _me,
      'seq': ++seq,
    });
    final ids = <String>[];
    for (var m = 0; m < 6; m++) {
      final id = newId();
      ids.add(id);
      members.add({
        'id': id,
        'group_id': gid,
        'user_id': m == 0 ? _me : null,
        'display_name': m == 0 ? 'Sam' : _names[(k + m) % _names.length],
        'position': m,
        'role': m == 0 ? 'owner' : 'member',
        'status': 'active',
        'created_at': _iso(created.add(Duration(minutes: m))),
        'created_by': _me,
        'seq': ++seq,
      });
    }
    memberIds[gid] = ids;
    for (var i = 0; i < n; i++) {
      expenses.add(_expense(gid, ids, i, k, at(i), ++seq));
    }
    for (var j = 0; j < _feedPerGroup; j++) {
      final e = expenses[expenses.length - 1 - j];
      activity.add({
        'id': newId(),
        'group_id': gid,
        'actor_user_id': _me,
        'actor_member_id': ids[0],
        'type': 'expense_added',
        'target_type': 'expense',
        'target_id': e['id'],
        'data': {
          'description': e['description'],
          'total': e['total'],
          'currency': e['currency'],
          'members': [...(e['shares']! as Map<String, int>).keys]..sort(),
        },
        'created_at': e['created_at'],
        'seq': ++seq,
      });
    }
  }
  return (
    page: PullPage(
      serverTime: DateTime.now().toUtc(),
      userSeq: 0,
      nextCursors: {for (final g in groupIds) g: seq + 1},
      rows: {
        'profiles': [
          {'id': _me, 'display_name': 'Sam', 'upi_id': 'sam@okaxis', 'default_currency': 'INR'},
        ],
        'groups': groups,
        'group_members': members,
        'expenses': expenses,
        'activity': activity,
      },
    ),
    groups: groupIds,
    members: memberIds,
    seq: seq,
  );
}

/// The engine's frame reports (profile mode batches them about once a second).
class _Frames {
  final _all = <FrameTiming>[];

  void attach() => SchedulerBinding.instance.addTimingsCallback(_all.addAll);

  int get mark => _all.length;

  Map<String, Object> since(int mark) {
    final f = _all.sublist(mark);
    List<double> ms(Duration Function(FrameTiming) d) =>
        [for (final x in f) d(x).inMicroseconds / 1000]..sort();
    final b = ms((x) => x.buildDuration);
    final r = ms((x) => x.rasterDuration);
    double r1(double v) => (v * 10).roundToDouble() / 10;
    double avg(List<double> v) => v.isEmpty ? 0 : r1(v.reduce((a, c) => a + c) / v.length);
    double p90(List<double> v) => v.isEmpty ? 0 : r1(v[((v.length - 1) * 0.9).round()]);
    double worst(List<double> v) => v.isEmpty ? 0 : r1(v.last);
    return {
      'frames': f.length,
      'build_avg': avg(b),
      'build_p90': p90(b),
      'build_worst': worst(b),
      'build_over_16ms': b.where((v) => v > 16.7).length,
      'raster_avg': avg(r),
      'raster_p90': p90(r),
    };
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final frames = _Frames()..attach();

  testWidgets('R3 perf: 50 groups, 2,000-expense group, storm, editor, insights, search, memory', (
    t,
  ) async {
    final env = Env.load();
    final data = _seed();
    final db = AppDatabase(NativeDatabase.memory());
    final seedClock = Stopwatch()..start();
    await t.runAsync(() => PullApplier(db).apply(data.page));
    seedClock.stop();
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
    final numbers = <String, Object>{
      'expenses': (data.page.rows['expenses'] ?? const []).length,
      'groups': _groupCount,
      'seed_ms': seedClock.elapsedMilliseconds,
    };

    Future<void> pumpFrames(int n) async {
      for (var i = 0; i < n; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
    }

    // Profile mode reports frame timings in batches about once a second.
    Future<void> flush() async {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500)));
      await t.pump();
    }

    /// Pumps until [finder] shows (max ~600 frames); returns the milliseconds it took.
    Future<int> until(Finder finder, Stopwatch sw) async {
      for (var i = 0; i < 600 && finder.evaluate().isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(finder, findsWidgets);
      return sw.elapsedMilliseconds;
    }

    Future<void> segment(String name, Future<void> Function() body) async {
      await flush();
      final mark = frames.mark;
      await body();
      await flush();
      numbers[name] = frames.since(mark);
      // Each part as soon as it is measured, so a later failure keeps what came before.
      debugPrint('R3PERF-SEG $name ${jsonEncode(numbers[name])}');
    }

    Future<void> scroll(Type screen) async {
      final list = find
          .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
          .first;
      for (var i = 0; i < 4; i++) {
        await t.fling(list, const Offset(0, -1200), 3000);
        await pumpFrames(50);
      }
      for (var i = 0; i < 2; i++) {
        await t.fling(list, const Offset(0, 1200), 3000);
        await pumpFrames(50);
      }
    }

    final router = container.read(routerProvider);
    final big = data.groups.first;

    // 1. Groups home with 50 groups: the app's first frames, then the cards.
    await segment('groups_open', () async {
      final sw = Stopwatch()..start();
      await t.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
      numbers['groups_first_frame_ms'] = sw.elapsedMilliseconds;
      numbers['groups_cards_ms'] = await until(find.byKey(Key('group-card-$big')), sw);
      await pumpFrames(30);
    });
    expect(find.byType(GroupsHomeScreen), findsOneWidget);
    await segment('groups_scroll', () => scroll(GroupsHomeScreen));

    // 2. The 2,000-expense group: open until the first row shows, then scroll.
    await segment('group_open', () async {
      final sw = Stopwatch()..start();
      unawaited(router.push(Routes.group(big)));
      await t.pump();
      numbers['group_first_frame_ms'] = sw.elapsedMilliseconds;
      numbers['group_rows_ms'] = await until(find.byType(ExpenseRow), sw);
      await pumpFrames(30);
    });
    expect(find.byType(GroupDetailScreen), findsOneWidget);
    await segment('group_scroll', () => scroll(GroupDetailScreen));

    // 3. Sync storm while the big group is open: 10 pulls, each one expense into another group.
    var seq = data.seq;
    await segment('sync_storm', () async {
      for (var i = 0; i < 10; i++) {
        final gid = data.groups[1 + i];
        final row = _expense(
          gid,
          data.members[gid]!,
          900 + i,
          1 + i,
          DateTime.utc(2026, 11, 21),
          ++seq,
        );
        await t.runAsync(
          () => PullApplier(db).apply(
            PullPage(
              serverTime: DateTime.now().toUtc(),
              userSeq: 0,
              nextCursors: {gid: seq + 1},
              rows: {
                'expenses': [row],
              },
            ),
          ),
        );
        await pumpFrames(6);
      }
    });

    // 4. The editor from the group page.
    await segment('editor_open', () async {
      final sw = Stopwatch()..start();
      unawaited(router.push(ExpenseRoutes.add(big)));
      await t.pump();
      numbers['editor_first_frame_ms'] = sw.elapsedMilliseconds;
      numbers['editor_ready_ms'] = await until(find.byKey(const Key('expense-amount-input')), sw);
      await pumpFrames(30);
    });
    expect(find.byType(ExpenseEditorScreen), findsOneWidget);
    router.pop();
    await pumpFrames(30);

    // 5. Insights over every group (my shares).
    await segment('insights_open', () async {
      final sw = Stopwatch()..start();
      unawaited(router.push(InsightsRoutes.me));
      await t.pump();
      numbers['insights_first_frame_ms'] = sw.elapsedMilliseconds;
      numbers['insights_ready_ms'] = await until(find.byKey(const Key('insights-categories')), sw);
      await pumpFrames(30);
    });
    expect(find.byType(InsightsScreen), findsOneWidget);
    router.pop();
    await pumpFrames(30);

    // 6. Search over ~5,000 expenses: type a word, time until results show.
    unawaited(router.push(SearchRoutes.search()));
    await pumpFrames(30);
    expect(find.byType(SearchScreen), findsOneWidget);
    // The field takes focus on open and talks to the real keyboard: hand it to the test keyboard first.
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpFrames(10);
    binding.testTextInput.register();
    await segment('search', () async {
      final sw = Stopwatch()..start();
      await t.enterText(find.byKey(const Key('search-field')), 'biryani');
      numbers['search_results_ms'] = await until(find.byType(ExpenseRow), sw);
      await pumpFrames(30);
    });
    router.pop();
    await pumpFrames(30);
    router.pop();
    await pumpFrames(30);

    // 7. Memory: open and close the group page, the editor and Insights 20 times each.
    await flush();
    final rssBefore = ProcessInfo.currentRss;
    for (var i = 0; i < 20; i++) {
      for (final route in [Routes.group(big), ExpenseRoutes.add(big), InsightsRoutes.me]) {
        unawaited(router.push(route));
        await pumpFrames(12);
        router.pop();
        await pumpFrames(12);
      }
    }
    await flush();
    await pumpFrames(60);
    numbers['rss_mb_before'] = rssBefore ~/ (1024 * 1024);
    numbers['rss_mb_after_20x'] = ProcessInfo.currentRss ~/ (1024 * 1024);
    numbers['rss_mb_max'] = ProcessInfo.maxRss ~/ (1024 * 1024);

    debugPrint(
      'R3PERF ${jsonEncode({for (final e in numbers.entries)
        if (e.value is! Map) e.key: e.value})}',
    );
    debugPrint('R3PERF-DONE');
    await t.pumpWidget(const SizedBox());
    await pumpFrames(10);
  });
}
