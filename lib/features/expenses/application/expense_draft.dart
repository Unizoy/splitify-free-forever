import 'package:splitify/core/money/amount_expression.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';

/// A member as the editor shows it.
typedef EditorMember = ({String id, String name, bool isMe});

/// Field limits (08 cross-cutting rules).
const maxDescription = 120;
const maxNotes = 1000;

/// Why the description cannot be saved.
enum DescriptionProblem { missing, tooLong }

/// Everything the add/edit-expense stepper holds (immutable).
final class ExpenseDraft {
  const ExpenseDraft({
    required this.groupId,
    required this.groupName,
    required this.currency,
    required this.members,
    required this.split,
    required this.date,
    required this.payers,
    this.expenseId,
    this.payerId,
    this.amountText = '',
    this.description = '',
    this.category = 'other.general',
    this.notes = '',
  });

  final String groupId;
  final String groupName;

  /// Null for a new expense.
  final String? expenseId;
  final String currency;

  /// Every member the editor can show, in fixed order (removed people of an old expense last).
  final List<EditorMember> members;
  final SplitDraft split;

  /// Local calendar date.
  final DateTime date;

  /// The one payer (single-payer picker); null when a saved expense has several payers ([payers]).
  final String? payerId;

  /// Saved payer amounts of a multi-payer expense (kept as they are until phase 10's editor).
  final Map<String, int> payers;
  final String amountText;
  final String description;
  final String category;
  final String notes;

  bool get isEdit => expenseId != null;

  AmountResult get amount => AmountExpression.evaluate(amountText, currency);

  /// Total in minor units when the amount is valid.
  int? get total => amount.minorOrNull;

  SplitCheck get splitCheck => split.check(total);

  DescriptionProblem? get descriptionProblem {
    final d = description.trim();
    if (d.isEmpty) return DescriptionProblem.missing;
    if (d.length > maxDescription) return DescriptionProblem.tooLong;
    return null;
  }

  /// What each payer paid for [total].
  Map<String, int> paidFor(int total) => payerId != null ? {payerId!: total} : payers;

  /// True when the payers are consistent with the total.
  bool get payersOk {
    final t = total;
    if (t == null) return false;
    try {
      checkPayers(t, paidFor(t));
      return true;
    } on MoneyError {
      return false;
    }
  }

  /// Amount + description set: the fast-path Save on step 1 is offered.
  bool get fastPathReady => total != null && descriptionProblem == null;

  bool get canSave =>
      fastPathReady && notes.trim().length <= maxNotes && payersOk && splitCheck is SplitReady;

  EditorMember? member(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Snake_case server columns for the repository (money already split by the engine). Throws
  /// [StateError] when not [canSave].
  Map<String, Object?> toRow() {
    final check = splitCheck;
    if (!canSave || check is! SplitReady) throw StateError('expense draft is not valid');
    final t = total!;
    final n = notes.trim();
    return {
      'kind': 'expense',
      'description': description.trim(),
      'notes': n.isEmpty ? null : n,
      'category': category,
      'date': isoDate(date),
      'currency': currency,
      'total': t,
      'payers': paidFor(t),
      'shares': check.shares,
      'split_kind': split.kind.name,
      'split_values': split.storedValues,
    };
  }

  ExpenseDraft copyWith({
    String? amountText,
    String? description,
    String? payerId,
    SplitDraft? split,
    String? category,
    DateTime? date,
    String? notes,
  }) => ExpenseDraft(
    groupId: groupId,
    groupName: groupName,
    expenseId: expenseId,
    currency: currency,
    members: members,
    split: split ?? this.split,
    date: date ?? this.date,
    payerId: payerId ?? this.payerId,
    payers: payers,
    amountText: amountText ?? this.amountText,
    description: description ?? this.description,
    category: category ?? this.category,
    notes: notes ?? this.notes,
  );
}

/// `yyyy-MM-dd` of a local calendar date.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Parses a stored `yyyy-MM-dd` date (time parts ignored) as a local calendar date.
DateTime parseIsoDate(String s) {
  final d = DateTime.parse(s.length >= 10 ? s.substring(0, 10) : s);
  return DateTime(d.year, d.month, d.day);
}

/// The stored kind, equal when unknown.
SplitKind splitKindOf(String name) {
  try {
    return SplitKind.parse(name);
  } on MoneyError {
    return SplitKind.equal;
  }
}
