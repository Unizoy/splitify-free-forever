// TC-D34D-02 (D-034 WP-D, P-5): search finds payments (by amount, person, note, method, "paid") and
// comments (by text) on the phone's own data, with the group / person / date / category filters; the
// mixed result list; recent searches.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/repositories/search_repository.dart';
import 'package:splitify/domain/rules/search_query.dart';
import 'package:splitify/features/search/application/search_controller.dart';
import 'package:splitify/features/search/application/search_everything.dart';

import 'd034_seed.dart';

void main() {
  late D034World w;

  setUp(() async => w = await seedD034());
  tearDown(() => w.dispose());

  SearchRepository repo() => w.container.read(searchRepositoryProvider);

  Future<List<String>> payments(String text, [SearchFilters f = const SearchFilters()]) async => [
    for (final p in await repo().watchPayments(SearchQuery.parse(text), f).first) p.id,
  ];

  Future<List<String>> comments(String text, [SearchFilters f = const SearchFilters()]) async => [
    for (final c in await repo().watchComments(SearchQuery.parse(text), f).first) c.body,
  ];

  group('payments', () {
    // TC-D34D-02
    test('found by amount in their currency, never when deleted', () async {
      expect(await payments('500'), ['p-asha']);
      expect(await payments('₹500'), ['p-asha']);
      expect(await payments('1,250.50'), ['p-kiran']);
      expect(await payments('1250.5'), ['p-kiran']);
      // The deleted ₹700 payment stays out.
      expect(await payments('700'), isEmpty);
    });

    // TC-D34D-02
    test('found by either person (member name), the note or the method', () async {
      expect(await payments('asha'), ['p-asha']);
      expect(await payments('kir'), ['p-kiran']);
      expect(await payments('mohit'), ['p-asha', 'p-kiran']);
      expect(await payments('rent share'), ['p-kiran']);
      expect(await payments('upi'), ['p-kiran']);
      expect(await payments('ravi'), isEmpty, reason: 'his only payment is deleted');
      expect(await payments('asha 500'), ['p-asha']);
      expect(await payments('asha 501'), isEmpty);
    });

    // TC-D34D-02
    test('"paid", "settle" and the like list every payment; with a name only theirs', () async {
      expect(await payments('paid'), ['p-asha', 'p-kiran']);
      expect(await payments('settle'), ['p-asha', 'p-kiran']);
      expect(await payments('asha paid'), ['p-asha']);
    });

    // TC-D34D-02
    test('group, person and date filters; a category leaves payments out', () async {
      expect(await payments('paid', SearchFilters(groupId: w.flat)), ['p-kiran']);
      expect(await payments('', SearchFilters(memberIds: {w.m['Asha']!})), ['p-asha']);
      expect(await payments('', const SearchFilters(memberIds: {})), isEmpty);
      expect(await payments('paid', const SearchFilters(from: '2026-11-10')), ['p-asha']);
      expect(await payments('paid', const SearchFilters(to: '2026-11-10')), ['p-kiran']);
      expect(await payments('paid', const SearchFilters(category: 'food')), isEmpty);
      expect(await payments(''), isEmpty, reason: 'nothing typed, no filter: nothing');
    });
  });

  group('comments', () {
    // TC-D34D-02
    test('found by text and numbers inside it, only on live records', () async {
      expect(await comments('cab'), ['Thanks for the cab!']);
      expect(await comments('THANKS'), ['Thanks for the cab!']);
      expect(await comments('500'), ['Paid the tip in cash, 500 extra']);
      expect(await comments('tip cash'), ['Paid the tip in cash, 500 extra']);
      // On a deleted payment.
      expect(await comments('nothing'), isEmpty);
      expect(await comments('cab zzz'), isEmpty);
    });

    // TC-D34D-02
    test('the person filter means the author; category keeps comments on such expenses', () async {
      final mine = SearchFilters(memberIds: {w.m['Mohit']!});
      expect((await comments('', mine)).length, 2);
      expect(await comments('', SearchFilters(memberIds: {w.m['Asha']!})), isEmpty);
      expect(await comments('', const SearchFilters(category: 'food')), [
        'Paid the tip in cash, 500 extra',
      ]);
      expect(await comments('', SearchFilters(groupId: w.flat)), isEmpty);
      expect((await comments('', const SearchFilters(from: '2000-01-01'))).length, 2);
      expect(await comments('', const SearchFilters(to: '2000-01-01')), isEmpty);
    });
  });

  group('providers', () {
    Future<SearchEverything> everything(String text, {String? group}) async {
      final c = w.container;
      final sub = c.listen(searchEverythingProvider(group), (_, _) {});
      addTearDown(sub.close);
      c.read(searchControllerProvider(group).notifier).setText(text);
      for (var i = 0; i < 50; i++) {
        final v = c.read(searchEverythingProvider(group));
        if (v.hasValue && !v.isLoading) return v.requireValue;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('search did not finish');
    }

    // TC-D34D-02
    test('expenses, payments and comments together, newest day first, with counts', () async {
      final found = await everything('cab');
      expect(found.count(SearchKind.expenses), 1);
      expect(found.count(SearchKind.payments), 0);
      expect(found.count(SearchKind.comments), 1);
      expect(found.count(SearchKind.all), 2);
      final rows = found.rows(SearchKind.all);
      // The comment was written "now" (after the October cab).
      expect(rows.first, isA<CommentResult>());
      expect(rows.last, isA<ExpenseResult>());
      final c = (rows.first as CommentResult).hit;
      expect(c.payment?.payment.id, 'p-asha');
      expect(c.authorName, 'Mohit');
      expect(c.groupName, 'Goa trip');
      expect(found.rows(SearchKind.expenses).single, isA<ExpenseResult>());
      expect(found.limited(SearchRepository.limit), isFalse);
    });

    // TC-D34D-02
    test('payment hits carry names, my side and the group; comments their expense', () async {
      final found = await everything('500');
      final p = found.payments.single;
      expect(p.view.iReceived, isTrue);
      expect(p.view.nameOf(p.view.payment.fromMember), 'Asha');
      expect(p.groupName, 'Goa trip');
      expect(found.comments.single.expense?.description, 'Dinner at Thalassa');
      final rows = found.rows(SearchKind.all);
      expect(rows.map((r) => r.kind), [SearchKind.comments, SearchKind.payments]);
      expect(rows.every((r) => r.unsynced), isTrue, reason: 'nothing was pushed yet');
    });

    // TC-D34D-02, TC-34-05
    test('opened from a group, only that group', () async {
      final found = await everything('paid', group: w.flat);
      expect(found.payments.map((p) => p.view.payment.id), ['p-kiran']);
      expect(found.comments, isEmpty);
    });
  });

  group('recent searches', () {
    // TC-D34D-02
    test('newest first, the same search once (any case), trimmed, at most 5', () {
      expect(withRecent(const [], '  '), isEmpty);
      expect(withRecent(const ['cab'], ' Dinner  at '), ['Dinner at', 'cab']);
      expect(withRecent(const ['cab', 'rent'], 'RENT'), ['RENT', 'cab']);
      expect(withRecent(const ['a', 'b', 'c', 'd', 'e'], 'f'), ['f', 'a', 'b', 'c', 'd']);
    });

    // TC-D34D-02
    test('kept on this phone: saved, removed, cleared, read back', () async {
      final prefs = await d034Prefs({
        RecentSearches.storageKey: ['old', ' ', 'a', 'b', 'c', 'd', 'e'],
      });
      final c = ProviderContainer(overrides: d034Overrides(w.db, prefs));
      addTearDown(c.dispose);
      expect(c.read(recentSearchesProvider), ['old', 'a', 'b', 'c', 'd']);
      final n = c.read(recentSearchesProvider.notifier)
        ..clear()
        ..add('cab')
        ..add('500')
        ..add('Cab');
      expect(c.read(recentSearchesProvider), ['Cab', '500']);
      expect(prefs.getStringList(RecentSearches.storageKey), ['Cab', '500']);
      n
        ..remove('500')
        ..add('');
      expect(prefs.getStringList(RecentSearches.storageKey), ['Cab']);
      final again = ProviderContainer(overrides: d034Overrides(w.db, prefs));
      addTearDown(again.dispose);
      expect(again.read(recentSearchesProvider), ['Cab']);
    });
  });
}
