import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart' show parseIsoDate;
import 'package:splitify/features/expenses/application/expense_editor_controller.dart'
    show currentUserIdProvider;
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/search/application/search_controller.dart';

/// One payment result (D-034 WP-D, P-5): the payment as the lists show it and its group's name.
typedef PaymentHit = ({PaymentView view, String groupName});

/// One comment result: the comment, its author's name (null when they left), what it is on (an expense
/// or a payment; null when that record is not on this phone) and the group's name.
typedef CommentHit = ({
  LocalComment comment,
  String? authorName,
  LocalExpense? expense,
  PaymentView? payment,
  String groupName,
});

/// A row of the mixed result list, with the local calendar day it is listed under.
sealed class SearchResult {
  const SearchResult();

  /// Local calendar day (month headers, newest first).
  DateTime get day;

  /// Ties within a day: newer first.
  String get stamp;

  SearchKind get kind;

  bool get unsynced;
}

final class ExpenseResult extends SearchResult {
  const ExpenseResult(this.hit);

  final SearchHit hit;

  @override
  DateTime get day => parseIsoDate(hit.view.expense.date);

  @override
  String get stamp => hit.view.expense.createdAt ?? '';

  @override
  SearchKind get kind => SearchKind.expenses;

  @override
  bool get unsynced => hit.view.expense.syncState != SyncState.synced;
}

final class PaymentResult extends SearchResult {
  const PaymentResult(this.hit);

  final PaymentHit hit;

  @override
  DateTime get day => parseIsoDate(hit.view.payment.date);

  @override
  String get stamp => hit.view.payment.createdAt ?? '';

  @override
  SearchKind get kind => SearchKind.payments;

  @override
  bool get unsynced => hit.view.unsynced;
}

final class CommentResult extends SearchResult {
  const CommentResult(this.hit);

  final CommentHit hit;

  /// When the comment was written, on this phone's calendar.
  DateTime get at {
    final raw = hit.comment.createdAt ?? hit.comment.clientUpdatedAt;
    return (raw == null ? null : DateTime.tryParse(raw))?.toLocal() ?? DateTime(1970);
  }

  @override
  DateTime get day {
    final t = at;
    return DateTime(t.year, t.month, t.day);
  }

  @override
  String get stamp => hit.comment.createdAt ?? hit.comment.clientUpdatedAt ?? '';

  @override
  SearchKind get kind => SearchKind.comments;

  @override
  bool get unsynced => hit.comment.syncState != SyncState.synced;
}

/// Everything the search found, per type (each type is cut at `SearchRepository.limit`).
final class SearchEverything {
  const SearchEverything({
    this.expenses = const [],
    this.payments = const [],
    this.comments = const [],
  });

  final List<SearchHit> expenses;
  final List<PaymentHit> payments;
  final List<CommentHit> comments;

  int count(SearchKind kind) => switch (kind) {
    SearchKind.all => expenses.length + payments.length + comments.length,
    SearchKind.expenses => expenses.length,
    SearchKind.payments => payments.length,
    SearchKind.comments => comments.length,
  };

  /// Whether any one type reached the per-type cut.
  bool limited(int limit) =>
      expenses.length >= limit || payments.length >= limit || comments.length >= limit;

  /// The rows for [kind], newest day first; within a day newer records first, then expenses, payments,
  /// comments (stable).
  List<SearchResult> rows(SearchKind kind) {
    final out = <SearchResult>[
      if (kind == SearchKind.all || kind == SearchKind.expenses) ...expenses.map(ExpenseResult.new),
      if (kind == SearchKind.all || kind == SearchKind.payments) ...payments.map(PaymentResult.new),
      if (kind == SearchKind.all || kind == SearchKind.comments) ...comments.map(CommentResult.new),
    ];
    final index = {for (var i = 0; i < out.length; i++) out[i]: i};
    return out..sort((a, b) {
      final byDay = b.day.compareTo(a.day);
      if (byDay != 0) return byDay;
      final byStamp = b.stamp.compareTo(a.stamp);
      return byStamp != 0 ? byStamp : index[a]!.compareTo(index[b]!);
    });
  }
}

final _members = StreamProvider.autoDispose<List<LocalMember>>(
  (ref) => ref.watch(searchRepositoryProvider).watchMembers(),
);

final _paymentMatches = StreamProvider.autoDispose.family<List<LocalPayment>, String?>((
  ref,
  group,
) {
  final s = ref.watch(searchControllerProvider(group));
  return ref.watch(searchRepositoryProvider).watchPayments(s.query, s.filters);
});

typedef _CommentMatches = ({
  List<LocalComment> comments,
  Map<String, LocalExpense> expenses,
  Map<String, LocalPayment> payments,
});

final _commentMatches = StreamProvider.autoDispose.family<_CommentMatches, String?>((ref, group) {
  final s = ref.watch(searchControllerProvider(group));
  final repo = ref.watch(searchRepositoryProvider);
  return repo.watchComments(s.query, s.filters).asyncMap((cs) async {
    final t = await repo.targetsOf(cs);
    return (comments: cs, expenses: t.expenses, payments: t.payments);
  });
});

Map<String, List<LocalMember>> _byGroup(List<LocalMember> members) {
  final out = <String, List<LocalMember>>{};
  for (final m in members) {
    (out[m.groupId] ??= []).add(m);
  }
  return out;
}

AsyncValue<T>? _waiting<T>(List<AsyncValue<Object?>> values) {
  for (final v in values) {
    if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
  }
  if (values.any((v) => !v.hasValue)) return const AsyncLoading();
  return null;
}

/// Payment results for the screen opened from [group], newest first.
final searchPaymentHitsProvider = Provider.autoDispose
    .family<AsyncValue<List<PaymentHit>>, String?>((ref, group) {
      final matches = ref.watch(_paymentMatches(group));
      final members = ref.watch(_members);
      final groups = ref.watch(searchGroupsProvider);
      final wait = _waiting<List<PaymentHit>>([matches, members, groups]);
      if (wait != null) return wait;
      final uid = ref.watch(currentUserIdProvider);
      final names = {for (final g in groups.requireValue) g.id: g.name};
      final byGroup = _byGroup(members.requireValue);
      return AsyncData([
        for (final p in matches.requireValue)
          (
            view: paymentViews([p], byGroup[p.groupId] ?? const [], uid).first,
            groupName: names[p.groupId] ?? '',
          ),
      ]);
    });

/// Comment results for the screen opened from [group], newest first.
final searchCommentHitsProvider = Provider.autoDispose
    .family<AsyncValue<List<CommentHit>>, String?>((ref, group) {
      final matches = ref.watch(_commentMatches(group));
      final members = ref.watch(_members);
      final groups = ref.watch(searchGroupsProvider);
      final wait = _waiting<List<CommentHit>>([matches, members, groups]);
      if (wait != null) return wait;
      final uid = ref.watch(currentUserIdProvider);
      final names = {for (final g in groups.requireValue) g.id: g.name};
      final byGroup = _byGroup(members.requireValue);
      final m = matches.requireValue;
      return AsyncData([
        for (final c in m.comments)
          (
            comment: c,
            authorName: (byGroup[c.groupId] ?? const <LocalMember>[])
                .where((x) => x.userId != null && x.userId == c.createdBy)
                .firstOrNull
                ?.displayName,
            expense: c.targetType == 'expense' ? m.expenses[c.targetId] : null,
            payment: switch (m.payments[c.targetId]) {
              final p? when c.targetType == 'payment' => paymentViews(
                [p],
                byGroup[p.groupId] ?? const [],
                uid,
              ).first,
              _ => null,
            },
            groupName: names[c.groupId] ?? '',
          ),
      ]);
    });

/// Expenses, payments and comments the screen opened from [group] shows (D-034 WP-D, P-5).
final searchEverythingProvider = Provider.autoDispose.family<AsyncValue<SearchEverything>, String?>(
  (ref, group) {
    final expenses = ref.watch(searchResultsProvider(group));
    final payments = ref.watch(searchPaymentHitsProvider(group));
    final comments = ref.watch(searchCommentHitsProvider(group));
    final wait = _waiting<SearchEverything>([expenses, payments, comments]);
    if (wait != null) return wait;
    return AsyncData(
      SearchEverything(
        expenses: expenses.requireValue,
        payments: payments.requireValue,
        comments: comments.requireValue,
      ),
    );
  },
);

/// [recent] with [text] put first: trimmed, the same search (any case) only once, at most [max].
List<String> withRecent(List<String> recent, String text, {int max = RecentSearches.max}) {
  final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return recent;
  return [t, ...recent.where((r) => r.toLowerCase() != t.toLowerCase())].take(max).toList();
}

/// The last [max] searches, kept on this phone only (D-034 WP-D), newest first.
final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);

class RecentSearches extends Notifier<List<String>> {
  /// SharedPreferences key.
  static const storageKey = 'search.recent';
  static const max = 5;

  @override
  List<String> build() {
    final saved = ref.watch(sharedPreferencesProvider).getStringList(storageKey) ?? const [];
    return saved.where((s) => s.trim().isNotEmpty).take(max).toList();
  }

  /// Remembers [text] (nothing when it is blank).
  void add(String text) => _set(withRecent(state, text));

  void remove(String text) => _set([
    for (final r in state)
      if (r != text) r,
  ]);

  void clear() => _set(const []);

  void _set(List<String> next) {
    if (_same(next, state)) return;
    state = next;
    unawaited(ref.read(sharedPreferencesProvider).setStringList(storageKey, next));
  }

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
