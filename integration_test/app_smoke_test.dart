import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/app/bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches on welcome and Get started opens sign-in', (tester) async {
    final app = await bootstrap();
    await tester.pumpWidget(app);
    // The welcome screen animates forever, so never wait for it to settle.
    await tester.pump(const Duration(seconds: 1));
    final getStarted = find.byKey(const Key('welcome-get-started'));
    expect(getStarted, findsOneWidget);

    // Signed out (phase 05+), Get started leads to sign-in, not the shell (phase 19 regression update).
    await tester.tap(getStarted);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('sign-in-email')), findsOneWidget);
  });
}
