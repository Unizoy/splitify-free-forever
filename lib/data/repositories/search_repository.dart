import 'package:drift/drift.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/rules/search_query.dart';

/// Search filters (#34): group, people (member ids: one person can be a member of several groups), date
/// range (inclusive local calendar days, `YYYY-MM-DD`) and a parent category key (`food`).
final class SearchFilters {
  const SearchFilters({this.groupId, this.memberIds, this.from, this.to, this.category});

  final String? groupId;
  final Set<String>? memberIds;
  final String? from;
  final String? to;
  final String? category;

  bool get isEmpty =>
      groupId == null && memberIds == null && from == null && to == null && category == null;
}

/// Offline search over the phone's own copy (FTS5 table `expense_search`, kept by `SearchIndex`): live
/// expenses (loans too) that match every term and filter, newest first.
class SearchRepository {
  SearchRepository(this.db);

  final AppDatabase db;

  /// At most this many results (newest first); the screen says so when the list is cut.
  static const limit = 200;

  static final _zeroDecimals = [
    for (final c in Currencies.all.values)
      if (c.exponent == 0) c.code,
  ];
  static final _threeDecimals = [
    for (final c in Currencies.all.values)
      if (c.exponent == 3) c.code,
  ];

  /// Matches of [query] and [filters]; an empty query with no filters gives no results.
  Stream<List<LocalExpense>> watch(SearchQuery query, SearchFilters filters) {
    if (query.isEmpty && filters.isEmpty) return Stream.value(const []);
    // Expenses of a deleted group stay out (final QA: they showed with an empty group name).
    final where = <String>[
      'e.deleted_at IS NULL',
      'e.group_id NOT IN (SELECT id FROM groups WHERE deleted_at IS NOT NULL)',
    ];
    final vars = <Variable<Object>>[];
    const fts = 'e.id IN (SELECT expense_id FROM expense_search WHERE expense_search MATCH ?)';
    if (query.words.isNotEmpty) {
      where.add(fts);
      vars.add(Variable<String>(query.words.map(_prefix).join(' ')));
    }
    for (final a in query.amounts) {
      final zero = _zeroDecimals.map((_) => '?').join(', ');
      final three = _threeDecimals.map((_) => '?').join(', ');
      where.add(
        '(e.total = CASE WHEN TRIM(e.currency) IN ($zero) THEN ? '
        'WHEN TRIM(e.currency) IN ($three) THEN ? ELSE ? END OR $fts)',
      );
      vars
        ..addAll(_zeroDecimals.map(Variable<String>.new))
        ..add(Variable<Object>(a.minorFor(0)))
        ..addAll(_threeDecimals.map(Variable<String>.new))
        ..add(Variable<Object>(a.minorFor(3)))
        ..add(Variable<Object>(a.minorFor(2)))
        ..add(Variable<String>(_prefix(a.text)));
    }
    final f = filters;
    if (f.groupId != null) {
      where.add('e.group_id = ?');
      vars.add(Variable<String>(f.groupId!));
    }
    final people = f.memberIds;
    if (people != null) {
      where.add(
        'e.id IN (SELECT expense_id FROM expense_parts WHERE member_id IN '
        '(${List.filled(people.isEmpty ? 1 : people.length, '?').join(', ')}))',
      );
      vars.addAll(people.isEmpty ? [const Variable<String>('')] : people.map(Variable<String>.new));
    }
    if (f.from != null) {
      where.add('e.date >= ?');
      vars.add(Variable<String>(f.from!));
    }
    if (f.to != null) {
      where.add('substr(e.date, 1, 10) <= ?');
      vars.add(Variable<String>(f.to!));
    }
    if (f.category != null) {
      where.add("(e.category = ? OR e.category LIKE ? || '.%')");
      vars
        ..add(Variable<String>(f.category!))
        ..add(Variable<String>(f.category!));
    }
    return db
        .customSelect(
          'SELECT e.* FROM expenses e WHERE ${where.join(' AND ')} '
          'ORDER BY e.date DESC, e.created_at DESC, e.id DESC LIMIT $limit',
          variables: vars,
          readsFrom: {db.expenses, db.expenseSearch, db.expenseParts, db.groups},
        )
        .watch()
        .map((rows) => [for (final r in rows) db.expenses.map(r.data)]);
  }

  /// Every member of every group (names of the people in the results, removed members too).
  Stream<List<LocalMember>> watchMembers() => (db.select(
    db.groupMembers,
  )..orderBy([(m) => OrderingTerm.asc(m.position), (m) => OrderingTerm.asc(m.id)])).watch();

  /// Every live group (names in the results and the group filter), direct (friend) groups included.
  Stream<List<LocalGroup>> watchGroups() =>
      (db.select(db.groups)
            ..where((g) => g.deletedAt.isNull())
            ..orderBy([(g) => OrderingTerm.asc(g.name)]))
          .watch();

  /// FTS5 prefix query of one term, quoted so punctuation is never syntax.
  static String _prefix(String term) => '"${term.replaceAll('"', '""')}"*';
}
