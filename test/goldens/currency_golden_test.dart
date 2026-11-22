import 'package:alchemist/alchemist.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/currency/application/conversion_controller.dart';
import 'package:splitify/features/currency/application/currency_providers.dart';
import 'package:splitify/features/currency/domain/conversion.dart';
import 'package:splitify/features/currency/domain/converted_balances.dart';
import 'package:splitify/features/currency/domain/fx_service.dart';
import 'package:splitify/features/currency/presentation/conversion_sheet.dart';
import 'package:splitify/features/currency/presentation/currency_picker_sheet.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/payments/application/settle_controller.dart';
import 'package:splitify/features/payments/presentation/settle_up_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/balances/balance_fixtures.dart';
import '../features/expenses/expense_fixtures.dart' show noRepeat;
import '../support/notification_fakes.dart' show quietNotificationOverrides;
import 'golden_support.dart';

/// A scenario: the screen, what feeds it, the frame height at text scale 1.0 / 2.0, and an optional
/// interaction run after the first frames.
typedef _Case = ({
  String name,
  Widget Function() screen,
  List<Override> Function() overrides,
  double height,
  double tallHeight,
  Future<void> Function(WidgetTester)? act,
});

_Case _case(
  String name,
  Widget Function() screen,
  List<Override> Function() overrides, {
  double height = 915,
  double? tallHeight,
  Future<void> Function(WidgetTester)? act,
}) => (
  name: name,
  screen: screen,
  overrides: overrides,
  height: height,
  tallHeight: tallHeight ?? height,
  act: act,
);

// ---------------------------------------------------------------------------------------------
// Bottom-sheet host
// ---------------------------------------------------------------------------------------------

/// [AppSheet] at the bottom of a dimmed screen, like the real modal sheet.
class _SheetHost extends StatelessWidget {
  const _SheetHost({required this.title, required this.child});

  final String Function(AppLocalizations) title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black54,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AppSheet(title: title(AppLocalizations.of(context)), child: child),
    ),
  );
}

// ---------------------------------------------------------------------------------------------
// Currency picker
// ---------------------------------------------------------------------------------------------

Widget _picker() => _SheetHost(
  title: (l) => l.curPickerTitle,
  child: const CurrencyPicker(selected: 'INR', groupCurrency: 'INR'),
);

List<Override> _pickerData() => [
  recentCurrenciesProvider.overrideWith((ref) => Stream.value(const ['USD', 'THB'])),
];

Future<void> Function(WidgetTester) _search(String text) =>
    (tester) => tester.enterText(find.byKey(const Key('currency-search')), text);

// ---------------------------------------------------------------------------------------------
// Conversion sheet
// ---------------------------------------------------------------------------------------------

const ConversionArgs _convArgs = (recordId: 'e2', payment: false);

class _FixedConversion extends ConversionController {
  _FixedConversion(super.args, this.draft);

  final ConversionDraft draft;

  @override
  Future<ConversionDraft> build() async => draft;
}

const _order = ['m1', 'm2', 'm3', 'm4'];

/// $100.00 hotel booking of 20 Nov paid by Rahul, split four ways.
FxRecord _usdRecord({String date = '2026-11-20', bool converted = false}) => FxRecord.expense(
  id: 'e2',
  date: date,
  currency: 'USD',
  amount: 10000,
  description: 'Hotel booking',
  paid: const {'m3': 10000},
  shares: const {'m1': 2500, 'm2': 2500, 'm3': 2500, 'm4': 2500},
  fxCurrency: converted ? 'INR' : null,
  fxAmount: converted ? 896437 : null,
  fxPaid: converted ? const {'m3': 896437} : null,
  fxShares: converted ? const {'m1': 224110, 'm2': 224109, 'm3': 224109, 'm4': 224109} : null,
);

FxRate _rate({String rate = '89.6437142330', DateTime? date, bool fallback = false}) => FxRate(
  from: 'USD',
  to: 'INR',
  rate: rate,
  effectiveDate: date ?? DateTime.utc(2026, 11, 20),
  source: FxSource.frankfurter,
  isFallback: fallback,
);

ConversionDraft _draft({
  String date = '2026-11-20',
  FxLookup? lookup,
  String? rateText,
  bool manual = false,
  SavedFx? saved,
}) {
  final found = lookup ?? FxRateFound(_rate());
  return ConversionDraft(
    groupId: gid,
    record: _usdRecord(date: date),
    to: 'INR',
    order: _order,
    lookup: found,
    rateText: rateText ?? (found is FxRateFound ? rateFieldText(found.rate.rate) : ''),
    saved: saved,
    manual: manual,
  );
}

Widget _conversionSheet() => _SheetHost(
  title: (l) => l.fxConvertTo('INR'),
  child: const ConversionSheet(args: _convArgs),
);

List<Override> _conversion(ConversionDraft d) => [
  conversionProvider(_convArgs).overrideWith(() => _FixedConversion(_convArgs, d)),
];

// ---------------------------------------------------------------------------------------------
// Converted balances (Balances tab)
// ---------------------------------------------------------------------------------------------

class _TabHost extends StatelessWidget {
  const _TabHost(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: child,
      ),
    ),
  );
}

/// ₹2,400 dinner paid by me (4 ways) plus the $100 hotel booking.
List<FxRecord> _records({required bool converted}) => [
  const FxRecord.expense(
    id: 'e1',
    date: '2026-11-20',
    currency: 'INR',
    amount: 240000,
    description: 'Dinner at Thalassa',
    paid: {'m1': 240000},
    shares: {'m1': 60000, 'm2': 60000, 'm3': 60000, 'm4': 60000},
  ),
  _usdRecord(converted: converted),
];

List<Override> _balancesTab({required bool converted}) {
  final group = goaMixed();
  final records = _records(converted: converted);
  final view = ConvertedGroupView(
    group: group,
    converted: convertedBalances('INR', _order, records),
    records: {for (final r in records) r.id: r},
  );
  return [
    groupBalancesProvider(gid).overrideWithValue(AsyncData(group)),
    convertedGroupProvider(gid).overrideWithValue(AsyncData(view)),
    ...quietNotificationOverrides(),
  ];
}

Future<void> _tapInInr(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const Key('balances-view-toggle')),
      matching: find.text('In INR'),
    ),
  );
}

// ---------------------------------------------------------------------------------------------
// Expense detail (conversion tile)
// ---------------------------------------------------------------------------------------------

List<Override> _detail({required bool converted}) {
  var e = sampleExpense(
    id: 'e2',
    description: 'Hotel booking',
    category: 'travel.hotel',
    total: 10000,
    payers: const {'m3': 10000},
    shares: const {'m1': 2500, 'm2': 2500, 'm3': 2500, 'm4': 2500},
  ).copyWith(currency: 'USD');
  if (converted) {
    e = e.copyWith(
      fxRate: const Value('89.6437142330'),
      fxRateDate: const Value('2026-11-20'),
      fxSource: const Value('frankfurter'),
      fxCurrency: const Value('INR'),
      fxTotal: const Value(896437),
    );
  }
  return [
    expenseViewProvider('e2').overrideWithValue(AsyncData(sampleView(e))),
    expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
    groupMainCurrencyProvider(gid).overrideWith((ref) => Stream.value('INR')),
    commentThreadProvider((groupId: gid, targetType: 'expense', targetId: 'e2'))
        .overrideWithValue(const AsyncData([])),
    // Phase 16: the detail also reads the repeat rule from the database.
    noRepeat('e2'),
  ];
}

// ---------------------------------------------------------------------------------------------
// Settle up in USD
// ---------------------------------------------------------------------------------------------

const SettleArgs _usdSettleArgs = (
  groupId: gid,
  from: 'm1',
  to: 'm3',
  currency: 'USD',
  paymentId: null,
);

List<Override> _settleUsd() => [
  settleProvider(_usdSettleArgs).overrideWith(
    () => FixedSettleController(
      _usdSettleArgs,
      sampleSettleDraft(balances: goaMixed(), amountText: '20').withCurrency('USD'),
    ),
  ),
];

// ---------------------------------------------------------------------------------------------

List<_Case> _cases() => [
  _case('picker', _picker, _pickerData, height: 915, tallHeight: 1100),
  _case('picker_search', _picker, _pickerData, act: _search('dollar'), tallHeight: 1100),
  _case('picker_no_match', _picker, _pickerData, act: _search('zzzz'), tallHeight: 1100),
  _case('convert_auto', _conversionSheet, () => _conversion(_draft()), tallHeight: 1700),
  _case(
    'convert_fallback_date',
    _conversionSheet,
    () => _conversion(_draft(date: '2026-11-22', lookup: FxRateFound(_rate(fallback: true)))),
    tallHeight: 1700,
  ),
  _case(
    'convert_manual',
    _conversionSheet,
    () => _conversion(_draft(manual: true, rateText: '90.5')),
    tallHeight: 1700,
  ),
  _case(
    'convert_no_rate',
    _conversionSheet,
    () => _conversion(
      _draft(
        lookup: FxNeedsManualRate(
          from: 'USD',
          to: 'INR',
          date: DateTime.utc(2026, 11, 20),
          reason: FxMissingReason.noRates,
          currencies: const ['USD', 'INR'],
        ),
        manual: true,
      ),
    ),
    tallHeight: 1700,
  ),
  _case(
    'convert_saved',
    _conversionSheet,
    () => _conversion(
      _draft(
        saved: SavedFx(
          rate: '89.6437142330',
          rateDate: DateTime.utc(2026, 11, 20),
          source: FxSource.frankfurter,
          currency: 'INR',
          total: 896437,
        ),
      ),
    ),
    height: 1000,
    tallHeight: 1800,
  ),
  _case(
    'balances_by_currency',
    () => const _TabHost(BalancesTab(groupId: gid)),
    () => _balancesTab(converted: true),
    height: 1700,
  ),
  _case(
    'balances_in_inr_missing',
    () => const _TabHost(BalancesTab(groupId: gid)),
    () => _balancesTab(converted: false),
    height: 1100,
    tallHeight: 1500,
    act: _tapInInr,
  ),
  _case(
    'balances_in_inr_converted',
    () => const _TabHost(BalancesTab(groupId: gid)),
    () => _balancesTab(converted: true),
    height: 1500,
    tallHeight: 2400,
    act: _tapInInr,
  ),
  _case(
    'expense_detail_not_converted',
    () => const ExpenseDetailScreen(expenseId: 'e2'),
    () => _detail(converted: false),
    height: 1100,
    tallHeight: 1800,
  ),
  _case(
    'expense_detail_converted',
    () => const ExpenseDetailScreen(expenseId: 'e2'),
    () => _detail(converted: true),
    height: 1100,
    tallHeight: 1800,
  ),
  _case(
    'settle_usd',
    () => const SettleUpScreen(groupId: gid, from: 'm1', to: 'm3', currency: 'USD'),
    _settleUsd,
    height: 1350,
  ),
];

Future<void> _pump(WidgetTester tester, Future<void> Function(WidgetTester)? act) async {
  await pumpFixedFrames(tester);
  if (act == null) return;
  await act(tester);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  // TC-14-xx (phase 14): currency picker, conversion sheet, converted balances, conversion tile and
  // Settle up in USD, light and dark at text scale 1.0 and 2.0.
  for (final c in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'phase 14 ${c.name} ${mode.name} $suffix',
          fileName: 'currency_${c.name}_${mode.name}_$suffix',
          pumpBeforeTest: (tester) => _pump(tester, c.act),
          builder: () => expenseApp(
            c.screen(),
            overrides: c.overrides(),
            mode: mode,
            scale: scale,
            size: Size(goldenWidth, scale > 1 ? c.tallHeight : c.height),
          ),
        );
      }
    }
  }
}
