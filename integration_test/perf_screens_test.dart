// Motion/scroll polish frame timings (profile mode) on four screens with realistic data: Groups home, a big
// group (600 expenses), the all-groups Activity feed (300 rows) and a friend page (5 shared groups). Every
// screen gets the same scroll script, so numbers compare across screens and before/after a change.
// Seeded like a pull from the server (one page), signed in without a server (the run never syncs).
// Run with the host driver (prints one `PERF <key>` line per timeline):
//   flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf_screens_test.dart -d emulator-5554 \
//     --dart-define-from-file=secrets/env.dev.json
import 'dart:async';
import 'dart:convert';

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
import 'package:splitify/features/activity/presentation/activity_screen.dart';
import 'package:splitify/features/friends/presentation/friend_page.dart';
import 'package:splitify/features/friends/presentation/friend_routes.dart';
import 'package:splitify/features/groups/presentation/group_detail_screen.dart';
import 'package:splitify/features/groups/presentation/groups_home_screen.dart';

/// Signed in as [id] without a server (the perf run never syncs).
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

/// Real accounts shared across groups (Friends tab, friend page): id, name, groups they are in.
const _asha = '00000000-0000-4000-8000-0000000000a1';
const _rohan = '00000000-0000-4000-8000-0000000000a2';
const _priya = '00000000-0000-4000-8000-0000000000a3';
const _people = [
  (id: _asha, name: 'Asha Verma', groups: {0, 2, 4, 6, 8, 10}),
  (id: _rohan, name: 'Rohan Mehta', groups: {1, 2, 3, 5, 7}),
  (id: _priya, name: 'Priya Nair', groups: {0, 3, 6, 9, 11}),
];

/// The friend page measured: Rohan shares 5 normal groups (300 expenses, payments) with me.
const _friendKey = 'u:$_rohan';

const _nameOnly = [
  'Kabir',
  'Meera',
  'Arjun',
  'Isha',
  'Dev',
  'Tara',
  'Neel',
  'Zoya',
  'Vikram',
  'Ananya',
  'Sameer',
  'Riya',
];

/// 12 groups: name, type, currency; group 0 is the big one, group 11 is archived.
const _groups = [
  (name: 'Goa trip 2026', type: 'trip', currency: 'INR'),
  (name: 'Flat 4B', type: 'home', currency: 'INR'),
  (name: 'Ladakh road trip', type: 'trip', currency: 'INR'),
  (name: 'Office lunch', type: 'other', currency: 'INR'),
  (name: 'Date nights', type: 'couple', currency: 'INR'),
  (name: 'Koramangala PG', type: 'home', currency: 'INR'),
  (name: 'Coorg weekend', type: 'trip', currency: 'INR'),
  (name: 'Badminton club', type: 'other', currency: 'INR'),
  (name: 'Anniversary plans', type: 'couple', currency: 'INR'),
  (name: 'Europe 2026', type: 'trip', currency: 'EUR'),
  (name: 'Diwali party', type: 'other', currency: 'INR'),
  (name: 'Old flat', type: 'home', currency: 'INR'),
];

const _bigExpenses = 600;
const _expensesPerGroup = 60;
const _paymentsPerGroup = 4;

/// Activity rows per group: group_created, 5 × member_added, 19 expense/payment/comment rows (12 × 25 = 300,
/// the feed's limit).
const _feedPerGroup = 19;

const _what = [
  ('Dinner at Toit', 'food.dining_out'),
  ('Cab to airport', 'travel.cab_auto'),
  ('Groceries', 'groceries.groceries'),
  ('Electricity bill', 'utilities.electricity'),
  ('Movie tickets', 'entertainment.movies'),
  ('Hotel booking', 'travel.hotel'),
  ('Breakfast', 'food.snacks'),
  ('Petrol', 'travel.fuel'),
  ('Wifi bill', 'utilities.internet_phone'),
  ('Biryani takeaway', 'food.takeaway'),
  ('Train tickets', 'travel.train_bus'),
  ('Coffee run', 'food.snacks'),
  ('Rent', 'rent.rent'),
  ('Birthday gift', 'shopping.gifts'),
  ('Parking and tolls', 'travel.parking_tolls'),
  ('Household supplies', 'groceries.household'),
];

class _Seed {
  _Seed(this.page, this.bigGroup, this.counts);

  final PullPage page;
  final String bigGroup;
  final Map<String, int> counts;
}

/// One `pull_changes` page with everything (12 groups, 1,260 expenses, 48 payments, 300 activity rows).
_Seed _seed() {
  var seq = 0;
  final end = DateTime.utc(2026, 11, 15, 20);
  String iso(DateTime d) => d.toIso8601String();
  String day(DateTime d) => d.toIso8601String().substring(0, 10);

  final profiles = <Map<String, Object?>>[
    {'id': _me, 'display_name': 'Sam', 'upi_id': 'sam@okaxis', 'default_currency': 'INR'},
    for (final p in _people)
      {
        'id': p.id,
        'display_name': p.name,
        'upi_id': '${p.name.split(' ').first.toLowerCase()}@okhdfc',
        'default_currency': 'INR',
      },
  ];
  final groups = <Map<String, Object?>>[];
  final members = <Map<String, Object?>>[];
  final expenses = <Map<String, Object?>>[];
  final payments = <Map<String, Object?>>[];
  final comments = <Map<String, Object?>>[];
  final activity = <Map<String, Object?>>[];
  final groupIds = <String>[];

  for (var k = 0; k < _groups.length; k++) {
    final spec = _groups[k];
    final gid = newId();
    groupIds.add(gid);
    final n = k == 0 ? _bigExpenses : _expensesPerGroup;
    final step = k == 0 ? const Duration(hours: 8) : const Duration(hours: 72);
    DateTime at(int i) => end.subtract(step * (n - 1 - i) + Duration(hours: k * 5));
    final created = at(0).subtract(const Duration(days: 1));
    final eur = spec.currency == 'EUR';

    groups.add({
      'id': gid,
      'name': spec.name,
      'type': spec.type,
      'main_currency': spec.currency,
      'cover_kind': 'generated',
      'simplify_debts': false,
      'archived_at': k == 11 ? iso(end) : null,
      'created_at': iso(created),
      'created_by': _me,
      'seq': ++seq,
    });

    // Me first, then the real people in this group, then name-only people up to 6.
    final ids = <String>[];
    final users = <String?>[];
    final names = <String>[];
    void member(String? userId, String name) {
      final id = newId();
      final position = ids.length;
      ids.add(id);
      users.add(userId);
      names.add(name);
      members.add({
        'id': id,
        'group_id': gid,
        'user_id': userId,
        'display_name': name,
        'position': position,
        'role': position == 0 ? 'owner' : 'member',
        'status': 'active',
        'created_at': iso(created.add(Duration(minutes: position))),
        'created_by': _me,
        'seq': ++seq,
      });
    }

    member(_me, 'Sam');
    for (final p in _people) {
      if (p.groups.contains(k)) member(p.id, p.name);
    }
    var extra = k;
    while (ids.length < 6) {
      member(null, _nameOnly[extra++ % _nameOnly.length]);
    }

    // Expenses: payer rotates; every 5th is split among 3 people, the rest among all 6. Leftover units go
    // one each to people in member order (rule 2), so the parts sum to the total.
    final expenseIds = <String>[];
    for (var i = 0; i < n; i++) {
      final id = newId();
      expenseIds.add(id);
      final total = eur
          ? 500 + (i * 7919 + k * 104729) % 20000
          : 15000 + (i * 7919 + k * 104729) % 450000;
      final payer = ids[(i + k) % ids.length];
      final r = i ~/ 5;
      final people = i % 5 == 4 ? [ids[0], ids[1 + r % 5], ids[1 + (r + 2) % 5]] : ids;
      final share = total ~/ people.length;
      final left = total - share * people.length;
      final shares = {
        for (var j = 0; j < people.length; j++) people[j]: share + (j < left ? 1 : 0),
      };
      final what = _what[(i + k * 3) % _what.length];
      expenses.add({
        'id': id,
        'group_id': gid,
        'kind': 'expense',
        'description': what.$1,
        'notes': i % 7 == 0 ? 'Split from the group chat' : null,
        'category': what.$2,
        'date': day(at(i)),
        'currency': spec.currency,
        'total': total,
        'payers': {payer: total},
        'shares': shares,
        'split_kind': 'equal',
        'split_values': null,
        'source': 'app',
        'created_at': iso(at(i)),
        'created_by': _me,
        'seq': ++seq,
      });
    }

    // Payments: four people paid me back over the last weeks (Rohan is one of them in his groups).
    final paymentIds = <String>[];
    for (var j = 0; j < _paymentsPerGroup; j++) {
      final id = newId();
      paymentIds.add(id);
      final when = end.subtract(Duration(days: 3 * j + 1, hours: k));
      payments.add({
        'id': id,
        'group_id': gid,
        'from_member': ids[1 + j],
        'to_member': ids[0],
        'amount': eur ? 2500 + j * 750 : 50000 + j * 12345,
        'currency': spec.currency,
        'date': day(when),
        'method': j.isEven ? 'upi' : 'cash',
        'note': null,
        'created_at': iso(when),
        'created_by': users[1 + j] ?? _me,
        'seq': ++seq,
      });
    }

    // Activity feed rows (what the server's activity trigger writes, 0009_sync.sql).
    String? actorUser(int j) =>
        j.isEven ? _me : (users.skip(1).whereType<String>().firstOrNull ?? _me);
    String actorMember(int j) => ids[users.indexOf(actorUser(j))];
    activity.add({
      'id': newId(),
      'group_id': gid,
      'actor_user_id': _me,
      'actor_member_id': ids[0],
      'type': 'group_created',
      'target_type': 'group',
      'target_id': gid,
      'data': {'name': spec.name},
      'created_at': iso(created),
      'seq': ++seq,
    });
    for (var m = 1; m < ids.length; m++) {
      activity.add({
        'id': newId(),
        'group_id': gid,
        'actor_user_id': _me,
        'actor_member_id': ids[0],
        'type': 'member_added',
        'target_type': 'member',
        'target_id': ids[m],
        'data': {'member_id': ids[m], 'name': names[m]},
        'created_at': iso(created.add(Duration(minutes: m))),
        'seq': ++seq,
      });
    }
    var paid = 0;
    for (var j = 0; j < _feedPerGroup; j++) {
      final e = expenses[expenses.length - 1 - j];
      final eAt = DateTime.parse(e['created_at']! as String);
      final Map<String, Object?> row;
      if (j % 6 == 5 && paid < paymentIds.length) {
        final p = payments[payments.length - paymentIds.length + paid++];
        row = {
          'type': 'payment_added',
          'target_type': 'payment',
          'target_id': p['id'],
          'data': {
            'amount': p['amount'],
            'currency': p['currency'],
            'from_member': p['from_member'],
            'to_member': p['to_member'],
          },
          'created_at': p['created_at'],
        };
      } else if (j % 6 == 2) {
        final commentId = newId();
        final when = iso(eAt.add(const Duration(minutes: 40)));
        comments.add({
          'id': commentId,
          'group_id': gid,
          'target_type': 'expense',
          'target_id': e['id'],
          'body': 'Added the bill photo, check the amount?',
          'created_at': when,
          'created_by': actorUser(j),
          'seq': ++seq,
        });
        row = {
          'type': 'comment_added',
          'target_type': 'comment',
          'target_id': commentId,
          'data': {'target_type': 'expense', 'target_id': e['id']},
          'created_at': when,
        };
      } else {
        row = {
          'type': j % 6 == 4 ? 'expense_edited' : 'expense_added',
          'target_type': 'expense',
          'target_id': e['id'],
          'data': {
            'description': e['description'],
            'total': e['total'],
            'currency': e['currency'],
            'members': [...(e['shares']! as Map<String, int>).keys]..sort(),
          },
          'created_at': j % 6 == 4 ? iso(eAt.add(const Duration(hours: 2))) : e['created_at'],
        };
      }
      activity.add({
        'id': newId(),
        'group_id': gid,
        'actor_user_id': actorUser(j),
        'actor_member_id': actorMember(j),
        ...row,
        'seq': ++seq,
      });
    }
  }

  return _Seed(
    PullPage(
      serverTime: DateTime.now().toUtc(),
      userSeq: 0,
      nextCursors: {for (final g in groupIds) g: seq + 1},
      rows: {
        'profiles': profiles,
        'groups': groups,
        'group_members': members,
        'expenses': expenses,
        'payments': payments,
        'comments': comments,
        'activity': activity,
      },
    ),
    groupIds.first,
    {
      'groups': groups.length,
      'members': members.length,
      'expenses': expenses.length,
      'payments': payments.length,
      'comments': comments.length,
      'activity': activity.length,
    },
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Screens perf: groups, big group, activity, friend (open + scroll)', (t) async {
    final env = Env.load();
    final data = _seed();
    final db = AppDatabase(NativeDatabase.memory());
    final seed = Stopwatch()..start();
    await t.runAsync(() => PullApplier(db).apply(data.page));
    seed.stop();

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

    // Repeating animations (loaders) never settle: pump fixed frames instead of pumpAndSettle.
    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
    }

    final numbers = <String, Object>{...data.counts, 'seed_ms': seed.elapsedMilliseconds};

    /// First open of a screen: [go], then 30 frames (traced); the first frame and the whole open timed.
    Future<void> open(String name, Future<void> Function() go) async {
      await binding.traceAction(() async {
        final sw = Stopwatch()..start();
        await go();
        await t.pump(const Duration(milliseconds: 16));
        numbers['${name}_first_frame_ms'] = sw.elapsedMilliseconds;
        await frames(29);
        numbers['${name}_open_ms'] = sw.elapsedMilliseconds;
      }, reportKey: '${name}_open_timeline');
      await frames(120);
    }

    /// The same scroll script on every screen: 4 flings up, then 2 down, 60 frames after each.
    Future<void> scroll(String name, Type screen) async {
      final list = find
          .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
          .first;
      expect(list, findsOneWidget);
      expect(axisDirectionToAxis(t.widget<Scrollable>(list).axisDirection), Axis.vertical);
      await binding.traceAction(() async {
        for (var i = 0; i < 4; i++) {
          await t.fling(list, const Offset(0, -1200), 3000);
          await frames(60);
        }
        for (var i = 0; i < 2; i++) {
          await t.fling(list, const Offset(0, 1200), 3000);
          await frames(60);
        }
      }, reportKey: '${name}_timeline');
    }

    final router = container.read(routerProvider);

    // 1. Groups home: the app starts there (signed in → /groups), so its open is the app's first frames.
    await open(
      'groups',
      () => t.pumpWidget(UncontrolledProviderScope(container: container, child: const App())),
    );
    expect(find.byType(GroupsHomeScreen), findsOneWidget);
    await scroll('groups', GroupsHomeScreen);

    // 2. The big group (600 expenses).
    await open('group', () async => router.go(Routes.group(data.bigGroup)));
    expect(find.byType(GroupDetailScreen), findsOneWidget);
    await scroll('group', GroupDetailScreen);

    // 3. Activity tab (every group's feed, 300 rows).
    await open('activity', () async => router.go(Routes.activity));
    expect(find.byType(ActivityScreen), findsOneWidget);
    await scroll('activity', ActivityScreen);

    // 4. Friend page (Rohan: 5 shared groups).
    await open('friend', () async => router.go(FriendRoutes.page(_friendKey)));
    expect(find.byType(FriendPage), findsOneWidget);
    await scroll('friend', FriendPage);

    binding.reportData!.addAll(numbers);
    // Only the numbers: printing the timelines through debugPrint takes minutes (it is throttled).
    debugPrint('PERF-NUMBERS ${jsonEncode(numbers)}');
    // Unmount; the in-memory database is left open (closing it under live app streams never completed).
    await t.pumpWidget(const SizedBox());
    await frames(30);
  });
}
