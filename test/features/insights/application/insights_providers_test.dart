// TC-33-01 (mapping part): the Insights numbers from the ledgers on the phone.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/domain/entities/profile.dart';
import 'package:splitify/features/auth/application/auth_providers.dart'
    show ProfileController, profileProvider;
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/insights/application/insights_providers.dart';
import 'package:splitify/features/insights/domain/aggregations.dart';

import '../../../support/fakes.dart';
import '../../../support/ledger_seed.dart';
import '../insights_fixtures.dart';

class _FixedProfile extends ProfileController {
  _FixedProfile(this.currency);
  final String? currency;

  @override
  Future<Profile?> build() async =>
      currency == null ? null : Profile(id: 'u1', displayName: 'Mohit', defaultCurrency: currency!);
}

InsightsView _view(
  List<GroupLedger> ledgers,
  InsightsMode mode, {
  String? groupId,
  String? userId = 'u1',
  String currency = 'INR',
}) => insightsViewOf(
  ledgers,
  (mode: mode, groupId: groupId),
  userId: userId,
  defaultCurrency: currency,
  today: insightsToday,
);

Map<String, int> _byCategory(InsightsView v) => {
  for (final c in v.summary.byCategory) c.category: c.minor,
};

GroupLedger _withCurrency(GroupLedger l, String currency) => GroupLedger(
  group: seedGroup(id: l.group.id, name: l.group.name, mainCurrency: '$currency '),
  members: l.members,
  expenses: l.expenses,
  payments: l.payments,
);

void main() {
  group('insightExpenseOf', () {
    // TC-33-01
    test('reads the stored JSON, trims codes and cuts the date to the day', () {
      final row = insightExpense(
        'x',
        groupId: goaId,
        ids: ['m1', 'm2'],
        category: 'food.snacks',
        date: '2026-11-20T10:00:00Z',
        total: 101,
        currency: 'USD ',
        fxCurrency: 'INR ',
        fxTotal: 8500,
        deletedAt: '2026-11-21T10:00:00Z',
      );
      final e = insightExpenseOf(row);
      expect(e.date, '2026-11-20');
      expect(e.currency, 'USD');
      expect(e.fxCurrency, 'INR');
      expect(e.fxTotal, 8500);
      expect(e.owed, {'m1': 51, 'm2': 50});
      expect(e.fxOwed, {'m1': 4250, 'm2': 4250});
      expect(e.deleted, isTrue);
      expect(e.isSpending, isFalse);
    });

    // TC-33-01
    test('without a saved conversion there are no fx values', () {
      final e = insightExpenseOf(
        insightExpense(
          'y',
          groupId: goaId,
          ids: ['m1'],
          category: 'other.general',
          date: '2026-11-20',
          total: 5,
        ),
      );
      expect((e.fxCurrency, e.fxTotal, e.fxOwed, e.deleted), (null, null, null, false));
      expect(insightInputsOf(goaLedger()), hasLength(13));
    });
  });

  group('myMemberIdIn', () {
    // TC-33-01
    test('my linked member, not a removed one, nothing without an account', () {
      final goa = goaLedger();
      expect(myMemberIdIn(goa, 'u1'), 'm1');
      expect(myMemberIdIn(goa, 'u2'), 'm2');
      expect(myMemberIdIn(goa, 'nobody'), isNull);
      expect(myMemberIdIn(goa, null), isNull);
      final gone = GroupLedger(
        group: goa.group,
        members: [seedMember('m1', groupId: goaId, userId: 'u1', deletedAt: '2026-11-01')],
        expenses: const [],
        payments: const [],
      );
      expect(myMemberIdIn(gone, 'u1'), isNull);
    });
  });

  group('Group mode', () {
    // TC-33-01
    test('totals by top-level category in the main currency; IOU out, saved conversion in', () {
      final v = _view(allInsightLedgers(), InsightsMode.group, groupId: goaId);
      expect(v.group!.id, goaId);
      expect(v.currency, 'INR');
      expect(_byCategory(v), {
        'travel': 3185000,
        'entertainment': 1206800, // 200000 + the saved USD conversion 1006800
        'food': 745000,
        'shopping': 460000,
        'groceries': 135000,
        'other': 60000, // the 5,000.00 IOU is not spending
      });
      expect(v.summary.total, 5791800);
      expect(v.summary.count, 11);
      expect(v.isEmpty, isFalse);
      expect(v.mode, InsightsMode.group);
    });

    // TC-33-01
    test('an expense in another currency without a saved conversion is counted, not added', () {
      final v = _view([goaLedger()], InsightsMode.group, groupId: goaId);
      expect(v.unconverted, 1);
      expect(v.summary.byCategory.first, const CategorySpend('travel', 3185000));
    });

    // TC-33-01
    test('only unconverted spending: nothing to draw, the left-out count says why', () {
      final v = _view(allInsightLedgers(), InsightsMode.group, groupId: baliId);
      expect(v.group!.archived, isTrue);
      expect(v.isEmpty, isTrue);
      expect(v.unconverted, 2);
    });

    // TC-33-01
    test('deleted expenses are not spending', () {
      final goa = goaLedger();
      final withDeleted = GroupLedger(
        group: goa.group,
        members: goa.members,
        expenses: [
          ...goa.expenses,
          insightExpense(
            'gone',
            groupId: goaId,
            ids: ['m1', 'm2', 'm3'],
            category: 'travel.flights',
            date: '2026-11-01',
            total: 999900,
            deletedAt: '2026-11-02T10:00:00Z',
          ),
        ],
        payments: goa.payments,
      );
      final v = _view([withDeleted], InsightsMode.group, groupId: goaId);
      expect(v.summary.total, 5791800);
      expect(v.summary.count, 11);
    });

    // TC-33-01
    test('12 months ending at today, oldest first, zeros included', () {
      final v = _view([goaLedger()], InsightsMode.group, groupId: goaId);
      expect(v.months, hasLength(12));
      expect(v.months.first.month, '2025-12');
      expect(v.months.last.month, '2026-11');
      expect(v.currentMonth, '2026-11');
      expect(v.months.last.minor, 320000 + 95000 + 135000);
      expect(v.months.firstWhere((m) => m.month == '2026-03').minor, 0);
      expect(v.months.firstWhere((m) => m.month == '2026-05').minor, 1006800);
    });

    // TC-33-01
    test('the group is shown in its own main currency', () {
      final usd = _withCurrency(goaLedger(), 'USD');
      final v = _view([usd], InsightsMode.group, groupId: goaId, currency: 'INR');
      expect(v.currency, 'USD');
      expect(v.summary.total, 12000 + 4500);
      expect(v.summary.count, 2);
      // The ten INR expenses have no saved conversion to USD.
      expect(v.unconverted, 10);
    });

    // TC-33-01
    test('no groups (only a friend group): no group, default currency, empty', () {
      final v = _view([friendLedger()], InsightsMode.group, currency: 'USD');
      expect(v.groups, isEmpty);
      expect(v.group, isNull);
      expect(v.currency, 'USD');
      expect(v.isEmpty, isTrue);
      expect(v.unconverted, 0);
      expect(_view(const [], InsightsMode.group).group, isNull);
    });
  });

  group('Me mode', () {
    // TC-33-01
    test('across every group and friend: my shares only, in the default currency', () {
      final v = _view(allInsightLedgers(), InsightsMode.me);
      expect(v.group, isNull);
      expect(v.currency, 'INR');
      expect(_byCategory(v), {
        'rent': 3600000,
        'entertainment': 66667 + 335600 + 45000, // goa share + converted share + friend movie
        'travel': 616667 + 413334 + 31667,
        'food': 106667 + 81667 + 60000,
        'shopping': 153334,
        'groceries': 45000 + 110000,
        'utilities': 90000,
        'other': 20000,
      });
      expect(v.summary.total, 5775603);
      expect(v.summary.count, 17);
      // Goa's USD expense without conversion + Bali's two.
      expect(v.unconverted, 3);
    });

    // TC-33-01
    test('picked group: its main currency and only that group', () {
      final v = _view(allInsightLedgers(), InsightsMode.me, groupId: flatId);
      expect(v.group!.name, 'Flat 4B');
      expect(v.summary.total, 3800000);
      expect(v.summary.count, 5);
      expect(v.unconverted, 0);

      final usd = _view([_withCurrency(goaLedger(), 'USD')], InsightsMode.me, groupId: goaId);
      expect(usd.currency, 'USD');
      expect(usd.summary.total, 4000 + 1500);
    });

    // TC-33-01
    test('an unknown picked group falls back to everything', () {
      final v = _view(allInsightLedgers(), InsightsMode.me, groupId: 'nope');
      expect(v.group, isNull);
      expect(v.summary.count, 17);
    });

    // TC-33-01
    test('without an account nothing is mine', () {
      final v = _view(allInsightLedgers(), InsightsMode.me, userId: null);
      expect(v.isEmpty, isTrue);
    });
  });

  group('groups and the default group', () {
    // TC-33-01
    test('picker leaves friends out; open before archived, each by name', () {
      final gs = insightsGroupsOf(allInsightLedgers());
      expect([for (final g in gs) g.name], ['Flat 4B', 'Goa trip', 'Weekend', 'Bali']);
      expect(gs.last.archived, isTrue);
      expect(gs.first.type, 'home');
      expect(gs.first.mainCurrency, 'INR');
    });

    // TC-33-01
    test('same names are ordered by id', () {
      final a = GroupLedger(
        group: seedGroup(id: 'b', name: 'Same'),
        members: const [],
        expenses: const [],
        payments: const [],
      );
      final b = GroupLedger(
        group: seedGroup(id: 'a', name: 'same'),
        members: const [],
        expenses: const [],
        payments: const [],
      );
      expect(
        [
          for (final g in insightsGroupsOf([a, b])) g.id,
        ],
        ['a', 'b'],
      );
    });

    // TC-33-01
    test('default = wanted group when pickable, else the open group with the newest expense', () {
      final ls = allInsightLedgers();
      final gs = insightsGroupsOf(ls);
      expect(defaultInsightsGroup(ls, gs, flatId)!.id, flatId);
      expect(defaultInsightsGroup(ls, gs, baliId)!.id, baliId);
      expect(defaultInsightsGroup(ls, gs, null)!.id, goaId);
      expect(defaultInsightsGroup(ls, gs, 'nope')!.id, goaId);
      // The friend group is not pickable.
      expect(defaultInsightsGroup(ls, gs, friendId)!.id, goaId);
    });

    // TC-33-01
    test('newest expense wins even when it is in a later-named group', () {
      final ls = [flatLedger(), emptyLedger()];
      final gs = insightsGroupsOf(ls);
      expect(defaultInsightsGroup(ls, gs, null)!.id, flatId);
      // Weekend sorts after Flat 4B and has no expense: Flat stays.
      expect(
        defaultInsightsGroup([emptyLedger()], insightsGroupsOf([emptyLedger()]), null)!.id,
        emptyId,
      );
    });

    // TC-33-01
    test('only archived groups: the first of them; none: null', () {
      final ls = [baliLedger(), friendLedger()];
      expect(defaultInsightsGroup(ls, insightsGroupsOf(ls), null)!.id, baliId);
      expect(defaultInsightsGroup(const [], const [], 'x'), isNull);
    });
  });

  group('insightsProvider', () {
    late ProviderContainer c;

    Future<T> data<T>(ProviderListenable<AsyncValue<T>> p) {
      final done = Completer<T>();
      late final ProviderSubscription<AsyncValue<T>> sub;
      sub = c.listen(p, (_, n) {
        if (done.isCompleted) return;
        if (n.hasValue) {
          done.complete(n.requireValue);
        } else if (n.hasError) {
          done.completeError(n.error!);
        }
      }, fireImmediately: true);
      return done.future.whenComplete(sub.close);
    }

    void open(List<GroupLedger> ledgers, {String? currency, String? userId = 'u1'}) {
      c = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          allLedgersProvider.overrideWith((ref) => Stream.value(ledgers)),
          currentUserIdProvider.overrideWithValue(userId),
          clockProvider.overrideWithValue(FakeClock(insightsToday)),
          profileProvider.overrideWith(() => _FixedProfile(currency)),
        ],
      );
    }

    tearDown(() => c.dispose());

    // TC-33-01
    test('end to end: group mode from the stream, the clock and the user', () async {
      open(allInsightLedgers());
      final v = await data(insightsProvider((mode: InsightsMode.group, groupId: goaId)));
      expect(v.group!.name, 'Goa trip');
      expect(v.summary.total, 5791800);
      expect(v.currentMonth, '2026-11');
      expect(v.months.last.minor, 550000);
    });

    // TC-33-01
    test('end to end: Me uses my user id', () async {
      open(allInsightLedgers());
      final v = await data(insightsProvider((mode: InsightsMode.me, groupId: null)));
      expect(v.summary.total, 5775603);
      c.dispose();
      open(allInsightLedgers(), userId: 'u2');
      final asha = await data(insightsProvider((mode: InsightsMode.me, groupId: null)));
      // u2 is only in Goa and Bali.
      expect(asha.summary.count, 11);
    });

    // TC-33-01
    test('Me across everything follows the profile default currency, INR without one', () async {
      open([friendLedger()], currency: 'USD');
      final usd = await data(insightsProvider((mode: InsightsMode.me, groupId: null)));
      expect(usd.currency, 'USD');
      expect(usd.isEmpty, isTrue);
      expect(usd.unconverted, 1);
      c.dispose();
      open([friendLedger()]);
      final inr = await data(insightsProvider((mode: InsightsMode.me, groupId: null)));
      expect(inr.currency, 'INR');
      expect(inr.summary.total, 45000);
    });
  });
}
