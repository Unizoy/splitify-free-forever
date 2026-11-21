import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/app/bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and shows the placeholder home', (tester) async {
    final app = await bootstrap();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placeholder-home')), findsOneWidget);
  });
}
