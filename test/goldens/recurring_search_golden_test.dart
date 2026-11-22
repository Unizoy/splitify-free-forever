import 'dart:convert';

import 'package:alchemist/alchemist.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/rules/recurrence.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/recurring/application/recurring_providers.dart';
import 'package:splitify/features/recurring/application/repeat_draft.dart';
import 'package:splitify/features/recurring/presentation/recurring_tile.dart';
import 'package:splitify/features/search/application/search_controller.dart';
import 'package:splitify/features/search/presentation/search_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';

import '../features/expenses/expense_fixtures.dart';
import 'golden_support.dart';

/// One golden scenario: the screen, its overrides and the frame height at text scale 1.0.
typedef _Case = (
  String name,
  Widget Function() screen,
  List<Override> Function() overrides,
  double h,
);

const ExpenseEditorArgs _newArgs = (groupId: gid, expenseId: null);
const _tid = 't1';

LocalRecurring _template({
  bool active = true,
  String? next = '2026-12-20',
  String? endsOn,
  String syncState = SyncState.synced,
}) => LocalRecurring(
  id: _tid,
  groupId: gid,
  expenseId: 'e0',
  interval: 'monthly',
  anchorDate: '2026-10-20',
  nextDate: next,
  endsOn: endsOn,
  active: active,
  template: jsonEncode({'description': 'Villa rent', 'total': 4000000, 'currency': 'INR'}),
  seq: 3,
  syncState: syncState,
);

/// [AppSheet] at the bottom of a dimmed screen, like the real modal sheet.
class _SheetHost extends StatelessWidget {
  const _SheetHost({required this.title, required this.child});

  final String Function(AppLocalizations) title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black54,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AppSheet(title: title(AppLocalizations.of(context)), child: child),
    ),
  );
}

/// Search controller with a fixed state (no typing in goldens).
class _FixedSearch extends ExpenseSearchController {
  _FixedSearch(this.fixed) : super(null);

  final SearchState fixed;

  @override
  SearchState build() => fixed;
}

LocalExpense _copy(String id, String date, {String syncState = SyncState.synced}) => sampleExpense(
  id: id,
  description: 'Villa rent',
  category: 'rent.rent',
  date: date,
  total: 4000000,
  payers: const {'m1': 4000000},
  syncState: syncState,
).copyWith(source: 'recurring', recurringId: const Value(_tid));

List<SearchHit> _hits() => [
  (
    view: sampleView(_copy('r3', '2026-11-20', syncState: SyncState.pending)),
    groupName: 'Goa trip',
  ),
  (view: sampleView(_copy('r2', '2026-10-20')), groupName: 'Goa trip'),
  (
    view: sampleView(
      sampleExpense(
        id: 'x1',
        description: 'Rent for the scooter',
        category: 'travel.fuel',
        date: '2026-10-12',
        total: 150000,
        payers: const {'m2': 150000},
        shares: const {'m1': 75000, 'm2': 75000},
      ),
    ),
    groupName: 'Flat 302',
  ),
  (view: sampleView(_copy('r1', '2026-09-20')), groupName: 'Goa trip'),
];

List<Override> _search(SearchState s, List<SearchHit> hits) => [
  searchControllerProvider(null).overrideWith(() => _FixedSearch(s)),
  searchResultsProvider(null).overrideWithValue(AsyncData(hits)),
  searchGroupsProvider.overrideWith((ref) => Stream.value([sampleGroup()])),
];

List<Override> _detail(LocalExpense e, LocalRecurring t) => [
  expenseViewProvider(e.id).overrideWithValue(AsyncData(sampleView(e))),
  expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
  commentThreadProvider((groupId: gid, targetType: 'expense', targetId: e.id))
      .overrideWithValue(const AsyncData([])),
  expenseRecurringProvider((expenseId: e.id, recurringId: e.recurringId))
      .overrideWith((ref) => Stream.value(t)),
];

List<_Case> _cases() => [
  (
    'repeat_editor_details',
    () => const ExpenseEditorScreen(groupId: gid, initialStep: EditorStep.details),
    () => [
      expenseEditorProvider(_newArgs).overrideWith(
        () => FixedEditorController(
          _newArgs,
          sampleDraft(
            expenseId: null,
            description: 'Villa rent',
            category: 'rent.rent',
            canRepeat: true,
            repeat: RepeatDraft(
              interval: RecurrenceInterval.monthly,
              endsOn: DateTime(2027, 3, 31),
            ),
          ),
        ),
      ),
    ],
    1250,
  ),
  (
    'repeat_editor_end_error',
    () => const ExpenseEditorScreen(groupId: gid, initialStep: EditorStep.details),
    () => [
      expenseEditorProvider(_newArgs).overrideWith(
        () => FixedEditorController(
          _newArgs,
          sampleDraft(
            expenseId: null,
            canRepeat: true,
            repeat: RepeatDraft(interval: RecurrenceInterval.weekly, endsOn: DateTime(2026, 11, 1)),
          ),
        ),
      ),
    ],
    1250,
  ),
  (
    'repeat_future_copies',
    () => const ExpenseEditorScreen(templateId: _tid, initialStep: EditorStep.details),
    () => [
      templateEditorProvider(_tid).overrideWith(
        () => FixedEditorController(
          (groupId: null, expenseId: null),
          sampleDraft(
            expenseId: null,
            description: 'Villa rent',
            category: 'rent.rent',
            templateId: _tid,
            repeat: const RepeatDraft(interval: RecurrenceInterval.monthly),
          ),
        ),
      ),
    ],
    1100,
  ),
  (
    'repeat_detail_copy',
    () => const ExpenseDetailScreen(expenseId: 'r2'),
    () => _detail(_copy('r2', '2026-10-20'), _template()),
    1500,
  ),
  (
    'repeat_sheet',
    () => _SheetHost(
      title: (l) => l.repeatMonthly,
      child: const RecurringSheet(templateId: _tid),
    ),
    () => [
      recurringTemplateProvider(_tid).overrideWith(
        (ref) => Stream.value(_template(syncState: SyncState.pending, endsOn: '2027-03-20')),
      ),
    ],
    915,
  ),
  (
    'repeat_sheet_stopped',
    () => _SheetHost(
      title: (l) => l.recurringStop,
      child: const RecurringSheet(templateId: _tid),
    ),
    () => [
      recurringTemplateProvider(_tid).overrideWith((ref) => Stream.value(_template(active: false))),
    ],
    915,
  ),
  ('search_idle', () => const SearchScreen(), () => _search(const SearchState(), const []), 915),
  (
    'search_results',
    () => const SearchScreen(),
    () => _search(const SearchState(text: 'rent'), _hits()),
    1100,
  ),
  (
    'search_no_matches',
    () => const SearchScreen(),
    () => _search(const SearchState(text: 'zzz', groupId: gid, category: 'food'), const []),
    915,
  ),
];

void main() {
  // TC-12-04 (repeat picker), #12 detail / sheet / future copies, #34 search: light and dark at text
  // scale 1.0 and 2.0.
  for (final (name, screen, overrides, height) in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'phase 16 $name ${mode.name} $suffix',
          fileName: '${name}_${mode.name}_$suffix',
          pumpBeforeTest: pumpFixedFrames,
          builder: () => expenseApp(
            screen(),
            overrides: overrides(),
            mode: mode,
            scale: scale,
            size: Size(goldenWidth, scale > 1 ? height * 1.8 : height),
          ),
        );
      }
    }
  }
}
