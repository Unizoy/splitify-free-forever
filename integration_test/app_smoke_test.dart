import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:splitify/ui/components/dashed_circle_button.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches on welcome and Get started opens the shell', (tester) async {
    final app = await bootstrap();
    await tester.pumpWidget(app);
    // The welcome screen animates forever, so never wait for it to settle.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DashedCircleButton), findsOneWidget);

    await tester.tap(find.byType(DashedCircleButton));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Groups'), findsWidgets);
  });
}
