import 'package:splitify/core/money/split.dart' show SplitKind;
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';

/// The four one-tap answers of a two-person expense (D-034 A1, Splitwise's "With you and one person").
/// "Owed the full amount" is a normal expense with an exact split (the payer 0, the other person the
/// whole amount), not a loan, so it counts in totals (S-371).
enum TwoPersonAnswer {
  /// You paid, split equally.
  youPaidEqual,

  /// You paid; they owe the full amount.
  youOwedFull,

  /// They paid, split equally.
  theyPaidEqual,

  /// They paid; you owe the full amount.
  theyOwedFull;

  /// The payer is me.
  bool get iPaid => this == youPaidEqual || this == youOwedFull;

  /// The person who did not pay owes everything.
  bool get full => this == youOwedFull || this == theyOwedFull;
}

/// Two-person answers on the draft (D-034 A1).
extension TwoPersonDraft on ExpenseDraft {
  /// Exactly two people, me and one other: a friend, or a group with two active members.
  bool get twoPeople => hasGroup && members.length == 2 && members.where((m) => m.isMe).length == 1;

  /// The other person of a two-person draft.
  EditorMember? get otherPerson => twoPeople ? members.firstWhere((m) => !m.isMe) : null;

  EditorMember? get _me => twoPeople ? members.firstWhere((m) => m.isMe) : null;

  /// The answer the draft matches: the one picked (kept while the amount changes), else the one the
  /// payer and split amount to (a saved expense, or the same choice made through "More options").
  TwoPersonAnswer? get twoPersonAnswer => answer ?? _detect();

  TwoPersonAnswer? _detect() {
    final me = _me;
    final other = otherPerson;
    final payer = payerId;
    if (me == null || other == null || payer == null) return null;
    final iPaid = payer == me.id;
    final owes = iPaid ? other.id : me.id;
    final s = split;
    if (s.isItems) return null;
    if (s.kind == SplitKind.equal) {
      if (s.included.length == 2)
        return iPaid ? TwoPersonAnswer.youPaidEqual : TwoPersonAnswer.theyPaidEqual;
      if (s.included.length == 1 && s.included.single == owes) {
        return iPaid ? TwoPersonAnswer.youOwedFull : TwoPersonAnswer.theyOwedFull;
      }
      return null;
    }
    if (s.kind == SplitKind.exact) {
      final v = s.values;
      final t = total;
      if (v == null || t == null) return null;
      if ((v[payer] ?? 0) == 0 && v[owes] == t)
        return iPaid ? TwoPersonAnswer.youOwedFull : TwoPersonAnswer.theyOwedFull;
    }
    return null;
  }

  /// The draft with [a]: its payer and split; the answer is remembered so "owed the full amount" follows
  /// the amount as it is typed.
  ExpenseDraft withAnswer(TwoPersonAnswer a) {
    final me = _me;
    final other = otherPerson;
    if (me == null || other == null) return this;
    final payer = a.iPaid ? me.id : other.id;
    final owes = a.iPaid ? other.id : me.id;
    final t = total;
    final next = SplitDraft.stored(
      members: split.members,
      exponent: exponent,
      kind: a.full ? SplitKind.exact : SplitKind.equal,
      participants: a.full ? split.members : [me.id, other.id],
      values: a.full && t != null ? {owes: t} : const {},
    );
    return answered(payerId: payer, split: next, answer: a);
  }

  /// [answer] again for the current amount (the amount or currency changed).
  ExpenseDraft reapplyAnswer() {
    final a = answer;
    return a == null || !a.full ? this : withAnswer(a);
  }

  /// What the other person owes me (+) or I owe them (−) with answer [a] for the current amount; null
  /// without a valid amount.
  int? netFor(TwoPersonAnswer a) {
    final me = _me;
    final t = total;
    if (me == null || t == null) return null;
    final check = withAnswer(a).splitCheck;
    if (check is! SplitReady) return null;
    final myShare = check.shares[me.id] ?? 0;
    return a.iPaid ? t - myShare : -myShare;
  }
}
