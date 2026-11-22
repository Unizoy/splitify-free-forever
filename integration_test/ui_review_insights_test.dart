// Emulator UI review for phase 17 (gate G5): the Insights screen in its states and the Totals tab with
// "See charts" / "Export CSV", with sample data (no sign-in, no network). Each screen prints
// `UI-CAPTURE <name>` and holds for `UI_HOLD` seconds while
// `.claude/skills/ui-review/scripts/capture_markers.ps1` takes light, dark and 200 % shots. The last step
// taps "Export CSV" with the real share_plus sharer and checks the Android share sheet opens (TC-22-01
// device check; the host screenshot shows the chooser with the CSV file).
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/application/totals_providers.dart';
import 'package:splitify/features/balances/presentation/totals_tab.dart';
import 'package:splitify/features/export/application/group_export.dart';
import 'package:splitify/features/insights/application/insights_providers.dart';
import 'package:splitify/features/insights/presentation/insights_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../test/features/balances/balance_fixtures.dart' show sampleTotals;
import '../test/features/expenses/expense_fixtures.dart' show baseOverrides, gid;
import '../test/features/insights/insights_fixtures.dart';
import '../test/support/ledger_seed.dart';

/// Seconds each screen stays up for the host captures (`UI_HOLD`, 0 = no hold).
const _hold = int.fromEnvironment('UI_HOLD');

class _TotalsHost extends StatelessWidget {
  const _TotalsHost();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: TotalsTab(groupId: gid),
      ),
    ),
  );
}

typedef _Screen = ({String name, Widget screen, List<Override> overrides, List<String> taps});

List<_Screen> _screens(AppDatabase db) {
  final all = insightsOverrides(allInsightLedgers());
  return [
    (
      name: 'insights-group',
      screen: const InsightsScreen(groupId: goaId),
      overrides: all,
      taps: [],
    ),
    (
      name: 'insights-picked',
      screen: const InsightsScreen(groupId: goaId),
      overrides: all,
      taps: ['insights-chip-travel', 'insights-bar-2026-09'],
    ),
    (
      name: 'insights-me',
      screen: const InsightsScreen(mode: InsightsMode.me),
      overrides: all,
      taps: [],
    ),
    (
      name: 'insights-picker',
      screen: const InsightsScreen(mode: InsightsMode.me),
      overrides: all,
      taps: ['insights-group-picker'],
    ),
    (
      name: 'insights-empty',
      screen: const InsightsScreen(groupId: emptyId),
      overrides: all,
      taps: [],
    ),
    (
      name: 'insights-convert',
      screen: const InsightsScreen(groupId: baliId),
      overrides: all,
      taps: [],
    ),
    (
      name: 'insights-loading',
      screen: const InsightsScreen(groupId: goaId),
      overrides: [insightsProvider.overrideWith((ref, q) => const AsyncLoading())],
      taps: [],
    ),
    (
      name: 'totals-links',
      screen: const _TotalsHost(),
      overrides: [
        groupTotalsProvider(gid).overrideWithValue(AsyncData(sampleTotals())),
        ledgerRepositoryProvider.overrideWithValue(LedgerRepository(db)),
      ],
      taps: [],
    ),
  ];
}

Future<void> _frames(WidgetTester t, [int n = 15]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Holds the screen for the host captures without starving Android's input (LEARNINGS phase 07).
Future<void> _holdFor(WidgetTester t, int seconds) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await t.pump();
  }
}

Widget _app(Widget screen, List<Override> overrides) => ProviderScope(
  key: UniqueKey(),
  overrides: [...baseOverrides(), ...overrides],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    debugShowCheckedModeBanner: false,
    home: screen,
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI review: Insights and export (phase 17)', (t) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final goa = goaLedger();
    await db.seed(
      groups: [goa.group.copyWith(id: gid)],
      members: [for (final m in goa.members) m.copyWith(groupId: gid)],
      expenses: [for (final e in goa.expenses) e.copyWith(groupId: gid)],
      payments: [seedPayment('pay1', groupId: gid, from: 'm2', to: 'm1', amount: 150000)],
    );

    for (final s in _screens(db)) {
      await t.pumpWidget(_app(s.screen, s.overrides));
      await _frames(t);
      for (final k in s.taps) {
        final f = find.byKey(Key(k));
        await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
        await t.tap(f);
        await _frames(t);
      }
      debugPrint('UI-CAPTURE ${s.name}');
      if (_hold > 0) await _holdFor(t, _hold);
    }

    // "Export CSV" through the real share sheet: the sharer must hand Android a file and not throw.
    final shared = Completer<String>();
    await t.pumpWidget(
      _app(const _TotalsHost(), [
        groupTotalsProvider(gid).overrideWithValue(AsyncData(sampleTotals())),
        ledgerRepositoryProvider.overrideWithValue(LedgerRepository(db)),
        csvSharerProvider.overrideWithValue((bytes, name, subject) async {
          shared.complete(name);
          // The real share_plus call opens the system chooser; not awaited (it waits for a choice).
          unawaited(shareCsvFile(bytes, name, subject));
        }),
      ]),
    );
    await _frames(t);
    final row = find.byKey(const Key('totals-export'));
    await t.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
    await t.tap(row);
    for (var i = 0; i < 30 && !shared.isCompleted; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(shared.isCompleted, isTrue);
    expect(await shared.future, matches(RegExp(r'^splitify-goa-trip-\d{4}-\d{2}-\d{2}\.csv$')));
    await Future<void>.delayed(const Duration(seconds: 3));
    debugPrint('UI-CAPTURE export-share-sheet');
    if (_hold > 0) await _holdFor(t, _hold);
  });
}
