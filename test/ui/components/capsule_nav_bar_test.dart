// Final QA (S-400): the tab shell's capsule nav bar must fit a 320 dp phone. There the bar is too narrow for
// the active pill's icon + label beside three 56 dp icons, so the inactive buttons shrink to the 48 dp touch
// size and the active pill shows its icon only (the label stays for screen readers). Wider phones keep the
// labelled pill.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/components/capsule_nav_bar.dart';
import 'package:splitify/ui/theme/theme.dart';

const _items = [
  CapsuleNavItem(label: 'Groups', icon: AppIcons.groups, activeIcon: AppIcons.groupsActive),
  CapsuleNavItem(label: 'Friends', icon: AppIcons.friends, activeIcon: AppIcons.friendsActive),
  CapsuleNavItem(label: 'Activity', icon: AppIcons.activity, activeIcon: AppIcons.activityActive),
  CapsuleNavItem(label: 'Account', leading: SizedBox(width: 28, height: 28)),
];

Future<void> _pumpBar(
  WidgetTester tester,
  double width, {
  int index = 0,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 640), textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          bottomNavigationBar: CapsuleNavBar(
            items: _items,
            currentIndex: index,
            onSelected: (_) {},
            onAdd: () {},
            addLabel: 'Add expense',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final index in [0, 1, 2, 3]) {
    testWidgets('320 dp: no overflow with tab $index active, icon-only pill', (tester) async {
      await _pumpBar(tester, 320, index: index);
      expect(tester.takeException(), isNull);
      // The label is not drawn, but the button still says its name.
      expect(find.text(_items[index].label), findsNothing);
      expect(find.bySemanticsLabel(_items[index].label), findsOneWidget);
    });
  }

  testWidgets('320 dp at text 2.0: no overflow', (tester) async {
    await _pumpBar(tester, 320, textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 dp: every button keeps a 48 dp touch target', (tester) async {
    await _pumpBar(tester, 320);
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  // R3-A (S-447): the active label shows only when it fits whole, never cut to "Frie…" (360 / 393 dp phones
  // showed "Gr", "Frie", "Accou"); then the other buttons shrink to 48 dp first, else the pill is icon only.
  testWidgets('the active label is drawn whole or not at all', (tester) async {
    for (final width in [340.0, 360.0, 393.0, 412.0, 480.0]) {
      for (final index in [0, 1, 2, 3]) {
        await _pumpBar(tester, width, index: index);
        expect(tester.takeException(), isNull, reason: '$width dp, tab $index');
        final label = find.text(_items[index].label);
        if (label.evaluate().isEmpty) continue;
        final p = tester.renderObject<RenderParagraph>(
          find.descendant(of: label, matching: find.byType(RichText)),
        );
        expect(
          p.size.width,
          greaterThanOrEqualTo(p.getMaxIntrinsicWidth(double.infinity) - 0.5),
          reason: '$width dp, tab $index: label cut',
        );
      }
    }
  });

  testWidgets('wide phones keep the labelled active pill', (tester) async {
    for (final width in [412.0, 480.0]) {
      await _pumpBar(tester, width);
      expect(tester.takeException(), isNull);
      expect(find.text('Groups'), findsOneWidget);
    }
  });

  testWidgets('tablet: a phone-sized capsule in the middle (S-444)', (tester) async {
    await _pumpBar(tester, 840);
    final bar = tester.getRect(find.byType(Row).first);
    expect(bar.width, lessThanOrEqualTo(AppSpacing.maxNav + 0.5));
    expect(bar.center.dx, closeTo(420, 1));
  });
}
