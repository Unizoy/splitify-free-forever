// Auto-category in the editor controller (D-028, S-271/S-272): suggestion while typing, manual picks stick,
// saved expenses never change, overrides are learned.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/category_memory.dart';
import 'package:splitify/features/expenses/application/category_providers.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';

import '../../../support/category_support.dart';
import 'expense_test_env.dart';

ExpenseDraft Function(ExpenseDraft) _fill(String amount, String description) =>
    (d) => d.copyWith(amountText: amount, description: description);

void main() {
  late ExpenseEnv env;
  late CategoryMemory memory;

  setUp(() async {
    memory = CategoryMemory.inMemory();
    env = await ExpenseEnv.create(
      overrides: [
        categorySuggesterProvider.overrideWith((ref) async => suggester),
        categoryMemoryProvider.overrideWithValue(memory),
      ],
    );
    await env.container.read(categorySuggesterProvider.future);
  });

  tearDown(() => env.dispose());

  test('a new expense follows the description until nothing matches, then goes back', () async {
    final e = await env.open();
    expect(e.draft.categoryOrigin, CategoryOrigin.initial);
    e
      ..edit(_fill('250', 'Swiggy'))
      ..controller.suggestCategory();
    expect(e.draft.category, 'food.takeaway');
    expect(e.draft.categoryIsAuto, isTrue);
    e
      ..edit((d) => d.copyWith(description: 'Swiggy Instamart'))
      ..controller.suggestCategory();
    expect(e.draft.category, 'groceries.groceries');
    e
      ..edit((d) => d.copyWith(description: 'Paid back'))
      ..controller.suggestCategory();
    expect(e.draft.category, 'other.general');
    expect(e.draft.categoryOrigin, CategoryOrigin.initial);
  });

  test('the starting category is the group\'s last one and comes back on no match', () async {
    final first = await env.open();
    first
      ..edit(_fill('80', 'Chai'))
      ..controller.suggestCategory();
    expect(first.draft.category, 'food.snacks');
    await first.save();
    final e = await env.open();
    expect(e.draft.category, 'food.snacks');
    e
      ..edit(_fill('900', 'Uber'))
      ..controller.suggestCategory();
    expect(e.draft.category, 'travel.cab_auto');
    e
      ..edit((d) => d.copyWith(description: 'Misc'))
      ..controller.suggestCategory();
    expect(e.draft.category, 'food.snacks');
  });

  test('a manual pick sticks and is learned on save', () async {
    final e = await env.open();
    e
      ..edit(_fill('400', 'Starbucks'))
      ..controller.suggestCategory();
    expect(e.draft.category, 'food.snacks');
    e.edit((d) => d.pickCategory('food.dining_out'));
    e
      ..edit((d) => d.copyWith(description: 'Uber'))
      ..controller.suggestCategory();
    expect(e.draft.category, 'food.dining_out');
    expect(e.draft.categoryOrigin, CategoryOrigin.manual);
    e
      ..edit((d) => d.copyWith(description: 'Starbucks'))
      ..controller.suggestCategory();
    expect(await e.save(), isNotNull);
    expect(memory.entries, {'starbucks': 'food.dining_out'});

    final next = await env.open();
    next
      ..edit(_fill('300', 'starbucks!'))
      ..controller.suggestCategory();
    expect(next.draft.category, 'food.dining_out');
    expect(next.draft.categoryIsAuto, isTrue);
  });

  test('an accepted suggestion teaches nothing', () async {
    final e = await env.open();
    e
      ..edit(_fill('400', 'Rapido'))
      ..controller.suggestCategory();
    await e.save();
    expect(memory.entries, isEmpty);
  });

  test('editing a saved expense never changes its category, but a pick there is learned', () async {
    final e = await env.open();
    e
      ..edit(_fill('400', 'Movie'))
      ..controller.suggestCategory();
    final id = await e.save();
    final edit = await env.open(expenseId: id);
    expect(edit.draft.categoryOrigin, CategoryOrigin.saved);
    expect(edit.draft.category, 'entertainment.movies');
    edit
      ..edit((d) => d.copyWith(description: 'Swiggy'))
      ..controller.suggestCategory();
    expect(edit.draft.category, 'entertainment.movies');
    edit.edit((d) => d.pickCategory('food.takeaway'));
    await edit.save();
    expect(memory.entries, isEmpty, reason: 'swiggy already suggests takeaway');
    final again = await env.open(expenseId: id);
    again.edit((d) => d.pickCategory('food.snacks'));
    await again.save();
    expect(memory.entries, {'swiggy': 'food.snacks'});
  });

  test('without the keyword list nothing is suggested and the category stays', () async {
    final broken = await ExpenseEnv.create(
      overrides: [
        categorySuggesterProvider.overrideWith((ref) async => throw StateError('no asset')),
        categoryMemoryProvider.overrideWithValue(CategoryMemory.inMemory()),
      ],
    );
    addTearDown(broken.dispose);
    final e = await broken.open();
    e
      ..edit(_fill('20', 'Swiggy'))
      ..controller.suggestCategory();
    expect(e.draft.category, 'other.general');
    e.edit((d) => d.pickCategory('food.snacks'));
    expect(await e.save(), isNotNull, reason: 'learning without the list still saves');
  });

  group('ExpenseDraft', () {
    test('withSuggestedCategory only while it follows the description', () {
      const base = 'rent.rent';
      final d = e0Draft(origin: CategoryOrigin.initial, category: base);
      expect(d.withSuggestedCategory('food.snacks').category, 'food.snacks');
      expect(d.withSuggestedCategory('food.snacks').withSuggestedCategory(null).category, base);
      for (final o in [CategoryOrigin.manual, CategoryOrigin.saved]) {
        final x = e0Draft(origin: o, category: base);
        expect(identical(x.withSuggestedCategory('food.snacks'), x), isTrue);
      }
    });

    test('origin and base survive copies and currency changes', () {
      final d = e0Draft(
        origin: CategoryOrigin.initial,
        category: 'rent.rent',
      ).withSuggestedCategory('food.snacks').withCurrency('USD').copyWith(notes: 'x');
      expect(d.categoryOrigin, CategoryOrigin.auto);
      expect(d.baseCategory, 'rent.rent');
      expect(d.pickCategory('travel.fuel').categoryFollowsDescription, isFalse);
    });
  });
}

ExpenseDraft e0Draft({required CategoryOrigin origin, required String category}) => ExpenseDraft(
  groupId: 'g',
  groupName: 'G',
  currency: 'INR',
  members: const [(id: 'm1', name: 'Mohit', isMe: true)],
  split: SplitDraft.initial(const ['m1'], 2),
  date: DateTime(2026, 11, 23),
  payers: const {},
  payerId: 'm1',
  category: category,
  categoryOrigin: origin,
);
