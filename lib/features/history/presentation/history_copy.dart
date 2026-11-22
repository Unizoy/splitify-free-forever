import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart' show splitKindOf;
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/history/application/history_providers.dart';
import 'package:splitify/features/history/domain/version_diff.dart';
import 'package:splitify/l10n/app_localizations.dart';

/// Names on the history screen: "You" for the viewer, "A former member" for people no longer known here.
class HistoryNames {
  const HistoryNames(this.l, this.view);

  final AppLocalizations l;
  final HistoryView view;

  String member(String id) =>
      id == view.meMemberId ? l.you : (view.memberNames[id] ?? l.histFormerMember);

  String user(String? userId) => userId != null && userId == view.meUserId
      ? l.you
      : (view.userNames[userId] ?? l.histFormerMember);
}

/// One displayed change of a [HistoryEntry].
sealed class ChangeRow {
  const ChangeRow(this.label);

  final String label;
}

/// A field with its old and new text (`from` null on a create, or when the field was empty).
final class ValueRow extends ChangeRow {
  const ValueRow(super.label, this.from, this.to, {this.showFrom = true});

  final String? from;
  final String? to;

  /// False for the first version: only the value is shown.
  final bool showFrom;
}

/// Per-member money (paid by / split).
final class MemberRow extends ChangeRow {
  const MemberRow(super.label, this.members, {this.showFrom = true});

  final List<({String name, String? from, String? to})> members;
  final bool showFrom;
}

/// A change told in words ("Receipt added", "Split details changed").
final class NoteRow extends ChangeRow {
  const NoteRow(super.label);
}

/// Headline of an entry ("Asha edited this").
String historyHeadline(AppLocalizations l, HistoryEntry e, HistoryNames n) {
  final who = n.user(e.changedBy);
  return switch (e.op) {
    HistoryOp.create => l.histAdded(who),
    HistoryOp.update => l.histEdited(who),
    HistoryOp.delete => l.histDeleted(who),
    HistoryOp.restore => l.histRestored(who),
    HistoryOp.conflictLost => l.histLostChange(who),
  };
}

/// "21 Nov 2026 · 9:41 pm" in the phone's time zone.
String historyWhen(BuildContext context, DateTime at) {
  final local = at.toLocal();
  final locale = Localizations.localeOf(context).toLanguageTag();
  return AppLocalizations.of(context)
      .histWhen(shortDate(context, local), DateFormat.jm(locale).format(local));
}

/// The rows an entry shows, in field order. Split values are not shown on their own (the per-member split
/// shows their effect); an edit that changed only them reads "Split details changed" (S-133).
List<ChangeRow> historyRows(BuildContext context, HistoryEntry e, HistoryNames n) {
  final l = AppLocalizations.of(context);
  final create = e.op == HistoryOp.create;
  String? money(Object? v) => v is Money ? MoneyFormatter.detail.format(v.minor, v.currency) : null;
  String? text(HistoryField f, Object? v) {
    if (v == null) return null;
    return switch (f) {
      HistoryField.amount => money(v),
      HistoryField.date => shortDate(context, v as DateTime),
      HistoryField.category => l.category(v as String),
      HistoryField.splitKind => l.splitKind(splitKindOf(v as String)),
      HistoryField.kind => v == 'iou' ? l.histKindIou : l.histKindExpense,
      HistoryField.method => switch (v) {
        'cash' => l.histMethodCash,
        'upi' => l.histMethodUpi,
        'bank' => l.histMethodBank,
        _ => l.histMethodOther,
      },
      HistoryField.fromMember || HistoryField.toMember => n.member(v as String),
      _ => (v as String).trim().isEmpty ? null : v.trim(),
    };
  }

  final rows = <ChangeRow>[];
  var splitValuesOnly = false;
  for (final c in e.changes) {
    switch (c.field) {
      case HistoryField.splitValues:
        splitValuesOnly = true;
      case HistoryField.receipt:
        if (create && c.newValue == null) continue;
        rows.add(
          NoteRow(
            c.oldValue == null
                ? l.histReceiptAdded
                : c.newValue == null
                ? l.histReceiptRemoved
                : l.histReceiptReplaced,
          ),
        );
      case HistoryField.payers || HistoryField.shares:
        final label = c.field == HistoryField.payers ? l.histFieldPayers : l.histFieldShares;
        final members = create
            ? [
                for (final m in ((c.newValue as Map?) ?? const {}).entries)
                  if ((m.value as Money).minor != 0)
                    (name: n.member(m.key as String), from: null, to: money(m.value)),
              ]
            : [
                for (final m in c.members)
                  (name: n.member(m.memberId), from: money(m.oldValue), to: money(m.newValue)),
              ];
        if (members.isNotEmpty) rows.add(MemberRow(label, members, showFrom: !create));
      default:
        final to = text(c.field, c.newValue);
        // The first version lists what was filled in; "expense" is the default type.
        if (create && (to == null || (c.field == HistoryField.kind && c.newValue != 'iou'))) {
          continue;
        }
        rows.add(ValueRow(_label(l, c.field), text(c.field, c.oldValue), to, showFrom: !create));
    }
  }
  if (rows.isEmpty && splitValuesOnly && !create) rows.add(NoteRow(l.histSplitDetailsChanged));
  return rows;
}

String _label(AppLocalizations l, HistoryField f) => switch (f) {
  HistoryField.description => l.histFieldDescription,
  HistoryField.amount => l.histFieldAmount,
  HistoryField.date => l.histFieldDate,
  HistoryField.category => l.histFieldCategory,
  HistoryField.splitKind => l.histFieldSplitKind,
  HistoryField.notes => l.histFieldNotes,
  HistoryField.kind => l.histFieldKind,
  HistoryField.method => l.histFieldMethod,
  HistoryField.fromMember => l.histFieldFrom,
  HistoryField.toMember => l.histFieldTo,
  // Rendered as member or note rows.
  HistoryField.payers => l.histFieldPayers,
  HistoryField.shares => l.histFieldShares,
  HistoryField.receipt || HistoryField.splitValues => l.histSplitDetailsChanged,
};
