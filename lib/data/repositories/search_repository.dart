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

  /// Words that find every payment (D-034 WP-D, S-361): "Asha paid" or "settle" still lists payments.
  static const paymentWords = {
    'paid',
    'pay',
    'payment',
    'payments',
    'settle',
    'settled',
    'settlement',
  };

  /// Live payments that match [query] and [filters] (D-034 WP-D, P-5), newest first. Plain local queries:
  /// a word matches inside the payer's or receiver's name (member or linked profile) or the note, a
  /// payment word ([paymentWords]) or the method (`cash`, `upi`, `bank`); a number matches the amount in
  /// the currency's decimals or the note. Payments have no category, so a category filter leaves them out.
  Stream<List<LocalPayment>> watchPayments(SearchQuery query, SearchFilters filters) {
    if ((query.isEmpty && filters.isEmpty) || filters.category != null) {
      return Stream.value(const []);
    }
    final where = <String>[
      'p.deleted_at IS NULL',
      'p.group_id NOT IN (SELECT id FROM groups WHERE deleted_at IS NOT NULL)',
    ];
    final vars = <Variable<Object>>[];
    for (final w in query.words) {
      if (paymentWords.contains(w)) continue;
      where.add(
        '(EXISTS (SELECT 1 FROM group_members m LEFT JOIN profiles pr ON pr.id = m.user_id '
        'WHERE m.id IN (p.from_member, p.to_member) AND (instr(lower(m.display_name), ?) > 0 '
        "OR instr(lower(COALESCE(pr.display_name, '')), ?) > 0)) "
        "OR instr(lower(COALESCE(p.note, '')), ?) > 0 OR lower(p.method) = ?)",
      );
      vars.addAll([for (var i = 0; i < 4; i++) Variable<String>(w)]);
    }
    for (final a in query.amounts) {
      where.add(
        '(p.amount = ${_minorCase('p.currency')} '
        "OR instr(lower(COALESCE(p.note, '')), ?) > 0)",
      );
      vars
        ..addAll(_minorVars(a))
        ..add(Variable<String>(a.text));
    }
    final f = filters;
    if (f.groupId != null) {
      where.add('p.group_id = ?');
      vars.add(Variable<String>(f.groupId!));
    }
    final people = f.memberIds;
    if (people != null) {
      final ids = people.isEmpty ? const [''] : people.toList();
      final marks = List.filled(ids.length, '?').join(', ');
      where.add('(p.from_member IN ($marks) OR p.to_member IN ($marks))');
      vars
        ..addAll(ids.map(Variable<String>.new))
        ..addAll(ids.map(Variable<String>.new));
    }
    if (f.from != null) {
      where.add('p.date >= ?');
      vars.add(Variable<String>(f.from!));
    }
    if (f.to != null) {
      where.add('substr(p.date, 1, 10) <= ?');
      vars.add(Variable<String>(f.to!));
    }
    return db
        .customSelect(
          'SELECT p.* FROM payments p WHERE ${where.join(' AND ')} '
          'ORDER BY p.date DESC, p.created_at DESC, p.id DESC LIMIT $limit',
          variables: vars,
          readsFrom: {db.payments, db.groupMembers, db.profiles, db.groups},
        )
        .watch()
        .map((rows) => [for (final r in rows) db.payments.map(r.data)]);
  }

  /// Live comments on live expenses and payments that match [query] and [filters] (D-034 WP-D, P-5),
  /// newest first: every word and number must be inside the comment text. The person filter means the
  /// author; the category filter keeps comments on expenses of that category; dates are the local day the
  /// comment was written.
  Stream<List<LocalComment>> watchComments(SearchQuery query, SearchFilters filters) {
    if (query.isEmpty && filters.isEmpty) return Stream.value(const []);
    final where = <String>[
      'c.deleted_at IS NULL',
      'c.group_id NOT IN (SELECT id FROM groups WHERE deleted_at IS NOT NULL)',
      "((c.target_type = 'expense' AND c.target_id IN (SELECT id FROM expenses WHERE deleted_at IS NULL)) "
          "OR (c.target_type = 'payment' AND c.target_id IN "
          '(SELECT id FROM payments WHERE deleted_at IS NULL)))',
    ];
    final vars = <Variable<Object>>[];
    for (final term in [...query.words, for (final a in query.amounts) a.text]) {
      where.add('instr(lower(c.body), ?) > 0');
      vars.add(Variable<String>(term));
    }
    final f = filters;
    if (f.groupId != null) {
      where.add('c.group_id = ?');
      vars.add(Variable<String>(f.groupId!));
    }
    final people = f.memberIds;
    if (people != null) {
      final ids = people.isEmpty ? const [''] : people.toList();
      where.add(
        'c.created_by IN (SELECT user_id FROM group_members WHERE user_id IS NOT NULL AND id IN '
        '(${List.filled(ids.length, '?').join(', ')}))',
      );
      vars.addAll(ids.map(Variable<String>.new));
    }
    const day = "date(COALESCE(c.created_at, c.client_updated_at), 'localtime')";
    if (f.from != null) {
      where.add('$day >= ?');
      vars.add(Variable<String>(f.from!));
    }
    if (f.to != null) {
      where.add('$day <= ?');
      vars.add(Variable<String>(f.to!));
    }
    if (f.category != null) {
      where.add(
        "c.target_type = 'expense' AND c.target_id IN (SELECT id FROM expenses "
        "WHERE category = ? OR category LIKE ? || '.%')",
      );
      vars
        ..add(Variable<String>(f.category!))
        ..add(Variable<String>(f.category!));
    }
    return db
        .customSelect(
          'SELECT c.* FROM comments c WHERE ${where.join(' AND ')} '
          'ORDER BY COALESCE(c.created_at, c.client_updated_at) DESC, c.id DESC LIMIT $limit',
          variables: vars,
          readsFrom: {db.comments, db.expenses, db.payments, db.groupMembers, db.groups},
        )
        .watch()
        .map((rows) => [for (final r in rows) db.comments.map(r.data)]);
  }

  /// The expenses and payments [comments] are on (deleted ones too), by id: the result titles.
  Future<({Map<String, LocalExpense> expenses, Map<String, LocalPayment> payments})> targetsOf(
    List<LocalComment> comments,
  ) async {
    final expenseIds = {
      for (final c in comments)
        if (c.targetType == 'expense') c.targetId,
    };
    final paymentIds = {
      for (final c in comments)
        if (c.targetType == 'payment') c.targetId,
    };
    final expenses = expenseIds.isEmpty
        ? const <LocalExpense>[]
        : await (db.select(db.expenses)..where((e) => e.id.isIn(expenseIds))).get();
    final payments = paymentIds.isEmpty
        ? const <LocalPayment>[]
        : await (db.select(db.payments)..where((p) => p.id.isIn(paymentIds))).get();
    return (
      expenses: {for (final e in expenses) e.id: e},
      payments: {for (final p in payments) p.id: p},
    );
  }

  /// `CASE` turning an amount term into minor units of the currency in [column] ([_minorVars] fills it).
  static String _minorCase(String column) {
    final zero = _zeroDecimals.map((_) => '?').join(', ');
    final three = _threeDecimals.map((_) => '?').join(', ');
    return 'CASE WHEN TRIM($column) IN ($zero) THEN ? '
        'WHEN TRIM($column) IN ($three) THEN ? ELSE ? END';
  }

  static List<Variable<Object>> _minorVars(AmountTerm a) => [
    ..._zeroDecimals.map(Variable<String>.new),
    Variable<Object>(a.minorFor(0)),
    ..._threeDecimals.map(Variable<String>.new),
    Variable<Object>(a.minorFor(3)),
    Variable<Object>(a.minorFor(2)),
  ];

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
