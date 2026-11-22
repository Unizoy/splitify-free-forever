import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/data_providers.dart' show clockProvider;
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/search_repository.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart' show parseIsoDate;
import 'package:splitify/features/expenses/presentation/editor/details_step.dart'
    show MonthCalendar;
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart' show ExpenseRow;
import 'package:splitify/features/search/application/search_controller.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Search (`/search?group=`, #34): pill search field (description, notes, people, amount), filter chips
/// (group, person, date, category) and the matching expenses by month. Reads only the phone's own data,
/// so it works offline; rows not synced yet carry the marker.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.groupId, super.key});

  /// Opened from a group: starts filtered to it.
  final String? groupId;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  ExpenseSearchController get _ctrl => ref.read(searchControllerProvider(widget.groupId).notifier);

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = ref.read(clockProvider).now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(searchControllerProvider(widget.groupId));
    final results = ref.watch(searchResultsProvider(widget.groupId));
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
                  IconButton(
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
                      onChanged: _ctrl.setText,
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
              child: _Results(state: s, results: results, onClear: _ctrl.clearFilters),
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
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
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
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: context.text.body,
              cursorColor: c.primary,
              decoration: InputDecoration.collapsed(
                hintText: l.searchFieldHint,
                hintStyle: context.text.body.copyWith(color: c.textTertiary),
              ),
              onChanged: onChanged,
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.text.isEmpty
                ? const SizedBox(width: AppSpacing.s3)
                : IconButton(
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

  Future<void> _pickDates(BuildContext context, ExpenseSearchController ctrl) async {
    final l = AppLocalizations.of(context);
    final picked = await showAppSheet<({DatePreset? preset})>(
      context,
      title: l.searchFilterDate,
      builder: (sheet) => _OptionList(
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
              selected: state.datePreset == p,
              onTap: () => Navigator.of(sheet).pop((preset: p)),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    if (picked.preset != DatePreset.custom) {
      ctrl.setDates(picked.preset, today: today);
      return;
    }
    final from = await _pickDay(context, l.searchFromTitle, state.from ?? today);
    if (from == null || !context.mounted) return;
    final to = await _pickDay(context, l.searchToTitle, state.to ?? today);
    if (to == null) return;
    ctrl.setDates(DatePreset.custom, today: today, from: from, to: to);
  }

  Future<DateTime?> _pickDay(BuildContext context, String title, DateTime initial) =>
      showAppSheet<DateTime>(
        context,
        title: title,
        builder: (sheet) => MonthCalendar(
          initial: initial,
          today: today,
          onPicked: (d) => Navigator.of(sheet).pop(d),
        ),
      );

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

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.results, required this.onClear});

  final SearchState state;
  final AsyncValue<List<SearchHit>> results;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    Widget padded(Widget child) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.s4,
        AppSpacing.screen,
        AppSpacing.s8,
      ),
      child: child,
    );
    if (state.idle) {
      return padded(
        ClipRRect(
          key: const Key('search-start'),
          borderRadius: AppRadii.all28,
          child: BlobBackground(
            child: SizedBox(
              width: double.infinity,
              child: EmptyState(
                icon: AppIcons.search,
                title: l.searchStartTitle,
                message: l.searchStartBody,
              ),
            ),
          ),
        ),
      );
    }
    final hits = results.value;
    if (hits == null) {
      return results.hasError
          ? padded(EmptyState(icon: AppIcons.warning, title: l.expLoadError))
          : Center(
              child: DotsPulse(color: c.primary, semanticLabel: l.loading),
            );
    }
    if (hits.isEmpty) {
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
    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s2),
        child: Text(
          hits.length >= SearchRepository.limit
              ? l.searchLimited(SearchRepository.limit)
              : l.searchResultCount(hits.length),
          key: const Key('search-count'),
          style: context.text.caption.copyWith(color: c.textSecondary),
        ),
      ),
    ];
    String? month;
    for (var i = 0; i < hits.length; i++) {
      final date = parseIsoDate(hits[i].view.expense.date);
      final header = monthHeader(context, date);
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
      final nextSame =
          i + 1 < hits.length &&
          monthHeader(context, parseIsoDate(hits[i + 1].view.expense.date)) == header;
      rows.add(
        ExpenseRow(
          view: hits[i].view,
          showDivider: nextSame,
          groupName: state.groupId == null ? hits[i].groupName : null,
        ),
      );
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

/// Search routes (07 §1): `/search`, `/search?group=<id>`.
abstract final class SearchRoutes {
  static String search({String? groupId}) => groupId == null
      ? '/search'
      : Uri(path: '/search', queryParameters: {'group': groupId}).toString();
}

/// Top-level search route (covers the tab shell).
List<RouteBase> searchRoutes() => [
  GoRoute(
    path: '/search',
    builder: (context, state) => SearchScreen(groupId: state.uri.queryParameters['group']),
  ),
];
