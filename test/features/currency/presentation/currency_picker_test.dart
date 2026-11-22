// TC-14-04: the currency picker (group currency first, recent, all, search) and the currency chip.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/features/currency/presentation/currency_picker_sheet.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../../support/ledger_seed.dart';
import '../../expenses/presentation/presentation_harness.dart';
import '../currency_harness.dart';

String? _picked;
bool _closed = false;

Future<void> _open(
  WidgetTester t, {
  String selected = 'USD',
  String group = 'INR',
  bool withRecent = true,
  double scale = 1,
}) async {
  _picked = null;
  _closed = false;
  final db = await seededDb();
  if (withRecent) {
    await db.seed(
      expenses: [
        seedExpense(
          'e1',
          currency: 'USD',
          date: '2026-11-20',
          total: 100,
          payers: {'m1': 100},
          shares: {'m1': 100},
        ),
        seedExpense(
          'e2',
          currency: 'EUR',
          date: '2026-11-18',
          total: 100,
          payers: {'m1': 100},
          shares: {'m1': 100},
        ),
        seedExpense('e3', date: '2026-11-19', total: 100, payers: {'m1': 100}, shares: {'m1': 100}),
      ],
      payments: [
        seedPayment('p1', from: 'm2', to: 'm1', amount: 50, currency: 'GBP', date: '2026-11-21'),
      ],
    );
  }
  await pumpOpener(
    t,
    db: db,
    overrides: dbOverrides(db, offlineRemote()),
    scale: scale,
    onOpen: (context, ref) async {
      _picked = await showCurrencyPicker(context, selected: selected, groupCurrency: group);
      _closed = true;
    },
  );
  await openSheet(t);
}

Finder _row(String section, String code) => find.byKey(Key('currency-$section-$code'));

void main() {
  group('searchCurrencies', () {
    // TC-14-04
    test('an empty query returns every currency in code order', () {
      expect(searchCurrencies('').length, Currencies.all.length);
      expect(searchCurrencies('   ').length, Currencies.all.length);
      final codes = [for (final c in searchCurrencies('')) c.code];
      expect(codes, Currencies.all.keys.toList());
    });

    // TC-14-04
    test('matches a code prefix, case-insensitive', () {
      expect([for (final c in searchCurrencies('us')) c.code], contains('USD'));
      expect([for (final c in searchCurrencies('inr')) c.code], contains('INR'));
      expect([for (final c in searchCurrencies(' INR ')) c.code], contains('INR'));
      // a code is matched from the start, not from the middle
      expect([for (final c in searchCurrencies('SD')) c.code], isNot(contains('USD')));
    });

    // TC-14-04
    test('matches part of the name', () {
      expect([for (final c in searchCurrencies('yen')) c.code], contains('JPY'));
      expect([
        for (final c in searchCurrencies('dollar')) c.code,
      ], containsAll(['USD', 'CAD', 'AUD']));
    });

    // TC-14-04
    test('no match gives an empty list', () {
      expect(searchCurrencies('zzzz'), isEmpty);
    });
  });

  group('CurrencyPicker', () {
    // TC-14-04
    testWidgets('shows the group currency first, then recent (without it), then all', (t) async {
      await _open(t);
      expect(find.text('Currency'), findsOneWidget);
      expect(find.text('GROUP CURRENCY'), findsOneWidget);
      expect(_row('group', 'INR'), findsOneWidget);
      expect(find.text('RECENT'), findsOneWidget);
      // newest first: GBP payment (21 Nov), USD (20 Nov), EUR (18 Nov); INR is the group currency
      expect(_row('recent', 'GBP'), findsOneWidget);
      expect(_row('recent', 'USD'), findsOneWidget);
      expect(_row('recent', 'EUR'), findsOneWidget);
      expect(_row('recent', 'INR'), findsNothing);
      final gbp = t.getTopLeft(_row('recent', 'GBP')).dy;
      final usd = t.getTopLeft(_row('recent', 'USD')).dy;
      final eur = t.getTopLeft(_row('recent', 'EUR')).dy;
      expect(gbp < usd && usd < eur, isTrue);
      expect(t.getTopLeft(_row('group', 'INR')).dy < gbp, isTrue);
    });

    // TC-14-04
    testWidgets('the all list holds every currency', (t) async {
      await _open(t, withRecent: false);
      expect(find.text('RECENT'), findsNothing);
      expect(find.text('ALL CURRENCIES'), findsOneWidget);
      final list = find.descendant(
        of: find.byKey(const Key('currency-list')),
        matching: find.byType(Scrollable),
      );
      await t.scrollUntilVisible(_row('all', 'USD'), 300, scrollable: list);
      expect(_row('all', 'USD'), findsOneWidget);
      final last = Currencies.all.keys.last;
      await t.scrollUntilVisible(_row('all', last), 500, scrollable: list);
      expect(_row('all', last), findsOneWidget);
    });

    // TC-14-04
    testWidgets('an unknown group currency shows no group section', (t) async {
      await _open(t, group: 'XXX', withRecent: false);
      expect(_row('group', 'XXX'), findsNothing);
      expect(find.text('GROUP CURRENCY'), findsNothing);
    });

    // TC-14-04
    testWidgets('search by code prefix', (t) async {
      await _open(t);
      await t.enterText(find.byKey(const Key('currency-search')), 'us');
      await settle(t);
      expect(_row('found', 'USD'), findsOneWidget);
      // sections are gone while searching
      expect(find.text('GROUP CURRENCY'), findsNothing);
      expect(_row('group', 'INR'), findsNothing);
      expect(_row('all', 'USD'), findsNothing);
    });

    // TC-14-04
    testWidgets('search by name', (t) async {
      await _open(t);
      await t.enterText(find.byKey(const Key('currency-search')), 'yen');
      await settle(t);
      expect(_row('found', 'JPY'), findsOneWidget);
      expect(_row('found', 'USD'), findsNothing);
    });

    // TC-14-04
    testWidgets('no match says so and clearing the search brings the sections back', (t) async {
      await _open(t);
      await t.enterText(find.byKey(const Key('currency-search')), 'zzzz');
      await settle(t);
      expect(find.byKey(const Key('currency-no-match')), findsOneWidget);
      expect(find.text('No currency matches “zzzz”'), findsOneWidget);
      await t.enterText(find.byKey(const Key('currency-search')), '');
      await settle(t);
      expect(find.byKey(const Key('currency-no-match')), findsNothing);
      expect(_row('group', 'INR'), findsOneWidget);
    });

    // TC-14-04
    testWidgets('tapping a row closes the sheet with its code', (t) async {
      await _open(t);
      await t.tap(_row('recent', 'GBP'));
      await settle(t);
      expect(_closed, isTrue);
      expect(_picked, 'GBP');
      expect(find.byKey(const Key('currency-search')), findsNothing);
    });

    // TC-14-04
    testWidgets('a found row can be picked too', (t) async {
      await _open(t);
      await t.enterText(find.byKey(const Key('currency-search')), 'yen');
      await settle(t);
      await t.tap(_row('found', 'JPY'));
      await settle(t);
      expect(_picked, 'JPY');
    });

    // TC-14-04
    testWidgets('dismissing returns null', (t) async {
      await _open(t);
      await t.tapAt(const Offset(200, 40));
      await settle(t);
      expect(_closed, isTrue);
      expect(_picked, isNull);
    });

    // TC-14-04
    testWidgets('the selected row has the check and says "selected"', (t) async {
      await _open(t, selected: 'USD');
      final selected = _row('recent', 'USD');
      expect(find.descendant(of: selected, matching: find.byIcon(AppIcons.check)), findsOneWidget);
      expect(
        find.descendant(of: _row('recent', 'GBP'), matching: find.byIcon(AppIcons.check)),
        findsNothing,
      );
      final handle = t.ensureSemantics();
      final sel = t.getSemantics(selected);
      expect(sel.label, 'US Dollar, USD, selected');
      expect(sel.getSemanticsData().flagsCollection.isSelected, ui.Tristate.isTrue);
      final other = t.getSemantics(_row('recent', 'GBP'));
      expect(other.label, 'British Pound, GBP');
      handle.dispose();
    });

    // TC-14-04
    testWidgets('lays out at text scale 2.0', (t) async {
      await _open(t, scale: 2);
      expect(t.takeException(), isNull);
      expect(_row('group', 'INR'), findsOneWidget);
    });
  });

  group('CurrencyChip', () {
    Future<void> pumpChip(WidgetTester t, VoidCallback? onTap) async {
      usePhone(t);
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: CurrencyChip(code: 'USD', onTap: onTap),
            ),
          ),
        ),
      );
      await t.pump();
    }

    // TC-14-04
    testWidgets('with onTap shows the chevron and taps', (t) async {
      var taps = 0;
      await pumpChip(t, () => taps++);
      expect(find.text('USD'), findsOneWidget);
      expect(find.byIcon(AppIcons.chevronDown), findsOneWidget);
      await t.tap(find.text('USD'));
      expect(taps, 1);
    });

    // TC-14-04
    testWidgets('without onTap there is no chevron and nothing to tap', (t) async {
      await pumpChip(t, null);
      expect(find.text('USD'), findsOneWidget);
      expect(find.byIcon(AppIcons.chevronDown), findsNothing);
      final handle = t.ensureSemantics();
      expect(
        t.getSemantics(find.byType(CurrencyChip)).getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      handle.dispose();
    });
  });
}
