import 'package:splitify/core/money/amount_expression.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';

/// "I lent" (the viewer is the lender) or "I borrowed".
enum LoanDirection { lent, borrowed }

/// The "Record a loan" form (#11): direction, the other person, amount, what for, date. Saved as an
/// expense with `kind = 'iou'`: the lender pays the total, the borrower's share is the total (05 §4).
final class LoanDraft {
  const LoanDraft({
    required this.groupId,
    required this.groupName,
    required this.currency,
    required this.members,
    required this.selfId,
    required this.date,
    this.selfIsMe = true,
    this.expenseId,
    this.direction = LoanDirection.lent,
    this.personId,
    this.amountText = '',
    this.note = '',
  });

  final String groupId;
  final String groupName;
  final String currency;

  /// Everyone who can take part, in fixed order.
  final List<EditorMember> members;

  /// Whose side the form is written from: the viewer's member, or the lender of a saved loan between
  /// two other people.
  final String selfId;
  final bool selfIsMe;

  /// Null for a new loan.
  final String? expenseId;
  final LoanDirection direction;

  /// The other side of the loan.
  final String? personId;
  final String amountText;

  /// "What for?" (optional; the description falls back to "Loan").
  final String note;
  final DateTime date;

  bool get isEdit => expenseId != null;

  AmountResult get amount => AmountExpression.evaluate(amountText, currency);

  int? get total => amount.minorOrNull;

  /// People the form can pick: everyone except [selfId].
  List<EditorMember> get others => [
    for (final m in members)
      if (m.id != selfId) m,
  ];

  EditorMember? member(String? id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  String? get lenderId => direction == LoanDirection.lent ? selfId : personId;
  String? get borrowerId => direction == LoanDirection.lent ? personId : selfId;

  bool get noteTooLong => note.trim().length > maxDescription;

  bool get canSave =>
      total != null &&
      personId != null &&
      personId != selfId &&
      member(personId) != null &&
      !noteTooLong;

  /// Snake_case server columns (IOU: one payer, one share, payer not in the shares). Throws
  /// [StateError] when not [canSave].
  Map<String, Object?> toRow({required String defaultDescription}) {
    if (!canSave) throw StateError('loan draft is not valid');
    final t = total!;
    final n = note.trim();
    return {
      'kind': 'iou',
      'description': n.isEmpty ? defaultDescription : n,
      'notes': null,
      'category': 'other.general',
      'date': isoDate(date),
      'currency': currency,
      'total': t,
      'payers': {lenderId!: t},
      'shares': {borrowerId!: t},
      'split_kind': 'equal',
      'split_values': null,
    };
  }

  LoanDraft copyWith({
    LoanDirection? direction,
    String? personId,
    String? amountText,
    String? note,
    DateTime? date,
  }) => LoanDraft(
    groupId: groupId,
    groupName: groupName,
    currency: currency,
    members: members,
    selfId: selfId,
    selfIsMe: selfIsMe,
    expenseId: expenseId,
    direction: direction ?? this.direction,
    personId: personId ?? this.personId,
    amountText: amountText ?? this.amountText,
    note: note ?? this.note,
    date: date ?? this.date,
  );
}
