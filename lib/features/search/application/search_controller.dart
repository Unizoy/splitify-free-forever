import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/search_repository.dart';
import 'package:splitify/domain/rules/search_query.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart' show isoDate;
import 'package:splitify/features/expenses/application/expense_editor_controller.dart'
    show currentUserIdProvider;
import 'package:splitify/features/expenses/application/expense_providers.dart';

/// Date filter presets of the search screen (#34); [custom] = two picked days.
enum DatePreset { thisMonth, lastMonth, last3Months, thisYear, custom }

/// A person the search can be narrowed to: one account across groups (`u:<user id>`) or one name-only
/// member (`m:<member id>`), with every member id they have.
typedef SearchPerson = ({String key, String name, Set<String> memberIds});

/// What the search screen holds: the typed text and the filters.
final class SearchState {
  const SearchState({
    this.text = '',
    this.groupId,
    this.person,
    this.datePreset,
    this.from,
    this.to,
    this.category,
  });

  final String text;
  final String? groupId;
  final SearchPerson? person;
  final DatePreset? datePreset;

  /// Inclusive local days of the date filter.
  final DateTime? from;
  final DateTime? to;

  /// Parent category key (`food`).
  final String? category;

  SearchQuery get query => SearchQuery.parse(text);

  SearchFilters get filters => SearchFilters(
    groupId: groupId,
    memberIds: person?.memberIds,
    from: from == null ? null : isoDate(from!),
    to: to == null ? null : isoDate(to!),
    category: category,
  );

  bool get hasFilters =>
      groupId != null || person != null || from != null || to != null || category != null;

  /// Nothing typed and no filter: the start screen.
  bool get idle => query.isEmpty && !hasFilters;

  SearchState copyWith({
    String? text,
    String? Function()? groupId,
    SearchPerson? Function()? person,
    DatePreset? Function()? datePreset,
    DateTime? Function()? from,
    DateTime? Function()? to,
    String? Function()? category,
  }) => SearchState(
    text: text ?? this.text,
    groupId: groupId == null ? this.groupId : groupId(),
    person: person == null ? this.person : person(),
    datePreset: datePreset == null ? this.datePreset : datePreset(),
    from: from == null ? this.from : from(),
    to: to == null ? this.to : to(),
    category: category == null ? this.category : category(),
  );
}

/// The search screen's state; the argument is the group it was opened from (null = all groups).
final searchControllerProvider = NotifierProvider.autoDispose
    .family<ExpenseSearchController, SearchState, String?>(ExpenseSearchController.new);

class ExpenseSearchController extends Notifier<SearchState> {
  ExpenseSearchController(this.initialGroup);

  final String? initialGroup;

  @override
  SearchState build() => SearchState(groupId: initialGroup);

  void setText(String text) => state = state.copyWith(text: text);

  /// Another group; a person who is not in it is dropped.
  void setGroup(String? groupId) =>
      state = state.copyWith(groupId: () => groupId, person: () => null);

  void setPerson(SearchPerson? person) => state = state.copyWith(person: () => person);

  void setCategory(String? category) => state = state.copyWith(category: () => category);

  /// A preset (computed from [today]) or a custom range; null clears the date filter.
  void setDates(DatePreset? preset, {required DateTime today, DateTime? from, DateTime? to}) {
    final range = preset == null ? null : presetRange(preset, today, from: from, to: to);
    state = state.copyWith(datePreset: () => preset, from: () => range?.from, to: () => range?.to);
  }

  void clearFilters() => state = SearchState(text: state.text);
}

/// The days a preset covers on [today] (custom: [from]..[to], swapped when picked backwards).
({DateTime from, DateTime to}) presetRange(
  DatePreset p,
  DateTime today, {
  DateTime? from,
  DateTime? to,
}) {
  final t = DateTime(today.year, today.month, today.day);
  return switch (p) {
    DatePreset.thisMonth => (from: DateTime(t.year, t.month), to: t),
    DatePreset.lastMonth => (from: DateTime(t.year, t.month - 1), to: DateTime(t.year, t.month, 0)),
    DatePreset.last3Months => (from: DateTime(t.year, t.month - 2), to: t),
    DatePreset.thisYear => (from: DateTime(t.year), to: t),
    DatePreset.custom => _ordered(from ?? t, to ?? t),
  };
}

({DateTime from, DateTime to}) _ordered(DateTime a, DateTime b) =>
    a.isAfter(b) ? (from: b, to: a) : (from: a, to: b);

/// One search result: the expense as the lists show it and its group's name.
typedef SearchHit = ({ExpenseView view, String groupName});

final _membersProvider = StreamProvider.autoDispose<List<LocalMember>>(
  (ref) => ref.watch(searchRepositoryProvider).watchMembers(),
);

/// Live groups for the group filter and the result captions (friend groups too).
final searchGroupsProvider = StreamProvider.autoDispose<List<LocalGroup>>(
  (ref) => ref.watch(searchRepositoryProvider).watchGroups(),
);

final _matchesProvider = StreamProvider.autoDispose.family<List<LocalExpense>, String?>((
  ref,
  group,
) {
  final s = ref.watch(searchControllerProvider(group));
  return ref.watch(searchRepositoryProvider).watch(s.query, s.filters);
});

/// The results for the screen opened from [group], newest first.
final searchResultsProvider = Provider.autoDispose.family<AsyncValue<List<SearchHit>>, String?>((
  ref,
  group,
) {
  final matches = ref.watch(_matchesProvider(group));
  final members = ref.watch(_membersProvider);
  final groups = ref.watch(searchGroupsProvider);
  for (final v in [matches, members, groups]) {
    if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
  }
  if (!matches.hasValue || !members.hasValue || !groups.hasValue) return const AsyncLoading();
  final uid = ref.watch(currentUserIdProvider);
  final names = {for (final g in groups.requireValue) g.id: g.name};
  final byGroup = <String, List<LocalMember>>{};
  for (final m in members.requireValue) {
    (byGroup[m.groupId] ??= []).add(m);
  }
  return AsyncData([
    for (final e in matches.requireValue)
      (
        view: expenseViews([e], byGroup[e.groupId] ?? const [], uid).first,
        groupName: names[e.groupId] ?? '',
      ),
  ]);
});

/// People for the person filter: everyone in [group] (or in all groups), except me, by name.
final searchPeopleProvider = Provider.autoDispose.family<List<SearchPerson>, String?>((ref, group) {
  final members = ref.watch(_membersProvider).value ?? const <LocalMember>[];
  final groups = {
    for (final g in ref.watch(searchGroupsProvider).value ?? const <LocalGroup>[]) g.id,
  };
  final uid = ref.watch(currentUserIdProvider);
  final people = <String, SearchPerson>{};
  for (final m in members) {
    if (!groups.contains(m.groupId) || m.deletedAt != null) continue;
    if (uid != null && m.userId == uid) continue;
    if (group != null && m.groupId != group) continue;
    final key = m.userId == null ? 'm:${m.id}' : 'u:${m.userId}';
    final old = people[key];
    people[key] = (
      key: key,
      name: old?.name ?? m.displayName,
      memberIds: {...?old?.memberIds, m.id},
    );
  }
  final list = people.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
});
