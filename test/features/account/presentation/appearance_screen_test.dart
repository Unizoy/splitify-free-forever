import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';

void main() {
  Future<(ProviderContainer, SharedPreferences)> pump(WidgetTester tester, String location) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerProvider.overrideWith((ref) => buildRouter(initialLocation: location)),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
    await tester.pump(const Duration(milliseconds: 500));
    return (container, prefs);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('settings-appearance')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings-appearance')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Brightness current(WidgetTester tester) =>
      Theme.of(tester.element(find.byKey(const Key('settings-appearance')))).brightness;

  // TC-B3-01, D-033: appearance is a sheet from the Account list; a pick applies at once, saves and closes.
  testWidgets('TC-B3-01 Appearance sheet: Dark then Light switches the theme, saves and closes', (
    tester,
  ) async {
    final (_, prefs) = await pump(tester, Routes.account);
    await openSheet(tester);
    expect(find.byKey(const Key('appearance-mode')), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('appearance-mode')), findsNothing);
    expect(current(tester), Brightness.dark);
    expect(prefs.getString('theme_mode'), 'dark');

    await openSheet(tester);
    await tester.tap(find.text('Light'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(current(tester), Brightness.light);
    expect(prefs.getString('theme_mode'), 'light');
  });

  testWidgets('D-033 the old appearance page link lands on the Account list', (tester) async {
    await pump(tester, Routes.appearance);
    expect(find.byKey(const Key('settings-appearance')), findsOneWidget);
  });
}
