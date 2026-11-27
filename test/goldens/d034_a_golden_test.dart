// D-034 WP-A smart entry goldens: the two-person answers sheet, the Items editor (empty and full), the
// receipt sheet with "Scan receipt", the scan review (found / nothing found), the deleted expense page and
// an itemized expense with its category trend — light and dark at text 1.0 and 2.0, plus a small phone
// (320 × 568) at text 1.0. Every state also runs the a11y guidelines (expectA11y in pumpFixedFrames).
import 'package:alchemist/alchemist.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/domain/rules/receipt_text_parser.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/expenses/application/category_trend.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/itemize_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/paid_split_sheet.dart';
import 'package:splitify/features/expenses/presentation/editor/receipt_field.dart';
import 'package:splitify/features/expenses/presentation/editor/two_person_sheet.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/insights/domain/aggregations.dart' show MonthSpend;
import 'package:splitify/features/receipt_scan/application/receipt_ocr.dart';
import 'package:splitify/features/receipt_scan/application/scan_apply.dart';
import 'package:splitify/features/receipt_scan/presentation/scan_review_sheet.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/expenses/expense_fixtures.dart';
import '../support/sample_photo.dart';
import 'golden_support.dart';

const _small = Size(320, 568);

/// Me and Asha (a friend expense) for ₹300.
ExpenseDraft _friend() {
  final d = sampleDraft(expenseId: null, amount: '300', description: 'Cab to airport');
  return ExpenseDraft(
    groupId: d.groupId,
    groupName: 'Asha Rao',
    groupType: 'direct',
    currency: 'INR',
    members: people.take(2).toList(),
    split: SplitDraft.initial(const ['m1', 'm2'], 2),
    date: d.date,
    payerId: me,
    payers: const {},
    amountText: '300',
    description: d.description,
  );
}

ExpenseDraft _itemsEmpty() => sampleDraft(
  expenseId: null,
  amount: '',
  description: 'Dinner',
  split: SplitDraft.initial(ids, 2).switchToItems(),
);

ExpenseDraft _itemsFull() {
  var it = SplitDraft.initial(ids, 2).switchToItems().items!;
  final k = it.items.first.key;
  it = it.setName(k, 'Paneer tikka').setAmount(k, '360');
  it = it.toggleMember(k, 'm3').toggleMember(k, 'm4');
  it = it.addItem(ids);
  it = it.setName(it.items[1].key, 'Butter naan').setAmount(it.items[1].key, '160');
  it = it.addItem(const ['m3']);
  it = it.setName(it.items[2].key, 'Mango lassi').setAmount(it.items[2].key, '120');
  it = it.setExtra(ItemExtra.tax, '32').setExtra(ItemExtra.service, '32');
  return sampleDraft(
    expenseId: null,
    amount: '704',
    description: 'Dinner at Punjab Grill',
    split: SplitDraft.initial(ids, 2).withItems(it),
  );
}

final _photo = PreparedImage(full: samplePhotoPng, thumb: samplePhotoPng);

ScanOutcome _found() => (
  scan: parseReceipt(const [
    'HOTEL SARAVANA BHAVAN',
    'Date: 21/11/2026',
    'Masala Dosa  2  90.00  180.00',
    'Ghee Roast  1  140.00  140.00',
    'Mini Meals  2  220.00  440.00',
    'Filter Coffee  4  35.00  140.00',
    'Sub Total  900.00',
    'Service Charge @ 5%  45.00',
    'CGST @ 2.5%  23.63',
    'SGST @ 2.5%  23.63',
    'Round Off  -0.26',
    'Grand Total  Rs. 992.00',
  ]),
  photo: _photo,
);

/// A sheet body at the bottom of a dimmed screen, like the real modal sheet.
class _SheetHost extends StatelessWidget {
  const _SheetHost({required this.title, required this.child});

  final String Function(AppLocalizations l) title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.scrim,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AppSheet(title: title(AppLocalizations.of(context)), child: child),
    ),
  );
}

Widget _paidSplit(ExpenseDraft d) => _SheetHost(
  title: (l) => l.expPaidSplitTitle,
  child: PaidSplitPanel(
    draft: d,
    onPayer: (_) {},
    onMultiple: () {},
    onPayerText: (_, _) {},
    onSplit: (_) {},
    onUseTotal: (_) {},
    onDone: () {},
  ),
);

/// An itemized dinner, saved (for the detail page).
final _itemizedRow =
    sampleExpense(
      id: 'e5',
      description: 'Dinner at Punjab Grill',
      total: 70400,
      payers: const {'m1': 70400},
      shares: const {'m1': 28160, 'm2': 22880, 'm3': 19360, 'm4': 0},
      splitKind: 'exact',
    ).copyWith(
      splitValues: const Value(
        '{"m1":28160,"m2":22880,"m3":19360,"itemized":{"v":1,"items":['
        '{"name":"Paneer tikka","amount":36000,"members":["m1","m2"]},'
        '{"name":"Butter naan","amount":16000,"members":["m1","m2","m3","m4"]},'
        '{"name":"Mango lassi","amount":12000,"members":["m3"]}],'
        '"extras":{"tax":3200,"service":3200,"tip":0,"discount":0}}}',
      ),
    );

List<Override> _detail(String id, ExpenseView view) => [
  noRepeat(id),
  expenseViewProvider(id).overrideWithValue(AsyncData(view)),
  expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
  commentThreadProvider((groupId: gid, targetType: 'expense', targetId: id))
      .overrideWithValue(const AsyncData([])),
];

typedef _Case = (String name, Widget screen, List<Override> overrides);

List<_Case> _cases() {
  final deleted = sampleExpense().copyWith(deletedAt: const Value('2026-11-21T09:00:00Z'));
  const trend = (
    currency: 'INR',
    category: 'food',
    groupName: 'Goa trip',
    months: [
      MonthSpend('2026-09', 184000),
      MonthSpend('2026-10', 96050),
      MonthSpend('2026-11', 310400),
    ],
  );
  final friend = _friend();
  final empty = sampleDraft(
    expenseId: null,
    amount: '',
    description: '',
  ).copyWith(receipt: const ReceiptDraft.none());
  return [
    (
      'two_person',
      _SheetHost(
        title: (l) => l.expPaidSplitTitle,
        child: TwoPersonPanel(draft: friend, onAnswer: (_) {}, onMore: () {}),
      ),
      const [],
    ),
    ('items_empty', _paidSplit(_itemsEmpty()), const []),
    ('items_full', _paidSplit(_itemsFull()), const []),
    (
      'receipt_sheet',
      _SheetHost(
        title: (l) => l.receiptLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScanReceiptTile(onTap: () {}),
            const SizedBox(height: AppSpacing.s3),
            ReceiptField(receipt: empty.receipt, onChanged: (_) {}),
          ],
        ),
      ),
      const [],
    ),
    (
      'scan_found',
      _SheetHost(
        title: (l) => l.entryScanTitle,
        child: ScanReviewPanel(
          outcome: _found(),
          draft: sampleDraft(expenseId: null, amount: '500', description: ''),
          onDone: (_) {},
          onRetry: () {},
        ),
      ),
      const [],
    ),
    (
      'scan_nothing',
      _SheetHost(
        title: (l) => l.entryScanTitle,
        child: ScanReviewPanel(
          outcome: (scan: const ReceiptScan(), photo: _photo),
          draft: empty,
          onDone: (_) {},
          onRetry: () {},
        ),
      ),
      const [],
    ),
    (
      'deleted_expense',
      const ExpenseDetailScreen(expenseId: 'e1'),
      _detail('e1', sampleView(deleted)),
    ),
    (
      'itemized_trend',
      // The base harness hides the trend; this page shows one.
      ProviderScope(
        overrides: [categoryTrendProvider.overrideWith((ref, q) => trend)],
        child: const ExpenseDetailScreen(expenseId: 'e5'),
      ),
      _detail('e5', sampleView(_itemizedRow)),
    ),
  ];
}

void main() {
  test('the samples are consistent', () {
    expect(_itemsFull().canSave, isTrue);
    expect(defaultChoice(_itemsEmpty(), _found().scan).amount, isTrue);
  });

  for (final (name, screen, overrides) in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'd034 a $name ${mode.name} $suffix',
          fileName: 'd034_a_${name}_${mode.name}_$suffix',
          pumpBeforeTest: pumpFixedFrames,
          builder: () => expenseApp(screen, overrides: overrides, mode: mode, scale: scale),
        );
      }
    }
    // The lower part of the long screens (items, extras, each person; item lines and the trend card).
    if (const ['items_full', 'itemized_trend', 'deleted_expense'].contains(name)) {
      goldenTest(
        'd034 a $name tall',
        fileName: 'd034_a_${name}_tall_light_text100',
        pumpBeforeTest: pumpFixedFrames,
        builder: () => expenseApp(screen, overrides: overrides, size: const Size(412, 2000)),
      );
    }
    goldenTest(
      'd034 a $name small phone',
      fileName: 'd034_a_${name}_small_light_text100',
      pumpBeforeTest: pumpFixedFrames,
      builder: () => expenseApp(screen, overrides: overrides, size: _small),
    );
  }
}
