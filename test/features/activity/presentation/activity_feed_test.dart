// TC-18-02 (feed grouping and filters): the activity sentences, the feed with day headers, the
// Activity tab, a group's own feed and its "Recent activity" section.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/activity/presentation/activity_feed.dart';
import 'package:splitify/features/activity/presentation/activity_screen.dart';
import 'package:splitify/features/activity/presentation/group_activity_screen.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/l10n/app_localizations_en.dart';
import 'package:splitify/ui/components/components.dart';

import '../../balances/balance_fixtures.dart';
import '../../expenses/presentation/presentation_harness.dart';

class _FeedHost extends StatelessWidget {
  const _FeedHost({required this.items, this.showGroup = true});

  final List<ActivityItem> items;
  final bool showGroup;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ActivityFeed(items: items, showGroup: showGroup),
      ),
    ),
  );
}

/// [home] at '/', with stubs for every place a row can open.
Future<void> _pump(
  WidgetTester t,
  Widget home, {
  List<Override> overrides = const [],
  double scale = 1,
}) async {
  usePhone(t);
  if (scale != 1) {
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await t.pumpWidget(const SizedBox());
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      stubRoute('/expense/:id'),
      stubRoute('/payment/:id'),
      stubRoute('/groups/:id/activity'),
      stubRoute('/groups/:id'),
    ],
  );
  await t.pumpWidget(routerApp(router, overrides: overrides));
  await settle(t);
}

AmountRow _row(WidgetTester t, String id) =>
    t.widget<AmountRow>(find.byKey(ValueKey('activity-$id')));

/// The caption with ICU's narrow no-break space before AM/PM turned into a plain space.
String _caption(WidgetTester t, String id) => _row(t, id).caption!.replaceAll(' ', ' ');

List<Override> _feed(AsyncValue<List<ActivityItem>> v, {String? group}) => [
  activityItemsProvider(group).overrideWithValue(v),
];

List<Override> _groupFeed(AsyncValue<List<ActivityItem>> v) => [
  ..._feed(v, group: gid),
  groupProvider.overrideWith((ref, id) => Stream.value(sampleGroup())),
];

bool _chipSelected(WidgetTester t, String name) =>
    t.widget<IconChip>(find.byKey(Key('activity-filter-$name'))).selected;

void main() {
  group('activitySentence', () {
    final l = AppLocalizationsEn();
    String s(
      String type, {
      ActivityPerson actor = activityMe,
      ActivityPerson? member,
      ActivityPerson? from,
      ActivityPerson? to,
      String? description,
    }) => activitySentence(
      l,
      activityOf(type, actor: actor, member: member, from: from, to: to, description: description),
    );

    // TC-18-02
    test('every activity type has a sentence', () {
      expect(s('group_created'), 'You created the group');
      expect(s('group_updated'), 'You updated the group');
      expect(s('group_archived'), 'You archived the group');
      expect(s('group_unarchived'), 'You brought the group back');
      expect(s('group_deleted'), 'You deleted the group');
      expect(s('group_restored'), 'You restored the group');
      expect(s('member_added', member: activityAsha), 'You added Asha Rao');
      expect(s('member_joined'), 'You joined the group');
      expect(s('member_claimed', member: activityAsha), 'You joined as Asha Rao');
      expect(s('member_left', member: activityAsha), 'Asha Rao left the group');
      expect(s('member_removed', member: activityAsha), 'You removed Asha Rao');
      expect(s('expense_added', description: 'Dinner'), 'You added “Dinner”');
      expect(s('expense_edited', description: 'Dinner'), 'You edited “Dinner”');
      expect(s('expense_deleted', description: 'Dinner'), 'You deleted “Dinner”');
      expect(s('expense_restored', description: 'Dinner'), 'You restored “Dinner”');
      expect(s('comment_added'), 'You added a comment');
      expect(s('comment_added', description: 'Dinner'), 'You commented on “Dinner”');
      expect(s('comment_deleted'), 'You deleted a comment');
      expect(s('reminder_sent'), 'You sent a payment reminder');
      expect(s('settings_changed'), 'You changed the group settings');
      expect(s('recurring_created'), 'You set up a recurring bill');
      expect(s('recurring_updated'), 'You changed a recurring bill');
      expect(s('recurring_stopped'), 'You stopped a recurring bill');
      expect(s('import_completed'), 'You imported expenses from Splitwise');
      expect(s('something_new'), 'You made a change');
    });

    // TC-18-02
    test('payment sentences name both people, "you" in the middle of a sentence', () {
      expect(
        s('payment_added', from: activityAsha, to: activityMe),
        'You recorded a payment from Asha Rao to you',
      );
      expect(
        s('payment_edited', from: activityMe, to: activityRahul),
        'You edited a payment from you to Rahul Mehta',
      );
      expect(
        s('payment_deleted', actor: activityAsha, from: activityRahul, to: activityPriya),
        'Asha Rao deleted a payment from Rahul Mehta to Priya Nair',
      );
      expect(
        s('payment_restored', actor: activityRahul, from: activityAsha, to: activityMe),
        'Rahul Mehta restored a payment from Asha Rao to you',
      );
    });

    // TC-18-02
    test('someone else as the actor, and unknown people', () {
      expect(
        s('expense_added', actor: activityAsha, description: 'Dinner'),
        'Asha Rao added “Dinner”',
      );
      const nobody = (name: '', seed: 'x', isMe: false);
      expect(s('expense_added', actor: nobody, description: 'Dinner'), 'Someone added “Dinner”');
      expect(s('member_added', member: nobody), 'You added Someone');
      expect(s('member_left', member: activityMe), 'You left the group');
      expect(s('expense_added'), 'You added “”');
    });
  });

  group('activityDay', () {
    // TC-18-02
    testWidgets('Today, Yesterday, then the weekday and date (with the year when not this year)', (
      t,
    ) async {
      late BuildContext ctx;
      await t.pumpWidget(
        expenseApp(
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final today = DateTime(2026, 11, 21, 10);
      expect(activityDay(ctx, DateTime(2026, 11, 21, 0, 5), today), 'Today');
      expect(activityDay(ctx, DateTime(2026, 11, 20, 23, 59), today), 'Yesterday');
      expect(activityDay(ctx, DateTime(2026, 11, 14, 11), today), 'Sat, 14 Nov');
      expect(activityDay(ctx, DateTime(2025, 12, 31, 11), today), 'Wed, 31 Dec 2025');
    });
  });

  group('ActivityFeed', () {
    // TC-18-02
    testWidgets('groups rows under Today, Yesterday and the older day, newest first', (t) async {
      await _pump(t, _FeedHost(items: sampleActivity()));
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.text('SAT, 14 NOV'), findsOneWidget);
      expect(find.byType(ActivityRow), findsNWidgets(6));
      double top(String id) => t.getTopLeft(find.byKey(ValueKey('activity-$id'))).dy;
      final order = ['a3', 'a1', 'a2', 'a4', 'a5', 'a6'];
      for (var i = 0; i + 1 < order.length; i++) {
        expect(top(order[i]), lessThan(top(order[i + 1])));
      }
      expect(t.getTopLeft(find.text('TODAY')).dy, lessThan(top('a3')));
      expect(t.getTopLeft(find.text('YESTERDAY')).dy, greaterThan(top('a2')));
      expect(t.getTopLeft(find.text('YESTERDAY')).dy, lessThan(top('a4')));
    });

    // TC-18-02
    testWidgets('each row has the sentence, group and time, and the amount when there is one', (
      t,
    ) async {
      await _pump(t, _FeedHost(items: sampleActivity()));
      expect(_row(t, 'a1').title, 'Asha Rao added “Dinner at Thalassa”');
      expect(_caption(t, 'a1'), 'Goa trip · 9:30 AM');
      expect(_row(t, 'a1').amountText, '₹2,400');
      expect(_row(t, 'a2').title, 'You recorded a payment from Asha Rao to you');
      expect(_row(t, 'a2').amountText, '₹500');
      expect(_row(t, 'a4').title, 'Rahul Mehta commented on “Dinner at Thalassa”');
      expect(_row(t, 'a4').amountText, '');
      expect(_caption(t, 'a4'), 'Goa trip · 6:45 PM');
      expect(_row(t, 'a5').title, 'Priya Nair joined the group');
      expect(_row(t, 'a6').title, 'You created the group');
    });

    // TC-18-02
    testWidgets('only my pending change carries the "not synced yet" marker', (t) async {
      await _pump(t, _FeedHost(items: sampleActivity()));
      expect(_row(t, 'a3').unsynced, isTrue);
      expect(_row(t, 'a3').title, 'You added “Cab to airport”');
      expect(_row(t, 'a1').unsynced, isFalse);
      expect(find.byType(SyncMarker), findsOneWidget);
    });

    // TC-18-02
    testWidgets('without the group name (a group\'s own feed) the caption is just the time', (
      t,
    ) async {
      await _pump(t, _FeedHost(items: sampleActivity(), showGroup: false));
      expect(_caption(t, 'a1'), '9:30 AM');
    });

    // TC-18-02
    testWidgets('taps open the expense, the payment or the group', (t) async {
      await _pump(t, _FeedHost(items: sampleActivity()));
      await tapKey(t, 'activity-a1');
      expect(find.text('at /expense/e1'), findsOneWidget);

      await _pump(t, _FeedHost(items: sampleActivity()));
      await tapKey(t, 'activity-a2');
      expect(find.text('at /payment/p1'), findsOneWidget);

      await _pump(t, _FeedHost(items: sampleActivity()));
      await tapKey(t, 'activity-a5');
      expect(find.text('at /groups/g-goa'), findsOneWidget);
    });

    // TC-18-02
    testWidgets('a row that is about nothing opens nothing', (t) async {
      final item = ActivityItem(
        id: 'z',
        type: 'reminder_sent',
        groupId: gid,
        groupName: 'Goa trip',
        at: DateTime(2026, 11, 21, 9),
        actor: activityAsha,
      );
      await _pump(t, _FeedHost(items: [item]));
      await tapKey(t, 'activity-z');
      expect(find.byKey(const Key('stub')), findsNothing);
      expect(find.byType(ActivityRow), findsOneWidget);
    });

    // TC-18-02
    testWidgets('the skeleton has a loading label', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, const Scaffold(body: FeedSkeleton()));
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      handle.dispose();
    });
  });

  group('ActivityScreen', () {
    // TC-18-02
    testWidgets('shows every group\'s activity with the filter chips, All selected', (t) async {
      await _pump(t, const ActivityScreen(), overrides: _feed(AsyncData(sampleActivity())));
      for (final label in ['All', 'Expenses', 'Payments', 'Comments', 'Groups']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(_chipSelected(t, 'all'), isTrue);
      expect(find.text('every rupee,\naccounted for.'), findsOneWidget);
      expect(find.byKey(const ValueKey('activity-a1')), findsOneWidget);
    });

    // TC-18-02
    testWidgets('each filter keeps only its kind of row', (t) async {
      await _pump(t, const ActivityScreen(), overrides: _feed(AsyncData(sampleActivity())));
      Future<void> pick(String name) async {
        await t.tap(find.byKey(Key('activity-filter-$name')));
        await settle(t);
      }

      Set<String> shown() => {
        for (final id in ['a1', 'a2', 'a3', 'a4', 'a5', 'a6'])
          if (find.byKey(ValueKey('activity-$id')).evaluate().isNotEmpty) id,
      };

      await pick('expenses');
      expect(_chipSelected(t, 'expenses'), isTrue);
      expect(_chipSelected(t, 'all'), isFalse);
      expect(shown(), {'a1', 'a3'});
      await pick('payments');
      expect(shown(), {'a2'});
      await pick('comments');
      expect(shown(), {'a4'});
      await pick('groups');
      expect(shown(), {'a5', 'a6'});
      await pick('all');
      expect(shown(), {'a1', 'a2', 'a3', 'a4', 'a5', 'a6'});
    });

    // TC-18-02
    testWidgets('a filter with no rows says so, and All brings the rows back', (t) async {
      await _pump(t, const ActivityScreen(), overrides: _feed(AsyncData([sampleActivity().first])));
      await t.tap(find.byKey(const Key('activity-filter-payments')));
      await settle(t);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Try another filter, or check back after the next change.'), findsOneWidget);
      expect(find.byType(ActivityRow), findsNothing);
      await t.tap(find.byKey(const Key('activity-filter-all')));
      await settle(t);
      expect(find.byType(ActivityRow), findsOneWidget);
    });

    // TC-18-02
    testWidgets('no activity at all: the blob empty state and no filter chips', (t) async {
      await _pump(t, const ActivityScreen(), overrides: _feed(const AsyncData([])));
      expect(find.text('No activity yet'), findsOneWidget);
      expect(find.text('Expenses, payments and comments show up here.'), findsOneWidget);
      expect(find.byType(BlobBackground), findsOneWidget);
      expect(find.byKey(const Key('activity-filter-all')), findsNothing);
    });

    // TC-18-02
    testWidgets('loading shows the skeleton, an error says so', (t) async {
      await _pump(t, const ActivityScreen(), overrides: _feed(const AsyncLoading()));
      expect(find.byType(FeedSkeleton), findsOneWidget);
      await _pump(
        t,
        const ActivityScreen(),
        overrides: _feed(AsyncError(Exception('db'), StackTrace.empty)),
      );
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    });

    // TC-18-02
    testWidgets('the bell says coming soon', (t) async {
      await _pump(t, const ActivityScreen(), overrides: _feed(AsyncData(sampleActivity())));
      await t.tap(find.byTooltip('Notifications'));
      await settle(t);
      expect(find.text('Coming soon'), findsOneWidget);
    });

    // TC-18-02
    testWidgets('a row opens its expense', (t) async {
      await _pump(t, const ActivityScreen(), overrides: _feed(AsyncData(sampleActivity())));
      await tapKey(t, 'activity-a1');
      expect(find.text('at /expense/e1'), findsOneWidget);
    });
  });

  group('GroupActivityScreen', () {
    // TC-18-02
    testWidgets('a group\'s feed has its name, the same filters, and no group name on rows', (
      t,
    ) async {
      await _pump(
        t,
        const GroupActivityScreen(groupId: gid),
        overrides: _groupFeed(AsyncData(sampleActivity())),
      );
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      expect(_caption(t, 'a1'), '9:30 AM');
      await t.tap(find.byKey(const Key('activity-filter-payments')));
      await settle(t);
      expect(find.byType(ActivityRow), findsOneWidget);
      expect(find.byKey(const ValueKey('activity-a2')), findsOneWidget);
    });

    // TC-18-02
    testWidgets('empty, filtered-empty, loading and error states', (t) async {
      await _pump(
        t,
        const GroupActivityScreen(groupId: gid),
        overrides: _groupFeed(const AsyncData([])),
      );
      expect(find.text('Nothing here yet'), findsOneWidget);

      await _pump(
        t,
        const GroupActivityScreen(groupId: gid),
        overrides: _groupFeed(const AsyncLoading()),
      );
      expect(find.byType(FeedSkeleton), findsOneWidget);

      await _pump(
        t,
        const GroupActivityScreen(groupId: gid),
        overrides: _groupFeed(AsyncError(Exception('db'), StackTrace.empty)),
      );
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    });

    // TC-18-02
    testWidgets('back returns to the previous screen', (t) async {
      usePhone(t);
      await t.pumpWidget(const SizedBox());
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (_, _) => const PushHost(GroupActivityScreen(groupId: gid)),
          ),
        ],
      );
      await t.pumpWidget(routerApp(router, overrides: _groupFeed(AsyncData(sampleActivity()))));
      await tapKey(t, 'open');
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.byType(GroupActivityScreen), findsNothing);
    });
  });

  group('GroupActivitySection', () {
    Widget host() => const Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(child: GroupActivitySection(groupId: gid)),
      ),
    );

    // TC-18-02
    testWidgets('shows the newest three rows and "See all activity"', (t) async {
      await _pump(t, host(), overrides: _feed(AsyncData(sampleActivity()), group: gid));
      expect(find.byKey(const Key('group-activity-section')), findsOneWidget);
      expect(find.text('RECENT ACTIVITY'), findsOneWidget);
      expect(find.byType(ActivityRow), findsNWidgets(3));
      expect(find.byKey(const ValueKey('activity-a3')), findsOneWidget);
      expect(find.byKey(const ValueKey('activity-a2')), findsOneWidget);
      expect(find.byKey(const ValueKey('activity-a4')), findsNothing);
      expect(_caption(t, 'a1'), '9:30 AM');
      await tapKey(t, 'group-activity-all');
      expect(find.text('at /groups/g-goa/activity'), findsOneWidget);
    });

    // TC-18-02
    testWidgets('hidden while loading, on error and when there is nothing', (t) async {
      for (final v in <AsyncValue<List<ActivityItem>>>[
        const AsyncLoading(),
        const AsyncData([]),
        AsyncError(Exception('db'), StackTrace.empty),
      ]) {
        await _pump(t, host(), overrides: _feed(v, group: gid));
        expect(find.byKey(const Key('group-activity-section')), findsNothing);
      }
    });
  });
}
