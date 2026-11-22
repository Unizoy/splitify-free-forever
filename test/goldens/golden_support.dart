import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Phone width used by every golden (logical px).
const goldenWidth = 412.0;

/// Pumps a few fixed frames; the app has endless animations, so never settle.
Future<void> pumpFixedFrames(WidgetTester tester) async {
  await tester.pump();
  // Generated covers render to images in the background; let that finish for real so the
  // golden always shows the cached image.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump(const Duration(milliseconds: 100));
  await expectA11y(tester);
}

/// TC-B3-03 (a11y sweep, phase 19 T3): every golden screen and state, light and dark, at text 1.0 and
/// 2.0, has 48 dp tap targets and a label on every tappable element (TalkBack). Text contrast is checked per
/// token pair (`test/ui/theme/contrast_test.dart`): golden text is drawn as blocks, so the pixel-sampling
/// contrast guideline cannot judge it here.
Future<void> expectA11y(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  try {
    await tester.pump();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  } finally {
    handle.dispose();
  }
}

/// Gives [child] the app theme for [brightness], localisations and a
/// background, like a real screen would have.
Widget themedFrame(Brightness brightness, Widget child, {EdgeInsets padding = EdgeInsets.zero}) {
  final theme = brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light();
  final colors = theme.extension<AppColors>()!;
  return Theme(
    data: theme,
    child: Builder(
      builder: (context) => Localizations(
        locale: const Locale('en'),
        delegates: AppLocalizations.localizationsDelegates,
        child: Material(
          color: colors.bg,
          child: Padding(padding: padding, child: child),
        ),
      ),
    ),
  );
}

/// Light and dark scenarios side by side.
GoldenTestGroup lightDarkGroup(Widget Function(BuildContext) build, {double width = goldenWidth}) {
  GoldenTestScenario scenario(String name, Brightness b) => GoldenTestScenario.builder(
    name: name,
    constraints: BoxConstraints.tightFor(width: width),
    builder: (context) => themedFrame(b, Builder(builder: build)),
  );
  return GoldenTestGroup(
    columns: 2,
    columnWidthBuilder: (_) => FixedColumnWidth(width + 16),
    children: [scenario('light', Brightness.light), scenario('dark', Brightness.dark)],
  );
}

/// Text scale factors every golden runs at, with the file-name suffix.
const goldenScales = <(String, double)>[('text100', 1.0), ('text200', 2.0)];
