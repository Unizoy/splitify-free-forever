import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';

void main() {
  // TC-B3-01: switching the appearance updates the theme at once and saves it.
  testWidgets('TC-B3-01 tapping Dark then Light switches the theme and saves', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerProvider.overrideWith((ref) => buildRouter(initialLocation: Routes.appearance)),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
    await tester.pump(const Duration(milliseconds: 500));

    Brightness current() =>
        Theme.of(tester.element(find.byKey(const Key('appearance-mode')))).brightness;

    expect(find.byKey(const Key('appearance-mode')), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(current(), Brightness.dark);
    expect(prefs.getString('theme_mode'), 'dark');

    await tester.tap(find.text('Light'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(current(), Brightness.light);
    expect(prefs.getString('theme_mode'), 'light');
  });
}
