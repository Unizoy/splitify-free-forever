// TC-33-02: the Insights charts (donut + legend chips, month bars) and their states, light and dark at
// text scale 1.0 and 2.0.
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/insights/application/insights_providers.dart';
import 'package:splitify/features/insights/presentation/insights_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';

import '../features/expenses/expense_fixtures.dart' show expenseApp;
import '../features/insights/insights_fixtures.dart';
import 'golden_support.dart';

typedef _Case = ({
  String name,
  InsightsMode mode,
  String? group,
  List<GroupLedger> Function() ledgers,
  List<String> taps,
  bool tall,
});

_Case _case(
  String name,
  InsightsMode mode, {
  String? group,
  List<GroupLedger> Function() ledgers = allInsightLedgers,
  List<String> taps = const [],
  bool tall = true,
}) => (name: name, mode: mode, group: group, ledgers: ledgers, taps: taps, tall: tall);

final _cases = <_Case>[
  _case('group', InsightsMode.group, group: goaId),
  _case(
    'group_picked',
    InsightsMode.group,
    group: goaId,
    taps: ['insights-chip-travel', 'insights-bar-2026-09'],
  ),
  _case('me_all', InsightsMode.me),
  _case('me_group', InsightsMode.me, group: flatId),
  _case('empty', InsightsMode.group, group: emptyId, tall: false),
  _case('convert', InsightsMode.group, group: baliId, tall: false),
  _case('no_groups', InsightsMode.group, ledgers: () => const [], tall: false),
];

Future<void> Function(WidgetTester) _pumpThenTap(List<String> keys) => (t) async {
  if (keys.isNotEmpty) {
    // The 200 % frames are taller than the test surface; grow it so taps reach the month bars.
    t.view.physicalSize = Size(t.view.physicalSize.width, 4000 * t.view.devicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
  }
  await pumpFixedFrames(t);
  for (final k in keys) {
    await t.tap(find.byKey(Key(k)));
    await pumpFixedFrames(t);
  }
};

/// The group picker sheet at the bottom of a dimmed screen, like the real modal sheet.
class _PickerHost extends StatelessWidget {
  const _PickerHost();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black54,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AppSheet(
        title: AppLocalizations.of(context).insPickGroup,
        child: InsightsGroupOptions(
          view: insightsViewOf(
            allInsightLedgers(),
            (mode: InsightsMode.me, groupId: flatId),
            userId: 'u1',
            defaultCurrency: 'INR',
            today: insightsToday,
          ),
          onPick: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  for (final c in _cases) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        // TC-33-02
        goldenTest(
          'TC-33-02 insights ${c.name} ${mode.name} $suffix',
          fileName: 'insights_${c.name}_${mode.name}_$suffix',
          pumpBeforeTest: _pumpThenTap(c.taps),
          builder: () => expenseApp(
            InsightsScreen(mode: c.mode, groupId: c.group),
            overrides: insightsOverrides(c.ledgers()),
            mode: mode,
            scale: scale,
            size: Size(goldenWidth, !c.tall ? 915 : (scale > 1 ? 3300 : 1750)),
          ),
        );
      }
    }
  }
  _pickerGoldens();
}

void _pickerGoldens() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final (suffix, scale) in goldenScales) {
      // TC-33-02
      goldenTest(
        'TC-33-02 insights picker ${mode.name} $suffix',
        fileName: 'insights_picker_${mode.name}_$suffix',
        pumpBeforeTest: pumpFixedFrames,
        builder: () => expenseApp(const _PickerHost(), mode: mode, scale: scale),
      );
    }
  }
}
