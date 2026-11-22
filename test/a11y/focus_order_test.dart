import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';

/// Phase 19 T3 (focus order): TalkBack's swipe order follows the reading order of the screen — top to bottom,
/// and start to end within a row. Every actionable or text node is visited, none jumps back up the page.
void main() {
  Future<void> pumpAt(WidgetTester tester, String location) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerProvider.overrideWith((ref) => buildRouter(initialLocation: location)),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(412 * 2, 2400 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
    await tester.pump(const Duration(milliseconds: 800));
  }

  Rect globalRect(SemanticsNode node) {
    var rect = node.rect;
    for (SemanticsNode? n = node; n != null; n = n.parent) {
      if (n.transform != null) rect = MatrixUtils.transformRect(n.transform!, rect);
    }
    return rect;
  }

  for (final (name, location) in [
    ('welcome', Routes.welcome),
    ('sign in', Routes.signIn),
    ('appearance', Routes.appearance),
    ('about', Routes.about),
  ]) {
    testWidgets('$name: traversal goes top to bottom', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAt(tester, location);
      final nodes = tester.semantics
          .simulatedAccessibilityTraversal()
          .where(
            (n) => !n.rect.isEmpty && (n.label.isNotEmpty || n.getSemanticsData().actions != 0),
          )
          .toList();
      expect(nodes, isNotEmpty);
      Rect? previous;
      for (final node in nodes) {
        final r = globalRect(node);
        if (previous != null) {
          final sameRow = r.top < previous.bottom && r.bottom > previous.top;
          expect(
            sameRow || r.top >= previous.top - 1,
            isTrue,
            reason:
                '"${node.label}" at ${r.top.round()} comes after a node at ${previous.top.round()}',
          );
        }
        previous = r;
      }
      handle.dispose();
    });
  }
}
