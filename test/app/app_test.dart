import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/bootstrap.dart';

void main() {
  testWidgets('App shows the placeholder home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placeholder-home')), findsOneWidget);
    expect(find.text('Splitify is getting ready'), findsOneWidget);
  });

  testWidgets('bootstrap shows config error when env is missing', (tester) async {
    final widget = await tester.runAsync(bootstrap);
    await tester.pumpWidget(widget!);
    await tester.pumpAndSettle();
    expect(find.text('App is not configured'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
