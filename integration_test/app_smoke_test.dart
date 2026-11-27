import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches on welcome and Get started opens sign-in', (tester) async {
    // The test binding's handler: bootstrap installs the app's own, and a failing expectation under it hung
    // the run ("A test overrode FlutterError.onError…", final QA S-411).
    final testOnError = FlutterError.onError;
    final app = await bootstrap();
    FlutterError.onError = testOnError;
    // Side-by-side device runs keep the app's data (--no-uninstall): an earlier test's session would open the
    // shell instead of the welcome, so start signed out (this phone only).
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) await auth.signOut(scope: SignOutScope.local);
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
