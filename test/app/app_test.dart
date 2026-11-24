import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:splitify/core/config/preferences.dart';

void main() {
  // TC-B3-03 / T3: the app opens on the welcome screen; signed out, "Get started" opens
  // sign-in and the tabs redirect back to welcome.
  testWidgets('App starts on welcome and Get started opens sign-in', (tester) async {
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

    final getStarted = find.byKey(const Key('welcome-get-started'));
    expect(getStarted, findsOneWidget);
    expect(find.text('Groups'), findsNothing);

    await tester.tap(getStarted);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(getStarted, findsNothing, reason: 'sign-in covers the welcome');
    expect(find.text('How would you like to sign in?'), findsOneWidget);
    expect(find.text('Groups'), findsNothing);
  });

  testWidgets('bootstrap shows config error when env is missing', (tester) async {
    final widget = await tester.runAsync(bootstrap);
    await tester.pumpWidget(widget!);
    await tester.pumpAndSettle();
    expect(find.text('App is not configured'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
