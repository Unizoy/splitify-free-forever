import 'package:splitify/core/money/amount_expression.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/core/money/scaled_input.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/recurring/application/repeat_draft.dart';

/// A member as the editor shows it.
typedef EditorMember = ({String id, String name, bool isMe});

/// Field limits (08 cross-cutting rules).
const maxDescription = 120;
const maxNotes = 1000;

/// Why the description cannot be saved.
enum DescriptionProblem { missing, tooLong }

/// Where the draft's category came from (auto-category, D-028).
enum CategoryOrigin {
  /// A new expense's starting category (the group's last one); typing a description may replace it.
  initial,

  /// Suggested from the description; follows further typing.
  auto,

  /// Picked by the user in this edit: it sticks, and is learned on save.
  manual,

  /// The saved expense's (or template's) own category: never changed automatically.
  saved,
}

/// Result of checking "Multiple people" payer amounts against the total (#10, 05 §4 Payers).
sealed class PayersCheck {
  const PayersCheck();
}

/// Valid: what each payer paid (only people with an amount, fixed member order; sums to the total).
final class PayersReady extends PayersCheck {
  const PayersReady(this.paid);

  final Map<String, int> paid;
}

/// Not valid yet: `PAYERS_SUM_MISMATCH` with the [remaining] amount (negative = over), `NO_PAYERS`
/// when nobody has an amount, `INVALID_INPUT` for text that is not an amount, `AMOUNT_NOT_POSITIVE`
/// without a total.
final class PayersInvalid extends PayersCheck {
  const PayersInvalid(this.code, [this.remaining = 0]);

  static const invalidInput = 'INVALID_INPUT';
  static const noPayers = 'NO_PAYERS';

  final String code;
  final int remaining;
}

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
    this.payerText,
    this.amountText = '',
    this.description = '',
    this.category = 'other.general',
    this.categoryOrigin = CategoryOrigin.saved,
    String? baseCategory,
    this.notes = '',
    this.receipt = const ReceiptDraft.none(),
    this.repeat = RepeatDraft.never,
    this.canRepeat = false,
    this.templateId,
    this.captureId,
  }) : baseCategory = baseCategory ?? category;

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

  /// The one payer; null while "Multiple people" is chosen (#10).
  final String? payerId;

  /// Saved payer amounts (minor units) of a multi-payer expense: the starting values of "Multiple people".
  final Map<String, int> payers;

  /// Typed per-person amounts once "Multiple people" was edited (null = start from [payers]).
  final Map<String, String>? payerText;
  final String amountText;
  final String description;
  final String category;

  /// How [category] was chosen; only [CategoryOrigin.initial] and [CategoryOrigin.auto] follow the description.
  final CategoryOrigin categoryOrigin;

  /// The category to go back to when the description stops matching anything (the starting one).
  final String baseCategory;
  final String notes;

  /// Receipt photo: unchanged, newly picked or removed (#29).
  final ReceiptDraft receipt;

  /// "Repeat" choice (#12); saved as a template next to the expense.
  final RepeatDraft repeat;

  /// The repeat picker is offered: new expenses, and saved ones that neither repeat yet nor are copies.
  final bool canRepeat;

  /// Set when the editor edits a repeating expense's future copies (its template, #12) instead of one
  /// expense; [date] is then the template's first date and only the repeat can change it.
  final String? templateId;

  /// The captured payment (payment bubble, phase 18b) this new expense starts from: saved with
  /// `source = 'capture'` and the capture is removed from "Payments to add" (S-227).
  final String? captureId;

  bool get isEdit => expenseId != null;

  /// Typing the description may still change the category (a new expense whose category was not picked).
  bool get categoryFollowsDescription =>
      categoryOrigin == CategoryOrigin.initial || categoryOrigin == CategoryOrigin.auto;

  /// The category shown was suggested from the description ("Auto" hint).
  bool get categoryIsAuto => categoryOrigin == CategoryOrigin.auto;

  bool get isTemplate => templateId != null;

  /// The repeat's end date is before the expense date.
  bool get repeatProblem => (canRepeat || isTemplate) && repeat.endsBefore(date);

  AmountResult get amount => AmountExpression.evaluate(amountText, currency);

  /// Total in minor units when the amount is valid.
  int? get total => amount.minorOrNull;

  SplitCheck get splitCheck => split.check(total);

  /// "Multiple people" is chosen.
  bool get multiplePayers => payerId == null;

  /// Currency exponent for typed payer amounts.
  int get exponent => Currencies.exponentOf(currency);

  /// What each person typed under "Multiple people" (saved amounts until edited).
  Map<String, String> get payerInputs =>
      payerText ??
      {
        for (final e in payers.entries)
          if (e.value != 0) e.key: ScaledInput.format(e.value, exponent),
      };

  /// Parsed payer amounts in member order, zeros left out; null when some text is not an amount.
  Map<String, int>? get typedPayers {
    final inputs = payerInputs;
    final ids = [for (final m in members) m.id];
    final out = <String, int>{};
    for (final id in [...ids, ...inputs.keys.where((k) => !ids.contains(k))]) {
      final v = ScaledInput.parse(inputs[id] ?? '', exponent);
      if (v == null) return null;
      if (v != 0) out[id] = v;
    }
    return out;
  }

  /// Sum of the typed payer amounts (live footer), 0 when some text is invalid.
  int get payerSum => (typedPayers ?? const {}).values.fold(0, (a, b) => a + b);

  /// Checks "Multiple people" against the total.
  PayersCheck get payersCheck {
    final t = total;
    if (t == null) return const PayersInvalid('AMOUNT_NOT_POSITIVE');
    if (!multiplePayers) return PayersReady({payerId!: t});
    final typed = typedPayers;
    if (typed == null) return const PayersInvalid(PayersInvalid.invalidInput);
    if (typed.isEmpty) return PayersInvalid(PayersInvalid.noPayers, t);
    try {
      checkPayers(t, typed);
      return PayersReady(typed);
    } on PayersSumMismatch catch (e) {
      return PayersInvalid(e.code, e.remaining);
    } on MoneyError catch (e) {
      return PayersInvalid(e.code);
    }
  }

  DescriptionProblem? get descriptionProblem {
    final d = description.trim();
    if (d.isEmpty) return DescriptionProblem.missing;
    if (d.length > maxDescription) return DescriptionProblem.tooLong;
    return null;
  }

  /// What each payer paid for [total] (empty while "Multiple people" is not valid).
  Map<String, int> paidFor(int total) {
    if (payerId != null) return {payerId!: total};
    final typed = typedPayers;
    return typed ?? const {};
  }

  /// People who paid, in member order (the review sentence "Paid by you and Asha").
  List<String> get payerIds {
    final id = payerId;
    if (id != null) return [id];
    return (typedPayers ?? const <String, int>{}).keys.toList();
  }

  /// True when the payers are consistent with the total.
  bool get payersOk => payersCheck is PayersReady;

  /// Amount + description set: the fast-path Save on step 1 is offered.
  bool get fastPathReady => total != null && descriptionProblem == null;

  bool get canSave =>
      fastPathReady &&
      notes.trim().length <= maxNotes &&
      payersOk &&
      splitCheck is SplitReady &&
      !repeatProblem;

  EditorMember? member(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Snake_case server columns for the repository (money already split by the engine). Throws
  /// [StateError] when not [canSave]. The receipt column is set by the controller (#29).
  Map<String, Object?> toRow() {
    final check = splitCheck;
    final paid = payersCheck;
    if (!canSave || check is! SplitReady || paid is! PayersReady) {
      throw StateError('expense draft is not valid');
    }
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
      'payers': paid.paid,
      'shares': check.shares,
      'split_kind': split.kind.name,
      'split_values': split.storedValues,
      if (captureId != null && expenseId == null) 'source': 'capture',
    };
  }

  /// The expense fields every copy of a repeating expense gets (#12): [toRow] without the date, the
  /// receipt and conversions (those belong to one expense).
  Map<String, Object?> templateFields() => {...toRow()}
    ..remove('date')
    ..remove('source');

  /// Another repeat choice.
  ExpenseDraft withRepeat(RepeatDraft r) =>
      _copy(payerId: payerId, payerText: payerText, repeat: r);

  /// The same draft in [code] (#14 currency picker): typed amounts are checked again for its decimals.
  ExpenseDraft withCurrency(String code) => ExpenseDraft(
    groupId: groupId,
    groupName: groupName,
    expenseId: expenseId,
    currency: code,
    members: members,
    split: split.withExponent(Currencies.exponentOf(code)),
    date: date,
    payerId: payerId,
    payers: payers,
    payerText: payerText,
    amountText: amountText,
    description: description,
    category: category,
    categoryOrigin: categoryOrigin,
    baseCategory: baseCategory,
    notes: notes,
    receipt: receipt,
    repeat: repeat,
    canRepeat: canRepeat,
    templateId: templateId,
    captureId: captureId,
  );

  /// The user picked [key] in the category picker: it sticks for this edit (and is learned on save).
  ExpenseDraft pickCategory(String key) =>
      _copy(payerId: payerId, payerText: payerText, category: key, origin: CategoryOrigin.manual);

  /// The description now suggests [key] (null: nothing): applied only while [categoryFollowsDescription];
  /// without a suggestion the starting category comes back.
  ExpenseDraft withSuggestedCategory(String? key) {
    if (!categoryFollowsDescription) return this;
    return key == null
        ? _copy(
            payerId: payerId,
            payerText: payerText,
            category: baseCategory,
            origin: CategoryOrigin.initial,
          )
        : _copy(payerId: payerId, payerText: payerText, category: key, origin: CategoryOrigin.auto);
  }

  /// One payer for the whole amount.
  ExpenseDraft withSinglePayer(String id) => _copy(payerId: id, payerText: payerText);

  /// "Multiple people": per-person amounts (saved or earlier typed ones are kept).
  ExpenseDraft withMultiplePayers() => _copy(payerId: null, payerText: payerInputs);

  /// Typed amount of [memberId] under "Multiple people".
  ExpenseDraft withPayerText(String memberId, String text) =>
      _copy(payerId: null, payerText: Map.unmodifiable({...payerInputs, memberId: text}));

  ExpenseDraft copyWith({
    String? amountText,
    String? description,
    String? payerId,
    SplitDraft? split,
    String? category,
    DateTime? date,
    String? notes,
    ReceiptDraft? receipt,
  }) => _copy(
    payerId: payerId ?? this.payerId,
    payerText: payerText,
    amountText: amountText,
    description: description,
    split: split,
    category: category,
    date: date,
    notes: notes,
    receipt: receipt,
  );

  ExpenseDraft _copy({
    required String? payerId,
    required Map<String, String>? payerText,
    String? amountText,
    String? description,
    SplitDraft? split,
    String? category,
    DateTime? date,
    String? notes,
    ReceiptDraft? receipt,
    RepeatDraft? repeat,
    CategoryOrigin? origin,
  }) => ExpenseDraft(
    groupId: groupId,
    groupName: groupName,
    expenseId: expenseId,
    currency: currency,
    members: members,
    split: split ?? this.split,
    date: date ?? this.date,
    payerId: payerId,
    payers: payers,
    payerText: payerText,
    amountText: amountText ?? this.amountText,
    description: description ?? this.description,
    category: category ?? this.category,
    categoryOrigin: origin ?? categoryOrigin,
    baseCategory: baseCategory,
    notes: notes ?? this.notes,
    receipt: receipt ?? this.receipt,
    repeat: repeat ?? this.repeat,
    canRepeat: canRepeat,
    templateId: templateId,
    captureId: captureId,
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
