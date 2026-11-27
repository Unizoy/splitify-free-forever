// Final QA (S-400): the tab shell's capsule nav bar must fit a 320 dp phone. There the bar is too narrow for
// the active pill's icon + label beside three 56 dp icons, so the inactive buttons shrink to the 48 dp touch
// size and the active pill shows its icon only (the label stays for screen readers). Wider phones keep the
// labelled pill.
import 'package:flutter/material.dart';
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

  testWidgets('360 dp and wider keep the labelled active pill', (tester) async {
    for (final width in [360.0, 412.0]) {
      await _pumpBar(tester, width);
      expect(tester.takeException(), isNull);
      expect(find.text('Groups'), findsOneWidget);
    }
  });
}
