import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/debug/presentation/gallery/gallery_sections.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Sections with images or glass/hero art behind text: the text-contrast guideline samples
/// pixels and cannot judge them, so it is only checked on the plain sections.
const _imagerySections = {
  'buttons',
  'chips',
  'covers',
  'cards',
  'showpieces',
  'navigation',
  'feedback',
  'avatars',
};

/// Sections that are known to fail a guideline (id -> guideline -> reason). Empty means all pass.
// Fixed in phase 02: medium PillButton is 48 dp (S-006), stepper circles are labelled.
const _knownFailures = <String, Map<String, String>>{};

Future<void> _pump(WidgetTester tester, GallerySection section) async {
  tester.view.physicalSize = const Size(412 * 2, 3000 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Builder(builder: section.builder),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
}

void main() {
  // TC-B3-03 (a11y): tap targets, labels and contrast on every gallery section.
  for (final section in gallerySections) {
    final known = _knownFailures[section.id] ?? const {};

    testWidgets(
      'TC-B3-03 ${section.id} meets android tap target guideline',
      skip: known['tapTarget'] != null,
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, section);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      },
    );

    testWidgets(
      'TC-B3-03 ${section.id} meets labeled tap target guideline',
      skip: known['labeled'] != null,
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, section);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      },
    );

    if (!_imagerySections.contains(section.id)) {
      testWidgets(
        'TC-B3-03 ${section.id} meets text contrast guideline',
        skip: known['contrast'] != null,
        (tester) async {
          final handle = tester.ensureSemantics();
          await _pump(tester, section);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        },
      );
    }
  }
}
