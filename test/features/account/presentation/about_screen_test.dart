import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/app_info.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/features/account/presentation/about_screen.dart';

/// Phase 19 T7: About & licences — project links open in the browser, a failed open says where the
/// link goes, and the licences page lists the bundled fonts.
void main() {
  Future<List<Uri>> pumpAbout(WidgetTester tester, {bool opens = true}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final opened = <Uri>[];
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        routerProvider.overrideWith((ref) => buildRouter(initialLocation: Routes.about)),
        linkOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return opens;
        }),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(412 * 2, 1400 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
    await tester.pump(const Duration(milliseconds: 500));
    return opened;
  }

  testWidgets('shows the name, version and project links', (tester) async {
    await pumpAbout(tester);
    expect(find.text('Splitify Free Forever'), findsOneWidget);
    expect(find.text('Version $appVersion'), findsOneWidget);
    for (final key in ['about-source', 'about-privacy', 'about-report', 'about-licences']) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(find.textContaining('SIL Open Font License'), findsOneWidget);
  });

  testWidgets('each link opens its page', (tester) async {
    final opened = await pumpAbout(tester);
    await tester.tap(find.byKey(const Key('about-source')));
    await tester.tap(find.byKey(const Key('about-privacy')));
    await tester.tap(find.byKey(const Key('about-report')));
    await tester.pump();
    expect(opened, [Uri.parse(repoUrl), Uri.parse(privacyUrl), Uri.parse(issuesUrl)]);
  });

  testWidgets('a link that cannot open shows where it goes', (tester) async {
    await pumpAbout(tester, opens: false);
    await tester.tap(find.byKey(const Key('about-privacy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining(privacyUrl), findsOneWidget);
  });

  testWidgets('open-source licences opens the licence page', (tester) async {
    await pumpAbout(tester);
    await tester.tap(find.byKey(const Key('about-licences')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
