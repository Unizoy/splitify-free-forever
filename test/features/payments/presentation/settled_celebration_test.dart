// T6 (phase 11): the settled celebration closes itself, closes on a tap, and never pops a route that is not
// its own (found on the device: a stack replaced during the celebration made the timer pop a dead route).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/payments/presentation/settled_celebration.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

void main() {
  final navigator = GlobalKey<NavigatorState>();

  Future<BuildContext> pumpHost(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('home', key: Key('home'))),
      ),
    );
    return t.element(find.byKey(const Key('home')));
  }

  Finder celebration() => find.byKey(const Key('settled-celebration'));

  testWidgets('T6 says who we are square with and closes itself after the hold', (t) async {
    final context = await pumpHost(t);
    var closed = false;
    showSettledCelebration(context, name: 'Asha').then((_) => closed = true).ignore();
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(celebration(), findsOneWidget);
    expect(find.text('You and Asha are square.'), findsOneWidget);
    await t.pump(celebrationHold);
    await t.pump(const Duration(milliseconds: 500));
    expect(celebration(), findsNothing);
    expect(closed, isTrue);
  });

  testWidgets('T6 a tap closes it early', (t) async {
    final context = await pumpHost(t);
    showSettledCelebration(context, name: 'Asha').ignore();
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(celebration(), warnIfMissed: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(celebration(), findsNothing);
    await t.pump(celebrationHold);
  });

  testWidgets('T6 when another screen is on top, the timer leaves it alone', (t) async {
    final context = await pumpHost(t);
    showSettledCelebration(context, name: 'Asha').ignore();
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    navigator.currentState!
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('other', key: Key('other'))),
          ),
        )
        .ignore();
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(celebrationHold);
    await t.pump(const Duration(milliseconds: 600));
    expect(
      find.byKey(const Key('other')),
      findsOneWidget,
      reason: 'the page on top was not popped',
    );
    expect(t.takeException(), isNull);
  });
}
