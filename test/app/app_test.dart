import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/ui/components/dashed_circle_button.dart';

void main() {
  // TC-B3-03: the app opens on the welcome screen and "Get started" leads into the shell.
  testWidgets('App starts on welcome and Get started opens the capsule nav', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const App(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DashedCircleButton), findsOneWidget);
    expect(find.text('Groups'), findsNothing);

    await tester.tap(find.byType(DashedCircleButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(DashedCircleButton), findsNothing);
    expect(find.text('Groups'), findsWidgets);
  });

  testWidgets('bootstrap shows config error when env is missing', (tester) async {
    final widget = await tester.runAsync(bootstrap);
    await tester.pumpWidget(widget!);
    await tester.pumpAndSettle();
    expect(find.text('App is not configured'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
