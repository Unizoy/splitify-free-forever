// R3-A (S-448): money shows with Indian grouping wherever it is displayed — a lakh amount reads ₹1,23,456.50
// on the expense page (hero and shares) — and every standalone amount on screen uses tabular figures. Typed
// amounts in fields stay as typed (no live grouping: the cursor would jump and "100+20" is allowed).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/money/money_formatter.dart';

import '../goldens/r3_screens.dart';
import '../support/text_contrast.dart';

void main() {
  test('the formatter groups in lakhs and crores for every currency', () {
    expect(MoneyFormatter.detail.format(12345650, 'INR'), '₹1,23,456.50');
    expect(MoneyFormatter.detail.format(1234567890, 'INR'), '₹1,23,45,678.90');
    expect(MoneyFormatter.detail.format(12345650, 'USD'), r'$1,23,456.50');
  });

  testWidgets('the expense page shows the lakh amount grouped, in tabular figures', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const size = Size(412, 915);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final detail = r3Screens().firstWhere((s) => s.name == 'expense_detail');
    await tester.pumpWidget(detail.build(prefs, size, ThemeMode.light, 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('1,23,456.50'), findsWidgets);
    expect(find.textContaining('123,456'), findsNothing);
    await expectLater(tester, meetsGuideline(tabularAmountsGuideline));
    await tester.pumpWidget(const SizedBox());
  });
}
