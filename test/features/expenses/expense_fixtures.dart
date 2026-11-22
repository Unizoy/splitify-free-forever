// Shared sample data and harness for the expense screens (goldens, widget tests).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/core/money/split.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/expenses/application/default_split_controller.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/recurring/application/repeat_draft.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show syncOfflineProvider;

import '../../support/fakes.dart';

const gid = 'g-goa';
const me = 'm1';

/// Four people in fixed order; "me" is Mohit.
const people = <EditorMember>[
  (id: 'm1', name: 'Mohit Bindal', isMe: true),
  (id: 'm2', name: 'Asha Rao', isMe: false),
  (id: 'm3', name: 'Rahul Mehta', isMe: false),
  (id: 'm4', name: 'Priya Nair', isMe: false),
];
final ids = [for (final p in people) p.id];
final fixedToday = DateTime(2026, 11, 21);

/// A filled draft of [kind] for 1,200.00 INR paid by me (values as the editor would hold them).
ExpenseDraft sampleDraft({
  SplitKind kind = SplitKind.equal,
  String amount = '1200',
  String description = 'Dinner at Thalassa',
  String category = 'food.dining_out',
  String notes = '',
  String? expenseId = 'e1',
  SplitDraft? split,
  bool canRepeat = false,
  RepeatDraft repeat = RepeatDraft.never,
  String? templateId,
}) {
  final base = SplitDraft.initial(ids, 2);
  final s =
      split ??
      switch (kind) {
        SplitKind.equal => base.toggle('m4'),
        SplitKind.exact => base.withValues(SplitKind.exact, {
          'm1': 50000,
          'm2': 30000,
          'm3': 25000,
          'm4': 15000,
        }),
        SplitKind.percent => base.withValues(SplitKind.percent, {
          'm1': 4000,
          'm2': 3000,
          'm3': 2000,
          'm4': 1000,
        }),
        SplitKind.shares => base.withValues(SplitKind.shares, {
          'm1': 2000,
          'm2': 1000,
          'm3': 1000,
          'm4': 0,
        }),
        SplitKind.adjust => base.withValues(SplitKind.adjust, {'m1': 10000, 'm2': -5000}),
      };
  return ExpenseDraft(
    groupId: gid,
    groupName: 'Goa trip',
    expenseId: expenseId,
    currency: 'INR',
    members: people,
    split: s,
    date: fixedToday,
    payerId: me,
    payers: const {},
    amountText: amount,
    description: description,
    category: category,
    notes: notes,
    canRepeat: canRepeat,
    repeat: repeat,
    templateId: templateId,
  );
}

/// Editor whose build returns [draft] (no database).
class FixedEditorController extends ExpenseEditorController {
  FixedEditorController(super.args, this.draft);

  final ExpenseDraft draft;
  int saves = 0;

  @override
  Future<ExpenseDraft> build() async => draft;

  @override
  Future<String?> save() async {
    final d = state.value;
    if (d == null || !d.canSave) return null;
    saves++;
    return d.expenseId ?? 'new-id';
  }
}

/// Default-split editor whose build returns [initial] (no database).
class FixedDefaultSplitController extends DefaultSplitController {
  FixedDefaultSplitController(super.groupId, this.initial);

  final DefaultSplitState initial;
  int saves = 0;

  @override
  Future<DefaultSplitState> build() async => initial;

  @override
  Future<bool> save() async {
    if (!(state.value?.canSave ?? false)) return false;
    saves++;
    return true;
  }
}

LocalGroup sampleGroup({String? defaultSplit}) => LocalGroup(
  id: gid,
  name: 'Goa trip',
  type: 'trip',
  mainCurrency: 'INR',
  coverKind: 'generated',
  simplifyDebts: false,
  defaultSplit: defaultSplit,
  seq: 1,
  syncState: SyncState.synced,
);

/// A stored expense row.
LocalExpense sampleExpense({
  String id = 'e1',
  String description = 'Dinner at Thalassa',
  String category = 'food.dining_out',
  String date = '2026-11-20',
  int total = 240000,
  Map<String, int> payers = const {'m1': 240000},
  Map<String, int>? shares,
  String splitKind = 'equal',
  Map<String, int>? splitValues,
  String? notes,
  String syncState = SyncState.synced,
}) => LocalExpense(
  id: id,
  groupId: gid,
  kind: 'expense',
  description: description,
  notes: notes,
  category: category,
  date: date,
  currency: 'INR',
  total: total,
  payers: jsonEncode(payers),
  shares: jsonEncode(shares ?? {for (final m in ids) m: total ~/ 4}),
  splitKind: splitKind,
  splitValues: splitValues == null ? null : jsonEncode(splitValues),
  source: 'app',
  createdAt: '2026-11-20T14:05:00Z',
  createdBy: 'u1',
  seq: 1,
  syncState: syncState,
);

/// Members as rows ([ExpenseView] names).
final memberNames = {for (final p in people) p.id: p.name};

ExpenseView sampleView(LocalExpense e) {
  Map<String, int> ints(String j) =>
      (jsonDecode(j) as Map<String, Object?>).map((k, v) => MapEntry(k, v! as int));
  return ExpenseView(
    expense: e,
    paid: ints(e.payers),
    owed: ints(e.shares),
    names: memberNames,
    meId: me,
    userNames: const {'u1': 'Mohit Bindal'},
  );
}

/// The Expenses tab sample: two months, one unsynced row, lent / borrowed / not involved.
List<ExpenseView> sampleViews() => [
  sampleView(
    sampleExpense(
      id: 'e2',
      description: 'Cab to airport',
      category: 'travel.cab_auto',
      date: '2026-11-21',
      total: 120000,
      payers: const {'m3': 120000},
      syncState: SyncState.pending,
    ),
  ),
  sampleView(sampleExpense()),
  sampleView(
    sampleExpense(
      id: 'e3',
      description: 'Groceries for the villa',
      category: 'groceries.groceries',
      date: '2026-10-28',
      total: 85050,
      payers: const {'m2': 85050},
      shares: const {'m2': 40050, 'm3': 45000},
      splitKind: 'exact',
      splitValues: const {'m2': 40050, 'm3': 45000},
    ),
  ),
  sampleView(
    sampleExpense(
      id: 'e4',
      description: 'Beach shack',
      category: 'travel.hotel',
      date: '2026-10-25',
      total: 1800000,
      payers: const {'m1': 900000, 'm2': 900000},
      shares: const {'m1': 450000, 'm2': 450000, 'm3': 450000, 'm4': 450000},
    ),
  ),
];

/// Overrides that keep the screens off the database and network.
List<Override> baseOverrides() => [
  clockProvider.overrideWithValue(FakeClock(DateTime(2026, 11, 21, 10))),
  syncOfflineProvider.overrideWith((ref) => Stream.value(false)),
  currentUserIdProvider.overrideWithValue('u1'),
  // Phase 09: the Expenses tab also lists payments; none in these fixtures.
  groupPaymentViewsProvider(gid).overrideWithValue(const AsyncData([])),
];

/// Themed app around [child] (no router).
Widget expenseApp(
  Widget child, {
  List<Override> overrides = const [],
  ThemeMode mode = ThemeMode.light,
  double scale = 1,
  Size size = const Size(412, 915),
}) {
  return SizedBox.fromSize(
    size: size,
    child: ProviderScope(
      overrides: [...baseOverrides(), ...overrides],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          textScaler: TextScaler.linear(scale),
        ),
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
          themeMode: mode,
          debugShowCheckedModeBanner: false,
          home: child,
        ),
      ),
    ),
  );
}
