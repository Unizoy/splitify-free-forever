// Auto-category in the one-screen editor (D-028, S-271, D-032): the category icon beside the description
// follows typing after ~250 ms with an "Auto" tag, a manual pick sticks, a saved expense never changes,
// Save and the picker apply a pending suggestion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';

import '../expense_fixtures.dart';
import 'presentation_harness.dart';

/// What TalkBack says for the category icon.
String _label(WidgetTester t) => t.getSemantics(find.byKey(const Key('category-hint'))).label;

double _autoOpacity(WidgetTester t) => t
    .widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byKey(const Key('category-auto')),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

ExpenseDraft _new({String description = '', String category = 'other.general'}) => sampleDraft(
  expenseId: null,
  description: description,
  category: category,
  categoryOrigin: CategoryOrigin.initial,
);

Future<void> _type(WidgetTester t, String text) async {
  await t.enterText(fieldIn('expense-description'), text);
  await t.pump();
}

void main() {
  testWidgets('the category follows the description after the pause, with an Auto tag', (t) async {
    final handle = t.ensureSemantics();
    final h = await pumpEditor(t, _new(), args: newArgs);
    expect(_label(t), 'Category: General');
    expect(_autoOpacity(t), 0);

    await _type(t, 'Swi');
    await _type(t, 'Swiggy');
    await t.pump(suggestDelay - const Duration(milliseconds: 50));
    expect(h.draft.category, 'other.general', reason: 'still typing');
    await t.pump(const Duration(milliseconds: 60));
    await settle(t);
    expect(h.draft.category, 'food.takeaway');
    expect(_autoOpacity(t), 1);
    expect(_label(t), 'Category: Takeaway, picked from the description');

    await _type(t, 'Swiggy Instamart');
    await t.pump(suggestDelay);
    await settle(t);
    expect(h.draft.category, 'groceries.groceries');

    await _type(t, 'Paid back');
    await t.pump(suggestDelay);
    await settle(t);
    expect(h.draft.category, 'other.general');
    expect(_autoOpacity(t), 0);
    handle.dispose();
  });

  testWidgets('the icon opens the picker on the suggestion; a manual pick sticks', (t) async {
    final h = await pumpEditor(
      t,
      _new(description: 'Uber', category: 'travel.cab_auto'),
      args: newArgs,
    );
    await _type(t, 'Uber to dinner');
    await tapKey(t, 'category-button');
    expect(find.byKey(const Key('category-travel.cab_auto')), findsOneWidget);
    expect(h.draft.category, 'travel.cab_auto');

    await tapKey(t, 'category-food');
    expect(h.draft.category, 'food.dining_out');
    expect(h.draft.categoryOrigin, CategoryOrigin.manual);
    await tapKey(t, 'category-done');
    expect(_autoOpacity(t), 0);

    await _type(t, 'Rapido home');
    await t.pump(suggestDelay);
    await settle(t);
    expect(h.draft.category, 'food.dining_out', reason: 'a manual pick sticks');
    expect(_autoOpacity(t), 0);
  });

  testWidgets('editing a saved expense never changes its category', (t) async {
    final h = await pumpEditor(t, sampleDraft(description: 'Dinner', category: 'rent.rent'));
    await _type(t, 'Swiggy');
    await t.pump(suggestDelay);
    await settle(t);
    expect(h.draft.category, 'rent.rent');
    expect(h.draft.categoryOrigin, CategoryOrigin.saved);
    expect(_autoOpacity(t), 0);
  });

  testWidgets('Save right after typing uses the suggestion', (t) async {
    final h = await pumpEditor(t, _new(), args: newArgs);
    await _type(t, 'IRCTC');
    await t.tap(find.byKey(const Key('expense-save')));
    await t.pump();
    expect(h.controller!.saves, 1);
    expect(h.draft.category, 'travel.train_bus');
    await settle(t, 12);
  });

  testWidgets('opening the picker right after typing shows the suggested category', (t) async {
    final h = await pumpEditor(t, _new(), args: newArgs);
    await _type(t, 'Netflix');
    await t.tap(find.byKey(const Key('category-button')));
    await settle(t);
    expect(h.draft.category, 'entertainment.movies');
    expect(find.byKey(const Key('category-entertainment.movies')), findsOneWidget);
  });
}
