import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/app/app_route.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/data_providers.dart' show clockProvider;
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/search_repository.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart' show listMoney;
import 'package:splitify/features/expenses/application/expense_draft.dart' show parseIsoDate;
import 'package:splitify/features/expenses/presentation/editor/pickers.dart' show MonthCalendar;
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart' show ExpenseRow;
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/payments/application/payment_providers.dart' show PaymentView;
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/features/search/application/search_controller.dart';
import 'package:splitify/features/search/application/search_everything.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Search (`/search?group=`, #34, D-034 P-5): pill search field (description, notes, people, amount),
/// filter chips (group, person, date, category), result-type chips and the matching expenses, payments
/// and comments by month; the last 5 searches when nothing is typed. Reads only the phone's own data,
/// so it works offline; rows not synced yet carry the marker. Opened from a group, it starts in that
/// group ("Search in Goa trip").
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.groupId, super.key});

  /// Opened from a group: starts filtered to it.
  final String? groupId;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _text = TextEditingController(
    text: ref.read(searchControllerProvider(widget.groupId)).text,
  );
  final _focus = FocusNode();

  ExpenseSearchController get _ctrl => ref.read(searchControllerProvider(widget.groupId).notifier);

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  /// Leaving the field (a result tapped, the list scrolled, the keyboard closed) or pressing search keeps
  /// the text among the recent searches (S-362).
  void _onFocus() {
    if (!_focus.hasFocus && mounted) _remember();
  }

  void _remember() {
    if (_text.text.trim().isEmpty) return;
    ref.read(recentSearchesProvider.notifier).add(_text.text);
  }

  void _useRecent(String text) {
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _ctrl.setText(text);
    ref.read(recentSearchesProvider.notifier).add(text);
  }

  DateTime get _today {
    return ref.read(clockProvider).today();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(searchControllerProvider(widget.groupId));
    final results = ref.watch(searchEverythingProvider(widget.groupId));
    final groups = ref.watch(searchGroupsProvider).value ?? const <LocalGroup>[];
    final groupName = groups.where((g) => g.id == s.groupId).firstOrNull?.name;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s2,
                AppSpacing.s3,
                AppSpacing.screen,
                AppSpacing.s2,
              ),
              child: Row(
                children: [
                  AppIconButton(
                    key: const Key('search-back'),
                    tooltip: l.back,
                    icon: const Icon(AppIcons.back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: AppSpacing.s1),
                  Expanded(
                    child: _SearchField(
                      controller: _text,
                      focusNode: _focus,
                      hint: groupName == null ? l.search2FieldHint : l.search2HintIn(groupName),
                      onChanged: _ctrl.setText,
                      onSubmitted: (_) => _remember(),
                      onClear: () {
                        _text.clear();
                        _ctrl.setText('');
                        _focus.requestFocus();
                      },
                    ),
                  ),
                ],
              ),
            ),
            _Filters(state: s, groupKey: widget.groupId, today: _today),
            Expanded(
              child: _Results(
                state: s,
                results: results,
                groupName: groupName,
                onClear: _ctrl.clearFilters,
                onKind: _ctrl.setKind,
                onRecent: _useRecent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.minTouch + 4),
      padding: const EdgeInsets.only(left: AppSpacing.s4, right: AppSpacing.s1),
      decoration: BoxDecoration(
        color: c.bgSubtle,
        borderRadius: AppRadii.allPill,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(AppIcons.search, size: 20, color: c.textSecondary),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: TextField(
              key: const Key('search-field'),
              controller: controller,
              focusNode: focusNode,
              // A fresh search opens the keyboard; coming back to typed text does not.
              autofocus: controller.text.isEmpty,
              textInputAction: TextInputAction.search,
              style: context.text.body,
              cursorColor: c.primary,
              decoration: pillInputDecoration(
                context: context,
                hint: hint,
                style: context.text.body,
                hintStyle: context.text.body.copyWith(color: c.textTertiary),
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.text.isEmpty
                ? const SizedBox(width: AppSpacing.s3)
                : AppIconButton(
                    key: const Key('search-clear'),
                    tooltip: l.searchClear,
                    icon: Icon(AppIcons.clearCircle, size: 20, color: c.textTertiary),
                    onPressed: onClear,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Group · Person · Date · Category chips (each opens a sheet), "Clear filters" once one is set.
class _Filters extends ConsumerWidget {
  const _Filters({required this.state, required this.groupKey, required this.today});

  final SearchState state;
  final String? groupKey;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ctrl = ref.read(searchControllerProvider(groupKey).notifier);
    final groups = ref.watch(searchGroupsProvider).value ?? const <LocalGroup>[];
    final group = groups.where((g) => g.id == state.groupId).firstOrNull;
    final s = state;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.s1,
        AppSpacing.screen,
        AppSpacing.s3,
      ),
      child: Row(
        children: [
          IconChip(
            key: const Key('search-filter-group'),
            label: group?.name ?? l.searchAnyGroup,
            icon: AppIcons.groups,
            selected: s.groupId != null,
            onTap: () => unawaited(_pickGroup(context, ctrl, groups)),
          ),
          const SizedBox(width: AppSpacing.s2),
          IconChip(
            key: const Key('search-filter-person'),
            label: s.person?.name ?? l.searchAnyPerson,
            icon: AppIcons.user,
            selected: s.person != null,
            onTap: () => unawaited(_pickPerson(context, ref, ctrl)),
          ),
          const SizedBox(width: AppSpacing.s2),
          IconChip(
            key: const Key('search-filter-date'),
            label: _dateLabel(context, l, s),
            icon: AppIcons.calendar,
            selected: s.from != null,
            onTap: () => unawaited(_pickDates(context, ctrl)),
          ),
          const SizedBox(width: AppSpacing.s2),
          IconChip(
            key: const Key('search-filter-category'),
            label: s.category == null ? l.searchAnyCategory : l.category(s.category!),
            icon: s.category == null ? AppIcons.tag : Category.values.byName(s.category!).icon,
            iconColor: s.category == null ? null : Category.values.byName(s.category!).color,
            selected: s.category != null,
            onTap: () => unawaited(_pickCategory(context, ctrl)),
          ),
          if (s.hasFilters) ...[
            const SizedBox(width: AppSpacing.s2),
            IconChip(
              key: const Key('search-clear-filters'),
              label: l.searchClearFilters,
              icon: AppIcons.close,
              onTap: ctrl.clearFilters,
            ),
          ],
        ],
      ),
    );
  }

  String _dateLabel(BuildContext context, AppLocalizations l, SearchState s) =>
      switch (s.datePreset) {
        null => l.searchAnyDate,
        DatePreset.thisMonth => l.searchThisMonth,
        DatePreset.lastMonth => l.searchLastMonth,
        DatePreset.last3Months => l.searchLast3Months,
        DatePreset.thisYear => l.searchThisYear,
        DatePreset.custom => l.searchDateRange(
          dayMonth(context, s.from!),
          dayMonth(context, s.to!),
        ),
      };

  Future<void> _pickGroup(
    BuildContext context,
    ExpenseSearchController ctrl,
    List<LocalGroup> groups,
  ) async {
    final l = AppLocalizations.of(context);
    final picked = await showAppSheet<({String? id})>(
      context,
      title: l.searchFilterGroup,
      builder: (sheet) => _OptionList(
        children: [
          OptionTile(
            key: const Key('search-group-any'),
            label: l.searchAnyGroup,
            selected: state.groupId == null,
            onTap: () => Navigator.of(sheet).pop((id: null)),
          ),
          for (final g in groups)
            OptionTile(
              key: Key('search-group-${g.id}'),
              label: g.name,
              selected: state.groupId == g.id,
              onTap: () => Navigator.of(sheet).pop((id: g.id)),
            ),
        ],
      ),
    );
    if (picked != null) ctrl.setGroup(picked.id);
  }

  Future<void> _pickPerson(
    BuildContext context,
    WidgetRef ref,
    ExpenseSearchController ctrl,
  ) async {
    final l = AppLocalizations.of(context);
    final people = ref.read(searchPeopleProvider(state.groupId));
    final picked = await showAppSheet<({SearchPerson? person})>(
      context,
      title: l.searchFilterPerson,
      builder: (sheet) => _OptionList(
        children: [
          OptionTile(
            key: const Key('search-person-any'),
            label: l.searchAnyPerson,
            selected: state.person == null,
            onTap: () => Navigator.of(sheet).pop((person: null)),
          ),
          for (final p in people)
            OptionTile(
              key: Key('search-person-${p.key}'),
              label: p.name,
              leading: Avatar(name: p.name, seed: p.memberIds.first),
              selected: state.person?.key == p.key,
              onTap: () => Navigator.of(sheet).pop((person: p)),
            ),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Text(
                l.searchNoPeople,
                textAlign: TextAlign.center,
                style: context.text.body.copyWith(color: context.colors.textSecondary),
              ),
            ),
        ],
      ),
    );
    if (picked != null) ctrl.setPerson(picked.person);
  }

  /// Presets, or "Pick dates": From then To on a calendar in the same sheet (D-033: one sheet, not three).
  Future<void> _pickDates(BuildContext context, ExpenseSearchController ctrl) async {
    final l = AppLocalizations.of(context);
    final picked = await showAppSheet<_DatePick>(
      context,
      title: l.searchFilterDate,
      builder: (sheet) => _DateSheet(
        preset: state.datePreset,
        from: state.from ?? today,
        to: state.to ?? today,
        today: today,
        onDone: (p) => Navigator.of(sheet).pop(p),
      ),
    );
    if (picked == null) return;
    if (picked.preset != DatePreset.custom) {
      ctrl.setDates(picked.preset, today: today);
      return;
    }
    ctrl.setDates(DatePreset.custom, today: today, from: picked.from, to: picked.to);
  }

  Future<void> _pickCategory(BuildContext context, ExpenseSearchController ctrl) async {
    final l = AppLocalizations.of(context);
    final picked = await showAppSheet<({String? key})>(
      context,
      title: l.searchFilterCategory,
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              IconChip(
                key: const Key('search-category-any'),
                label: l.searchAnyCategory,
                selected: state.category == null,
                onTap: () => Navigator.of(sheet).pop((key: null)),
              ),
              for (final p in ExpenseCategories.tree.keys)
                IconChip(
                  key: Key('search-category-$p'),
                  label: l.category(p),
                  icon: Category.values.byName(p).icon,
                  iconColor: Category.values.byName(p).color,
                  selected: state.category == p,
                  onTap: () => Navigator.of(sheet).pop((key: p)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
        ],
      ),
    );
    if (picked != null) ctrl.setCategory(picked.key);
  }
}

typedef _DatePick = ({DatePreset? preset, DateTime? from, DateTime? to});

/// The date filter sheet: the presets; "Pick dates" turns it into From, then To, on one calendar.
class _DateSheet extends StatefulWidget {
  const _DateSheet({
    required this.preset,
    required this.from,
    required this.to,
    required this.today,
    required this.onDone,
  });

  final DatePreset? preset;
  final DateTime from;
  final DateTime to;
  final DateTime today;
  final ValueChanged<_DatePick> onDone;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  /// null = the presets; then the From and To steps of a custom range.
  DateTime? _from;
  bool _range = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!_range) {
      return _OptionList(
        children: [
          for (final (p, label) in <(DatePreset?, String)>[
            (null, l.searchAnyDate),
            (DatePreset.thisMonth, l.searchThisMonth),
            (DatePreset.lastMonth, l.searchLastMonth),
            (DatePreset.last3Months, l.searchLast3Months),
            (DatePreset.thisYear, l.searchThisYear),
            (DatePreset.custom, l.searchPickDates),
          ])
            OptionTile(
              key: Key('search-date-${p?.name ?? 'any'}'),
              label: label,
              selected: widget.preset == p,
              onTap: () => p == DatePreset.custom
                  ? setState(() => _range = true)
                  : widget.onDone((preset: p, from: null, to: null)),
            ),
        ],
      );
    }
    final from = _from;
    return Column(
      key: ValueKey(from == null ? 'from' : 'to'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            (from == null ? l.searchFromTitle : l.searchToTitle).toUpperCase(),
            key: const Key('search-range-step'),
            style: context.text.labelCaps.copyWith(color: context.colors.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.s3),
        MonthCalendar(
          key: ValueKey(from),
          initial: from ?? widget.from,
          today: widget.today,
          onPicked: (d) => from == null
              ? setState(() => _from = d)
              : widget.onDone((preset: DatePreset.custom, from: from, to: d)),
        ),
      ],
    );
  }
}

class _OptionList extends StatelessWidget {
  const _OptionList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final c in children) ...[c, const SizedBox(height: AppSpacing.s2)],
    ],
  );
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.state,
    required this.results,
    required this.groupName,
    required this.onClear,
    required this.onKind,
    required this.onRecent,
  });

  final SearchState state;
  final AsyncValue<SearchEverything> results;

  /// The group filter's name, when one is set.
  final String? groupName;
  final VoidCallback onClear;
  final ValueChanged<SearchKind> onKind;
  final ValueChanged<String> onRecent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    Widget padded(Widget child) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.s4,
        AppSpacing.screen,
        AppSpacing.s8,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: child,
    );
    if (state.idle) {
      final recent = ref.watch(recentSearchesProvider);
      return padded(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (recent.isNotEmpty) ...[
              _RecentSearches(recent: recent, onPick: onRecent),
              const SizedBox(height: AppSpacing.s6),
            ],
            ClipRRect(
              key: const Key('search-start'),
              borderRadius: AppRadii.all28,
              child: BlobBackground(
                child: SizedBox(
                  width: double.infinity,
                  child: EmptyState(
                    icon: AppIcons.search,
                    title: l.search2StartTitle,
                    message: groupName == null
                        ? l.search2StartBody
                        : l.search2StartBodyIn(groupName!),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final found = results.value;
    if (found == null) {
      return results.hasError
          ? padded(EmptyState(icon: AppIcons.warning, title: l.expLoadError))
          : Center(
              child: DotsPulse(color: c.primary, semanticLabel: l.loading),
            );
    }
    if (found.count(SearchKind.all) == 0) {
      return padded(
        EmptyState(
          key: const Key('search-empty'),
          icon: AppIcons.search,
          title: l.searchNoResultsTitle,
          message: l.searchNoResultsBody,
          actions: [
            if (state.hasFilters)
              PillButton(
                key: const Key('search-empty-clear'),
                label: l.searchClearFilters,
                variant: PillVariant.outline,
                expand: false,
                onPressed: onClear,
              ),
          ],
        ),
      );
    }
    // A type that found nothing keeps its chip only while it is picked.
    final kind = state.kind;
    final hits = found.rows(kind);
    final kinds = [
      for (final k in SearchKind.values.skip(1))
        if (found.count(k) > 0 || k == kind) k,
    ];
    final count = hits.length;
    final rows = <Widget>[
      if (kinds.length > 1 || kind != SearchKind.all)
        _KindChips(found: found, kinds: kinds, selected: kind, onPick: onKind),
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s2),
        child: Text(
          found.limited(SearchRepository.limit)
              ? l.searchLimited(SearchRepository.limit)
              : groupName == null
              ? l.search2ResultCount(count)
              : l.search2ResultCountIn(count, groupName!),
          key: const Key('search-count'),
          style: context.text.caption.copyWith(color: c.textSecondary),
        ),
      ),
    ];
    String? month;
    for (var i = 0; i < hits.length; i++) {
      final header = monthHeader(context, hits[i].day);
      if (header != month) {
        month = header;
        rows.add(
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? AppSpacing.s2 : AppSpacing.s6),
            child: Semantics(
              header: true,
              child: Text(
                header.toUpperCase(),
                style: context.text.labelCaps.copyWith(color: c.textSecondary),
              ),
            ),
          ),
        );
      }
      final nextSame = i + 1 < hits.length && monthHeader(context, hits[i + 1].day) == header;
      final allGroups = state.groupId == null;
      rows.add(switch (hits[i]) {
        ExpenseResult(:final hit) => ExpenseRow(
          view: hit.view,
          showDivider: nextSame,
          groupName: allGroups ? hit.groupName : null,
        ),
        PaymentResult(:final hit) => _PaymentHitRow(
          hit: hit,
          showDivider: nextSame,
          showGroup: allGroups,
        ),
        final CommentResult r => _CommentHitRow(
          result: r,
          showDivider: nextSame,
          showGroup: allGroups,
        ),
      });
    }
    return ListView(
      key: const Key('search-results'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.s2,
        AppSpacing.screen,
        AppSpacing.s8,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: rows,
    );
  }
}

/// All · Expenses · Payments · Comments, each with its count; only types that found something.
class _KindChips extends StatelessWidget {
  const _KindChips({
    required this.found,
    required this.kinds,
    required this.selected,
    required this.onPick,
  });

  final SearchEverything found;
  final List<SearchKind> kinds;
  final SearchKind selected;
  final ValueChanged<SearchKind> onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String label(SearchKind k) => switch (k) {
      SearchKind.all => l.search2KindAll,
      SearchKind.expenses => l.search2KindExpenses,
      SearchKind.payments => l.search2KindPayments,
      SearchKind.comments => l.search2KindComments,
    };
    IconData icon(SearchKind k) => switch (k) {
      SearchKind.all => AppIcons.search,
      SearchKind.expenses => AppIcons.receipt,
      SearchKind.payments => AppIcons.payment,
      SearchKind.comments => AppIcons.chat,
    };
    return Semantics(
      container: true,
      label: l.search2KindLabel,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s3),
        child: Wrap(
          key: const Key('search-kinds'),
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: [
            for (final k in [SearchKind.all, ...kinds])
              IconChip(
                key: Key('search-kind-${k.name}'),
                label: l.search2KindChip(label(k), found.count(k)),
                icon: icon(k),
                selected: selected == k,
                onTap: () => onPick(k),
              ),
          ],
        ),
      ),
    );
  }
}

/// "RECENT SEARCHES · Clear" and the last searches; a tap searches again, × forgets one.
class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.recent, required this.onPick});

  final List<String> recent;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final store = ref.read(recentSearchesProvider.notifier);
    return Column(
      key: const Key('search-recent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l.search2Recent.toUpperCase(),
                  style: context.text.labelCaps.copyWith(color: c.textSecondary),
                ),
              ),
            ),
            TextButton(
              key: const Key('search-recent-clear'),
              onPressed: store.clear,
              child: Semantics(
                label: l.search2RecentClearHint,
                excludeSemantics: true,
                child: Text(l.search2RecentClear),
              ),
            ),
          ],
        ),
        for (var i = 0; i < recent.length; i++)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: recent[i],
                      hint: l.search2RecentHint,
                      excludeSemantics: true,
                      onTap: () => onPick(recent[i]),
                      child: Pressable(
                        key: Key('search-recent-$i'),
                        onTap: () => onPick(recent[i]),
                        borderRadius: AppRadii.all16,
                        scale: AppMotion.rowPressScale,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
                          child: Row(
                            children: [
                              Icon(AppIcons.history, size: 20, color: c.textTertiary),
                              const SizedBox(width: AppSpacing.s3),
                              Expanded(
                                child: Text(
                                  recent[i],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  AppIconButton(
                    key: Key('search-recent-remove-$i'),
                    tooltip: l.search2RecentRemove(recent[i]),
                    icon: Icon(AppIcons.close, size: 18, color: c.textTertiary),
                    onPressed: () => store.remove(recent[i]),
                  ),
                ],
              ),
              if (i < recent.length - 1) const DashedDivider(),
            ],
          ),
      ],
    );
  }
}

/// "Asha paid you" · "Payment · 21 Nov · Goa trip", the amount and my side.
class _PaymentHitRow extends StatelessWidget {
  const _PaymentHitRow({required this.hit, required this.showDivider, required this.showGroup});

  final PaymentHit hit;
  final bool showDivider;
  final bool showGroup;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = hit.view;
    final p = v.payment;
    final date = dayMonth(context, parseIsoDate(p.date));
    return AmountRow(
      key: ValueKey('search-payment-${p.id}'),
      title: paymentSentence(l, v),
      caption: showGroup && hit.groupName.isNotEmpty
          ? l.search2PaymentCaption(date, hit.groupName)
          : l.payRowCaption(date),
      amountText: listMoney(p.amount, p.currency.trim()),
      amountCaption: v.iPaid
          ? l.payYouPaid
          : v.iReceived
          ? l.payYouReceived
          : l.expNotInvolved,
      unsynced: v.unsynced,
      showDivider: showDivider,
      leading: TintedIcon(icon: AppIcons.payment, color: context.colors.owedAccent, size: 44),
      onTap: () => unawaited(context.push(PaymentRoutes.detail(p.id))),
    );
  }
}

/// "Asha paid you" / "You paid Asha" for a payment.
String paymentSentence(AppLocalizations l, PaymentView v) {
  String name(String id, {bool start = true}) {
    if (id == v.meId) return start ? l.you : l.youLower;
    final n = v.nameOf(id);
    return n.isEmpty ? l.someone : n;
  }

  return l.settlePaidSentence(name(v.payment.fromMember), name(v.payment.toMember, start: false));
}

/// A comment: its text, "Asha on Dinner · 21 Nov", opening the expense or payment it is on.
class _CommentHitRow extends StatelessWidget {
  const _CommentHitRow({required this.result, required this.showDivider, required this.showGroup});

  final CommentResult result;
  final bool showDivider;
  final bool showGroup;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hit = result.hit;
    final cm = hit.comment;
    final body = cm.body.trim().replaceAll(RegExp(r'\s+'), ' ');
    final snippet = body.length > 90 ? '${body.substring(0, 89).trimRight()}\u2026' : body;
    final target =
        hit.expense?.description ??
        (hit.payment == null ? l.search2CommentTargetPayment : paymentSentence(l, hit.payment!));
    final author = hit.authorName ?? l.someone;
    final date = dayMonth(context, result.at);
    return AmountRow(
      key: ValueKey('search-comment-${cm.id}'),
      title: l.search2CommentTitle(snippet),
      caption: showGroup && hit.groupName.isNotEmpty
          ? l.search2CommentCaptionIn(author, target, date, hit.groupName)
          : l.search2CommentCaption(author, target, date),
      amountText: '',
      unsynced: result.unsynced,
      showDivider: showDivider,
      leading: TintedIcon(icon: AppIcons.chat, color: context.colors.primary, size: 44),
      onTap: () => unawaited(
        context.push(
          cm.targetType == 'payment'
              ? PaymentRoutes.detail(cm.targetId)
              : ExpenseRoutes.detail(cm.targetId),
        ),
      ),
    );
  }
}

/// Search routes (07 §1): `/search`, `/search?group=<id>`.
abstract final class SearchRoutes {
  static String search({String? groupId}) => groupId == null
      ? '/search'
      : Uri(path: '/search', queryParameters: {'group': groupId}).toString();
}

/// Top-level search route (covers the tab shell).
List<RouteBase> searchRoutes() => [
  AppRoute(
    path: '/search',
    builder: (context, state) => SearchScreen(groupId: state.uri.queryParameters['group']),
  ),
];
